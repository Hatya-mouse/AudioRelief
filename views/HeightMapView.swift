//
//  HeightMapView.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/27.
//

import SwiftUI
import RealityKit

extension ContentView {
    @ViewBuilder
    var heightMapView: some View {
        GeometryReader { proxy in
            RealityView { content in
                // Add the HeightMapMeshEntity
                content.add(viewModel.heightMapMeshEntity)
                // Set the initial transform
                let initialRotation = simd_quatf(angle: .pi / 4, axis: [1, 0, 0]) * simd_quatf(angle: .pi / 4, axis: [0, 1, 0])
                viewModel.heightMapMeshEntity.transform = Transform(rotation: initialRotation)
                viewModel.totalAngle = [.pi / 4, .pi / 4]
                
                // Prepare the mesh
                guard let commandBuffer = viewModel.commandQueue.makeCommandBuffer(),
                      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
                let context = ComputeUpdateContext(commandBuffer: commandBuffer, computeEncoder: computeEncoder)
                viewModel.heightMapMeshEntity.heightMapMesh?.prepareMesh(computeContext: context, heightMapBuffer: viewModel.heightMapBuffer?.getWritableBuffer(), height: 0.5)
                
                computeEncoder.endEncoding()
                commandBuffer.commit()
                
                viewModel.heightMapBuffer?.swap()
                
                _ = content.subscribe(to: SceneEvents.Update.self) { event in
                    if viewModel.isDrawing {
                        sculptAndUpdate()
                    }
                    viewModel.heightMapMeshEntity.updateMaterial(playhead: viewModel.isPlayingAudio ? viewModel.audioPlayer!.getPlayhead() : -1)
                }
            } update: { content in
                if viewModel.currentMode == .edit {
                    guard let ray = content.ray(through: viewModel.dragPoint, in: .global, to: .scene) else { return }
                    
                    if let scene = viewModel.heightMapMeshEntity.scene {
                        let hits = scene.raycast(origin: ray.origin, direction: ray.direction, length: 100)
                        
                        if let firstHit = hits.first {
                            let localLocation = viewModel.heightMapMeshEntity.convert(position: firstHit.position, from: nil)
                            let interactionPosition: SIMD2<Float> = [localLocation.x, localLocation.z]
                            viewModel.sculptPoint = interactionPosition
                        }
                    }
                }
            }
            .gesture(editGesture)
            .gesture(cameraMoveGesture(proxy.size))
            .gesture(magnifyGesture(proxy.size.width))
        }
    }
    
    func sculptAndUpdate() {
        guard let commandBuffer = viewModel.commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        let context = ComputeUpdateContext(commandBuffer: commandBuffer, computeEncoder: computeEncoder)
        viewModel.heightMapMeshEntity.heightMapMesh?.sculptAndUpdate(computeContext: context, heightMapBuffer: viewModel.heightMapBuffer?.getWritableBuffer(), brush: viewModel.brush, sculptPoint: viewModel.sculptPoint)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    var editGesture: (some Gesture)? {
        viewModel.currentMode == .edit
        ? DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .targetedToEntity(viewModel.heightMapMeshEntity)
            .onChanged { value in
                viewModel.dragPoint = value.location
                viewModel.isDrawing = true
                viewModel.heightMapMeshEntity.highlightCursor(
                    cursorLocation: viewModel.sculptPoint,
                    radius: viewModel.brush.radius
                )
            }
            .onEnded { value in
                viewModel.dragPoint = value.location
                viewModel.isDrawing = false
                
                viewModel.heightMapMeshEntity.stopHighlight()
                viewModel.heightMapMeshEntity.updateCollision()
                
                viewModel.heightMapBuffer?.swap()
                viewModel.audioPlayer?.updateFrequencies()
            }
        : nil
    }
    
    func cameraMoveGesture(_ viewSize: CGSize) -> (some Gesture)? {
        viewModel.currentMode == .camera
        ? DragGesture()
            .onChanged { value in
                // Adjust the drag amount based on the view size
                let adjustedWidth = value.translation.width / viewSize.width
                let adjustedHeight = value.translation.height / viewSize.height
                // Calculate the rotation delta
                let rotDelta: SIMD2<Float> = [Float(adjustedWidth - viewModel.lastRotateAmount.width), Float(adjustedHeight - viewModel.lastRotateAmount.height)]
                viewModel.totalAngle += rotDelta * 4
                // Limit pitch rotation
                viewModel.totalAngle.y = max(-.pi / 2, min(viewModel.totalAngle.y, .pi / 2))
                // Apply the rotation
                let rotX = simd_quatf(angle: viewModel.totalAngle.x, axis: SIMD3(0, 1, 0))
                let rotY = simd_quatf(angle: viewModel.totalAngle.y, axis: SIMD3(1, 0, 0))
                viewModel.heightMapMeshEntity.setOrientation(rotY * rotX, relativeTo: nil)
                viewModel.lastRotateAmount = CGSize(width: adjustedWidth, height: adjustedHeight)
            }
            .onEnded { _ in
                viewModel.lastRotateAmount = .zero
            }
        : nil
    }
    
    func magnifyGesture(_ viewWidth: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // Adjust the magnification amount based on the view width
//                let adjustedMagnification = Float(value.magnification / viewWidth)
                // Apply log to the magnification amount
                let logScale = log(Float(value.magnification))
                // Apply the magnification
                viewModel.magnifyAmount = max(0.5, min(viewModel.initialMagnify + logScale, 2.0))
                viewModel.heightMapMeshEntity.transform.translation = [0, 0, -1 + viewModel.magnifyAmount]
            }
            .onEnded { _ in
                viewModel.initialMagnify = viewModel.magnifyAmount
            }
    }
}
