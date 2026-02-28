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
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                heightMapView
                BrushControl(brush: $viewModel.brush, currentMode: viewModel.currentMode)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    EditModeButton(currentMode: $viewModel.currentMode)
                        .accessibilityLabel("Change to edit mode")
                    CameraModeButton(currentMode: $viewModel.currentMode)
                        .accessibilityLabel("Change to camera movement mode")
                }
                
                if #available(iOS 26, macOS 26, macCatalyst 26, *) {
                    ToolbarSpacer(.flexible)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    PlayPauseButton(
                        isPlaying: $viewModel.isPlayingAudio,
                        onPlay: viewModel.playAudio,
                        onPause: viewModel.pauseAudio
                    )
                    .keyboardShortcut(.space, modifiers: [])
                    .accessibilityLabel("Play / Pause")
                }
            }
        }
    }
}
