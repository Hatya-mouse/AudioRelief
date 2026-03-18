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
    
    var imageName: String {
        switch self {
        case .smooth: "smooth"
        case .sharp: "sharp"
        case .square: "square"
        }
    }
    var displayName: String { imageName.capitalized }
}

class BrushMode {
    var brushType: BrushType = .smooth
    var radius: Float = 0.1
    var strength: Float = 0.01
}

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isDrawing: Bool = false
    @Published var dragPoint: CGPoint = .zero
    var sculptPoint: SIMD2<Float> = .zero
    
    @Published var lastRotateAmount: CGSize = .zero
    @Published var totalAngle: SIMD2<Float> = .zero
    
    @Published var initialMagnify: Float = 1.0
    @Published var magnifyAmount: Float = 0.0
    
    @Published var brush: BrushMode = BrushMode()
    
    @Published var currentMode: ViewMode = .edit
    @Published var isPlayingAudio: Bool = false
    @Published var playbackSpeed: Float = 10.0 {
        didSet {
            audioPlayer?.setPlaybackSpeed(playbackSpeed)
        }
    }
    
    @Published var document: BufferFile
    
    let device = MTLCreateSystemDefaultDevice()!
    let commandQueue: MTLCommandQueue
    
    /// A heightmap buffer for gpu.
    let heightMapBuffer: MTLBufferPair?
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
            heightMapBuffer = MTLBufferPair(gpuBuffer, audioBuffer, capacity: bufferSize)
            audioPlayer = AudioPlayer(dimension: meshDimension, pointer: heightMapBuffer!.pointer)
        } else {
            heightMapBuffer = nil
            audioPlayer = nil
        }
        
        // Set the audio session category to playback
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        
        heightMapMeshEntity = HeightMapMeshEntity(device: device, size: meshSize, dimensions: [UInt32(meshDimension.x), UInt32(meshDimension.y)], maxThickness: 0.25, baseThickness: 0.1)
        
        document = BufferFile()
    }
    
    func playAudio() {
        audioPlayer?.play()
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
    }
    
    func loadBuffer() throws {
        let newBuffer = try document.loadData(device: device)
        heightMapBuffer?.replaceBuffer(newBuffer, capacity: newBuffer.length)
        heightMapBuffer?.swap()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
                                     let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        let context = ComputeUpdateContext(commandBuffer: commandBuffer, computeEncoder: computeEncoder)
        let writableBuffer = heightMapBuffer?.getWritableBuffer()
        heightMapMeshEntity.heightMapMesh?.update(computeContext: context, heightMapBuffer: writableBuffer)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    func prepareBufferForExport() {
        let readableBuffer = heightMapBuffer!.getReadableBuffer()
        let data = BufferFile.prepareExportData(device: device, buffer: readableBuffer)
        document.data = data
    }
}
