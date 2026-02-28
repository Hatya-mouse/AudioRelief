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
        RealityView { content in
            // Add the HeightMapMeshEntity
            content.add(viewModel.heightMapMeshEntity)
            
            // Prepare the mesh
            guard let commandBuffer = viewModel.commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
            let context = ComputeUpdateContext(commandBuffer: commandBuffer, computeEncoder: computeEncoder)
            viewModel.heightMapMeshEntity.heightMapMesh?.prepareMesh(computeContext: context, heightMapBuffer: viewModel.heightMapGPUBuffer, height: 0.5)
            
            computeEncoder.endEncoding()
            commandBuffer.commit()
            
            _ = content.subscribe(to: SceneEvents.Update.self) { event in
                guard let commandBuffer = viewModel.commandQueue.makeCommandBuffer(),
                      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
                let context = ComputeUpdateContext(commandBuffer: commandBuffer, computeEncoder: computeEncoder)
                viewModel.heightMapMeshEntity.heightMapMesh?.update(computeContext: context, heightMapBuffer: viewModel.heightMapGPUBuffer, brush: viewModel.brush)
                
                computeEncoder.endEncoding()
                commandBuffer.commit()
                
                viewModel.heightMapMeshEntity.updateMaterial(playhead: viewModel.isPlayingAudio ? viewModel.audioPlayer!.playhead : -1)
            }
        } update: { content in
            if viewModel.currentMode == .edit {
                guard let ray = content.ray(through: viewModel.dragPoint, in: .global, to: .scene) else { return }
                
                if let scene = viewModel.heightMapMeshEntity.scene {
                    let hits = scene.raycast(origin: ray.origin, direction: ray.direction, length: 100)
                    
                    if let firstHit = hits.first {
                        if viewModel.heightMapMeshEntity.heightMapMesh!.isInteractionHappening {
                            let localLocation = viewModel.heightMapMeshEntity.convert(position: firstHit.position, from: nil)
                            let interactionPosition = SIMD2(localLocation.x, localLocation.z)
                            viewModel.heightMapMeshEntity.heightMapMesh?.interactionPosition = interactionPosition
                            viewModel.heightMapMeshEntity.highlightCursor(cursorLocation: interactionPosition, radius: viewModel.brush.radius)
                        }
                    }
                }
            }
        }
        .gesture(editGesture)
        .gesture(cameraMoveGesture)
        .gesture(magnifyGesture)
    }
    
    var editGesture: (some Gesture)? {
        viewModel.currentMode == .edit
        ? DragGesture(coordinateSpace: .global)
            .targetedToEntity(viewModel.heightMapMeshEntity)
            .onChanged { value in
                viewModel.dragPoint = value.location
                viewModel.heightMapMeshEntity.heightMapMesh?.isInteractionHappening = true
            }
            .onEnded { value in
                viewModel.dragPoint = value.location
                viewModel.heightMapMeshEntity.heightMapMesh?.isInteractionHappening = false
                
                viewModel.heightMapMeshEntity.stopHighlight()
                viewModel.heightMapMeshEntity.updateCollision()
                
                let src = viewModel.heightMapGPUBuffer!.contents()
                let dst = viewModel.heightMapAudioBuffer!.contents()
                memcpy(dst, src, viewModel.heightMapGPUBuffer!.length)
                viewModel.audioPlayer?.updateFrequencies()
            }
        : nil
    }
    
    var cameraMoveGesture: (some Gesture)? {
        viewModel.currentMode == .camera
        ? DragGesture()
            .onChanged { value in
                let rotDelta: SIMD2<Float> = [Float(value.translation.width - viewModel.lastRotateAmount.width), Float(value.translation.height - viewModel.lastRotateAmount.height)]
                viewModel.totalAngle += rotDelta / 700
                viewModel.totalAngle.y = max(-.pi / 2, min(viewModel.totalAngle.y, .pi / 2))
                let rotX = simd_quatf(angle: viewModel.totalAngle.x, axis: SIMD3(0, 1, 0))
                let rotY = simd_quatf(angle: viewModel.totalAngle.y, axis: SIMD3(1, 0, 0))
                viewModel.heightMapMeshEntity.setOrientation(rotY * rotX, relativeTo: nil)
                viewModel.lastRotateAmount = value.translation
            }
            .onEnded { _ in
                viewModel.lastRotateAmount = .zero
            }
        : nil
    }
    
    var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let logScale = log(Float(value.magnification))
                viewModel.magnifyAmount = max(0.5, min(viewModel.initialMagnify + logScale, 2.0))
                viewModel.heightMapMeshEntity.transform.translation = [0, 0, -1 + viewModel.magnifyAmount]
            }
            .onEnded { _ in
                viewModel.initialMagnify = viewModel.magnifyAmount
            }
    }
}
