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

struct PlaneVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
}

struct SculptureParams {
    var brush: UInt32
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
