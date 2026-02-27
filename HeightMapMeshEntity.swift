//
//  HeightMapMeshEntity.swift
//  AudioRelief
//
//  Created by Shuntaro Kasatani on 2026/02/25.
//

import Foundation
import RealityKit
import Metal

class HeightMapMeshEntity: Entity, HasModel {
    var heightMapMesh: HeightMapMesh?
    
    var playhead: UnsafePointer<Float>?
    var isPlayingAudio: Bool = false
    var cursorLocation: SIMD2<Float> = .zero
    var radius: Float = 0
    
    private func setup(device: MTLDevice?, playhead: UnsafePointer<Float>?, size: SIMD2<Float>, dimensions: SIMD2<UInt32>, maxThickness: Float, baseThickness: Float) {
        guard let heightMapMesh = try? HeightMapMesh(size: size, dimensions: dimensions, maxThickness: maxThickness, baseThickness: baseThickness),
              let lowLevelMesh = try? MeshResource(from: heightMapMesh.mesh) else {
            assertionFailure("Failed to create height map mesh and get its low-level mesh.")
            return
        }
        self.heightMapMesh = heightMapMesh
        self.playhead = playhead
        
        // Setup the material
        if let device = device {
            let library = device.makeDefaultLibrary()!
            let highlightShader = CustomMaterial.SurfaceShader(named: "highlightCursorShader", in: library)
            var material = try! CustomMaterial(surfaceShader: highlightShader, lightingModel: .lit)
            material.custom.value = SIMD4(.zero, maxThickness)
            self.components.set(ModelComponent(mesh: lowLevelMesh, materials: [material]))
        }
        
        self.components.set(InputTargetComponent())
        
        self.updateCollision()
    }
    
    init(device: MTLDevice, playhead: UnsafePointer<Float>, size: SIMD2<Float>, dimensions: SIMD2<UInt32>, maxThickness: Float, baseThickness: Float) {
        super.init()
        setup(device: device, playhead: playhead, size: size, dimensions: dimensions, maxThickness: maxThickness, baseThickness: baseThickness)
    }
    
    required init() {
        super.init()
        setup(device: nil, playhead: nil, size: [1, 1], dimensions: [512, 512], maxThickness: 1, baseThickness: 0.5)
    }
    
    func updateCollision() {
        Task {
            if let mesh = heightMapMesh?.mesh {
                guard let meshResource = try? await MeshResource(from: mesh) else {
                    //                    print("MeshResource initialization failed")
                    return
                }
                guard let shape = try? await ShapeResource.generateStaticMesh(from: meshResource) else {
                    //                    print("ShapeResource.generateStaticMesh failed")
                    return
                }
                let newCollision = CollisionComponent(shapes: [shape])
                self.components.set(newCollision)
            }
        }
    }
    
    func getPlayhead() -> Float {
        if isPlayingAudio {
            return playhead?.pointee ?? 0
        } else {
            return -1
        }
    }
    
    func updateMaterial() {
        guard var material = self.model?.materials.first as? CustomMaterial else { return }
        material.custom.value = SIMD4(cursorLocation.x, cursorLocation.y, radius, getPlayhead())
        self.model?.materials = [material]
    }
    
    func highlightCursor(cursorLocation: SIMD2<Float>, radius: Float) {
        self.cursorLocation = cursorLocation
        self.radius = radius
    }
    
    func stopHighlight() {
        self.cursorLocation = .zero
        self.radius = 0
    }
}
