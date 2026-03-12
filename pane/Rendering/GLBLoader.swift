import Foundation
import SceneKit

/// Result of loading a GLB/VRM file, including skeleton and blend shape info.
struct GLBLoadResult {
    let rootNode: SCNNode
    let skeletonRoot: SCNNode?
    let bones: [String: SCNNode]        // bone name → SCNNode
    let morpherNode: SCNNode?           // node carrying SCNMorpher (for blend shapes)
    let blendShapeMap: [String: Int]    // blend shape name → morpher target index
}

/// GLB (glTF 2.0 Binary) loader with full skeletal skinning and morph targets.
/// Supports: meshes, PBR materials, textures, skeleton/skinning, blend shapes.
/// Designed for loading VRM avatars (VRM is a superset of glTF 2.0).
final class GLBLoader {

    enum GLBError: Error, LocalizedError {
        case invalidHeader
        case unsupportedVersion
        case missingJSONChunk
        case missingBINChunk
        case invalidJSON
        case missingData(String)

        var errorDescription: String? {
            switch self {
            case .invalidHeader:        return "Not a valid GLB file"
            case .unsupportedVersion:   return "Unsupported glTF version"
            case .missingJSONChunk:     return "Missing JSON chunk"
            case .missingBINChunk:      return "Missing BIN chunk"
            case .invalidJSON:          return "Failed to parse JSON"
            case .missingData(let s):   return "Missing data: \(s)"
            }
        }
    }

    // MARK: - Public

    /// Load a GLB/VRM file and return the root SCNNode (backward compat).
    static func loadScene(from url: URL) throws -> SCNNode {
        try loadFull(from: url).rootNode
    }

    /// Load a GLB/VRM file with full skeleton, blend shape, and bone info.
    static func loadFull(from url: URL) throws -> GLBLoadResult {
        let data = try Data(contentsOf: url)
        return try loadFull(from: data)
    }

    static func loadFull(from data: Data) throws -> GLBLoadResult {
        // ── Parse GLB header ──
        guard data.count >= 12 else { throw GLBError.invalidHeader }
        let magic = data.readUInt32(at: 0)
        guard magic == 0x46546C67 else { throw GLBError.invalidHeader } // "glTF"
        let version = data.readUInt32(at: 4)
        guard version == 2 else { throw GLBError.unsupportedVersion }

        // ── Parse chunks ──
        var offset = 12
        var jsonData: Data?
        var binData: Data?

        while offset + 8 <= data.count {
            let chunkLength = Int(data.readUInt32(at: offset))
            let chunkType = data.readUInt32(at: offset + 4)
            let chunkStart = offset + 8
            let chunkEnd = min(chunkStart + chunkLength, data.count)

            if chunkType == 0x4E4F534A { // JSON
                jsonData = data.subdata(in: chunkStart..<chunkEnd)
            } else if chunkType == 0x004E4942 { // BIN
                binData = data.subdata(in: chunkStart..<chunkEnd)
            }
            offset = chunkEnd
            // Only align if the next 8 bytes don't look like a valid chunk header.
            // Some VRM exporters don't pad JSON chunks to 4-byte boundaries.
            let aligned = (offset + 3) & ~3
            if aligned != offset, aligned + 8 <= data.count {
                let typeAtAligned = data.readUInt32(at: aligned + 4)
                if typeAtAligned == 0x4E4F534A || typeAtAligned == 0x004E4942 {
                    offset = aligned
                }
            }
        }

        guard let json = jsonData else { throw GLBError.missingJSONChunk }
        guard let bin = binData else { throw GLBError.missingBINChunk }

        guard let gltf = try JSONSerialization.jsonObject(with: json) as? [String: Any] else {
            throw GLBError.invalidJSON
        }

        let loader = GLBLoader(gltf: gltf, bin: bin)
        return try loader.buildFullScene()
    }

    // MARK: - Internal state

