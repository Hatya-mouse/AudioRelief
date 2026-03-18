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
    @StateObject var viewModel = ContentViewModel()
    @StateObject var tutorialModel = TutorialModel()
    
    var body: some View {
        TutorialView(isActive: $tutorialModel.isTutorialActive, currentStepNumber: $tutorialModel.currentStep, onNextStep: tutorialModel.nextStep) {
            NavigationStack {
                ZStack(alignment: .bottom) {
                    // Spotlight region for the tutorial
                    GeometryReader { geometry in
                        Rectangle()
                            .opacity(0)
                            .frame(maxWidth: geometry.size.width / 2, maxHeight: geometry.size.height / 2)
                            .addSpotlight(id: "height_map_view")
                            // Apply position after addSpotlight
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    
                    heightMapView
                    
                    BrushControl(brush: $viewModel.brush, currentMode: viewModel.currentMode)
                        .addSpotlight(id: "brush_control")
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        EditModeButton(currentMode: $viewModel.currentMode)
                            .addSpotlight(id: "edit_mode_button")
                        CameraModeButton(currentMode: $viewModel.currentMode)
                            .addSpotlight(id: "camera_mode_button")
                    }
                    
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        PlaybackSpeedControl(playbackSpeed: $viewModel.playbackSpeed)
                            .padding(.horizontal, 6)
                            .addSpotlight(id: "playback_speed")
                        
                        PlayPauseButton(
                            isPlaying: $viewModel.isPlayingAudio,
                            onPlay: viewModel.playAudio,
                            onPause: viewModel.pauseAudio
                        )
                        .addSpotlight(id: "play_pause_button")
                        .keyboardShortcut(.space, modifiers: [])
                    }
                    
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ExportButton(document: $viewModel.document, prepareDocument: viewModel.prepareBufferForExport, heightMapBuffer: viewModel.heightMapBuffer!)
                            .addSpotlight(id: "export_button")
                        LoadButton(document: $viewModel.document, loadCallback: viewModel.loadBuffer)
                            .addSpotlight(id: "load_button")
                        TutorialButton(
                            isTutorialActive: $tutorialModel.isTutorialActive,
                            currentStepNumber: $tutorialModel.currentStep,
                            currentMode: $viewModel.currentMode
                        )
                        .addSpotlight(id: "tutorial_button")
                    }
                }
            }
        }
    }
}
