//
//  HeightMapMesh.swift
//  AudioRelief
//
//  Created by Shuntaro Kasatani on 2026/02/25.
//

import Foundation
import RealityKit
import Metal

struct PlaneVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
}

@MainActor
class HeightMapMesh {
    var mesh: LowLevelMesh!
//    var heightMap: HeightMap!
    var heightMapGenerator = SculptureGenerator()

    let size: SIMD2<Float>
    let dimensions: SIMD2<UInt32>
    let maxThickness: Float
    let baseThickness: Float
    
    var interactionPosition: SIMD2<Float>
    var isInteractionHappening: Bool

    init(size: SIMD2<Float>, dimensions: SIMD2<UInt32>, maxThickness: Float, baseThickness: Float) throws {
        self.size = size
        self.dimensions = dimensions
        self.maxThickness = maxThickness
        self.baseThickness = baseThickness
        self.interactionPosition = .zero
        self.isInteractionHappening = false
        
        // Create the low-level mesh.
        self.mesh = try createMesh()
        
        // Fill the mesh's vertex buffer with data.
        initializeVertexData()
        
        // Fill the mesh's index buffer with data.
        initializeIndexData()
        
        // Initialize the mesh parts.
        initializeMeshParts()
    }
    
    private func createMesh() throws -> LowLevelMesh {
        let positionAttributeOffset = MemoryLayout.offset(of: \PlaneVertex.position) ?? 0
        let normalAttributeOffset = MemoryLayout.offset(of: \PlaneVertex.normal) ?? 16
        
        let positionAttribute = LowLevelMesh.Attribute(semantic: .position, format: .float3, offset: positionAttributeOffset)
        let normalAttribute = LowLevelMesh.Attribute(semantic: .normal, format: .float3, offset: normalAttributeOffset)
        
        let vertexAttributes = [positionAttribute, normalAttribute]
        
        let vertexLayouts = [LowLevelMesh.Layout(bufferIndex: 0, bufferStride: MemoryLayout<PlaneVertex>.stride)]
        
        // Derive the vertex and index count from the dimensions.
        let vertexCount = Int(dimensions.x * dimensions.y) * 2
        let indicesPerTriangle = 3
        let trianglesPerCell = 2
        // (dimensions.x - 1) * (dimensions.y - 1): Top surface
        // (dimensions.x - 1) * 2 + (dimensions.y - 1) * 2: Side
        // (dimensions.x - 1) * (dimensions.y - 1): Bottom
        // (6 is 2 + 4 from side and bottom)
        let cellCount = Int((dimensions.x - 1) * (dimensions.y - 1) * 2 + (dimensions.x - 1) * 2 + (dimensions.y - 1) * 2)
        let indexCount = indicesPerTriangle * trianglesPerCell * cellCount
        
        // Create a low-level mesh with the necessary `PlaneVertex` capacity.
        let meshDescriptor = LowLevelMesh.Descriptor(vertexCapacity: vertexCount,
                                                     vertexAttributes: vertexAttributes,
                                                     vertexLayouts: vertexLayouts,
                                                     indexCapacity: indexCount)
        return try LowLevelMesh(descriptor: meshDescriptor)
    }
    
    /// Calculate the index of the top surface in the vertex array of the mesh.
    private func getTopVertexIndex(_ xCoord: UInt32, _ yCoord: UInt32) -> UInt32 {
        xCoord + dimensions.x * yCoord
    }
    
    /// Calculate the index of the bottom surface in the vertex array of the mesh.
    private func getBottomVertexIndex(_ xCoord: UInt32, _ yCoord: UInt32) -> UInt32 {
        getTopVertexIndex(dimensions.x - 1, dimensions.y - 1) + getTopVertexIndex(xCoord, yCoord)
    }
    