    private let gltf: [String: Any]
    private let bin: Data
    private var textureCache: [Int: Any] = [:]
    private var builtNodes: [Int: SCNNode] = [:]  // glTF node index → SCNNode

    private init(gltf: [String: Any], bin: Data) {
        self.gltf = gltf
        self.bin = bin
    }

    // MARK: - Scene building

    private func buildFullScene() throws -> GLBLoadResult {
        let root = SCNNode()
        root.name = "glb_root"

        let allNodes = gltf["nodes"] as? [[String: Any]] ?? []
        let scenes = gltf["scenes"] as? [[String: Any]] ?? []
        let sceneIndex = gltf["scene"] as? Int ?? 0
        guard sceneIndex < scenes.count else {
            return GLBLoadResult(rootNode: root, skeletonRoot: nil, bones: [:], morpherNode: nil, blendShapeMap: [:])
        }

        let scene = scenes[sceneIndex]
        let rootNodeIndices = scene["nodes"] as? [Int] ?? []

        // Phase 1: Build all nodes (without skinning yet)
        for nodeIndex in rootNodeIndices {
            if let node = try buildNode(index: nodeIndex, allNodes: allNodes) {
                root.addChildNode(node)
            }
        }

        // Phase 2: Parse skins and apply skinning
        let skins = gltf["skins"] as? [[String: Any]] ?? []
        var skeletonRoot: SCNNode?
        var boneMap: [String: SCNNode] = [:]

        for (nodeIndex, nodeDef) in allNodes.enumerated() {
            guard let skinIndex = nodeDef["skin"] as? Int,
                  skinIndex < skins.count,
                  let sceneNode = builtNodes[nodeIndex] else { continue }

            let skin = skins[skinIndex]
            let jointIndices = skin["joints"] as? [Int] ?? []

            // Build bone array in joint-index order
            var bones: [SCNNode] = []
            for ji in jointIndices {
                if let boneNode = builtNodes[ji] {
                    bones.append(boneNode)
                    if let name = boneNode.name {
                        boneMap[name] = boneNode
                    }
                }
            }

            // Find skeleton root
            if let skelIdx = skin["skeleton"] as? Int, let skelNode = builtNodes[skelIdx] {
                skeletonRoot = skelNode
            } else if let firstJoint = jointIndices.first, let firstNode = builtNodes[firstJoint] {
                skeletonRoot = firstNode
            }

            // Read inverse bind matrices
            var ibms: [NSValue] = []
            if let ibmAccessor = skin["inverseBindMatrices"] as? Int {
                let matrices = try readAccessorMat4(index: ibmAccessor)
                ibms = matrices.map { NSValue(scnMatrix4: $0) }
            }

            // Apply skinning to all mesh geometry nodes under this scene node
            applySkinning(to: sceneNode, bones: bones, ibms: ibms, skeletonRoot: skeletonRoot)
        }

        // Phase 3: Parse morph targets (blend shapes) from VRM extension
        var morpherNode: SCNNode?
        var blendShapeMap: [String: Int] = [:]

        // Find the node that has a morpher (mesh with targets)
        let meshes = gltf["meshes"] as? [[String: Any]] ?? []
        for (nodeIndex, nodeDef) in allNodes.enumerated() {
            guard let meshIndex = nodeDef["mesh"] as? Int,
                  meshIndex < meshes.count else { continue }

            let meshDef = meshes[meshIndex]
            let primitives = meshDef["primitives"] as? [[String: Any]] ?? []
            guard let firstPrim = primitives.first,
                  let targets = firstPrim["targets"] as? [[String: Any]],
                  !targets.isEmpty else { continue }

            // Build morph targets
            guard let sceneNode = builtNodes[nodeIndex] else { continue }
            let geomNode = findFirstGeometryNode(in: sceneNode)
            guard let baseGeom = geomNode?.geometry else { continue }

            let basePositions = try readAccessorFloat3(index: (firstPrim["attributes"] as? [String: Int])?["POSITION"] ?? 0)

            var morphTargets: [SCNGeometry] = []
            for target in targets {
                guard let posAccessor = target["POSITION"] as? Int else { continue }
                let deltas = try readAccessorFloat3(index: posAccessor)

                // Morph target = base + delta
                let morphedPositions = zip(basePositions, deltas).map { base, delta in
                    SCNVector3(base.x + delta.x, base.y + delta.y, base.z + delta.z)
                }

                // Create target geometry with same topology
                var sources = [SCNGeometrySource(vertices: morphedPositions)]
                // Copy normals from base if available
                if let normAccessor = target["NORMAL"] as? Int {
                    let baseNormals = baseGeom.sources(for: .normal).first
                    let normDeltas = try readAccessorFloat3(index: normAccessor)
                    if let bn = baseNormals {
                        var baseNormData: [SCNVector3] = []
                        let vertCount = bn.vectorCount
                        let stride = bn.dataStride
                        let normOffset = bn.dataOffset
                        bn.data.withUnsafeBytes { ptr in
                            for i in 0..<vertCount {
                                let off = normOffset + i * stride
                                let x = ptr.load(fromByteOffset: off, as: Float.self)
                                let y = ptr.load(fromByteOffset: off + 4, as: Float.self)
                                let z = ptr.load(fromByteOffset: off + 8, as: Float.self)
                                baseNormData.append(SCNVector3(x, y, z))
                            }
                        }
                        let morphedNormals = zip(baseNormData, normDeltas).map { b, d in
                            SCNVector3(b.x + d.x, b.y + d.y, b.z + d.z)
                        }
                        sources.append(SCNGeometrySource(normals: morphedNormals))
                    }
                }

                let targetGeom = SCNGeometry(sources: sources, elements: baseGeom.elements)
                targetGeom.materials = baseGeom.materials
                morphTargets.append(targetGeom)
            }

            if !morphTargets.isEmpty {
                let morpher = SCNMorpher()
                morpher.targets = morphTargets
                morpher.calculationMode = .additive
                // Set all weights to 0 initially
                for i in 0..<morphTargets.count {
                    morpher.setWeight(0, forTargetAt: i)
                }
                geomNode?.morpher = morpher
                morpherNode = geomNode

                // Map blend shape names from VRM extension
                let vrmExt = gltf["extensions"] as? [String: Any]
                let vrm = vrmExt?["VRM"] as? [String: Any]
                let bsMaster = vrm?["blendShapeMaster"] as? [String: Any]
                let groups = bsMaster?["blendShapeGroups"] as? [[String: Any]] ?? []
                for group in groups {
                    guard let name = group["name"] as? String,
                          let binds = group["binds"] as? [[String: Any]],
                          let firstBind = binds.first,
                          let idx = firstBind["index"] as? Int,
                          idx < morphTargets.count else { continue }
                    blendShapeMap[name] = idx
                }
            }
            break // Only process first mesh with targets
        }

        return GLBLoadResult(
            rootNode: root,
            skeletonRoot: skeletonRoot,
            bones: boneMap,
            morpherNode: morpherNode,
            blendShapeMap: blendShapeMap
        )
    }

