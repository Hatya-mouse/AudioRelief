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
        let vertexCount = Int(dimensions.x * dimensions.y + dimensions.x + dimensions.y - 2) * 2
        let indicesPerTriangle = 3
        let trianglesPerCell = 2
        
        // Cell count calculation:
        // (dimensions.x - 1) * (dimensions.y - 1): Top surface
        // (dimensions.x - 1) * 2 + (dimensions.y - 1) * 2: Side, upper
        // (dimensions.x - 1) * 2 + (dimensions.y - 1) * 2: Side, lower
        // (dimensions.x - 1) * (dimensions.y - 1): Bottom
        let cellCount = Int((dimensions.x - 1) * (dimensions.y - 1) * 2 + dimensions.x * 4 + dimensions.y * 4 - 8)
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
        let firstBottomIndex = getTopVertexIndex(dimensions.x - 1, dimensions.y - 1) + 1
        return firstBottomIndex + getTopVertexIndex(xCoord, yCoord)
    }
    
    /// Calculate the index of the side surface in the vertex array of the mesh.
    /// Either xCoord or yCoord must be 0 or dimensions.x - 1, dimensions.y - 1.
    private func getSideVertexIndex(_ xCoord: UInt32, _ yCoord: UInt32) -> UInt32 {
        let firstSideIndex = getBottomVertexIndex(dimensions.x - 1, dimensions.y - 1) + 1
        if yCoord == 0 {
            // 0 ~ dimensions.x - 1
            return firstSideIndex + xCoord
        } else if yCoord == dimensions.y - 1 {
            // dimensions.x ~ dimensions.x * 2 - 1
            return firstSideIndex + dimensions.x + xCoord
        } else if xCoord == 0 {
            // dimensions.x * 2 - 1 ~ dimensions.x * 2 + dimensions.y - 3
            // yCoord must not be 0 or dimensions.y - 1 at this point
            return firstSideIndex + dimensions.x * 2 + yCoord - 1
        }
        // dimensions.x * 2 + dimensions.y - 2 ~ dimensions.x * 2 + dimensions.y * 2 - 5
        return firstSideIndex + dimensions.x * 2 + dimensions.y - 3 + yCoord
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
                for yCoord in 0..<dimensions.y {
                    let yPosition = Float(-baseThickness)
                    let vertexIndex = getTopVertexIndex(xCoord, yCoord)
                    setVertexInfo(vertices, vertexIndex, xCoord, yCoord, yPosition, normalDirection)
                }
            }
            
            // Iterate through each vertex of the side surface.
            // Left & right
            let leftSideNormal: SIMD3<Float> = [-1, 0, 0]
            let rightSideNormal: SIMD3<Float> = [1, 0, 0]
            for yCoord in 0..<dimensions.y {
                let yPosition = Float(-baseThickness)
                let leftXCoord: UInt32 = 0
                let leftVertexIndex = getSideVertexIndex(leftXCoord, yCoord)
                var leftNormal = leftSideNormal
                if yCoord == 0 {
                    leftNormal = normalize([-1, 0, -1])
                } else if yCoord == dimensions.y - 1 {
                    leftNormal = normalize([-1, 0, 1])
                }
                setVertexInfo(vertices, leftVertexIndex, leftXCoord, yCoord, yPosition, leftNormal)
                
                let rightXCoord = dimensions.x - 1
                let rightVertexIndex = getSideVertexIndex(rightXCoord, yCoord)
                var rightNormal = rightSideNormal
                if yCoord == 0 {
                    rightNormal = normalize([1, 0, -1])
                } else if yCoord == dimensions.y - 1 {
                    rightNormal = normalize([1, 0, 1])
                }
                setVertexInfo(vertices, rightVertexIndex, rightXCoord, yCoord, yPosition, rightNormal)
            }
            
            // Top & bottom
            let topNormal: SIMD3<Float> = [0, 0, -1]
            let bottomNormal: SIMD3<Float> = [0, 0, 1]
            // xCoord = 1, (dimensions.x - 1) should have been processed by the previous loop at this point
            for xCoord in 1..<dimensions.x - 1 {
                let yPosition = Float(-baseThickness)
                let topYCoord: UInt32 = 0
                let topVertexIndex = getSideVertexIndex(xCoord, topYCoord)
                setVertexInfo(vertices, topVertexIndex, xCoord, topYCoord, yPosition, topNormal)
                
                let bottomYCoord = dimensions.y - 1
                let bottomVertexIndex = getSideVertexIndex(xCoord, bottomYCoord)
                setVertexInfo(vertices, bottomVertexIndex, xCoord, bottomYCoord, yPosition, bottomNormal)
            }
            
            // Also iterate through each vertex of the bottom surface.
            for xCoord in 0..<dimensions.x {
                for yCoord in 0..<dimensions.y {
                    let yPosition = Float(-baseThickness)
                    let vertexIndex = getBottomVertexIndex(xCoord, yCoord)
                    setVertexInfo(vertices, vertexIndex, xCoord, yCoord, yPosition, -normalDirection)
                }
            }
        }
    }
    
    private func setVertexInfo(_ vertices: UnsafeMutableBufferPointer<PlaneVertex>, _ index: UInt32, _ xCoord: UInt32, _ yCoord: UInt32, _ yPosition: Float, _ normal: SIMD3<Float>) {
        // Remap the x and z vertex coordinates to the range [0, 1].
        let xCoord01 = Float(xCoord) / Float(dimensions.x - 1)
        let yCoord01 = Float(yCoord) / Float(dimensions.y - 1)
        
        // Derive the vertex position from the remapped vertex coordinates and the size.
        let xPosition = size.x * xCoord01 - size.x / 2
        let zPosition = size.y * yCoord01 - size.y / 2
        
        // Get the current vertex from the vertex coordinates and set its position and normal.
        let vertexIndex = Int(index)
        vertices[vertexIndex].position = [xPosition, yPosition, zPosition]
        vertices[vertexIndex].normal = normal
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
                    
                    setCellInfo(&indices, topLeft, topRight, bottomRight, bottomLeft)
                }
            }
            
            // Iterate through left & right side cells.
            // 1. Left or Right: left side or right side.
            // 2. Top or Bottom: top or bottom, seen from the top.
            // 3. Top, Middle or Bottom: whether the vertex is on the top, side or bottom surface.
            for yCoord in 0..<dimensions.y - 1 {
                let leftTopTop = getTopVertexIndex(0, yCoord)
                let leftTopSide = getSideVertexIndex(0, yCoord)
                let leftTopBottom = getBottomVertexIndex(0, yCoord)
                let leftBottomTop = getTopVertexIndex(0, yCoord + 1)
                let leftBottomSide = getSideVertexIndex(0, yCoord + 1)
                let leftBottomBottom = getBottomVertexIndex(0, yCoord + 1)
                setCellInfo(&indices, leftTopTop, leftBottomTop, leftBottomSide, leftTopSide)
                setCellInfo(&indices, leftTopSide, leftBottomSide, leftBottomBottom, leftTopBottom)
                
                let rightTopTop = getTopVertexIndex(dimensions.x - 1, yCoord)
                let rightTopSide = getSideVertexIndex(dimensions.x - 1, yCoord)
                let rightTopBottom = getBottomVertexIndex(dimensions.x - 1, yCoord)
                let rightBottomTop = getTopVertexIndex(dimensions.x - 1, yCoord + 1)
                let rightBottomSide = getSideVertexIndex(dimensions.x - 1, yCoord + 1)
                let rightBottomBottom = getBottomVertexIndex(dimensions.x - 1, yCoord + 1)
                setCellInfo(&indices, rightBottomTop, rightTopTop, rightTopSide, rightBottomSide)
                setCellInfo(&indices, rightBottomSide, rightTopSide, rightTopBottom, rightBottomBottom)
            }
            
            // Iterate through top & bottom side cells.
            // 1. Top or Bottom: top side or bottom side.
            // 2. Left or Right: left or right, seen from the top.
            // 3. Top, Middle or Bottom: whether the vertex is on the top, side or bottom surface.
            for xCoord in 0..<dimensions.x - 1 {
                let topLeftTop = getTopVertexIndex(xCoord, 0)
                let topLeftSide = getSideVertexIndex(xCoord, 0)
                let topLeftBottom = getBottomVertexIndex(xCoord, 0)
                let topRightTop = getTopVertexIndex(xCoord + 1, 0)
                let topRightSide = getSideVertexIndex(xCoord + 1, 0)
                let topRightBottom = getBottomVertexIndex(xCoord + 1, 0)
                setCellInfo(&indices, topRightTop, topLeftTop, topLeftSide, topRightSide)
                setCellInfo(&indices, topRightSide, topLeftSide, topLeftBottom, topRightBottom)
                
                let bottomLeftTop = getTopVertexIndex(xCoord, dimensions.y - 1)
                let bottomLeftSide = getSideVertexIndex(xCoord, dimensions.y - 1)
                let bottomLeftBottom = getBottomVertexIndex(xCoord, dimensions.y - 1)
                let bottomRightTop = getTopVertexIndex(xCoord + 1, dimensions.y - 1)
                let bottomRightSide = getSideVertexIndex(xCoord + 1, dimensions.y - 1)
                let bottomRightBottom = getBottomVertexIndex(xCoord + 1, dimensions.y - 1)
                setCellInfo(&indices, bottomLeftTop, bottomRightTop, bottomRightSide, bottomLeftSide)
                setCellInfo(&indices, bottomLeftSide, bottomRightSide, bottomRightBottom, bottomLeftBottom)
            }
            
            // Iterate through each cell of the bottom surface.
            for xCoord in 0..<dimensions.x - 1 {
                for yCoord in 0..<dimensions.y - 1 {
                    let topLeft = getBottomVertexIndex(xCoord, yCoord)
                    let topRight = getBottomVertexIndex(xCoord + 1, yCoord)
                    let bottomRight = getBottomVertexIndex(xCoord + 1, yCoord + 1)
                    let bottomLeft = getBottomVertexIndex(xCoord, yCoord + 1)
                    
                    setCellInfo(&indices, topLeft, bottomLeft, bottomRight, topRight)
                }
            }
        }
    }
    
    /// Add triangle to the indices pointer.
    private func setCellInfo(_ indices: inout UnsafeMutablePointer<UInt32>, _ topLeft: UInt32, _ topRight: UInt32, _ bottomRight: UInt32, _ bottomLeft: UInt32) {
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
        
        indices += 6
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
