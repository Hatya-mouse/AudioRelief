//
//  HeightMap.swift
//  AudioRelief
//
//  Created by Shuntaro Kasatani on 2026/02/25.
//

import Foundation
import RealityKit
import Metal

struct ComputeUpdateContext {
    let commandBuffer: MTLCommandBuffer
    let computeEncoder: MTLComputeCommandEncoder
}

struct SculptureParams {
    var radius: Float
    var strength: Float
    var position: simd_float2
    var dimensions: simd_uint2
    var size: simd_float2
    var cellSize: simd_float2
}

struct MeshParams {
    var dimensions: simd_uint2
    var size: simd_float2
    var maxThickness: Float
}