    private func buildNode(index: Int, allNodes: [[String: Any]]) throws -> SCNNode? {
        if let cached = builtNodes[index] { return cached }
        guard index < allNodes.count else { return nil }
        let nodeDef = allNodes[index]
        let node = SCNNode()
        node.name = nodeDef["name"] as? String ?? "node_\(index)"

        // Apply transform
        if let matrix = nodeDef["matrix"] as? [Double], matrix.count == 16 {
            node.simdTransform = float4x4(matrix)
        } else {
            if let t = nodeDef["translation"] as? [Double], t.count == 3 {
                node.simdPosition = SIMD3<Float>(Float(t[0]), Float(t[1]), Float(t[2]))
            }
            if let r = nodeDef["rotation"] as? [Double], r.count == 4 {
                node.simdOrientation = simd_quatf(ix: Float(r[0]), iy: Float(r[1]), iz: Float(r[2]), r: Float(r[3]))
            }
            if let s = nodeDef["scale"] as? [Double], s.count == 3 {
                node.simdScale = SIMD3<Float>(Float(s[0]), Float(s[1]), Float(s[2]))
            }
        }

        builtNodes[index] = node

        // Build mesh if present
        if let meshIndex = nodeDef["mesh"] as? Int {
            let meshNode = try buildMesh(index: meshIndex)
            node.addChildNode(meshNode)
        }

        // Recurse into children
        if let children = nodeDef["children"] as? [Int] {
            for childIndex in children {
                if let child = try buildNode(index: childIndex, allNodes: allNodes) {
                    node.addChildNode(child)
                }
            }
        }

        return node
    }

