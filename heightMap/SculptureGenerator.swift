//
//  SculptureGenerator.swift
//  AudioRelief
//
//  Created by Shuntaro Kasatani on 2026/02/25.
//

import Foundation
import RealityKit
import Metal

@MainActor
class SculptureGenerator {
    let metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()

    func makeComputePipeline(named name: String) -> MTLComputePipelineState? {
        guard let function = metalDevice?.makeDefaultLibrary()?.makeFunction(name: name) else {
            return nil
        }
        return try? metalDevice?.makeComputePipelineState(function: function)
    }

    func sculptSurface(computeContext: ComputeUpdateContext, heightMapBuffer: (any MTLBuffer)?, sculptureParams: inout SculptureParams) {
        let w = Int(sculptureParams.dimensions.x)
        let h = Int(sculptureParams.dimensions.y)
        
        let sculptSurfacePipeline = makeComputePipeline(named: "sculptSurface")!
        computeContext.computeEncoder.setComputePipelineState(sculptSurfacePipeline)
        
        computeContext.computeEncoder.setBytes(&sculptureParams, length: MemoryLayout<SculptureParams>.size, index: 0)
        computeContext.computeEncoder.setBuffer(heightMapBuffer, offset: 0, index: 1)

        let threadsPerGroup = MTLSize(width: 8, height: 8, depth: 1)
        let numGroups = MTLSize(width: (w + 7) / 8, height: (h + 7) / 8, depth: 1)

        computeContext.computeEncoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerGroup)
    }
    
    func updateVertices(computeContext: ComputeUpdateContext, mesh: LowLevelMesh, heightMapBuffer: (any MTLBuffer)?, meshParams: inout MeshParams) {
        let w = Int(meshParams.dimensions.x)
        let h = Int(meshParams.dimensions.y)
        
        let setVerticesPipeline = makeComputePipeline(named: "setVertexData")!
        computeContext.computeEncoder.setComputePipelineState(setVerticesPipeline)
        
        computeContext.computeEncoder.setBytes(&meshParams, length: MemoryLayout<MeshParams>.stride, index: 0)
        let vertexBuffer = mesh.replace(bufferIndex: 0, using: computeContext.commandBuffer)
        computeContext.computeEncoder.setBuffer(vertexBuffer, offset: 0, index: 1)
        computeContext.computeEncoder.setBuffer(heightMapBuffer, offset: 0, index: 2)
        
        let threadsPerGroup = MTLSize(width: 8, height: 8, depth: 1)
        let numGroups = MTLSize(width: (w + 7) / 8, height: (h + 7) / 8, depth: 1)
        
        computeContext.computeEncoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerGroup)
    }
}
