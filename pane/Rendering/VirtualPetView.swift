import SwiftUI
import SceneKit

// MARK: - Virtual Pet Component

struct VirtualPetComponentView: View {
    let widgetID: UUID
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var pet: UserDataStore.PetStateData?
    @State private var isLoaded = false
    @State private var showHeart = false
    @State private var showFood = false
    @State private var showPlayMenu = false
    @State private var activeGame: PetGame? = nil

    enum PetGame: String, CaseIterable {
        case laser = "Laser Chase"
        case fetch = "Fetch Ball"
        case yarn = "Yarn Play"

        var icon: String {
            switch self {
            case .laser: return "light.max"
            case .fetch: return "circle.fill"
            case .yarn: return "circle.dotted"
            }
        }
    }

    private var componentKey: String {
        "\(widgetID.uuidString)#\(component.id ?? "pet")"
    }

    private func tc(_ token: String) -> Color {
        ThemeResolver.color(for: token, theme: theme)
    }

    var body: some View {
        GeometryReader { geo in
            if isLoaded, let pet {
                VStack(spacing: 0) {
                    // 3D Scene
                    ZStack(alignment: .topTrailing) {
                        PetSceneView(
                            pet: pet,
                            theme: theme,
                            activeGame: activeGame,
                            onTap: { handleSceneTap() },
                            onPet: { interact(.pet) },
                            onPlay: { interact(.play) }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        // Floating particles
                        if showHeart {
                            floatingParticle(text: "\u{2764}\u{FE0F}")
                        }
                        if showFood {
                            floatingParticle(text: "\u{1F356}")
                                .offset(x: -30)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.58)

                    Spacer(minLength: 4)

                    // Name
                    Text(component.content ?? "Pixel")
                        .font(.system(size: max(11, min(geo.size.width * 0.055, 16)), weight: .bold, design: .rounded))
                        .foregroundStyle(tc("primary"))
                        .lineLimit(1)

                    if pet.isAlive {
                        // Stat bars
                        VStack(spacing: max(3, geo.size.height * 0.012)) {
                            statBar(label: "HP", value: pet.health, color: petHealthColor(pet.health), width: geo.size.width)
                            statBar(label: "Food", value: pet.hunger, color: .orange, width: geo.size.width)
                            statBar(label: "Joy", value: pet.happiness, color: .pink, width: geo.size.width)
                        }
                        .padding(.horizontal, geo.size.width * 0.08)
                        .padding(.top, 4)

                        // Action buttons
                        HStack(spacing: geo.size.width * 0.03) {
                            petButton(icon: "fork.knife", label: "Feed", width: geo.size.width) {
                                interact(.feed)
                            }
                            petButton(icon: "hand.wave.fill", label: "Pet", width: geo.size.width) {
                                interact(.pet)
                            }
                            petButton(
                                icon: activeGame != nil ? "stop.fill" : "gamecontroller.fill",
                                label: activeGame != nil ? "Stop" : "Play",
                                width: geo.size.width
                            ) {
                                if activeGame != nil {
                                    activeGame = nil
                                    showPlayMenu = false
                                } else {
                                    showPlayMenu.toggle()
                                }
                            }
                        }
                        .padding(.top, 6)

                        // Game selection menu
                        if showPlayMenu && activeGame == nil {
                            HStack(spacing: geo.size.width * 0.02) {
                                ForEach(PetGame.allCases, id: \.rawValue) { game in
                                    Button {
                                        activeGame = game
                                        showPlayMenu = false
                                        interact(.play)
                                    } label: {
                                        VStack(spacing: 1) {
                                            Image(systemName: game.icon)
                                                .font(.system(size: max(9, geo.size.width * 0.04)))
                                            Text(game.rawValue)
                                                .font(.system(size: max(7, geo.size.width * 0.028), weight: .medium, design: .rounded))
                                        }
                                        .foregroundStyle(tc("accent"))
                                        .padding(.horizontal, geo.size.width * 0.02)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(tc("accent").opacity(0.12))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .padding(.top, 3)
                        }

                        // Active game indicator
                        if let game = activeGame {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Playing: \(game.rawValue)")
                                    .font(.system(size: max(8, geo.size.width * 0.032), weight: .medium, design: .rounded))
                                    .foregroundStyle(tc("muted"))
                            }
                            .padding(.top, 2)
                        }
                    } else {
                        Text("R.I.P.")
                            .font(.system(size: max(14, geo.size.width * 0.06), weight: .heavy, design: .rounded))
                            .foregroundStyle(tc("muted"))
                            .padding(.top, 4)

                        if let birth = parseISO(pet.birthDate),
                           let death = parseISO(pet.lastDecayAt) {
                            let days = max(0, Calendar.current.dateComponents([.day], from: birth, to: death).day ?? 0)
                            Text("Lived \(days) day\(days == 1 ? "" : "s")")
                                .font(.system(size: max(9, geo.size.width * 0.04), design: .rounded))
                                .foregroundStyle(tc("muted").opacity(0.6))
                        }
                    }

                    Spacer(minLength: 4)
                }
                .padding(8)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await loadOrCreate() }
    }

    // MARK: - Floating Particle

    @ViewBuilder
    private func floatingParticle(text: String) -> some View {
        Text(text)
            .font(.system(size: 22))
            .padding(6)
            .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale))
    }

    // MARK: - Stat Bar

    @ViewBuilder
    private func statBar(label: String, value: Double, color: Color, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: max(8, width * 0.035), weight: .semibold, design: .rounded))
                .foregroundStyle(tc("muted"))
                .frame(width: width * 0.1, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(value / 100)))
                        .animation(.easeInOut(duration: 0.3), value: value)
                }
            }
            .frame(height: max(5, width * 0.025))
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private func petButton(icon: String, label: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: max(11, width * 0.05)))
                Text(label)
                    .font(.system(size: max(8, width * 0.032), weight: .medium, design: .rounded))
            }
            .foregroundStyle(tc("secondary"))
            .padding(.horizontal, width * 0.03)
            .padding(.vertical, width * 0.018)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tc("accent").opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scene tap

    private func handleSceneTap() {
        guard let p = pet, p.isAlive else { return }
        interact(.pet)
    }

    // MARK: - Helpers

    private func petHealthColor(_ health: Double) -> Color {
        if health > 60 { return .green }
        if health > 30 { return .orange }
        return .red
    }

    // MARK: - Interactions

    private enum PetAction { case feed, pet, play }

    private func interact(_ action: PetAction) {
        guard var p = pet, p.isAlive else { return }
        let now = ISO8601DateFormatter().string(from: Date())

        switch action {
        case .feed:
            p.hunger = min(100, p.hunger + 25)
            p.health = min(100, p.health + 5)
            p.lastFedAt = now
            withAnimation(.spring(response: 0.3)) { showFood = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { showFood = false }
            }
        case .pet:
            p.happiness = min(100, p.happiness + 15)
            p.health = min(100, p.health + 2)
            withAnimation(.spring(response: 0.3)) { showHeart = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { showHeart = false }
            }
        case .play:
            p.happiness = min(100, p.happiness + 20)
            p.hunger = max(0, p.hunger - 10)  // playing is tiring!
            p.health = min(100, p.health + 1)
            p.lastPlayedAt = now
        }

        pet = p
        Task { await UserDataStore.shared.setPetState(p, for: componentKey) }
    }

    // MARK: - Persistence & Decay

    private func loadOrCreate() async {
        if let existing = await UserDataStore.shared.petState(for: componentKey) {
            pet = existing
        } else {
            pet = await UserDataStore.shared.createPet(for: componentKey)
        }
        isLoaded = true
        await decayStats()
        startDecayTimer()
    }

    private func startDecayTimer() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in await decayStats() }
        }
    }

    private func decayStats() async {
        guard var p = pet, p.isAlive else { return }
        let now = Date()
        guard let lastDecay = parseISO(p.lastDecayAt) else { return }
        let elapsed = now.timeIntervalSince(lastDecay)
        guard elapsed >= 60 else { return }
        let minutes = elapsed / 60.0

        p.hunger = max(0, p.hunger - minutes * 0.35)
        p.happiness = max(0, p.happiness - minutes * 0.15)

        if p.hunger <= 0 {
            p.health = max(0, p.health - minutes * 0.5)
        } else if p.hunger < 20 {
            p.health = max(0, p.health - minutes * 0.1)
        }
        if p.hunger > 60 && p.health < 100 {
            p.health = min(100, p.health + minutes * 0.08)
        }
        if p.health <= 0 {
            p.isAlive = false
            p.health = 0
        }

        p.lastDecayAt = ISO8601DateFormatter().string(from: now)
        pet = p
        await UserDataStore.shared.setPetState(p, for: componentKey)
    }

    private func parseISO(_ string: String?) -> Date? {
        guard let string else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }
}

// MARK: - SceneKit 3D Pet Scene

private struct PetSceneView: NSViewRepresentable {
    let pet: UserDataStore.PetStateData
    let theme: WidgetTheme
    let activeGame: VirtualPetComponentView.PetGame?
    let onTap: () -> Void
    let onPet: () -> Void
    let onPlay: () -> Void

    func makeNSView(context: Context) -> PetSCNView {
        let scnView = PetSCNView()
        scnView.coordinator = context.coordinator
        scnView.scene = context.coordinator.buildScene(pet: pet, theme: theme)
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = false  // we handle mouse ourselves
        scnView.autoenablesDefaultLighting = false
        scnView.isJitteringEnabled = true

        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        scnView.addGestureRecognizer(click)

        // Tracking area for mouse movement (laser pointer + petting)
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: context.coordinator,
            userInfo: nil
        )
        scnView.addTrackingArea(trackingArea)

