import Foundation
import SceneKit

/// Minimal GLB (glTF 2.0 Binary) loader that produces an SCNNode hierarchy.
/// Supports: meshes, materials with PBR base-color textures, node transforms.
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

    /// Load a GLB/VRM file and return the root SCNNode with all meshes/materials.
    static func loadScene(from url: URL) throws -> SCNNode {
        let data = try Data(contentsOf: url)
        return try loadScene(from: data)
    }

    static func loadScene(from data: Data) throws -> SCNNode {
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
            // Align to 4 bytes
            offset = (offset + 3) & ~3
        }

        guard let json = jsonData else { throw GLBError.missingJSONChunk }
        guard let bin = binData else { throw GLBError.missingBINChunk }

        guard let gltf = try JSONSerialization.jsonObject(with: json) as? [String: Any] else {
            throw GLBError.invalidJSON
        }

        let loader = GLBLoader(gltf: gltf, bin: bin)
        return try loader.buildScene()
    }

    // MARK: - Internal state

    private let gltf: [String: Any]
    private let bin: Data
    private var textureCache: [Int: Any] = [:]  // image index → NSImage or CGImage

    private init(gltf: [String: Any], bin: Data) {
        self.gltf = gltf
        self.bin = bin
    }

    // MARK: - Scene building

    private func buildScene() throws -> SCNNode {
        let root = SCNNode()
        root.name = "glb_root"

        // Find the default scene
        let scenes = gltf["scenes"] as? [[String: Any]] ?? []
        let sceneIndex = gltf["scene"] as? Int ?? 0
        guard sceneIndex < scenes.count else { return root }

        let scene = scenes[sceneIndex]
        let rootNodes = scene["nodes"] as? [Int] ?? []
        let allNodes = gltf["nodes"] as? [[String: Any]] ?? []

        for nodeIndex in rootNodes {
            if let node = try buildNode(index: nodeIndex, allNodes: allNodes) {
                root.addChildNode(node)
            }
        }

        return root
    }

    private func buildNode(index: Int, allNodes: [[String: Any]]) throws -> SCNNode? {
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

    // MARK: - Mesh building

    private func buildMesh(index: Int) throws -> SCNNode {
        let meshes = gltf["meshes"] as? [[String: Any]] ?? []
        guard index < meshes.count else { throw GLBError.missingData("mesh \(index)") }

        let meshDef = meshes[index]
        let primitives = meshDef["primitives"] as? [[String: Any]] ?? []
        let meshNode = SCNNode()
        meshNode.name = meshDef["name"] as? String ?? "mesh_\(index)"

        for prim in primitives {
            if let geometry = try buildGeometry(from: prim) {
                let primNode = SCNNode(geometry: geometry)
                meshNode.addChildNode(primNode)
            }
        }

        return meshNode
    }

    private func buildGeometry(from primitive: [String: Any]) throws -> SCNGeometry? {
        let attributes = primitive["attributes"] as? [String: Int] ?? [:]

        // Position data (required)
        guard let posIndex = attributes["POSITION"] else { return nil }
        let positions = try readAccessorFloat3(index: posIndex)

        var sources: [SCNGeometrySource] = []
        sources.append(SCNGeometrySource(vertices: positions))

        // Normals
        if let normIndex = attributes["NORMAL"] {
            let normals = try readAccessorFloat3(index: normIndex)
            sources.append(SCNGeometrySource(normals: normals))
        }

        // Texture coordinates
        if let uvIndex = attributes["TEXCOORD_0"] {
            let uvs = try readAccessorFloat2(index: uvIndex)
            // glTF UVs: flip V for SceneKit (SceneKit uses bottom-left origin)
            let flippedUVs = uvs.map { CGPoint(x: CGFloat($0.x), y: CGFloat(1.0 - $0.y)) }
            sources.append(SCNGeometrySource(textureCoordinates: flippedUVs))
        }

        // Joint weights and indices for skinning (read but skip - we use simple transforms)

        // Index buffer
        var elements: [SCNGeometryElement] = []
        if let indicesIndex = primitive["indices"] as? Int {
            let element = try readIndices(accessorIndex: indicesIndex)
            elements.append(element)
        } else {
            // Non-indexed: generate sequential indices
            let count = positions.count
            let indices = (0..<count).map { UInt32($0) }
            let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
            elements.append(element)
        }

        let geometry = SCNGeometry(sources: sources, elements: elements)

        // Material
        if let matIndex = primitive["material"] as? Int {
            geometry.materials = [try buildMaterial(index: matIndex)]
        } else {
            let defaultMat = SCNMaterial()
            defaultMat.diffuse.contents = NSColor.white
            defaultMat.lightingModel = .physicallyBased
            geometry.materials = [defaultMat]
        }

        return geometry
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

        // PBR Metallic Roughness
        if let pbr = matDef["pbrMetallicRoughness"] as? [String: Any] {
            // Base color factor
            if let factor = pbr["baseColorFactor"] as? [Double], factor.count >= 3 {
                let color = NSColor(
                    red: CGFloat(factor[0]),
                    green: CGFloat(factor[1]),
                    blue: CGFloat(factor[2]),
                    alpha: factor.count > 3 ? CGFloat(factor[3]) : 1.0
                )
                mat.diffuse.contents = color
            }

            // Base color texture
            if let texInfo = pbr["baseColorTexture"] as? [String: Any],
               let texIndex = texInfo["index"] as? Int {
                if let image = try loadTexture(index: texIndex) {
                    mat.diffuse.contents = image
                }
            }

            // Metallic/roughness
            mat.metalness.contents = NSColor(white: CGFloat(pbr["metallicFactor"] as? Double ?? 0.0), alpha: 1)
            mat.roughness.contents = NSColor(white: CGFloat(pbr["roughnessFactor"] as? Double ?? 1.0), alpha: 1)
        }

        // Emissive
        if let emFactor = matDef["emissiveFactor"] as? [Double], emFactor.count >= 3 {
            mat.emission.contents = NSColor(
                red: CGFloat(emFactor[0]),
                green: CGFloat(emFactor[1]),
                blue: CGFloat(emFactor[2]),
                alpha: 1.0
            )
        }

        // Alpha mode
        if let alphaMode = matDef["alphaMode"] as? String {
            switch alphaMode {
            case "BLEND":
                mat.blendMode = .alpha
                mat.transparencyMode = .aOne
                mat.writesToDepthBuffer = false
            case "MASK":
                let cutoff = matDef["alphaCutoff"] as? Double ?? 0.5
                mat.transparencyMode = .aOne
                // SceneKit doesn't have alpha cutoff; use transparency
                if cutoff > 0 {
                    mat.transparency = 1.0
                }
            default:
                break  // OPAQUE
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

        // Embedded image (bufferView reference)
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
        case 5121: // UNSIGNED_BYTE
            var indices: [UInt32] = []
            for i in 0..<count {
                let off = byteOffset + i
                guard off < bvData.count else { break }
                indices.append(UInt32(bvData[off]))
            }
            return SCNGeometryElement(indices: indices, primitiveType: .triangles)

        case 5123: // UNSIGNED_SHORT
            var indices: [UInt16] = []
            for i in 0..<count {
                let off = byteOffset + i * 2
                guard off + 2 <= bvData.count else { break }
                indices.append(bvData.readUInt16(at: off))
            }
            return SCNGeometryElement(indices: indices, primitiveType: .triangles)

        case 5125: // UNSIGNED_INT
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
