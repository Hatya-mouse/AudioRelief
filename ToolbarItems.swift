//
//  ToolbarItems.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/27.
//

import SwiftUI

struct EditModeButton: View {
    @Binding var currentMode: ViewMode
    
    var body: some View {
        let isActive = currentMode == .edit
        Button("Edit Mode", systemImage: isActive ? "paintbrush.fill" : "paintbrush") {
            withAnimation {
                currentMode = .edit
            }
        }
        .tint(isActive ? Color.accentColor : nil)
    }
}

struct CameraModeButton: View {
    @Binding var currentMode: ViewMode
    
    var body: some View {
        let isActive = currentMode == .camera
        Button("Camera Rotation Mode", systemImage: isActive ? "rotate.3d.fill" : "rotate.3d") {
            withAnimation {
                currentMode = .camera
            }
        }
        .tint(isActive ? Color.accentColor : nil)
    }
}

struct PlayPauseButton: View {
    @Binding var isPlaying: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    
    var body: some View {
        Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") {
            isPlaying.toggle()
            if isPlaying {
                onPlay()
            } else {
                onPause()
            }
        }
    }
}