    // MARK: - Skinning

    private func applySkinning(to node: SCNNode, bones: [SCNNode], ibms: [NSValue], skeletonRoot: SCNNode?) {
        // Find all geometry nodes under this node and apply skinner
        node.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }

            // Look for the mesh that has JOINTS_0/WEIGHTS_0 data
            // We stored this info as user data during mesh building
            guard let skinData = child.value(forKey: "skinData") as? SkinGeometryData else { return }

            let skinner = SCNSkinner(
                baseGeometry: geometry,
                bones: bones,
                boneInverseBindTransforms: ibms.isEmpty ? nil : ibms,
                boneWeights: skinData.weights,
                boneIndices: skinData.joints
            )
            skinner.skeleton = skeletonRoot
            child.skinner = skinner
        }
    }

    private func findFirstGeometryNode(in node: SCNNode) -> SCNNode? {
        if node.geometry != nil { return node }
        for child in node.childNodes {
            if let found = findFirstGeometryNode(in: child) { return found }
        }
        return nil
    }

    // MARK: - Mesh building

    private func buildMesh(index: Int) throws -> SCNNode {
        let meshes = gltf["meshes"] as? [[String: Any]] ?? []
        guard index < meshes.count else { throw GLBError.missingData("mesh \(index)") }

        let meshDef = meshes[index]
        let primitives = meshDef["primitives"] as? [[String: Any]] ?? []
        let meshNode = SCNNode()
        meshNode.name = meshDef["name"] as? String ?? "mesh_\(index)"

        for prim in primitives {
            if let (geometry, skinData) = try buildGeometry(from: prim) {
                let primNode = SCNNode(geometry: geometry)
                if let sd = skinData {
                    primNode.setValue(sd, forKey: "skinData")
                }
                meshNode.addChildNode(primNode)
            }
        }

        return meshNode
    }

    private func buildGeometry(from primitive: [String: Any]) throws -> (SCNGeometry, SkinGeometryData?)? {
        let attributes = primitive["attributes"] as? [String: Int] ?? [:]

        guard let posIndex = attributes["POSITION"] else { return nil }
        let positions = try readAccessorFloat3(index: posIndex)

        var sources: [SCNGeometrySource] = []
        sources.append(SCNGeometrySource(vertices: positions))

        if let normIndex = attributes["NORMAL"] {
            let normals = try readAccessorFloat3(index: normIndex)
            sources.append(SCNGeometrySource(normals: normals))
        }

        if let uvIndex = attributes["TEXCOORD_0"] {
            let uvs = try readAccessorFloat2(index: uvIndex)
            let flippedUVs = uvs.map { CGPoint(x: CGFloat($0.x), y: CGFloat(1.0 - $0.y)) }
            sources.append(SCNGeometrySource(textureCoordinates: flippedUVs))
        }

        // Read skinning data (JOINTS_0 + WEIGHTS_0)
        var skinData: SkinGeometryData?
        if let jointsIdx = attributes["JOINTS_0"],
           let weightsIdx = attributes["WEIGHTS_0"] {
            let jointSource = try readJointsAccessor(index: jointsIdx, vertexCount: positions.count)
            let weightSource = try readWeightsAccessor(index: weightsIdx, vertexCount: positions.count)
            skinData = SkinGeometryData(joints: jointSource, weights: weightSource)
        }

        // Index buffer
        var elements: [SCNGeometryElement] = []
        if let indicesIndex = primitive["indices"] as? Int {
            let element = try readIndices(accessorIndex: indicesIndex)
            elements.append(element)
        } else {
            let count = positions.count
            let indices = (0..<count).map { UInt32($0) }
            let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
            elements.append(element)
        }

        let geometry = SCNGeometry(sources: sources, elements: elements)

        if let matIndex = primitive["material"] as? Int {
            geometry.materials = [try buildMaterial(index: matIndex)]
        } else {
            let defaultMat = SCNMaterial()
            defaultMat.diffuse.contents = NSColor.white
            defaultMat.lightingModel = .physicallyBased
            geometry.materials = [defaultMat]
        }

        return (geometry, skinData)
    }

    // MARK: - Material building

    private func buildMaterial(index: Int) throws -> SCNMaterial {
        let materials = gltf["materials"] as? [[String: Any]] ?? []
        guard index < materials.count else {
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor.white
            return mat
        }

        let matDef = materials[index]
        let mat = SCNMaterial()
        mat.name = matDef["name"] as? String
        mat.lightingModel = .physicallyBased
        mat.isDoubleSided = true

        if let pbr = matDef["pbrMetallicRoughness"] as? [String: Any] {
            if let factor = pbr["baseColorFactor"] as? [Double], factor.count >= 3 {
                mat.diffuse.contents = NSColor(
                    red: CGFloat(factor[0]),
                    green: CGFloat(factor[1]),
                    blue: CGFloat(factor[2]),
                    alpha: factor.count > 3 ? CGFloat(factor[3]) : 1.0
                )
            }

            if let texInfo = pbr["baseColorTexture"] as? [String: Any],
               let texIndex = texInfo["index"] as? Int {
                if let image = try loadTexture(index: texIndex) {
                    mat.diffuse.contents = image
                }
            }

            mat.metalness.contents = NSColor(white: CGFloat(pbr["metallicFactor"] as? Double ?? 0.0), alpha: 1)
            mat.roughness.contents = NSColor(white: CGFloat(pbr["roughnessFactor"] as? Double ?? 1.0), alpha: 1)
        }

        if let emFactor = matDef["emissiveFactor"] as? [Double], emFactor.count >= 3 {
            mat.emission.contents = NSColor(
                red: CGFloat(emFactor[0]),
                green: CGFloat(emFactor[1]),
                blue: CGFloat(emFactor[2]),
                alpha: 1.0
            )
        }

        if let alphaMode = matDef["alphaMode"] as? String {
            switch alphaMode {
            case "BLEND":
                mat.blendMode = .alpha
                mat.transparencyMode = .aOne
                mat.writesToDepthBuffer = false
            case "MASK":
                mat.transparencyMode = .aOne
                mat.transparency = 1.0
            default:
                break
            }
        }

        return mat
    }

    // MARK: - Texture loading

    private func loadTexture(index: Int) throws -> NSImage? {
        if let cached = textureCache[index] as? NSImage { return cached }

        let textures = gltf["textures"] as? [[String: Any]] ?? []
        guard index < textures.count else { return nil }

        let texDef = textures[index]
        guard let sourceIndex = texDef["source"] as? Int else { return nil }

        let images = gltf["images"] as? [[String: Any]] ?? []
        guard sourceIndex < images.count else { return nil }

        let imageDef = images[sourceIndex]

        if let bvIndex = imageDef["bufferView"] as? Int {
            let imageData = try readBufferView(index: bvIndex)
            if let image = NSImage(data: imageData) {
                textureCache[index] = image
                return image
            }
        }

        return nil
    }

    // MARK: - Accessor reading

    private func readAccessorFloat3(index: Int) throws -> [SCNVector3] {
        let accessors = gltf["accessors"] as? [[String: Any]] ?? []
        guard index < accessors.count else { throw GLBError.missingData("accessor \(index)") }

        let acc = accessors[index]
        let count = acc["count"] as? Int ?? 0
        let bvIndex = acc["bufferView"] as? Int ?? 0
        let byteOffset = acc["byteOffset"] as? Int ?? 0

        let bvData = try readBufferView(index: bvIndex)
        let bufferViews = gltf["bufferViews"] as? [[String: Any]] ?? []
        let byteStride = (bvIndex < bufferViews.count ? bufferViews[bvIndex]["byteStride"] as? Int : nil) ?? (3 * 4)

        var result: [SCNVector3] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let off = byteOffset + i * byteStride
            guard off + 12 <= bvData.count else { break }
            let x = bvData.readFloat(at: off)
            let y = bvData.readFloat(at: off + 4)
            let z = bvData.readFloat(at: off + 8)
            result.append(SCNVector3(x, y, z))
        }

        return result
    }

    private func readAccessorFloat2(index: Int) throws -> [SIMD2<Float>] {
        let accessors = gltf["accessors"] as? [[String: Any]] ?? []
        guard index < accessors.count else { throw GLBError.missingData("accessor \(index)") }

        let acc = accessors[index]
        let count = acc["count"] as? Int ?? 0
        let bvIndex = acc["bufferView"] as? Int ?? 0
        let byteOffset = acc["byteOffset"] as? Int ?? 0

        let bvData = try readBufferView(index: bvIndex)
        let bufferViews = gltf["bufferViews"] as? [[String: Any]] ?? []
        let byteStride = (bvIndex < bufferViews.count ? bufferViews[bvIndex]["byteStride"] as? Int : nil) ?? (2 * 4)

        var result: [SIMD2<Float>] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let off = byteOffset + i * byteStride
            guard off + 8 <= bvData.count else { break }
            let u = bvData.readFloat(at: off)
            let v = bvData.readFloat(at: off + 4)
            result.append(SIMD2(u, v))
        }

        return result
    }

    private func readAccessorMat4(index: Int) throws -> [SCNMatrix4] {
        let accessors = gltf["accessors"] as? [[String: Any]] ?? []
        guard index < accessors.count else { throw GLBError.missingData("accessor \(index)") }

        let acc = accessors[index]
        let count = acc["count"] as? Int ?? 0
        let bvIndex = acc["bufferView"] as? Int ?? 0
        let byteOffset = acc["byteOffset"] as? Int ?? 0

        let bvData = try readBufferView(index: bvIndex)

        var result: [SCNMatrix4] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let off = byteOffset + i * 64  // 16 floats × 4 bytes
            guard off + 64 <= bvData.count else { break }
            // glTF stores column-major
            let m = SCNMatrix4(
                m11: CGFloat(bvData.readFloat(at: off)),
                m12: CGFloat(bvData.readFloat(at: off + 4)),
                m13: CGFloat(bvData.readFloat(at: off + 8)),
                m14: CGFloat(bvData.readFloat(at: off + 12)),
                m21: CGFloat(bvData.readFloat(at: off + 16)),
                m22: CGFloat(bvData.readFloat(at: off + 20)),
                m23: CGFloat(bvData.readFloat(at: off + 24)),
                m24: CGFloat(bvData.readFloat(at: off + 28)),
                m31: CGFloat(bvData.readFloat(at: off + 32)),
                m32: CGFloat(bvData.readFloat(at: off + 36)),
                m33: CGFloat(bvData.readFloat(at: off + 40)),
                m34: CGFloat(bvData.readFloat(at: off + 44)),
                m41: CGFloat(bvData.readFloat(at: off + 48)),
                m42: CGFloat(bvData.readFloat(at: off + 52)),
                m43: CGFloat(bvData.readFloat(at: off + 56)),
                m44: CGFloat(bvData.readFloat(at: off + 60))
            )
            result.append(m)
        }

        return result
    }

    /// Read JOINTS_0 accessor as SCNGeometrySource with .boneIndices semantic.
    private func readJointsAccessor(index: Int, vertexCount: Int) throws -> SCNGeometrySource {
        let accessors = gltf["accessors"] as? [[String: Any]] ?? []
        guard index < accessors.count else { throw GLBError.missingData("accessor \(index)") }

        let acc = accessors[index]
        let count = acc["count"] as? Int ?? 0
        let componentType = acc["componentType"] as? Int ?? 5121
        let bvIndex = acc["bufferView"] as? Int ?? 0
        let byteOffset = acc["byteOffset"] as? Int ?? 0

        let bvData = try readBufferView(index: bvIndex)

        // Component type: 5121=UInt8 (4 bytes/vertex), 5123=UInt16 (8 bytes/vertex)
        let bytesPerComponent = componentType == 5123 ? 2 : 1
        let stride = bytesPerComponent * 4

        // Extract raw joint index data
        var jointData = Data(capacity: count * stride)
        let bufferViews = gltf["bufferViews"] as? [[String: Any]] ?? []
        let bvStride = (bvIndex < bufferViews.count ? bufferViews[bvIndex]["byteStride"] as? Int : nil) ?? stride

        for i in 0..<count {
            let off = byteOffset + i * bvStride
            guard off + stride <= bvData.count else { break }
            jointData.append(bvData.subdata(in: off..<(off + stride)))
        }

        // SCNSkinner requires UInt16 bone indices
        let finalData: Data
        let finalBytesPerComponent: Int
        if bytesPerComponent == 1 {
            // Upconvert UInt8 → UInt16
            var converted = Data(capacity: count * 8)
            for i in 0..<(jointData.count) {
                let val = UInt16(jointData[jointData.startIndex + i])
                var le = val.littleEndian
                converted.append(Data(bytes: &le, count: 2))
            }
            finalData = converted
            finalBytesPerComponent = 2
        } else {
            finalData = jointData
            finalBytesPerComponent = 2
        }

        return SCNGeometrySource(
            data: finalData,
            semantic: .boneIndices,
            vectorCount: count,
            usesFloatComponents: false,
            componentsPerVector: 4,
            bytesPerComponent: finalBytesPerComponent,
            dataOffset: 0,
            dataStride: finalBytesPerComponent * 4
        )
    }

    /// Read WEIGHTS_0 accessor as SCNGeometrySource with .boneWeights semantic.
    private func readWeightsAccessor(index: Int, vertexCount: Int) throws -> SCNGeometrySource {
        let accessors = gltf["accessors"] as? [[String: Any]] ?? []
        guard index < accessors.count else { throw GLBError.missingData("accessor \(index)") }

        let acc = accessors[index]
        let count = acc["count"] as? Int ?? 0
        let bvIndex = acc["bufferView"] as? Int ?? 0
        let byteOffset = acc["byteOffset"] as? Int ?? 0

        let bvData = try readBufferView(index: bvIndex)
        let bufferViews = gltf["bufferViews"] as? [[String: Any]] ?? []
        let bvStride = (bvIndex < bufferViews.count ? bufferViews[bvIndex]["byteStride"] as? Int : nil) ?? 16

        var weightData = Data(capacity: count * 16)
        for i in 0..<count {
            let off = byteOffset + i * bvStride
            guard off + 16 <= bvData.count else { break }
            weightData.append(bvData.subdata(in: off..<(off + 16)))
        }

        return SCNGeometrySource(
            data: weightData,
            semantic: .boneWeights,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: 4,
            dataOffset: 0,
            dataStride: 16
        )
    }

    private func readIndices(accessorIndex: Int) throws -> SCNGeometryElement {
        let accessors = gltf["accessors"] as? [[String: Any]] ?? []
        guard accessorIndex < accessors.count else { throw GLBError.missingData("accessor \(accessorIndex)") }

        let acc = accessors[accessorIndex]
        let count = acc["count"] as? Int ?? 0
        let componentType = acc["componentType"] as? Int ?? 5123
        let bvIndex = acc["bufferView"] as? Int ?? 0
        let byteOffset = acc["byteOffset"] as? Int ?? 0

        let bvData = try readBufferView(index: bvIndex)

        switch componentType {
        case 5121:
            var indices: [UInt32] = []
            for i in 0..<count {
                let off = byteOffset + i
                guard off < bvData.count else { break }
                indices.append(UInt32(bvData[off]))
            }
            return SCNGeometryElement(indices: indices, primitiveType: .triangles)

        case 5123:
            var indices: [UInt16] = []
            for i in 0..<count {
                let off = byteOffset + i * 2
                guard off + 2 <= bvData.count else { break }
                indices.append(bvData.readUInt16(at: off))
            }
            return SCNGeometryElement(indices: indices, primitiveType: .triangles)

        case 5125:
            var indices: [UInt32] = []
            for i in 0..<count {
                let off = byteOffset + i * 4
                guard off + 4 <= bvData.count else { break }
                indices.append(bvData.readUInt32LE(at: off))
            }
            return SCNGeometryElement(indices: indices, primitiveType: .triangles)

        default:
            throw GLBError.missingData("unsupported index component type \(componentType)")
        }
    }

    // MARK: - Buffer reading

    private func readBufferView(index: Int) throws -> Data {
        let bufferViews = gltf["bufferViews"] as? [[String: Any]] ?? []
        guard index < bufferViews.count else { throw GLBError.missingData("bufferView \(index)") }

        let bv = bufferViews[index]
        let byteOffset = bv["byteOffset"] as? Int ?? 0
        let byteLength = bv["byteLength"] as? Int ?? 0

        guard byteOffset + byteLength <= bin.count else {
            throw GLBError.missingData("bufferView \(index) out of range")
        }

        return bin.subdata(in: byteOffset..<(byteOffset + byteLength))
    }
}

