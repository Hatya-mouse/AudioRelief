//
//  ContentView.swift
//  AudioRelief
//
//  Created by Shuntaro Kasatani on 2026/02/24.
//

import SwiftUI
import RealityKit

let meshSize: SIMD2<Float> = [1.0, 1.0]
let meshDimension: SIMD2<Int> = [256, 256]

struct ContentView: View {
    enum CurrentMode: String, CaseIterable {
        case edit = "Edit"
        case camera = "Camera"
        var id: String { rawValue }
    }
    
    @State var lastDragWidth: CGFloat = 0
    @State var dragPoint: CGPoint = .zero
    @State var lastRotateAmount: CGSize = .zero
    @State var totalAngle: SIMD2<Float> = .zero
    @State var magnifyAmount: CGFloat = 1.0
    
    @State var radius: Float = 10
    @State var strength: Float = 0
    
    @State var isPlayingAudio: Bool = false
    @State var currentMode: CurrentMode = .edit
    
    let device = MTLCreateSystemDefaultDevice()!
    let commandQueue: MTLCommandQueue
    
    let heightMapBuffer: (any MTLBuffer)?
    let heightMapMeshEntity: HeightMapMeshEntity
    
    let audioPlayer: AudioPlayer?
    
    init() {
        commandQueue = device.makeCommandQueue()!
        
        let w = meshDimension.x
        let h = meshDimension.y
        
        let heightMap = [Float].init(repeating: 0.5, count: w * h)
        let bufferSize = w * h * MemoryLayout<Float>.size
        
        if let buffer = device.makeBuffer(bytes: heightMap, length: bufferSize, options: .storageModeShared) {
            heightMapBuffer = buffer
            audioPlayer = AudioPlayer(dimension: meshDimension, buffer: buffer)
        } else {
            heightMapBuffer = nil
            audioPlayer = nil
        }

        heightMapMeshEntity = HeightMapMeshEntity(device: device, playhead: audioPlayer!.playhead, size: meshSize, dimensions: [UInt32(meshDimension.x), UInt32(meshDimension.y)], maxThickness: 0.25, baseThickness: 0.1)
    }
    
    var body: some View {
        VStack {
            HStack {
                Slider(
                    value: $radius,
                    in: 1...10,
                )
                Slider(
                    value: $strength,
                    in: -100...100,
                )
                Group {
                    ForEach(CurrentMode.allCases, id: \.id) { option in
                        Button {
                            currentMode = option
                        } label: {
                            switch option {
                            case .edit:
                                Image(systemName: "pencil")
                            case .camera:
                                Image(systemName: "move.3d")
                            }
                        }
                    }
                }
                Button {
                    isPlayingAudio.toggle()
                    if isPlayingAudio {
                        audioPlayer?.play()
                        heightMapMeshEntity.isPlayingAudio = true
                    } else {
                        audioPlayer?.pause()
                        heightMapMeshEntity.isPlayingAudio = false
                    }
                } label: {
                    if isPlayingAudio {
                        Image(systemName: "pause.fill")
                    } else {
                        Image(systemName: "play.fill")
                    }
                }
            }
            .padding()
            
            RealityView { content in
                // Add the HeightMapMeshEntity
                content.add(heightMapMeshEntity)
                // Set the initial transform for the entity
                heightMapMeshEntity.transform = Transform(translation: [0, -0.2, 0])
                
                // Prepare the mesh
                guard let commandBuffer = commandQueue.makeCommandBuffer(),
                      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
                let context = ComputeUpdateContext(commandBuffer: commandBuffer, computeEncoder: computeEncoder)
                heightMapMeshEntity.heightMapMesh?.prepareMesh(computeContext: context, heightMapBuffer: heightMapBuffer, height: 0.5)
                
                computeEncoder.endEncoding()
                commandBuffer.commit()
                
                _ = content.subscribe(to: SceneEvents.Update.self) { event in
                    guard let commandBuffer = commandQueue.makeCommandBuffer(),
                          let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
                    let context = ComputeUpdateContext(commandBuffer: commandBuffer, computeEncoder: computeEncoder)
                    heightMapMeshEntity.heightMapMesh?.update(computeContext: context, heightMapBuffer: heightMapBuffer, radius: radius * 0.1, strength: strength * 0.0001)
                    
                    computeEncoder.endEncoding()
                    commandBuffer.commit()
                    
                    heightMapMeshEntity.updateMaterial()
                }
            } update: { content in
                if currentMode == .edit {
                    guard let ray = content.ray(through: dragPoint, in: .global, to: .scene) else { return }
                    
                    if let scene = heightMapMeshEntity.scene {
                        let hits = scene.raycast(origin: ray.origin, direction: ray.direction, length: 100)
                        
                        if let firstHit = hits.first {
                            if heightMapMeshEntity.heightMapMesh!.isInteractionHappening {
                                let localLocation = heightMapMeshEntity.convert(position: firstHit.position, from: nil)
                                let interactionPosition = SIMD2(localLocation.x, localLocation.z)
                                heightMapMeshEntity.heightMapMesh?.interactionPosition = interactionPosition
                                heightMapMeshEntity.highlightCursor(cursorLocation: interactionPosition, radius: radius * 0.1)
                            }
                        }
                    }
                }
            }
            .gesture(
                currentMode == .edit
                ? DragGesture(coordinateSpace: .global)
                    .targetedToEntity(heightMapMeshEntity)
                    .onChanged { value in
                        dragPoint = value.location
                        heightMapMeshEntity.heightMapMesh?.isInteractionHappening = true
                    }
                    .onEnded { value in
                        dragPoint = value.location
                        heightMapMeshEntity.heightMapMesh?.isInteractionHappening = false
                        heightMapMeshEntity.stopHighlight()
                        heightMapMeshEntity.updateCollision()
                        
                        audioPlayer?.updateFrequencies()
                    } : nil
            )
            .gesture(
                currentMode == .camera
                ? DragGesture()
                    .onChanged { value in
                        let rotDelta: SIMD2<Float> = [Float(value.translation.width - lastRotateAmount.width), Float(value.translation.height - lastRotateAmount.height)]
                        totalAngle += rotDelta / 1000
                        let rotY = simd_quatf(angle: totalAngle.y, axis: SIMD3(1, 0, 0))
                        let rotX = simd_quatf(angle: totalAngle.x, axis: SIMD3(0, 1, 0))
                        heightMapMeshEntity.setOrientation(rotY * rotX, relativeTo: nil)
                        lastRotateAmount = value.translation
                    }
                    .onEnded { _ in
                        lastRotateAmount = .zero
                    } : nil
            )
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        magnifyAmount *= value.magnification
                    }
            )
        }
    }
}