        return scnView
    }

    func updateNSView(_ scnView: PetSCNView, context: Context) {
        context.coordinator.activeGame = activeGame
        context.coordinator.updateMood(pet: pet, in: scnView.scene)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onPet: onPet, onPlay: onPlay)
    }

    // Custom SCNView subclass to forward mouse events to coordinator
    class PetSCNView: SCNView {
        weak var coordinator: Coordinator?

        override func mouseMoved(with event: NSEvent) {
            coordinator?.handleMouseMoved(in: self, event: event)
        }

        override func mouseDragged(with event: NSEvent) {
            coordinator?.handleMouseDragged(in: self, event: event)
        }

        override func mouseExited(with event: NSEvent) {
            coordinator?.handleMouseExited()
        }

        override var acceptsFirstResponder: Bool { true }
    }

    class Coordinator: NSObject {
        let onTap: () -> Void
        let onPet: () -> Void
        let onPlay: () -> Void
        private var petBodyNode: SCNNode?   // the root node of the pet
        private var bodyMeshNode: SCNNode?  // the capsule body mesh
        private var headNode: SCNNode?
        private var leftEyeNode: SCNNode?
        private var rightEyeNode: SCNNode?
        private var leftPupilNode: SCNNode?
        private var rightPupilNode: SCNNode?
        private var mouthNode: SCNNode?
        private var leftCheekNode: SCNNode?
        private var rightCheekNode: SCNNode?
        private var leftArmNode: SCNNode?
        private var rightArmNode: SCNNode?
        private var leftFootNode: SCNNode?
        private var rightFootNode: SCNNode?
        private var leftEarNode: SCNNode?
        private var rightEarNode: SCNNode?
        private var tailNode: SCNNode?
        private var laserDotNode: SCNNode?
        private var laserGlowNode: SCNNode?
        private var isChasing = false
        private var isPettingActive = false
        private var lastPetTime: Date = .distantPast
        private var lastPlayTime: Date = .distantPast
        private var petStrokeCount = 0
        private var sceneRef: SCNScene?
        // Room objects that can be toppled
        private var toyBallNode: SCNNode?
        private var yarnBallNode: SCNNode?
        private var bookStackNode: SCNNode?
        private var plantNode: SCNNode?
        private var cushionNode: SCNNode?
        private var toppledObjects: [SCNNode] = []  // objects currently knocked over
        var activeGame: VirtualPetComponentView.PetGame?

        init(onTap: @escaping () -> Void, onPet: @escaping () -> Void, onPlay: @escaping () -> Void) {
            self.onTap = onTap
            self.onPet = onPet
            self.onPlay = onPlay
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else {
                onTap()
                return
            }

            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])

            // Check if clicked on the pet
            let hitPet = hitResults.contains { result in
                var node: SCNNode? = result.node
                while let n = node {
                    if n === petBodyNode { return true }
                    node = n.parent
                }
                return false
            }

            if hitPet {
                onTap()
                // Bounce + spin on click
                guard let body = petBodyNode else { return }
                let jump = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.4, z: 0, duration: 0.15),
                    SCNAction.group([
                        SCNAction.moveBy(x: 0, y: -0.4, z: 0, duration: 0.15),
                        SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 0.4)
                    ])
                ])
                jump.timingMode = .easeInEaseOut
                body.runAction(jump)
                wiggleEars()
                showHappyFace()

                // Spawn heart particle at hit point
                if let firstHit = hitResults.first {
                    spawnHeartParticle(at: firstHit.worldCoordinates)
                }
            } else if activeGame != nil {
                // Game is active — interact with floor based on game type
                let floorHits = hitResults.filter { result in
                    result.node.geometry is SCNFloor || result.node.name == "floor"
                }
                if let floorHit = floorHits.first {
                    switch activeGame {
                    case .laser:
                        moveLaserDot(to: floorHit.worldCoordinates)
                        chaseLaserDot(target: floorHit.worldCoordinates)
                    case .fetch:
                        // Throw the ball to that spot, pet fetches it
                        throwBall(to: floorHit.worldCoordinates)
                    case .yarn:
                        // Roll yarn there, pet chases
                        rollYarn(to: floorHit.worldCoordinates)
                    case .none:
                        break
                    }
                }
            }
        }

        // MARK: - Mouse Interaction

        func handleMouseMoved(in scnView: SCNView, event: NSEvent) {
            let location = scnView.convert(event.locationInWindow, from: nil)
            let hitResults = scnView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])

            // Laser dot only visible during laser game
            if activeGame == .laser {
                let floorHits = hitResults.filter { $0.node.geometry is SCNFloor || $0.node.name == "floor" }
                if let floorHit = floorHits.first {
                    moveLaserDot(to: floorHit.worldCoordinates)
                }
            }

            // Check if hovering over pet (for visual feedback)
            let overPet = hitResults.contains { result in
                var node: SCNNode? = result.node
                while let n = node {
                    if n === petBodyNode { return true }
                    node = n.parent
                }
                return false
            }

            if overPet {
                headNode?.removeAction(forKey: "look")
                headNode?.runAction(SCNAction.rotateTo(x: 0.1, y: 0, z: 0, duration: 0.2), forKey: "lookAtMouse")
                leftPupilNode?.runAction(SCNAction.move(to: SCNVector3(0, 0.01, 0.065), duration: 0.1))
                rightPupilNode?.runAction(SCNAction.move(to: SCNVector3(0, 0.01, 0.065), duration: 0.1))
            }
        }

        func handleMouseDragged(in scnView: SCNView, event: NSEvent) {
            let location = scnView.convert(event.locationInWindow, from: nil)
            let hitResults = scnView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])

            // Check if dragging over pet = petting!
            let overPet = hitResults.contains { result in
                var node: SCNNode? = result.node
                while let n = node {
                    if n === petBodyNode { return true }
                    node = n.parent
                }
                return false
            }

            if overPet {
                petStrokeCount += 1

                // Visual feedback: pet leans into the touch
                if !isPettingActive {
                    isPettingActive = true
                    bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0.08, y: 0, z: 0, duration: 0.2), forKey: "petLean")
                    // Squint eyes happily
                    leftEyeNode?.runAction(SCNAction.scale(to: 0.6, duration: 0.15), forKey: "petSquint")
                    rightEyeNode?.runAction(SCNAction.scale(to: 0.6, duration: 0.15), forKey: "petSquint")
                    // Purr vibration
                    let purr = SCNAction.sequence([
                        SCNAction.moveBy(x: 0.01, y: 0, z: 0, duration: 0.03),
                        SCNAction.moveBy(x: -0.02, y: 0, z: 0, duration: 0.06),
                        SCNAction.moveBy(x: 0.01, y: 0, z: 0, duration: 0.03)
                    ])
                    petBodyNode?.runAction(.repeatForever(purr), forKey: "purr")
                }

                // Spawn heart particle every few strokes
                if petStrokeCount % 8 == 0, let firstHit = hitResults.first {
                    spawnHeartParticle(at: firstHit.worldCoordinates)
                }

                // Trigger stat boost every ~20 strokes (not too spammy)
                if petStrokeCount % 20 == 0 {
                    let now = Date()
                    if now.timeIntervalSince(lastPetTime) > 2.0 {
                        lastPetTime = now
                        onPet()
                    }
                }
            } else {
                endPetting()
                // If dragging on floor during a game, interact
                if activeGame != nil {
                    let floorHits = hitResults.filter { $0.node.geometry is SCNFloor || $0.node.name == "floor" }
                    if let floorHit = floorHits.first {
                        if activeGame == .laser {
                            moveLaserDot(to: floorHit.worldCoordinates)
                            chaseLaserDot(target: floorHit.worldCoordinates)
                        }
                    }
                }
            }
        }

        func handleMouseExited() {
            endPetting()
            // Hide laser dot
            laserDotNode?.runAction(SCNAction.scale(to: 0.001, duration: 0.2))
            laserGlowNode?.runAction(SCNAction.fadeOut(duration: 0.2))

            // Resume normal head look-around
            if let head = headNode {
                head.removeAction(forKey: "lookAtMouse")
                let lookAround = SCNAction.sequence([
                    SCNAction.wait(duration: 4),
                    SCNAction.rotateBy(x: 0, y: 0.3, z: 0, duration: 0.5),
                    SCNAction.wait(duration: 1.5),
                    SCNAction.rotateBy(x: 0, y: -0.6, z: 0, duration: 0.8),
                    SCNAction.wait(duration: 1.5),
                    SCNAction.rotateBy(x: 0, y: 0.3, z: 0, duration: 0.5),
                    SCNAction.wait(duration: 3)
                ])
                lookAround.timingMode = .easeInEaseOut
                head.runAction(.repeatForever(lookAround), forKey: "look")
            }
        }

        private func endPetting() {
            guard isPettingActive else { return }
            isPettingActive = false
            petStrokeCount = 0
            bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2), forKey: "petLean")
            leftEyeNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.15), forKey: "petSquint")
            rightEyeNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.15), forKey: "petSquint")
            petBodyNode?.removeAction(forKey: "purr")
        }

        // MARK: - Laser Dot (Cat Toy)

        private func buildLaserDot(in scene: SCNScene) {
            // Red laser dot on the floor
            let dotGeo = SCNCylinder(radius: 0.06, height: 0.005)
            let dotMat = SCNMaterial()
            dotMat.diffuse.contents = NSColor.systemRed
            dotMat.emission.contents = NSColor.systemRed
            dotGeo.materials = [dotMat]
            let dot = SCNNode(geometry: dotGeo)
            dot.position = SCNVector3(0, 0.003, 0)
            dot.opacity = 0
            dot.name = "laserDot"
            scene.rootNode.addChildNode(dot)
            laserDotNode = dot

            // Glow ring around dot
            let glowGeo = SCNCylinder(radius: 0.12, height: 0.002)
            let glowMat = SCNMaterial()
            glowMat.diffuse.contents = NSColor.systemRed.withAlphaComponent(0.2)
            glowMat.emission.contents = NSColor.systemRed.withAlphaComponent(0.15)
            glowGeo.materials = [glowMat]
            let glow = SCNNode(geometry: glowGeo)
            glow.position = SCNVector3(0, 0.002, 0)
            glow.opacity = 0
            glow.name = "laserGlow"
            scene.rootNode.addChildNode(glow)
            laserGlowNode = glow

            // Pulsing animation for the glow
            let pulse = SCNAction.sequence([
                SCNAction.scale(to: 1.3, duration: 0.4),
                SCNAction.scale(to: 0.8, duration: 0.4)
            ])
            pulse.timingMode = .easeInEaseOut
            glow.runAction(.repeatForever(pulse))
        }

        private func moveLaserDot(to worldPos: SCNVector3) {
            guard let dot = laserDotNode, let glow = laserGlowNode else { return }

            // Clamp to room bounds
            let x = max(-2.3, min(2.3, CGFloat(worldPos.x)))
            let z = max(-2.0, min(1.5, CGFloat(worldPos.z)))

            let targetPos = SCNVector3(x, 0.003, z)
            let glowPos = SCNVector3(x, 0.002, z)

            dot.runAction(SCNAction.move(to: targetPos, duration: 0.05))
            glow.runAction(SCNAction.move(to: glowPos, duration: 0.05))

            // Show if hidden
            if dot.opacity < 0.5 {
                dot.runAction(SCNAction.fadeIn(duration: 0.15))
                glow.runAction(SCNAction.fadeIn(duration: 0.15))
            }
        }

        private func chaseLaserDot(target worldPos: SCNVector3) {
            guard let body = petBodyNode, !isChasing else { return }
            isChasing = true

            let x = max(-2.3, min(2.3, CGFloat(worldPos.x)))
            let z = max(-2.0, min(1.5, CGFloat(worldPos.z)))

            let currentPos = body.position
            let dx = x - CGFloat(currentPos.x)
            let dz = z - CGFloat(currentPos.z)
            let distance = sqrt(dx * dx + dz * dz)

            guard distance > 0.3 else {
                isChasing = false
                return
            }

            // Face the laser
            let angle = atan2(dx, dz)
            let faceAction = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.15)

            // Run to laser (faster than walk)
            let runDuration = Double(distance) * 0.5
            let moveAction = SCNAction.moveBy(x: dx, y: 0, z: dz, duration: runDuration)
            moveAction.timingMode = .easeOut

            // Excited bouncing while running
            let bounceCount = max(1, Int(runDuration / 0.15))
            var bounces: [SCNAction] = []
            for _ in 0..<bounceCount {
                bounces.append(contentsOf: [
                    SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.075),
                    SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.075)
                ])
            }

            // Pounce at the end!
            let pounce = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.25, z: 0, duration: 0.12),
                SCNAction.moveBy(x: 0, y: -0.25, z: 0, duration: 0.1),
                SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.06),
                SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.06)
            ])

            let faceCamera = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)

            let chase = SCNAction.sequence([
                faceAction,
                SCNAction.group([moveAction, SCNAction.sequence(bounces)]),
                pounce,
                faceCamera
            ])

            // Stop current behavior and chase
            body.removeAction(forKey: "behavior")
            body.runAction(chase, forKey: "chase") { [weak self] in
                self?.isChasing = false
                // Trigger play stat boost
                let now = Date()
                if now.timeIntervalSince(self?.lastPlayTime ?? .distantPast) > 3.0 {
                    self?.lastPlayTime = now
                    DispatchQueue.main.async {
                        self?.onPlay()
                    }
                }
                // Resume random behaviors after a pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    guard let self, let body = self.petBodyNode else { return }
                    self.startRandomBehaviors(body)
                }
            }

            // Arm animation — excited flailing
            leftArmNode?.runAction(SCNAction.sequence([
                SCNAction.rotateTo(x: -0.3, y: 0, z: CGFloat.pi * 0.5, duration: 0.15),
                SCNAction.wait(duration: runDuration),
                SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.2)
            ]))
            rightArmNode?.runAction(SCNAction.sequence([
                SCNAction.rotateTo(x: -0.3, y: 0, z: -CGFloat.pi * 0.5, duration: 0.15),
                SCNAction.wait(duration: runDuration),
                SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2)
            ]))

            // Fast tail wag while chasing
            tailNode?.removeAction(forKey: "tailWag")
            let chaseTailWag = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0.5, z: 0.3, duration: 0.08),
                SCNAction.rotateBy(x: 0, y: -1.0, z: -0.6, duration: 0.16),
                SCNAction.rotateBy(x: 0, y: 0.5, z: 0.3, duration: 0.08)
            ])
            tailNode?.runAction(.repeatForever(chaseTailWag), forKey: "tailWag")
        }

        // MARK: - Fetch Ball Game

        private func throwBall(to worldPos: SCNVector3) {
            guard let ball = toyBallNode, let body = petBodyNode, !isChasing else { return }

            let x = max(-2.0, min(2.0, CGFloat(worldPos.x)))
            let z = max(-1.5, min(1.5, CGFloat(worldPos.z)))

            showSpeechBubble("fetch!")

            // Throw the ball there (arc trajectory)
            ball.runAction(SCNAction.sequence([
                SCNAction.group([
                    SCNAction.move(to: SCNVector3(x, 0.12, z), duration: 0.4),
                    SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 0.2),
                        SCNAction.moveBy(x: 0, y: -0.5, z: 0, duration: 0.2)
                    ]),
                    SCNAction.rotateBy(x: CGFloat.pi * 4, y: CGFloat.pi * 2, z: 0, duration: 0.4)
                ]),
                // Bounce
                SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.1),
                SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.1)
            ]))

            // Pet chases ball after a moment of excitement
            isChasing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }

                let dx = x - CGFloat(body.position.x)
                let dz = z - CGFloat(body.position.z)
                let distance = sqrt(dx * dx + dz * dz)
                let angle = atan2(dx, dz)

                let chase = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.15),
                    SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(distance) * 0.45),
                    // Pounce on ball
                    SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 0.1),
                    SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.08),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
                ])

                body.removeAction(forKey: "behavior")
                body.runAction(chase, forKey: "chase") { [weak self] in
                    self?.isChasing = false
                    self?.showSpeechBubble(["got it!", "woof!", "again!"].randomElement()!)

                    // Return ball to original spot
                    ball.runAction(SCNAction.move(to: SCNVector3(1.2, 0.12, 0.8), duration: 0.8))

                    let now = Date()
                    if now.timeIntervalSince(self?.lastPlayTime ?? .distantPast) > 2.0 {
                        self?.lastPlayTime = now
                        DispatchQueue.main.async { self?.onPlay() }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard let self, let body = self.petBodyNode else { return }
                        self.startRandomBehaviors(body)
                    }
                }
            }
        }

        // MARK: - Yarn Play Game

        private func rollYarn(to worldPos: SCNVector3) {
            guard let yarn = yarnBallNode, let body = petBodyNode, !isChasing else { return }

            let x = max(-1.5, min(1.5, CGFloat(worldPos.x)))
            let z = max(-1.0, min(1.2, CGFloat(worldPos.z)))

            // Roll yarn to target
            yarn.runAction(SCNAction.group([
                SCNAction.move(to: SCNVector3(x, 0.1, z), duration: 0.5),
                SCNAction.rotateBy(x: CGFloat.pi * 6, y: 0, z: CGFloat.pi * 3, duration: 0.5)
            ]))

            isChasing = true

            // Pet stalks then pounces
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }

                let dx = x - CGFloat(body.position.x)
                let dz = z - CGFloat(body.position.z)
                let distance = sqrt(dx * dx + dz * dz)
                let angle = atan2(dx, dz)

                // Crouch down first (stalking)
                self.bodyMeshNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0.15, y: 0, z: 0, duration: 0.2),
                    SCNAction.wait(duration: 0.4),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.15)
                ]))

                // Butt wiggle before pounce
                self.tailNode?.removeAction(forKey: "tailWag")
                let fastWag = SCNAction.sequence([
                    SCNAction.rotateBy(x: 0, y: 0.5, z: 0.3, duration: 0.06),
                    SCNAction.rotateBy(x: 0, y: -1.0, z: -0.6, duration: 0.12),
                    SCNAction.rotateBy(x: 0, y: 0.5, z: 0.3, duration: 0.06)
                ])
                self.tailNode?.runAction(SCNAction.repeat(fastWag, count: 4))

                let stalkAndPounce = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.15),
                    SCNAction.wait(duration: 0.6), // stalking pause
                    // POUNCE!
                    SCNAction.group([
                        SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(distance) * 0.3),
                        SCNAction.sequence([
                            SCNAction.moveBy(x: 0, y: 0.35, z: 0, duration: Double(distance) * 0.15),
                            SCNAction.moveBy(x: 0, y: -0.35, z: 0, duration: Double(distance) * 0.15)
                        ])
                    ]),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
                ])

                body.removeAction(forKey: "behavior")
                body.runAction(stalkAndPounce, forKey: "chase") { [weak self] in
                    self?.isChasing = false
                    self?.showSpeechBubble(["pounce!", "got ya!", "hehe!"].randomElement()!)
                    self?.startTailWag()

                    // Bat yarn around a bit
                    yarn.runAction(SCNAction.sequence([
                        SCNAction.moveBy(x: CGFloat.random(in: -0.3...0.3), y: 0, z: CGFloat.random(in: -0.2...0.2), duration: 0.2),
                        SCNAction.rotateBy(x: CGFloat.pi * 2, y: 0, z: 0, duration: 0.3)
                    ]))

                    let now = Date()
                    if now.timeIntervalSince(self?.lastPlayTime ?? .distantPast) > 2.0 {
                        self?.lastPlayTime = now
                        DispatchQueue.main.async { self?.onPlay() }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard let self, let body = self.petBodyNode else { return }
                        self.startRandomBehaviors(body)
                    }
                }
            }
        }

        // MARK: - Heart Particles in 3D

        private func spawnHeartParticle(at position: SCNVector3) {
            guard let scene = sceneRef else { return }

            let heartGeo = SCNText(string: "\u{2764}\u{FE0F}", extrusionDepth: 0.02)
            heartGeo.font = NSFont.systemFont(ofSize: 0.15)
            heartGeo.flatness = 0.1
            let heartMat = SCNMaterial()
            heartMat.diffuse.contents = NSColor.systemPink
            heartMat.emission.contents = NSColor.systemPink.withAlphaComponent(0.5)
            heartGeo.materials = [heartMat]

            let heart = SCNNode(geometry: heartGeo)
            heart.position = SCNVector3(
                CGFloat(position.x) - 0.07,
                CGFloat(position.y) + 0.2,
                CGFloat(position.z)
            )
            heart.scale = SCNVector3(0.5, 0.5, 0.5)
            scene.rootNode.addChildNode(heart)

            // Float up and fade out
            let floatUp = SCNAction.moveBy(x: CGFloat.random(in: -0.2...0.2), y: 0.8, z: 0, duration: 1.0)
            floatUp.timingMode = .easeOut
            let fadeOut = SCNAction.fadeOut(duration: 0.8)
            let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi, z: 0, duration: 1.0)
            let group = SCNAction.group([floatUp, fadeOut, spin])

            heart.runAction(SCNAction.sequence([group, SCNAction.removeFromParentNode()]))
        }

        func buildScene(pet: UserDataStore.PetStateData, theme: WidgetTheme) -> SCNScene {
            let scene = SCNScene()
            let palette = ThemeResolver.palette(for: theme)

            // Camera
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 45
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 50
            cameraNode.position = SCNVector3(0, 1.8, 4.5)
            cameraNode.look(at: SCNVector3(0, 0.4, 0))
            scene.rootNode.addChildNode(cameraNode)

            // Lighting
            let keyLight = SCNNode()
            keyLight.light = SCNLight()
            keyLight.light?.type = .directional
            keyLight.light?.intensity = 800
            keyLight.light?.color = NSColor.white
            keyLight.light?.castsShadow = true
            keyLight.light?.shadowMode = .deferred
            keyLight.light?.shadowSampleCount = 8
            keyLight.light?.shadowRadius = 3
            keyLight.light?.shadowColor = NSColor.black.withAlphaComponent(0.3)
            keyLight.eulerAngles = SCNVector3(-CGFloat.pi / 3, CGFloat.pi / 5, 0)
            scene.rootNode.addChildNode(keyLight)

            let fillLight = SCNNode()
            fillLight.light = SCNLight()
            fillLight.light?.type = .omni
            fillLight.light?.intensity = 250
            fillLight.light?.color = NSColor(palette.accent).withAlphaComponent(0.4)
            fillLight.position = SCNVector3(-2, 2, 2)
            scene.rootNode.addChildNode(fillLight)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 300
            ambient.light?.color = NSColor.white
            scene.rootNode.addChildNode(ambient)

            // Room
            buildRoom(in: scene, palette: palette)

            // Laser dot (cat toy)
            buildLaserDot(in: scene)

            // Pet character
            let body = buildPet(alive: pet.isAlive, palette: palette)
            scene.rootNode.addChildNode(body)
            petBodyNode = body
            sceneRef = scene

            // Animations
            if pet.isAlive {
                startIdleAnimations(body)
                startBlinking()
            } else {
                // Dead pose - fall over
                body.eulerAngles.z = CGFloat.pi / 2
                body.position.y = 0.25
                body.opacity = 0.5

                // Gray out
                body.enumerateChildNodes { node, _ in
                    if let mat = node.geometry?.firstMaterial {
                        mat.diffuse.contents = NSColor.gray
                    }
                }
            }

            return scene
        }

        private func buildRoom(in scene: SCNScene, palette: ThemePalette) {
            let accent = NSColor(palette.accent)
            let secondary = accent.blended(withFraction: 0.4, of: .white) ?? accent

            // Floor — warm wood-toned
            let floor = SCNFloor()
            floor.reflectivity = 0.12
            floor.reflectionFalloffEnd = 2.5
            let floorMat = SCNMaterial()
            floorMat.diffuse.contents = NSColor(red: 0.85, green: 0.75, blue: 0.62, alpha: 1.0)
            floorMat.roughness.contents = NSColor(white: 0.6, alpha: 1)
            floor.materials = [floorMat]
            let floorNode = SCNNode(geometry: floor)
            floorNode.name = "floor"
            scene.rootNode.addChildNode(floorNode)

            // Colorful round rug in the center
            let rugGeo = SCNCylinder(radius: 1.4, height: 0.01)
            let rugMat = SCNMaterial()
            rugMat.diffuse.contents = accent.withAlphaComponent(0.2)
            rugGeo.materials = [rugMat]
            let rugNode = SCNNode(geometry: rugGeo)
            rugNode.position = SCNVector3(0, 0.005, 0.2)
            scene.rootNode.addChildNode(rugNode)

            // Rug border ring
            let rugBorderGeo = SCNTorus(ringRadius: 1.4, pipeRadius: 0.03)
            let rugBorderMat = SCNMaterial()
            rugBorderMat.diffuse.contents = secondary.withAlphaComponent(0.35)
            rugBorderGeo.materials = [rugBorderMat]
            let rugBorder = SCNNode(geometry: rugBorderGeo)
            rugBorder.position = SCNVector3(0, 0.015, 0.2)
            scene.rootNode.addChildNode(rugBorder)

            // Back wall — warm pastel
            let wallGeo = SCNPlane(width: 6, height: 4)
            let wallMat = SCNMaterial()
            wallMat.diffuse.contents = accent.withAlphaComponent(0.08)
            wallMat.isDoubleSided = true
            wallGeo.materials = [wallMat]
            let wall = SCNNode(geometry: wallGeo)
            wall.position = SCNVector3(0, 2, -2.5)
            scene.rootNode.addChildNode(wall)

            // Side walls
            let sideGeo = SCNPlane(width: 5, height: 4)
            let sideWallMat = SCNMaterial()
            sideWallMat.diffuse.contents = secondary.withAlphaComponent(0.05)
            sideWallMat.isDoubleSided = true
            sideGeo.materials = [sideWallMat]

            let leftWall = SCNNode(geometry: sideGeo)
            leftWall.position = SCNVector3(-3, 2, 0)
            leftWall.eulerAngles.y = CGFloat.pi / 2
            scene.rootNode.addChildNode(leftWall)

            let rightWall = SCNNode(geometry: sideGeo)
            rightWall.position = SCNVector3(3, 2, 0)
            rightWall.eulerAngles.y = -CGFloat.pi / 2
            scene.rootNode.addChildNode(rightWall)

            // --- Window on back wall with stars ---
            let windowFrame = SCNBox(width: 1.2, height: 1.0, length: 0.05, chamferRadius: 0.04)
            let frameMat = SCNMaterial()
            frameMat.diffuse.contents = NSColor(white: 0.9, alpha: 1)
            windowFrame.materials = [frameMat]
            let windowNode = SCNNode(geometry: windowFrame)
            windowNode.position = SCNVector3(1.2, 2.2, -2.47)
            scene.rootNode.addChildNode(windowNode)

            // Night sky behind window
            let skyGeo = SCNPlane(width: 1.0, height: 0.8)
            let skyMat = SCNMaterial()
            skyMat.diffuse.contents = NSColor(red: 0.1, green: 0.1, blue: 0.25, alpha: 1.0)
            skyMat.emission.contents = NSColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0)
            skyGeo.materials = [skyMat]
            let skyNode = SCNNode(geometry: skyGeo)
            skyNode.position = SCNVector3(1.2, 2.2, -2.44)
            scene.rootNode.addChildNode(skyNode)

            // Tiny stars in the window
            for _ in 0..<8 {
                let starGeo = SCNSphere(radius: 0.02)
                let starMat = SCNMaterial()
                starMat.diffuse.contents = NSColor.white
                starMat.emission.contents = NSColor(white: 1, alpha: 0.8)
                starGeo.materials = [starMat]
                let star = SCNNode(geometry: starGeo)
                star.position = SCNVector3(
                    1.2 + CGFloat.random(in: -0.4...0.4),
                    2.2 + CGFloat.random(in: -0.3...0.3),
                    -2.43
                )
                scene.rootNode.addChildNode(star)
                // Twinkle
                let twinkle = SCNAction.sequence([
                    SCNAction.fadeOpacity(to: 0.3, duration: Double.random(in: 0.5...1.5)),
                    SCNAction.fadeOpacity(to: 1.0, duration: Double.random(in: 0.5...1.5))
                ])
                star.runAction(.repeatForever(twinkle))
            }

            // --- Picture frame on back wall ---
            let picFrame = SCNBox(width: 0.7, height: 0.55, length: 0.03, chamferRadius: 0.02)
            let picFrameMat = SCNMaterial()
            picFrameMat.diffuse.contents = NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
            picFrame.materials = [picFrameMat]
            let picNode = SCNNode(geometry: picFrame)
            picNode.position = SCNVector3(-1.0, 2.3, -2.47)
            scene.rootNode.addChildNode(picNode)

            // Picture content (colorful)
            let picContent = SCNPlane(width: 0.55, height: 0.4)
            let picContentMat = SCNMaterial()
            picContentMat.diffuse.contents = accent.withAlphaComponent(0.3)
            picContent.materials = [picContentMat]
            let picContentNode = SCNNode(geometry: picContent)
            picContentNode.position = SCNVector3(-1.0, 2.3, -2.45)
            scene.rootNode.addChildNode(picContentNode)

            // Heart in the picture
            let heartGeo = SCNText(string: "\u{2764}\u{FE0F}", extrusionDepth: 0.01)
            heartGeo.font = NSFont.systemFont(ofSize: 0.12)
            heartGeo.flatness = 0.1
            let heartMat = SCNMaterial()
            heartMat.diffuse.contents = NSColor.systemPink
            heartGeo.materials = [heartMat]
            let heartPicNode = SCNNode(geometry: heartGeo)
            heartPicNode.position = SCNVector3(-1.12, 2.2, -2.43)
            scene.rootNode.addChildNode(heartPicNode)

            // --- Shelf on right wall ---
            let shelfGeo = SCNBox(width: 1.2, height: 0.05, length: 0.3, chamferRadius: 0.01)
            let shelfMat = SCNMaterial()
            shelfMat.diffuse.contents = NSColor(red: 0.65, green: 0.45, blue: 0.25, alpha: 1)
            shelfGeo.materials = [shelfMat]
            let shelfNode = SCNNode(geometry: shelfGeo)
            shelfNode.position = SCNVector3(-1.8, 1.5, -2.0)
            scene.rootNode.addChildNode(shelfNode)

            // Books on shelf (colorful stack)
            let bookColors: [NSColor] = [.systemBlue, .systemGreen, .systemRed, .systemPurple, .systemYellow]
            for (i, color) in bookColors.enumerated() {
                let bookGeo = SCNBox(width: 0.08, height: 0.25, length: 0.18, chamferRadius: 0.005)
                let bookMat = SCNMaterial()
                bookMat.diffuse.contents = color.withAlphaComponent(0.7)
                bookGeo.materials = [bookMat]
                let book = SCNNode(geometry: bookGeo)
                book.position = SCNVector3(
                    -2.15 + CGFloat(i) * 0.15,
                    1.65,
                    -2.0
                )
                // Slight random tilt for natural look
                book.eulerAngles.z = CGFloat.random(in: -0.05...0.05)
                scene.rootNode.addChildNode(book)
            }

            // --- Toy ball (topple-able) ---
            let ball = SCNSphere(radius: 0.12)
            let ballMat = SCNMaterial()
            ballMat.diffuse.contents = NSColor.systemRed.withAlphaComponent(0.7)
            ballMat.metalness.contents = NSColor(white: 0.3, alpha: 1)
            ball.materials = [ballMat]
            let ballNode = SCNNode(geometry: ball)
            ballNode.position = SCNVector3(1.2, 0.12, 0.8)
            ballNode.name = "toyBall"
            scene.rootNode.addChildNode(ballNode)
            toyBallNode = ballNode

            // Ball stripe
            let stripeGeo = SCNTorus(ringRadius: 0.12, pipeRadius: 0.015)
            let stripeMat = SCNMaterial()
            stripeMat.diffuse.contents = NSColor.white.withAlphaComponent(0.6)
            stripeGeo.materials = [stripeMat]
            let stripe = SCNNode(geometry: stripeGeo)
            stripe.eulerAngles.x = CGFloat.pi / 2
            ballNode.addChildNode(stripe)

            // --- Yarn ball (topple-able, rolls away) ---
            let yarnGeo = SCNSphere(radius: 0.1)
            let yarnMat = SCNMaterial()
            yarnMat.diffuse.contents = NSColor.systemPink.withAlphaComponent(0.6)
            yarnMat.roughness.contents = NSColor(white: 0.8, alpha: 1)
            yarnGeo.materials = [yarnMat]
            let yarnNode = SCNNode(geometry: yarnGeo)
            yarnNode.position = SCNVector3(-0.6, 0.1, 1.0)
            yarnNode.name = "yarnBall"
            scene.rootNode.addChildNode(yarnNode)
            yarnBallNode = yarnNode

            // Yarn string trailing
            let stringGeo = SCNCylinder(radius: 0.008, height: 0.4)
            let stringMat = SCNMaterial()
            stringMat.diffuse.contents = NSColor.systemPink.withAlphaComponent(0.5)
            stringGeo.materials = [stringMat]
            let stringNode = SCNNode(geometry: stringGeo)
            stringNode.position = SCNVector3(0, -0.05, 0.05)
            stringNode.eulerAngles.z = CGFloat.pi / 3
            yarnNode.addChildNode(stringNode)

            // --- Cushion / pet bed (topple-able) ---
            let cushGeo = SCNCylinder(radius: 0.35, height: 0.08)
            let cushMat = SCNMaterial()
            cushMat.diffuse.contents = accent.withAlphaComponent(0.3)
            cushMat.roughness.contents = NSColor(white: 0.8, alpha: 1)
            cushGeo.materials = [cushMat]
            let cushNode = SCNNode(geometry: cushGeo)
            cushNode.position = SCNVector3(1.5, 0.04, -0.5)
            cushNode.name = "cushion"
            scene.rootNode.addChildNode(cushNode)
            cushionNode = cushNode

            // Cushion inner circle
            let cushInner = SCNCylinder(radius: 0.25, height: 0.09)
            let cushInnerMat = SCNMaterial()
            cushInnerMat.diffuse.contents = secondary.withAlphaComponent(0.3)
            cushInner.materials = [cushInnerMat]
            let cushInnerNode = SCNNode(geometry: cushInner)
            cushInnerNode.position = SCNVector3(0, 0.01, 0)
            cushNode.addChildNode(cushInnerNode)

            // --- Small plant (topple-able) ---
            // Pot
            let potGeo = SCNCylinder(radius: 0.1, height: 0.15)
            let potMat = SCNMaterial()
            potMat.diffuse.contents = NSColor(red: 0.75, green: 0.45, blue: 0.3, alpha: 1)
            potGeo.materials = [potMat]
            let potNode = SCNNode(geometry: potGeo)
            potNode.position = SCNVector3(-1.6, 0.075, 0.3)
            potNode.name = "plant"
            scene.rootNode.addChildNode(potNode)
            plantNode = potNode

            // Plant leaves (stacked spheres)
            let leafColors: [NSColor] = [
                NSColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.8),
                NSColor(red: 0.25, green: 0.65, blue: 0.35, alpha: 0.7),
                NSColor(red: 0.3, green: 0.75, blue: 0.3, alpha: 0.75)
            ]
            for (i, leafColor) in leafColors.enumerated() {
                let leafGeo = SCNSphere(radius: 0.08 + CGFloat(i) * 0.02)
                let leafMat = SCNMaterial()
                leafMat.diffuse.contents = leafColor
                leafGeo.materials = [leafMat]
                let leaf = SCNNode(geometry: leafGeo)
                leaf.position = SCNVector3(
                    CGFloat.random(in: -0.03...0.03),
                    0.1 + CGFloat(i) * 0.06,
                    CGFloat.random(in: -0.03...0.03)
                )
                potNode.addChildNode(leaf)
            }

            // --- Food bowl ---
            let bowl = SCNTorus(ringRadius: 0.18, pipeRadius: 0.06)
            let bowlMat = SCNMaterial()
            bowlMat.diffuse.contents = NSColor.systemOrange.withAlphaComponent(0.5)
            bowl.materials = [bowlMat]
            let bowlNode = SCNNode(geometry: bowl)
            bowlNode.position = SCNVector3(-1.0, 0.06, 0.8)
            bowlNode.name = "foodBowl"
            scene.rootNode.addChildNode(bowlNode)

            // Food dots in bowl
            for _ in 0..<4 {
                let kibble = SCNSphere(radius: 0.025)
                let kibbleMat = SCNMaterial()
                kibbleMat.diffuse.contents = NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
                kibble.materials = [kibbleMat]
                let kibbleNode = SCNNode(geometry: kibble)
                kibbleNode.position = SCNVector3(
                    CGFloat.random(in: -0.08...0.08),
                    0.04,
                    CGFloat.random(in: -0.08...0.08)
                )
                bowlNode.addChildNode(kibbleNode)
            }

            // --- Book stack on floor (topple-able) ---
            let stackNode = SCNNode()
            stackNode.position = SCNVector3(0.8, 0, -1.0)
            stackNode.name = "bookStack"
            let stackColors: [NSColor] = [.systemTeal, .systemIndigo, .systemOrange]
            for (i, color) in stackColors.enumerated() {
                let bGeo = SCNBox(width: 0.3, height: 0.06, length: 0.22, chamferRadius: 0.008)
                let bMat = SCNMaterial()
                bMat.diffuse.contents = color.withAlphaComponent(0.6)
                bGeo.materials = [bMat]
                let bNode = SCNNode(geometry: bGeo)
                bNode.position = SCNVector3(
                    CGFloat.random(in: -0.02...0.02),
                    0.03 + CGFloat(i) * 0.065,
                    0
                )
                bNode.eulerAngles.y = CGFloat(i) * 0.15
                stackNode.addChildNode(bNode)
            }
            scene.rootNode.addChildNode(stackNode)
            bookStackNode = stackNode

            // --- Small star mobile hanging from ceiling ---
            let mobileRod = SCNCylinder(radius: 0.01, height: 0.6)
            let rodMat = SCNMaterial()
            rodMat.diffuse.contents = NSColor(white: 0.8, alpha: 1)
            mobileRod.materials = [rodMat]
            let rodNode = SCNNode(geometry: mobileRod)
            rodNode.position = SCNVector3(0, 3.2, -1.0)
            scene.rootNode.addChildNode(rodNode)

            // Hanging stars
            let mobileColors: [NSColor] = [.systemYellow, .systemPink, accent, .systemCyan]
            for (i, color) in mobileColors.enumerated() {
                let starShape = SCNSphere(radius: 0.06)
                let sMat = SCNMaterial()
                sMat.diffuse.contents = color.withAlphaComponent(0.6)
                sMat.emission.contents = color.withAlphaComponent(0.2)
                starShape.materials = [sMat]
                let sNode = SCNNode(geometry: starShape)
                let angleOffset = CGFloat(i) * CGFloat.pi / 2
                sNode.position = SCNVector3(
                    sin(angleOffset) * 0.25,
                    2.85,
                    -1.0 + cos(angleOffset) * 0.25
                )
                scene.rootNode.addChildNode(sNode)

                // Thread connecting to rod
                let threadGeo = SCNCylinder(radius: 0.003, height: 0.35)
                let threadMat = SCNMaterial()
                threadMat.diffuse.contents = NSColor(white: 0.7, alpha: 0.5)
                threadGeo.materials = [threadMat]
                let thread = SCNNode(geometry: threadGeo)
                thread.position = SCNVector3(
                    sin(angleOffset) * 0.25,
                    3.02,
                    -1.0 + cos(angleOffset) * 0.25
                )
                scene.rootNode.addChildNode(thread)

                // Gentle swinging
                let swing = SCNAction.sequence([
                    SCNAction.moveBy(x: CGFloat.random(in: -0.05...0.05), y: 0, z: CGFloat.random(in: -0.05...0.05), duration: Double.random(in: 2...4)),
                    SCNAction.moveBy(x: CGFloat.random(in: -0.05...0.05), y: 0, z: CGFloat.random(in: -0.05...0.05), duration: Double.random(in: 2...4))
                ])
                swing.timingMode = .easeInEaseOut
                sNode.runAction(.repeatForever(swing))
            }
        }

        private func buildPet(alive: Bool, palette: ThemePalette) -> SCNNode {
            let root = SCNNode()
            root.position = SCNVector3(0, 0, 0)

            let accentColor = NSColor(palette.accent)
            let lighterAccent = accentColor.blended(withFraction: 0.35, of: .white) ?? accentColor
            let palest = accentColor.blended(withFraction: 0.65, of: .white) ?? accentColor
            let bellyColor = accentColor.blended(withFraction: 0.7, of: .white) ?? accentColor

            // Helper to make soft fluffy material
            func fluffyMat(_ color: NSColor) -> SCNMaterial {
                let m = SCNMaterial()
                m.diffuse.contents = color
                m.roughness.contents = NSColor(white: 0.85, alpha: 1)  // very matte = fluffy look
                m.metalness.contents = NSColor(white: 0.0, alpha: 1)
                // Subtle warm glow
                m.emission.contents = color.withAlphaComponent(0.06)
                return m
            }

            let bodyFluff = fluffyMat(accentColor)

            // ── BODY ── Chubby round sphere (not capsule!) — Kirby/Molang style
            let bodyGeo = SCNSphere(radius: 0.52)
            bodyGeo.segmentCount = 48
            bodyGeo.materials = [bodyFluff]
            let bodyNode = SCNNode(geometry: bodyGeo)
            bodyNode.position = SCNVector3(0, 0.55, 0)
            root.addChildNode(bodyNode)
            bodyMeshNode = bodyNode

            // ── BELLY PATCH ── Soft lighter oval on tummy
            let bellyGeo = SCNSphere(radius: 0.36)
            bellyGeo.segmentCount = 32
            bellyGeo.materials = [fluffyMat(bellyColor)]
            let bellyNode = SCNNode(geometry: bellyGeo)
            bellyNode.position = SCNVector3(0, -0.06, 0.22)
            bellyNode.scale = SCNVector3(0.75, 0.85, 0.35)
            bodyNode.addChildNode(bellyNode)

            // ── HEAD ── Big round head (bigger than body = cuter!)
            let headGeo = SCNSphere(radius: 0.46)
            headGeo.segmentCount = 48
            headGeo.materials = [fluffyMat(accentColor)]
            let head = SCNNode(geometry: headGeo)
            head.position = SCNVector3(0, 0.58, 0)
            bodyNode.addChildNode(head)
            headNode = head

            // ── FLUFFY TUFT ── Little fluff on top of head
            for i in 0..<3 {
                let tuftGeo = SCNSphere(radius: 0.07 - CGFloat(i) * 0.015)
                tuftGeo.materials = [fluffyMat(lighterAccent)]
                let tuft = SCNNode(geometry: tuftGeo)
                tuft.position = SCNVector3(
                    CGFloat(i - 1) * 0.04,
                    0.42 + CGFloat(i) * 0.03,
                    0.02
                )
                head.addChildNode(tuft)
            }

            // ── EYES ── BIG sparkly anime-style eyes
            let eyeWhiteGeo = SCNSphere(radius: 0.13)
            eyeWhiteGeo.segmentCount = 32
            let eyeWhiteMat = SCNMaterial()
            eyeWhiteMat.diffuse.contents = NSColor.white
            eyeWhiteMat.emission.contents = NSColor(white: 1, alpha: 0.1)
            eyeWhiteGeo.materials = [eyeWhiteMat]

            let leftEye = SCNNode(geometry: eyeWhiteGeo)
            leftEye.position = SCNVector3(-0.15, 0.06, 0.38)
            head.addChildNode(leftEye)
            leftEyeNode = leftEye

            let rightEye = SCNNode(geometry: eyeWhiteGeo)
            rightEye.position = SCNVector3(0.15, 0.06, 0.38)
            head.addChildNode(rightEye)
            rightEyeNode = rightEye

            // ── PUPILS ── Large dark pupils with colored iris ring
            let pupilGeo = SCNSphere(radius: 0.075)
            pupilGeo.segmentCount = 24
            let pupilMat = SCNMaterial()
            pupilMat.diffuse.contents = NSColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1)
            pupilGeo.materials = [pupilMat]

            let leftPupil = SCNNode(geometry: pupilGeo)
            leftPupil.position = SCNVector3(0, 0, 0.07)
            leftEye.addChildNode(leftPupil)
            leftPupilNode = leftPupil

            let rightPupil = SCNNode(geometry: pupilGeo)
            rightPupil.position = SCNVector3(0, 0, 0.07)
            rightEye.addChildNode(rightPupil)
            rightPupilNode = rightPupil

            // ── EYE SPARKLES ── Two white highlights per eye (anime style!)
            for eye in [leftPupil, rightPupil] {
                let sparkGeo1 = SCNSphere(radius: 0.025)
                let sparkMat = SCNMaterial()
                sparkMat.diffuse.contents = NSColor.white
                sparkMat.emission.contents = NSColor(white: 1, alpha: 0.9)
                sparkGeo1.materials = [sparkMat]
                let spark1 = SCNNode(geometry: sparkGeo1)
                spark1.position = SCNVector3(0.02, 0.025, 0.05)
                eye.addChildNode(spark1)

                let sparkGeo2 = SCNSphere(radius: 0.015)
                sparkGeo2.materials = [sparkMat]
                let spark2 = SCNNode(geometry: sparkGeo2)
                spark2.position = SCNVector3(-0.015, -0.015, 0.055)
                eye.addChildNode(spark2)
            }

            // ── IRIS RING ── Colored ring around pupil
            for (eye, pupil) in [(leftEye, leftPupil), (rightEye, rightPupil)] {
                let irisGeo = SCNTorus(ringRadius: 0.075, pipeRadius: 0.012)
                let irisMat = SCNMaterial()
                irisMat.diffuse.contents = accentColor.blended(withFraction: 0.2, of: .brown) ?? accentColor
                irisGeo.materials = [irisMat]
                let iris = SCNNode(geometry: irisGeo)
                iris.position = SCNVector3(0, 0, 0.04)
                let _ = eye  // suppress warning
                pupil.addChildNode(iris)
            }

            // ── TINY NOSE ── Little pink button nose
            let noseGeo = SCNSphere(radius: 0.04)
            noseGeo.segmentCount = 16
            let noseMat = SCNMaterial()
            noseMat.diffuse.contents = NSColor(red: 0.95, green: 0.55, blue: 0.6, alpha: 1)
            noseMat.emission.contents = NSColor(red: 0.95, green: 0.55, blue: 0.6, alpha: 0.15)
            noseGeo.materials = [noseMat]
            let nose = SCNNode(geometry: noseGeo)
            nose.position = SCNVector3(0, -0.04, 0.43)
            nose.scale = SCNVector3(1.0, 0.7, 0.6)
            head.addChildNode(nose)

            // ── MOUTH ── Tiny curved smile (small torus, half-hidden)
            let mouthGeo = SCNTorus(ringRadius: 0.05, pipeRadius: 0.012)
            let mouthMat = SCNMaterial()
            mouthMat.diffuse.contents = NSColor(red: 0.9, green: 0.45, blue: 0.5, alpha: 0.8)
            mouthGeo.materials = [mouthMat]
            let mouth = SCNNode(geometry: mouthGeo)
            mouth.position = SCNVector3(0, -0.1, 0.4)
            mouth.eulerAngles.x = CGFloat.pi / 5
            mouth.scale = SCNVector3(1, 0.5, 1)  // flatten to a cute line
            head.addChildNode(mouth)
            mouthNode = mouth

            // ── CHEEKS ── Big rosy blush circles
            let cheekGeo = SCNSphere(radius: 0.08)
            cheekGeo.segmentCount = 16
            let cheekMat = SCNMaterial()
            cheekMat.diffuse.contents = NSColor.systemPink.withAlphaComponent(0.3)
            cheekMat.emission.contents = NSColor.systemPink.withAlphaComponent(0.08)
            cheekGeo.materials = [cheekMat]

            let leftCheek = SCNNode(geometry: cheekGeo)
            leftCheek.position = SCNVector3(-0.28, -0.04, 0.3)
            leftCheek.scale = SCNVector3(1, 0.6, 0.4)  // flatten into blush ovals
            head.addChildNode(leftCheek)
            leftCheekNode = leftCheek

            let rightCheek = SCNNode(geometry: cheekGeo)
            rightCheek.position = SCNVector3(0.28, -0.04, 0.3)
            rightCheek.scale = SCNVector3(1, 0.6, 0.4)
            head.addChildNode(rightCheek)
            rightCheekNode = rightCheek

            // ── EARS ── Soft rounded cat-like ears
            let earGeo = SCNSphere(radius: 0.14)
            earGeo.segmentCount = 24
            let earMat = fluffyMat(lighterAccent)

            let leftEar = SCNNode(geometry: earGeo)
            leftEar.position = SCNVector3(-0.26, 0.38, -0.05)
            leftEar.scale = SCNVector3(0.7, 1.1, 0.5)  // pointy-ish shape
            leftEar.eulerAngles.z = 0.25
            head.addChildNode(leftEar)
            leftEarNode = leftEar

            let rightEar = SCNNode(geometry: earGeo)
            rightEar.position = SCNVector3(0.26, 0.38, -0.05)
            rightEar.scale = SCNVector3(0.7, 1.1, 0.5)
            rightEar.eulerAngles.z = -0.25
            head.addChildNode(rightEar)
            rightEarNode = rightEar

            // Inner ear (pink)
            let innerEarGeo = SCNSphere(radius: 0.07)
            innerEarGeo.segmentCount = 16
            let innerEarMat = SCNMaterial()
            innerEarMat.diffuse.contents = NSColor(red: 1, green: 0.7, blue: 0.75, alpha: 0.6)
            innerEarGeo.materials = [innerEarMat]

            let leftInnerEar = SCNNode(geometry: innerEarGeo)
            leftInnerEar.position = SCNVector3(0, 0, 0.04)
            leftEar.addChildNode(leftInnerEar)

            let rightInnerEar = SCNNode(geometry: innerEarGeo)
            rightInnerEar.position = SCNVector3(0, 0, 0.04)
            rightEar.addChildNode(rightInnerEar)

            // ── TINY BOW ── Cute accessory on right ear
            let bowCenter = SCNSphere(radius: 0.03)
            let bowMat = SCNMaterial()
            bowMat.diffuse.contents = NSColor.systemPink
            bowMat.emission.contents = NSColor.systemPink.withAlphaComponent(0.2)
            bowCenter.materials = [bowMat]
            let bowNode = SCNNode(geometry: bowCenter)
            bowNode.position = SCNVector3(0.05, 0.08, 0.06)
            rightEar.addChildNode(bowNode)

            // Bow loops
            let bowLoopGeo = SCNSphere(radius: 0.04)
            bowLoopGeo.materials = [bowMat]
            let bowLeft = SCNNode(geometry: bowLoopGeo)
            bowLeft.position = SCNVector3(-0.04, 0.01, 0)
            bowLeft.scale = SCNVector3(1.2, 0.7, 0.5)
            bowNode.addChildNode(bowLeft)
            let bowRight = SCNNode(geometry: bowLoopGeo)
            bowRight.position = SCNVector3(0.04, 0.01, 0)
            bowRight.scale = SCNVector3(1.2, 0.7, 0.5)
            bowNode.addChildNode(bowRight)

            // ── BANDANA / SCARF ── Around the neck area
            let scarfGeo = SCNTorus(ringRadius: 0.3, pipeRadius: 0.05)
            let scarfMat = SCNMaterial()
            let scarfColor = NSColor.systemRed.blended(withFraction: 0.3, of: accentColor) ?? .systemRed
            scarfMat.diffuse.contents = scarfColor.withAlphaComponent(0.7)
            scarfMat.roughness.contents = NSColor(white: 0.7, alpha: 1)
            scarfGeo.materials = [scarfMat]
            let scarf = SCNNode(geometry: scarfGeo)
            scarf.position = SCNVector3(0, 0.26, 0)
            scarf.eulerAngles.x = 0.1
            bodyNode.addChildNode(scarf)

            // Scarf knot
            let knotGeo = SCNSphere(radius: 0.06)
            knotGeo.materials = [scarfMat]
            let knot = SCNNode(geometry: knotGeo)
            knot.position = SCNVector3(0, -0.02, 0.3)
            scarf.addChildNode(knot)

            // Scarf tails hanging from knot
            let tailPieceGeo = SCNCapsule(capRadius: 0.025, height: 0.14)
            tailPieceGeo.materials = [scarfMat]
            let scarfTail1 = SCNNode(geometry: tailPieceGeo)
            scarfTail1.position = SCNVector3(-0.03, -0.09, 0.02)
            scarfTail1.eulerAngles.z = 0.2
            knot.addChildNode(scarfTail1)
            let scarfTail2 = SCNNode(geometry: tailPieceGeo)
            scarfTail2.position = SCNVector3(0.03, -0.1, 0.02)
            scarfTail2.eulerAngles.z = -0.15
            knot.addChildNode(scarfTail2)

            // ── ARMS ── Stubby round little paws
            let armGeo = SCNCapsule(capRadius: 0.09, height: 0.22)
            armGeo.materials = [bodyFluff]

            let leftArm = SCNNode(geometry: armGeo)
            leftArm.position = SCNVector3(-0.45, 0.05, 0.1)
            leftArm.eulerAngles.z = CGFloat.pi / 5
            bodyNode.addChildNode(leftArm)
            leftArmNode = leftArm

            let rightArm = SCNNode(geometry: armGeo)
            rightArm.position = SCNVector3(0.45, 0.05, 0.1)
            rightArm.eulerAngles.z = -CGFloat.pi / 5
            bodyNode.addChildNode(rightArm)
            rightArmNode = rightArm

            // Little paw pads (pink circles on paw tips)
            let pawPadGeo = SCNSphere(radius: 0.035)
            let pawPadMat = SCNMaterial()
            pawPadMat.diffuse.contents = NSColor(red: 1, green: 0.7, blue: 0.75, alpha: 0.7)
            pawPadGeo.materials = [pawPadMat]

            let leftPad = SCNNode(geometry: pawPadGeo)
            leftPad.position = SCNVector3(0, -0.11, 0.05)
            leftArm.addChildNode(leftPad)
            let rightPad = SCNNode(geometry: pawPadGeo)
            rightPad.position = SCNVector3(0, -0.11, 0.05)
            rightArm.addChildNode(rightPad)

            // ── FEET ── Round stubby feet
            let footGeo = SCNSphere(radius: 0.13)
            footGeo.segmentCount = 24
            footGeo.materials = [bodyFluff]

            let leftFoot = SCNNode(geometry: footGeo)
            leftFoot.position = SCNVector3(-0.2, -0.45, 0.08)
            leftFoot.scale = SCNVector3(1, 0.6, 1.2)  // flattened oval
            bodyNode.addChildNode(leftFoot)
            leftFootNode = leftFoot

            let rightFoot = SCNNode(geometry: footGeo)
            rightFoot.position = SCNVector3(0.2, -0.45, 0.08)
            rightFoot.scale = SCNVector3(1, 0.6, 1.2)
            bodyNode.addChildNode(rightFoot)
            rightFootNode = rightFoot

            // Foot paw pads
            let footPadGeo = SCNSphere(radius: 0.04)
            footPadGeo.materials = [pawPadMat]
            let leftFootPad = SCNNode(geometry: footPadGeo)
            leftFootPad.position = SCNVector3(0, -0.04, 0.06)
            leftFoot.addChildNode(leftFootPad)
            let rightFootPad = SCNNode(geometry: footPadGeo)
            rightFootPad.position = SCNVector3(0, -0.04, 0.06)
            rightFoot.addChildNode(rightFootPad)

            // ── TAIL ── Fluffy round pom-pom tail
            let tailGeo = SCNSphere(radius: 0.13)
            tailGeo.segmentCount = 24
            tailGeo.materials = [fluffyMat(palest)]
            let tail = SCNNode(geometry: tailGeo)
            tail.position = SCNVector3(0, -0.1, -0.48)
            bodyNode.addChildNode(tail)
            tailNode = tail

            // Extra fluff on tail
            let tailFluffGeo = SCNSphere(radius: 0.08)
            tailFluffGeo.materials = [fluffyMat(lighterAccent)]
            let tailFluff = SCNNode(geometry: tailFluffGeo)
            tailFluff.position = SCNVector3(0, 0.06, -0.06)
            tail.addChildNode(tailFluff)

            // ── WHISKERS ── Tiny subtle whisker lines
            let whiskerMat = SCNMaterial()
            whiskerMat.diffuse.contents = NSColor(white: 0.7, alpha: 0.3)
            for side: CGFloat in [-1, 1] {
                for i in 0..<2 {
                    let wGeo = SCNCylinder(radius: 0.004, height: 0.12)
                    wGeo.materials = [whiskerMat]
                    let w = SCNNode(geometry: wGeo)
                    w.position = SCNVector3(
                        side * 0.22,
                        -0.05 + CGFloat(i) * 0.04,
                        0.38
                    )
                    w.eulerAngles.z = CGFloat.pi / 2 + side * 0.15
                    w.eulerAngles.x = CGFloat(i) * 0.1 - 0.05
                    head.addChildNode(w)
                }
            }

            return root
        }

        // MARK: - Animations

        private func startIdleAnimations(_ root: SCNNode) {
            // Gentle breathing/bounce
            let breathe = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 1.5),
                SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 1.5)
            ])
            breathe.timingMode = .easeInEaseOut
            root.runAction(.repeatForever(breathe), forKey: "breathe")

            // Subtle side sway
            let sway = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0, z: 0.04, duration: 2.0),
                SCNAction.rotateBy(x: 0, y: 0, z: -0.08, duration: 4.0),
                SCNAction.rotateBy(x: 0, y: 0, z: 0.04, duration: 2.0)
            ])
            sway.timingMode = .easeInEaseOut
            root.runAction(.repeatForever(sway), forKey: "sway")

            // Head look-around
            if let head = headNode {
                let lookAround = SCNAction.sequence([
                    SCNAction.wait(duration: 4),
                    SCNAction.rotateBy(x: 0, y: 0.3, z: 0, duration: 0.5),
                    SCNAction.wait(duration: 1.5),
                    SCNAction.rotateBy(x: 0, y: -0.6, z: 0, duration: 0.8),
                    SCNAction.wait(duration: 1.5),
                    SCNAction.rotateBy(x: 0, y: 0.3, z: 0, duration: 0.5),
                    SCNAction.wait(duration: 3)
                ])
                lookAround.timingMode = .easeInEaseOut
                head.runAction(.repeatForever(lookAround), forKey: "look")

                // Occasional head tilt (cute!)
                let headTilt = SCNAction.sequence([
                    SCNAction.wait(duration: Double.random(in: 7...12)),
                    SCNAction.rotateBy(x: 0, y: 0, z: 0.15, duration: 0.3),
                    SCNAction.wait(duration: 1.0),
                    SCNAction.rotateBy(x: 0, y: 0, z: -0.15, duration: 0.3)
                ])
                headTilt.timingMode = .easeInEaseOut
                head.runAction(.repeatForever(headTilt), forKey: "headTilt")
            }

            // Tail wag
            startTailWag()

            // Random behaviors: walk, dance, jump — cycled
            startRandomBehaviors(root)
        }

        private func startTailWag() {
            guard let tail = tailNode else { return }
            let wag = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0.3, z: 0.2, duration: 0.2),
                SCNAction.rotateBy(x: 0, y: -0.6, z: -0.4, duration: 0.4),
                SCNAction.rotateBy(x: 0, y: 0.3, z: 0.2, duration: 0.2)
            ])
            wag.timingMode = .easeInEaseOut
            tail.runAction(.repeatForever(wag), forKey: "tailWag")
        }

        private func startRandomBehaviors(_ root: SCNNode) {
            let behaviors: [() -> SCNAction] = [
                { [weak self] in self?.walkAction(root) ?? SCNAction.wait(duration: 1) },
                { [weak self] in self?.playWithToyAction(root) ?? SCNAction.wait(duration: 1) },
                { [weak self] in self?.danceAction(root) ?? SCNAction.wait(duration: 1) },
                { self.jumpAction() },
                { [weak self] in self?.playWithToyAction(root) ?? SCNAction.wait(duration: 1) },
                { [weak self] in self?.stretchAction() ?? SCNAction.wait(duration: 1) },
                { [weak self] in self?.screenEscapeAction() ?? SCNAction.wait(duration: 1) },
                { [weak self] in self?.walkAction(root) ?? SCNAction.wait(duration: 1) },
                { [weak self] in self?.batYarnAction(root) ?? SCNAction.wait(duration: 1) },
            ]

            func runNext(_ index: Int) {
                let pause = SCNAction.wait(duration: Double.random(in: 4...7))
                let action = behaviors[index % behaviors.count]()
                let seq = SCNAction.sequence([pause, action])
                root.runAction(seq, forKey: "behavior") { [weak root] in
                    guard let root else { return }
                    DispatchQueue.main.async {
                        runNext(index + 1)
                    }
                }
            }
            runNext(0)
        }

        // MARK: - Walk Animation

        private func walkAction(_ root: SCNNode) -> SCNAction {
            // Pick a random target position within the room
            let targetX = CGFloat.random(in: -1.2...1.2)
            let targetZ = CGFloat.random(in: -0.5...1.0)
            let currentPos = root.position
            let dx = targetX - CGFloat(currentPos.x)
            let dz = targetZ - CGFloat(currentPos.z)
            let distance = sqrt(dx * dx + dz * dz)
            let walkDuration = Double(distance) * 1.2  // speed

            // Face the direction of movement
            let angle = atan2(dx, dz)
            let faceDirection = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.3)

            // Leg movement (alternate feet up/down)
            let stepDuration = 0.25
            let stepCount = max(2, Int(walkDuration / stepDuration))
            var legActions: [SCNAction] = []
            for i in 0..<stepCount {
                let isLeft = i % 2 == 0
                let foot = isLeft ? leftFootNode : rightFootNode
                let otherFoot = isLeft ? rightFootNode : leftFootNode
                let arm = isLeft ? leftArmNode : rightArmNode
                let otherArm = isLeft ? rightArmNode : leftArmNode

                let stepUp = SCNAction.run { _ in
                    foot?.runAction(SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: stepDuration * 0.4))
                    otherFoot?.runAction(SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: stepDuration * 0.4))
                    // Swing arms opposite to legs
                    arm?.runAction(SCNAction.rotateBy(x: 0.2, y: 0, z: 0, duration: stepDuration * 0.4))
                    otherArm?.runAction(SCNAction.rotateBy(x: -0.2, y: 0, z: 0, duration: stepDuration * 0.4))
                }
                legActions.append(stepUp)
                legActions.append(SCNAction.wait(duration: stepDuration))
            }

            // Reset limbs after walk + check for topples
            let resetLimbs = SCNAction.run { [weak self] _ in
                guard let self else { return }
                self.leftFootNode?.runAction(SCNAction.move(to: SCNVector3(-0.18, -0.45, 0.05), duration: 0.2))
                self.rightFootNode?.runAction(SCNAction.move(to: SCNVector3(0.18, -0.45, 0.05), duration: 0.2))
                self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.2))
                self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2))
                // Check if pet knocked anything over
                if let body = self.petBodyNode {
                    self.checkForTopples(at: body.position)
                }
            }

            let moveToTarget = SCNAction.moveBy(x: dx, y: 0, z: dz, duration: walkDuration)
            moveToTarget.timingMode = .easeInEaseOut

            // Face back to camera after arriving
            let faceCamera = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4)

            return SCNAction.sequence([
                faceDirection,
                SCNAction.group([moveToTarget, SCNAction.sequence(legActions)]),
                resetLimbs,
                faceCamera
            ])
        }

        // MARK: - Dance Animation

        private func danceAction(_ root: SCNNode) -> SCNAction {
            let beatDuration = 0.3
            let beats = 12  // 12-beat dance routine

            var danceSteps: [SCNAction] = []

            for i in 0..<beats {
                let step = SCNAction.run { [weak self] _ in
                    guard let self else { return }

                    // Body bounce on every beat
                    self.petBodyNode?.runAction(SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: beatDuration * 0.4),
                        SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: beatDuration * 0.4)
                    ]))

                    // Alternate arm raises
                    if i % 4 == 0 {
                        // Both arms up
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi * 0.7, duration: beatDuration))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi * 0.7, duration: beatDuration))
                    } else if i % 4 == 1 {
                        // Right arm up, left down
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: beatDuration))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi * 0.7, duration: beatDuration))
                    } else if i % 4 == 2 {
                        // Left arm up, right down
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi * 0.7, duration: beatDuration))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: beatDuration))
                    } else {
                        // Hip sway
                        self.bodyMeshNode?.runAction(SCNAction.sequence([
                            SCNAction.rotateBy(x: 0, y: 0, z: 0.12, duration: beatDuration * 0.5),
                            SCNAction.rotateBy(x: 0, y: 0, z: -0.24, duration: beatDuration * 0.5)
                        ]))
                    }

                    // Spin on beat 6
                    if i == 6 {
                        self.petBodyNode?.runAction(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: beatDuration * 2))
                    }

                    // Head bob
                    self.headNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateBy(x: 0.08, y: 0, z: 0, duration: beatDuration * 0.3),
                        SCNAction.rotateBy(x: -0.08, y: 0, z: 0, duration: beatDuration * 0.3)
                    ]))
                }
                danceSteps.append(step)
                danceSteps.append(SCNAction.wait(duration: beatDuration))
            }

            // Reset arms after dance
            let resetArms = SCNAction.run { [weak self] _ in
                self?.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.3))
                self?.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.3))
                self?.bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
            }

            danceSteps.append(resetArms)
            return SCNAction.sequence(danceSteps)
        }

        // MARK: - Jump Animation

        private func jumpAction() -> SCNAction {
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 0.2),
                SCNAction.rotateBy(x: 0, y: CGFloat.pi, z: 0, duration: 0.25),
                SCNAction.moveBy(x: 0, y: -0.5, z: 0, duration: 0.2),
                SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.1),
                SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.1)
            ])
        }

        // MARK: - Stretch Animation

        private func stretchAction() -> SCNAction {
            SCNAction.run { [weak self] _ in
                guard let self else { return }
                // Arms stretch up
                self.leftArmNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi * 0.8, duration: 0.5),
                    SCNAction.wait(duration: 1.0),
                    SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.4)
                ]))
                self.rightArmNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi * 0.8, duration: 0.5),
                    SCNAction.wait(duration: 1.0),
                    SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.4)
                ]))
                // Body stretches up slightly
                self.bodyMeshNode?.runAction(SCNAction.sequence([
                    SCNAction.scale(to: 1.08, duration: 0.5),
                    SCNAction.wait(duration: 0.8),
                    SCNAction.scale(to: 1.0, duration: 0.4)
                ]))
                // Yawn — open mouth wider
                self.mouthNode?.runAction(SCNAction.sequence([
                    SCNAction.scale(to: 1.6, duration: 0.3),
                    SCNAction.wait(duration: 1.0),
                    SCNAction.scale(to: 1.0, duration: 0.3)
                ]))
            }
        }

        // MARK: - Play With Toy

        private func playWithToyAction(_ root: SCNNode) -> SCNAction {
            // Pick a random toy to walk to and play with
            let toys = [toyBallNode, yarnBallNode, cushionNode].compactMap { $0 }
            guard let toy = toys.randomElement() else { return jumpAction() }

            let toyPos = toy.position
            let currentPos = root.position
            let dx = CGFloat(toyPos.x) - CGFloat(currentPos.x)
            let dz = CGFloat(toyPos.z) - CGFloat(currentPos.z)
            let distance = sqrt(dx * dx + dz * dz)
            let walkDuration = Double(distance) * 0.8

            let angle = atan2(dx, dz)
            let face = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.2)
            let walkTo = SCNAction.moveBy(x: dx, y: 0, z: dz, duration: walkDuration)
            walkTo.timingMode = .easeInEaseOut

            // Play animation at the toy
            let playWithIt = SCNAction.run { [weak self] _ in
                guard let self else { return }

                if toy === self.toyBallNode {
                    // Bat the ball — it rolls away
                    self.showSpeechBubble("wheee!")
                    let rollDir = CGFloat.random(in: -1...1)
                    toy.runAction(SCNAction.sequence([
                        SCNAction.group([
                            SCNAction.moveBy(x: rollDir * 0.5, y: 0, z: CGFloat.random(in: -0.3...0.3), duration: 0.4),
                            SCNAction.rotateBy(x: CGFloat.pi * 3, y: 0, z: CGFloat.pi * 2, duration: 0.4)
                        ]),
                        SCNAction.moveBy(x: rollDir * 0.2, y: 0, z: 0.1, duration: 0.3)
                    ]))
                    // Paw bat animation
                    self.rightArmNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.6, y: 0, z: -CGFloat.pi * 0.4, duration: 0.15),
                        SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2)
                    ]))
                } else if toy === self.yarnBallNode {
                    // Bat the yarn
                    self.showSpeechBubble("hehe!")
                    let rollX = CGFloat.random(in: -0.4...0.4)
                    toy.runAction(SCNAction.group([
                        SCNAction.moveBy(x: rollX, y: 0, z: 0.3, duration: 0.3),
                        SCNAction.rotateBy(x: CGFloat.pi * 4, y: 0, z: 0, duration: 0.3)
                    ]))
                    // Both paws
                    self.leftArmNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.5, y: 0, z: CGFloat.pi * 0.3, duration: 0.12),
                        SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.2)
                    ]))
                    self.rightArmNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.5, y: 0, z: -CGFloat.pi * 0.3, duration: 0.12),
                        SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2)
                    ]))
                } else if toy === self.cushionNode {
                    // Sit on cushion momentarily
                    self.showSpeechBubble("comfy~")
                    self.petBodyNode?.runAction(SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.2),
                        SCNAction.wait(duration: 2.0),
                        SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.2)
                    ]))
                    // Squint eyes contentedly
                    self.leftEyeNode?.runAction(SCNAction.sequence([
                        SCNAction.scale(to: 0.5, duration: 0.2),
                        SCNAction.wait(duration: 1.5),
                        SCNAction.scale(to: 1.0, duration: 0.2)
                    ]))
                    self.rightEyeNode?.runAction(SCNAction.sequence([
                        SCNAction.scale(to: 0.5, duration: 0.2),
                        SCNAction.wait(duration: 1.5),
                        SCNAction.scale(to: 1.0, duration: 0.2)
                    ]))
                }
            }

            let faceCamera = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)

            return SCNAction.sequence([
                face,
                walkTo,
                playWithIt,
                SCNAction.wait(duration: toy === cushionNode ? 2.5 : 0.8),
                faceCamera
            ])
        }

        // MARK: - Bat Yarn (Chase it)

        private func batYarnAction(_ root: SCNNode) -> SCNAction {
            guard let yarn = yarnBallNode else { return jumpAction() }

            return SCNAction.run { [weak self] _ in
                guard let self, let body = self.petBodyNode else { return }

                // Bat yarn to a random spot
                let newX = CGFloat.random(in: -1.0...1.0)
                let newZ = CGFloat.random(in: 0...1.2)
                yarn.runAction(SCNAction.group([
                    SCNAction.move(to: SCNVector3(newX, 0.1, newZ), duration: 0.5),
                    SCNAction.rotateBy(x: CGFloat.pi * 5, y: 0, z: CGFloat.pi * 3, duration: 0.5)
                ]))

                self.showSpeechBubble("catch!")

                // Chase the yarn after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    let dx = newX - CGFloat(body.position.x)
                    let dz = newZ - CGFloat(body.position.z)
                    let angle = atan2(dx, dz)
                    let dist = sqrt(dx * dx + dz * dz)

                    let chase = SCNAction.sequence([
                        SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.15),
                        SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(dist) * 0.4),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
                    ])
                    body.runAction(chase)
                }
            }
        }

        // MARK: - Screen Escape Animation

        private func screenEscapeAction() -> SCNAction {
            return SCNAction.run { [weak self] _ in
                guard let self, let body = self.petBodyNode else { return }

                // The "screen wall" is at z ≈ 2.0 (toward camera)
                let screenZ: CGFloat = 1.8
                let startX = CGFloat(body.position.x)
                let startZ = CGFloat(body.position.z)

                // Step 1: Walk toward the screen (camera direction)
                let dz1 = screenZ - CGFloat(body.position.z)
                let walkToScreen = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                    SCNAction.moveBy(x: 0, y: 0, z: dz1, duration: 0.8)
                ])

                // Hop steps while walking
                self.leftFootNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: -0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: -0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
                ]))
                self.rightFootNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: -0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
                ]))

                body.runAction(walkToScreen) {
                    // Step 2: Press face against screen — lean forward
                    self.showSpeechBubble("hello?? 👀")
                    self.bodyMeshNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.15, y: 0, z: 0, duration: 0.3),
                    ]))
                    // Head tilts curiously
                    self.headNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: 0, y: 0, z: 0.2, duration: 0.3),
                        SCNAction.wait(duration: 0.5),
                        SCNAction.rotateTo(x: 0, y: 0, z: -0.2, duration: 0.3),
                    ]))

                    // Step 3: Knock on the screen — tap arm forward repeatedly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.showSpeechBubble("*knock knock*")

                        // Right arm knocks forward
                        let knockOnce = SCNAction.sequence([
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.45, y: 0, z: -0.1, duration: 0.12),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.3, y: 0, z: -0.1, duration: 0.1),
                        ])
                        self.rightArmNode?.runAction(SCNAction.sequence([
                            knockOnce, knockOnce, knockOnce,
                            SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2)
                        ]))

                        // Body bounces slightly with each knock
                        let knockBounce = SCNAction.sequence([
                            SCNAction.moveBy(x: 0, y: 0, z: 0.03, duration: 0.12),
                            SCNAction.moveBy(x: 0, y: 0, z: -0.03, duration: 0.1),
                        ])
                        body.runAction(SCNAction.sequence([knockBounce, knockBounce, knockBounce]))
                    }

                    // Step 4: Inspect the right corner
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                        self.showSpeechBubble("hmm... 🤔")
                        self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))

                        // Shuffle to the right corner
                        let moveRight = SCNAction.sequence([
                            SCNAction.rotateTo(x: 0, y: -CGFloat.pi * 0.3, z: 0, duration: 0.2),
                            SCNAction.moveBy(x: 1.2, y: 0, z: 0, duration: 0.7),
                        ])
                        body.runAction(moveRight) {
                            // Peer into the corner — head tilts and leans
                            self.headNode?.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0.15, y: -0.3, z: -0.25, duration: 0.3),
                                SCNAction.wait(duration: 0.6),
                                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                            ]))
                            self.bodyMeshNode?.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0, y: -0.15, z: -0.1, duration: 0.3),
                                SCNAction.wait(duration: 0.6),
                                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                            ]))

                            // Paw at the corner
                            self.rightArmNode?.runAction(SCNAction.sequence([
                                SCNAction.wait(duration: 0.2),
                                SCNAction.rotateTo(x: -0.5, y: -0.3, z: -0.2, duration: 0.2),
                                SCNAction.rotateTo(x: -0.6, y: -0.4, z: -0.3, duration: 0.15),
                                SCNAction.rotateTo(x: -0.5, y: -0.3, z: -0.2, duration: 0.15),
                                SCNAction.wait(duration: 0.3),
                                SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2),
                            ]))
                        }
                    }

                    // Step 5: Move to left corner and check there too
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.showSpeechBubble("is there a gap? 🧐")

                        let moveLeft = SCNAction.sequence([
                            SCNAction.rotateTo(x: 0, y: CGFloat.pi * 0.3, z: 0, duration: 0.2),
                            SCNAction.moveBy(x: -2.4, y: 0, z: 0, duration: 1.0),
                        ])
                        body.runAction(moveLeft) {
                            // Look around the left corner
                            self.headNode?.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0.15, y: 0.3, z: 0.25, duration: 0.3),
                                SCNAction.wait(duration: 0.4),
                            ]))
                        }
                    }

                    // Step 6: Try to squeeze paw/leg through the "gap"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                        self.showSpeechBubble("almost..! 😤")

                        // Face forward again
                        body.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
                        self.headNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))

                        // Press body against screen
                        self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: -0.1, y: 0, z: 0, duration: 0.2))

                        // Left arm reaches way forward (through the "screen")
                        self.leftArmNode?.runAction(SCNAction.sequence([
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: 0, z: 0.2, duration: 0.3),
                            // Wiggle the paw trying to push through
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: 0.1, z: 0.15, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: -0.1, z: 0.25, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.65, y: 0.1, z: 0.15, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: -0.1, z: 0.25, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: 0.05, z: 0.2, duration: 0.1),
                            // Hold it stretched out
                            SCNAction.wait(duration: 0.5),
                        ]))

                        // Right arm also tries
                        self.rightArmNode?.runAction(SCNAction.sequence([
                            SCNAction.wait(duration: 0.5),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: 0, z: -0.2, duration: 0.3),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: -0.1, z: -0.15, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: 0.1, z: -0.25, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: -0.1, z: -0.15, duration: 0.15),
                            SCNAction.wait(duration: 0.4),
                        ]))

                        // Left foot tries to squeeze through too — kicks forward
                        self.leftFootNode?.runAction(SCNAction.sequence([
                            SCNAction.wait(duration: 1.0),
                            SCNAction.rotateTo(x: -0.6, y: 0, z: 0, duration: 0.2),
                            SCNAction.rotateTo(x: -0.7, y: 0, z: 0, duration: 0.15),
                            SCNAction.rotateTo(x: -0.55, y: 0, z: 0, duration: 0.15),
                            SCNAction.rotateTo(x: -0.7, y: 0, z: 0, duration: 0.15),
                            SCNAction.wait(duration: 0.3),
                            SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                        ]))

                        // Body pushes forward
                        body.runAction(SCNAction.sequence([
                            SCNAction.moveBy(x: 0, y: 0, z: 0.1, duration: 0.3),
                            SCNAction.moveBy(x: 0, y: 0, z: 0.05, duration: 0.15),
                            SCNAction.moveBy(x: 0, y: 0, z: -0.05, duration: 0.15),
                            SCNAction.moveBy(x: 0, y: 0, z: 0.05, duration: 0.15),
                            SCNAction.moveBy(x: 0, y: 0, z: -0.15, duration: 0.2),
                        ]))
                    }

                    // Step 7: Give up — sigh and walk back
                    DispatchQueue.main.asyncAfter(deadline: .now() + 9.5) {
                        self.showSpeechBubble("hmph! 😤")

                        // Reset arms, body, head
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.3))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.3))
                        self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3))
                        self.headNode?.runAction(SCNAction.sequence([
                            // Dejected head shake
                            SCNAction.rotateTo(x: 0.1, y: 0.15, z: 0, duration: 0.15),
                            SCNAction.rotateTo(x: 0.1, y: -0.15, z: 0, duration: 0.3),
                            SCNAction.rotateTo(x: 0.1, y: 0.15, z: 0, duration: 0.3),
                            SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                        ]))

                        // Turn around and walk back to center
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            let returnX = CGFloat.random(in: -0.5...0.5)
                            let returnZ = CGFloat.random(in: 0...0.5)
                            let dx = returnX - CGFloat(body.position.x)
                            let dz = returnZ - CGFloat(body.position.z)
                            let angle = atan2(dx, dz)
                            let dist = sqrt(dx * dx + dz * dz)

                            body.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.3),
                                SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(dist) * 0.6),
                                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                            ]))

                            // Sad tail droop momentarily
                            self.tailNode?.removeAction(forKey: "tailWag")
                            self.tailNode?.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.3),
                                SCNAction.wait(duration: 1.5),
                                SCNAction.rotateTo(x: -0.2, y: 0, z: 0, duration: 0.3),
                            ])) {
                                self.startTailWag()
                            }

                            self.showSpeechBubble("fine... 😒")
                        }
                    }
                }
            }
        }

        // MARK: - Topple Check (called during walk)

        private func checkForTopples(at position: SCNVector3) {
            let toppleTargets: [(node: SCNNode?, name: String, originalPos: SCNVector3)] = [
                (bookStackNode, "bookStack", SCNVector3(0.8, 0, -1.0)),
                (plantNode, "plant", SCNVector3(-1.6, 0.075, 0.3)),
            ]

            for target in toppleTargets {
                guard let node = target.node else { continue }
                // Already toppled?
                if toppledObjects.contains(where: { $0 === node }) { continue }

                let dx = CGFloat(position.x) - CGFloat(node.position.x)
                let dz = CGFloat(position.z) - CGFloat(node.position.z)
                let dist = sqrt(dx * dx + dz * dz)

                if dist < 0.5 {
                    // Topple it!
                    toppledObjects.append(node)
                    let toppleDir: CGFloat = dx > 0 ? 1 : -1

                    node.runAction(SCNAction.sequence([
                        SCNAction.group([
                            SCNAction.rotateBy(x: toppleDir * 0.8, y: 0, z: toppleDir * 0.4, duration: 0.25),
                            SCNAction.moveBy(x: toppleDir * 0.15, y: -0.02, z: 0, duration: 0.25)
                        ]),
                    ]))

                    // Pet reacts — "oopsie!" then goes to fix it
                    showSpeechBubble(["oopsie!", "uh oh!", "oh no!", "whoops!"].randomElement()!)

                    // After a pause, go pick it up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.fixToppledObject(node, originalPos: target.originalPos)
                    }
                }
            }
        }

        private func fixToppledObject(_ node: SCNNode, originalPos: SCNVector3) {
            guard let body = petBodyNode else { return }

            let dx = CGFloat(node.position.x) - CGFloat(body.position.x)
            let dz = CGFloat(node.position.z) - CGFloat(body.position.z)
            let angle = atan2(dx, dz)
            let dist = sqrt(dx * dx + dz * dz)

            let walkToIt = SCNAction.sequence([
                SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.2),
                SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(dist) * 0.8)
            ])

            let fixIt = SCNAction.run { [weak self] _ in
                // Pet bends down (lean forward)
                self?.bodyMeshNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0.25, y: 0, z: 0, duration: 0.3),
                    SCNAction.wait(duration: 0.5),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
                ]))
                // Arms reach down
                self?.leftArmNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: -0.5, y: 0, z: 0.1, duration: 0.3),
                    SCNAction.wait(duration: 0.5),
                    SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.3)
                ]))
                self?.rightArmNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: -0.5, y: 0, z: -0.1, duration: 0.3),
                    SCNAction.wait(duration: 0.5),
                    SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.3)
                ]))

                self?.showSpeechBubble(["all fixed!", "there we go!", "good as new!"].randomElement()!)

                // Fix the object — restore position and rotation
                node.runAction(SCNAction.sequence([
                    SCNAction.wait(duration: 0.3),
                    SCNAction.group([
                        SCNAction.move(to: originalPos, duration: 0.4),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4)
                    ])
                ]))

                // Remove from toppled list
                self?.toppledObjects.removeAll { $0 === node }
            }

            let faceCamera = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)

            body.runAction(SCNAction.sequence([walkToIt, fixIt, SCNAction.wait(duration: 1.2), faceCamera]), forKey: "fixTopple")
        }

        // MARK: - Speech Bubble

        private func showSpeechBubble(_ text: String) {
            guard let scene = sceneRef, let body = petBodyNode else { return }

            // Remove any existing speech bubble
            scene.rootNode.childNode(withName: "speechBubble", recursively: false)?.removeFromParentNode()

            // Background bubble
            let bubbleWidth: CGFloat = CGFloat(text.count) * 0.09 + 0.2
            let bgGeo = SCNBox(width: bubbleWidth, height: 0.2, length: 0.02, chamferRadius: 0.08)
            let bgMat = SCNMaterial()
            bgMat.diffuse.contents = NSColor.white.withAlphaComponent(0.9)
            bgMat.roughness.contents = NSColor(white: 0.3, alpha: 1)
            bgGeo.materials = [bgMat]

            let bubbleNode = SCNNode(geometry: bgGeo)
            bubbleNode.name = "speechBubble"
            let petY = CGFloat(body.position.y) + 1.9
            bubbleNode.position = SCNVector3(CGFloat(body.position.x), petY, CGFloat(body.position.z) + 0.3)
            // Always face camera
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = [.Y]
            bubbleNode.constraints = [constraint]

            // Text
            let textGeo = SCNText(string: text, extrusionDepth: 0.005)
            textGeo.font = NSFont.systemFont(ofSize: 0.09, weight: .medium)
            textGeo.flatness = 0.1
            textGeo.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1)
            let textNode = SCNNode(geometry: textGeo)
            // Center the text
            let (minBound, maxBound) = textNode.boundingBox
            let textWidth = CGFloat(maxBound.x - minBound.x)
            let textHeight = CGFloat(maxBound.y - minBound.y)
            textNode.position = SCNVector3(-textWidth / 2, -textHeight / 2, 0.012)
            bubbleNode.addChildNode(textNode)

            // Small triangle pointer at bottom
            let triGeo = SCNPyramid(width: 0.08, height: 0.06, length: 0.02)
            let triMat = SCNMaterial()
            triMat.diffuse.contents = NSColor.white.withAlphaComponent(0.9)
            triGeo.materials = [triMat]
            let triNode = SCNNode(geometry: triGeo)
            triNode.position = SCNVector3(0, -0.13, 0)
            triNode.eulerAngles.x = CGFloat.pi
            bubbleNode.addChildNode(triNode)

            scene.rootNode.addChildNode(bubbleNode)

            // Pop in
            bubbleNode.scale = SCNVector3(0.01, 0.01, 0.01)
            bubbleNode.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.0, duration: 0.15),
                SCNAction.wait(duration: 2.0),
                SCNAction.group([
                    SCNAction.scale(to: 0.01, duration: 0.2),
                    SCNAction.fadeOut(duration: 0.2)
                ]),
                SCNAction.removeFromParentNode()
            ]))
        }

        // MARK: - Expression Helpers

        private func wiggleEars() {
            let wiggle = SCNAction.sequence([
                SCNAction.rotateBy(x: 0.2, y: 0, z: 0.15, duration: 0.1),
                SCNAction.rotateBy(x: -0.4, y: 0, z: -0.3, duration: 0.2),
                SCNAction.rotateBy(x: 0.2, y: 0, z: 0.15, duration: 0.1)
            ])
            leftEarNode?.runAction(wiggle)
            rightEarNode?.runAction(wiggle)
        }

        private func showHappyFace() {
            // Bigger cheeks
            leftCheekNode?.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.5, duration: 0.15),
                SCNAction.wait(duration: 0.6),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ]))
            rightCheekNode?.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.5, duration: 0.15),
                SCNAction.wait(duration: 0.6),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ]))

            // Pupils dilate (happy = big pupils)
            leftPupilNode?.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.4, duration: 0.15),
                SCNAction.wait(duration: 0.6),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ]))
            rightPupilNode?.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.4, duration: 0.15),
                SCNAction.wait(duration: 0.6),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ]))

            // Faster tail wag
            tailNode?.removeAction(forKey: "tailWag")
            let fastWag = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0.4, z: 0.25, duration: 0.1),
                SCNAction.rotateBy(x: 0, y: -0.8, z: -0.5, duration: 0.2),
                SCNAction.rotateBy(x: 0, y: 0.4, z: 0.25, duration: 0.1)
            ])
            tailNode?.runAction(SCNAction.repeat(fastWag, count: 5)) { [weak self] in
                self?.startTailWag()
            }
        }

        private func startBlinking() {
            Timer.scheduledTimer(withTimeInterval: Double.random(in: 2.8...4.5), repeats: true) { [weak self] _ in
                guard let self, let leftEye = self.leftEyeNode, let rightEye = self.rightEyeNode else { return }
                let close = SCNAction.scale(to: 0.15, duration: 0.06)
                let open = SCNAction.scale(to: 1.0, duration: 0.06)
                let blinkSeq = SCNAction.sequence([close, SCNAction.wait(duration: 0.08), open])

                // Occasionally double-blink
                let doDouble = Bool.random()
                let fullBlink = doDouble
                    ? SCNAction.sequence([blinkSeq, SCNAction.wait(duration: 0.15), blinkSeq])
                    : blinkSeq

                DispatchQueue.main.async {
                    leftEye.runAction(fullBlink)
                    rightEye.runAction(fullBlink)
                }
            }
        }

        func updateMood(pet: UserDataStore.PetStateData, in scene: SCNScene?) {
            let avg = (pet.health + pet.hunger + pet.happiness) / 3

            // Show/hide cheeks based on mood
            let showCheeks = avg >= 60 && pet.isAlive
            leftCheekNode?.opacity = showCheeks ? 1.0 : 0.0
            rightCheekNode?.opacity = showCheeks ? 1.0 : 0.0

            // Droopy eyes when sad
            let eyeScale: CGFloat = (avg < 30 && pet.isAlive) ? 0.7 : 1.0
            leftEyeNode?.scale = SCNVector3(1, eyeScale, 1)
            rightEyeNode?.scale = SCNVector3(1, eyeScale, 1)

            // Sad pupil position (looking down)
            if avg < 30 && pet.isAlive {
                leftPupilNode?.position = SCNVector3(0, -0.02, 0.06)
                rightPupilNode?.position = SCNVector3(0, -0.02, 0.06)
            } else {
                leftPupilNode?.position = SCNVector3(0, 0, 0.06)
                rightPupilNode?.position = SCNVector3(0, 0, 0.06)
            }

            // Mouth changes with mood
            if pet.isAlive {
                if avg > 70 {
                    // Happy — big smile
                    mouthNode?.scale = SCNVector3(1.2, 1.2, 1.2)
                    mouthNode?.eulerAngles.x = CGFloat.pi / 6
                } else if avg < 30 {
                    // Sad — frown (flip mouth)
                    mouthNode?.scale = SCNVector3(0.8, 0.8, 0.8)
                    mouthNode?.eulerAngles.x = -CGFloat.pi / 6
                } else {
                    // Neutral
                    mouthNode?.scale = SCNVector3(1, 1, 1)
                    mouthNode?.eulerAngles.x = CGFloat.pi / 12
                }
            }

            // Ears droop when sad
            if avg < 30 && pet.isAlive {
                leftEarNode?.position = SCNVector3(-0.25, 0.24, 0)
                rightEarNode?.position = SCNVector3(0.25, 0.24, 0)
            } else {
                leftEarNode?.position = SCNVector3(-0.22, 0.32, 0)
                rightEarNode?.position = SCNVector3(0.22, 0.32, 0)
            }

            // Tail wag speed based on happiness
            if pet.isAlive {
                tailNode?.removeAction(forKey: "tailWag")
                let wagSpeed = pet.happiness > 60 ? 0.15 : (pet.happiness > 30 ? 0.25 : 0.5)
                let amplitude: CGFloat = pet.happiness > 60 ? 0.35 : 0.15
                let wag = SCNAction.sequence([
                    SCNAction.rotateBy(x: 0, y: amplitude, z: amplitude * 0.6, duration: wagSpeed),
                    SCNAction.rotateBy(x: 0, y: -amplitude * 2, z: -amplitude * 1.2, duration: wagSpeed * 2),
                    SCNAction.rotateBy(x: 0, y: amplitude, z: amplitude * 0.6, duration: wagSpeed)
                ])
                wag.timingMode = .easeInEaseOut
                tailNode?.runAction(.repeatForever(wag), forKey: "tailWag")
            }
        }
    }
}