/// Internal struct to pass skinning data from geometry building to skinning phase.
@objc private class SkinGeometryData: NSObject {
    let joints: SCNGeometrySource
    let weights: SCNGeometrySource

    init(joints: SCNGeometrySource, weights: SCNGeometrySource) {
        self.joints = joints
        self.weights = weights
    }
}

// MARK: - Data helpers

private extension Data {
    func readUInt32(at offset: Int) -> UInt32 {
        withUnsafeBytes { buf in
            buf.load(fromByteOffset: offset, as: UInt32.self)
        }
    }

    func readUInt16(at offset: Int) -> UInt16 {
        withUnsafeBytes { buf in
            buf.load(fromByteOffset: offset, as: UInt16.self)
        }
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        withUnsafeBytes { buf in
            buf.load(fromByteOffset: offset, as: UInt32.self)
        }
    }

    func readFloat(at offset: Int) -> Float {
        withUnsafeBytes { buf in
            buf.load(fromByteOffset: offset, as: Float.self)
        }
    }

    subscript(offset offset: Int) -> UInt8 {
        self[self.startIndex + offset]
    }
}

// MARK: - simd helpers

private extension float4x4 {
    init(_ values: [Double]) {
        self.init(
            SIMD4<Float>(Float(values[0]), Float(values[1]), Float(values[2]), Float(values[3])),
            SIMD4<Float>(Float(values[4]), Float(values[5]), Float(values[6]), Float(values[7])),
            SIMD4<Float>(Float(values[8]), Float(values[9]), Float(values[10]), Float(values[11])),
            SIMD4<Float>(Float(values[12]), Float(values[13]), Float(values[14]), Float(values[15]))
        )
    }
}
