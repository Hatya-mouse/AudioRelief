//
//  ToolbarItems.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/27.
//

import SwiftUI

struct EditModeButton: View {
    @Binding var currentMode: CurrentMode
    
    var body: some View {
        Button("Edit Mode", systemImage: "pencil") {
            withAnimation {
                currentMode = .edit
            }
        }
        .foregroundColor(currentMode == .edit ? Color.accentColor : nil)
    }
}

struct CameraModeButton: View {
    @Binding var currentMode: CurrentMode
    
    var body: some View {
        Button("Camera Rotation Mode", systemImage: "rotate.3d") {
            withAnimation {
                currentMode = .camera
            }
        }
        .foregroundColor(currentMode == .camera ? Color.accentColor : nil)
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
