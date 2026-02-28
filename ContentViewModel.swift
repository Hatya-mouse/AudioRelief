//
//  ContentViewModel.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/27.
//

import SwiftUI
import RealityKit
import Metal
import AVFoundation

enum ViewMode: String, CaseIterable, Identifiable {
    case edit = "Edit"
    case camera = "Camera"
    var id: String { rawValue }
}

enum BrushType: UInt32, CaseIterable, Identifiable {
    case smooth = 0
    case sharp = 1
    case square = 2
    var id: UInt32 { rawValue }
}

class BrushMode {
    var brushType: BrushType = .smooth
    var radius: Float = 0.1
    var strength: Float = 0
}

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isDragging: Bool = false
    @Published var lastDragWidth: CGFloat = 0.0
    @Published var dragPoint: CGPoint = .zero
    @Published var lastRotateAmount: CGSize = .zero
    @Published var totalAngle: SIMD2<Float> = .zero
    
    @Published var initialMagnify: Float = 1.0
    @Published var magnifyAmount: Float = 0.0
    
    @Published var brush: BrushMode = BrushMode()
    
    @Published var isPlayingAudio: Bool = false
    @Published var playbackSpeed: Float = 1.0 {
        didSet {
            audioPlayer?.setPlaybackSpeed(playbackSpeed)
        }
    }
    @Published var currentMode: ViewMode = .edit
    
    let device = MTLCreateSystemDefaultDevice()!
    let commandQueue: MTLCommandQueue
    
    /// A heightmap buffer for gpu.
    let heightMapGPUBuffer: (any MTLBuffer)?
    /// A heightmap buffer for the audio thread.
    let heightMapAudioBuffer: (any MTLBuffer)?
    let heightMapMeshEntity: HeightMapMeshEntity
    
    let audioPlayer: AudioPlayer?
    
    init() {
        commandQueue = device.makeCommandQueue()!
        
        let w = meshDimension.x
        let h = meshDimension.y
        
        let heightMap = [Float].init(repeating: 0.5, count: w * h)
        let bufferSize = w * h * MemoryLayout<Float>.size
        
        if let gpuBuffer = device.makeBuffer(bytes: heightMap, length: bufferSize, options: .storageModeShared),
           let audioBuffer = device.makeBuffer(bytes: heightMap, length: bufferSize, options: .storageModeShared) {
            heightMapGPUBuffer = gpuBuffer
            heightMapAudioBuffer = audioBuffer
            let pointer = audioBuffer.contents().bindMemory(to: Float.self, capacity: bufferSize)
            audioPlayer = AudioPlayer(dimension: meshDimension, pointer: pointer)
        } else {
            heightMapGPUBuffer = nil
            heightMapAudioBuffer = nil
            audioPlayer = nil
        }
        
        // Set the audio session category to playback
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        
        heightMapMeshEntity = HeightMapMeshEntity(device: device, size: meshSize, dimensions: [UInt32(meshDimension.x), UInt32(meshDimension.y)], maxThickness: 0.25, baseThickness: 0.1)
    }
    
    func playAudio() {
        audioPlayer?.play()
        heightMapMeshEntity.isPlayingAudio = true
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        heightMapMeshEntity.isPlayingAudio = false
    }
}