    private func initializeVertexData() {
        // Initialize mesh vertex positions and normals.
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            // Convert `rawBytes` into a `PlaneVertex` buffer pointer.
            let vertices = rawBytes.bindMemory(to: PlaneVertex.self)

            // Define the normal direction for the vertices.
            let normalDirection: SIMD3<Float> = [0, 1, 0]

            // Iterate through each vertex of the top surface.
            for xCoord in 0..<dimensions.x {
                for zCoord in 0..<dimensions.y {
                    // Remap the x and z vertex coordinates to the range [0, 1].
                    let xCoord01 = Float(xCoord) / Float(dimensions.x - 1)
                    let zCoord01 = Float(zCoord) / Float(dimensions.y - 1)
                    
                    // Derive the vertex position from the remapped vertex coordinates and the size.
                    let xPosition = size.x * xCoord01 - size.x / 2
                    let yPosition = Float(0)
                    let zPosition = size.y * zCoord01 - size.y / 2
                    
                    // Get the current vertex from the vertex coordinates and set its position and normal.
                    let vertexIndex = Int(getTopVertexIndex(xCoord, zCoord))
                    vertices[vertexIndex].position = [xPosition, yPosition, zPosition]
                    vertices[vertexIndex].normal = normalDirection
                }
            }
            
            // Also iterate through each vertex of the bottom surface.
            for xCoord in 0..<dimensions.x {
                for zCoord in 0..<dimensions.y {
                    // Remap the x and z vertex coordinates to the range [0, 1].
                    let xCoord01 = Float(xCoord) / Float(dimensions.x - 1)
                    let zCoord01 = Float(zCoord) / Float(dimensions.y - 1)
                    
                    // Derive the vertex position from the remapped vertex coordinates and the size.
                    let xPosition = size.x * xCoord01 - size.x / 2
                    let yPosition = Float(-baseThickness)
                    let zPosition = size.y * zCoord01 - size.y / 2
                    
                    // Get the current vertex from the vertex coordinates and set its position and normal.
                    let vertexIndex = Int(getBottomVertexIndex(xCoord, zCoord))
                    vertices[vertexIndex].position = [xPosition, yPosition, zPosition]
                    vertices[vertexIndex].normal = -normalDirection
                }
            }
        }
    }
    
    private func initializeIndexData() {
        mesh.withUnsafeMutableIndices { rawIndices in
            // Convert `rawIndices` into a UInt32 pointer.
            guard var indices = rawIndices.baseAddress?.assumingMemoryBound(to: UInt32.self) else { return }
            
            // Iterate through each cell or the top surface.
            for xCoord in 0..<dimensions.x - 1 {
                for yCoord in 0..<dimensions.y - 1 {
                    let topLeft = getTopVertexIndex(xCoord, yCoord)
                    let topRight = getTopVertexIndex(xCoord + 1, yCoord)
                    let bottomRight = getTopVertexIndex(xCoord + 1, yCoord + 1)
                    let bottomLeft = getTopVertexIndex(xCoord, yCoord + 1)
                    
                    addCell(indices, topLeft, topRight, bottomRight, bottomLeft)
                    indices += 6
                }
            }
            
            // Iterate through left & right side cells.
            // Variable Name:
            // 1. Left or Right: left side or right side.
            // 2. Top or Bottom: top or bottom, seen from the top.
            // 3. Top or Bottom: top or bottom, seen from the side.
            for yCoord in 0..<dimensions.y - 1 {
                let leftTopTop = getTopVertexIndex(0, yCoord)
                let leftTopBottom = getBottomVertexIndex(0, yCoord)
                let leftBottomTop = getTopVertexIndex(0, yCoord + 1)
                let leftBottomBottom = getBottomVertexIndex(0, yCoord + 1)
                addCell(indices, leftTopTop, leftBottomTop, leftBottomBottom, leftTopBottom)
                indices += 6
                
                let rightTopTop = getTopVertexIndex(dimensions.x - 1, yCoord)
                let rightTopBottom = getBottomVertexIndex(dimensions.x - 1, yCoord)
                let rightBottomTop = getTopVertexIndex(dimensions.x - 1, yCoord + 1)
                let rightBottomBottom = getBottomVertexIndex(dimensions.x - 1, yCoord + 1)
                addCell(indices, rightBottomTop, rightTopTop, rightTopBottom, rightBottomBottom)
                indices += 6
            }
            
            // Iterate through top & bottom side cells.
            // Variable Name:
            // 1. Top or Bottom: top side or bottom side.
            // 2. Left or Right: left or right, seen from the top.
            // 3. Top or Bottom: top or bottom, seen from the side.
            for xCoord in 0..<dimensions.x - 1 {
                let topLeftTop = getTopVertexIndex(xCoord, 0)
                let topLeftBottom = getBottomVertexIndex(xCoord, 0)
                let topRightTop = getTopVertexIndex(xCoord + 1, 0)
                let topRightBottom = getBottomVertexIndex(xCoord + 1, 0)
                addCell(indices, topRightTop, topLeftTop, topLeftBottom, topRightBottom)
                indices += 6
                
                let bottomLeftTop = getTopVertexIndex(xCoord, dimensions.x - 1)
                let bottomLeftBottom = getBottomVertexIndex(xCoord, dimensions.x - 1)
                let bottomRightTop = getTopVertexIndex(xCoord + 1, dimensions.x - 1)
                let bottomRightBottom = getBottomVertexIndex(xCoord + 1, dimensions.x - 1)
                addCell(indices, bottomLeftTop, bottomRightTop, bottomRightBottom, bottomLeftBottom)
                indices += 6
            }
            
            // Iterate through each cell of the bottom surface.
            for xCoord in 0..<dimensions.x - 1 {
                for yCoord in 0..<dimensions.y - 1 {
                    let topLeft = getBottomVertexIndex(xCoord, yCoord)
                    let topRight = getBottomVertexIndex(xCoord + 1, yCoord)
                    let bottomRight = getBottomVertexIndex(xCoord + 1, yCoord + 1)
                    let bottomLeft = getBottomVertexIndex(xCoord, yCoord + 1)
                    
                    addCell(indices, topLeft, bottomLeft, bottomRight, topRight)
                    indices += 6
                }
            }
        }
    }
    
    /// Add triangle to the indices pointer.
    private func addCell(_ indices: UnsafeMutablePointer<UInt32>, _ topLeft: UInt32, _ topRight: UInt32, _ bottomRight: UInt32, _ bottomLeft: UInt32) {
        /*
           Each cell in the plane mesh consists of two triangles:
            
                      topLeft     topRight
                             |\ ̅ ̅|
             1st Triangle--> | \ | <-- 2nd Triangle
                             | ̲ ̲\|
          +y       bottomLeft     bottomRight
           ^
           |
           *---> +x
         
         */

        indices[0] = topLeft
        indices[1] = bottomLeft
        indices[2] = bottomRight
        
        indices[3] = bottomRight
        indices[4] = topRight
        indices[5] = topLeft
    }

    func initializeMeshParts() {
        // Create a bounding box that encompasses the plane's size and max vertex depth.
        let bounds = BoundingBox(min: [-size.x / 2, 0, -size.y / 2],
                                 max: [size.x / 2, maxThickness, size.y / 2])
        
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: mesh.descriptor.indexCapacity,
                                                 topology: .triangle,
                                                 bounds: bounds)])
    }
    
    func prepareMesh(computeContext: ComputeUpdateContext, heightMapBuffer: (any MTLBuffer)?, height: Float) {
        var meshParams = MeshParams(dimensions: dimensions, size: size, maxThickness: maxThickness)
        heightMapGenerator.updateVertices(computeContext: computeContext, mesh: mesh, heightMapBuffer: heightMapBuffer, meshParams: &meshParams)
    }
    
    func update(computeContext: ComputeUpdateContext, heightMapBuffer: (any MTLBuffer)?, radius: Float, strength: Float) {
        if isInteractionHappening {
            var params = SculptureParams(radius: radius,
                                         strength: strength,
                                         position: interactionPosition,
                                         dimensions: dimensions,
                                         size: size,
                                         cellSize: SIMD2(x: size.x / (Float(dimensions.x) - 1), y: size.y / (Float(dimensions.x) - 1)))
            heightMapGenerator.sculptSurface(computeContext: computeContext, heightMapBuffer: heightMapBuffer, sculptureParams: &params)
            
            var meshParams = MeshParams(dimensions: dimensions, size: size, maxThickness: maxThickness)
            heightMapGenerator.updateVertices(computeContext: computeContext, mesh: mesh, heightMapBuffer: heightMapBuffer, meshParams: &meshParams)
        }
    }
}
