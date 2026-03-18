//
//  ToolbarItems.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/27.
//

import SwiftUI
import UniformTypeIdentifiers

struct EditModeButton: View {
    @Binding var currentMode: ViewMode
    
    var body: some View {
        let isActive = currentMode == .edit
        Button {
            withAnimation {
                currentMode = .edit
            }
        } label: {
            Image(systemName: isActive ? "paintbrush.fill" : "paintbrush")
        }
        .tint(isActive ? Color.accentColor : nil)
    }
}

struct CameraModeButton: View {
    @Binding var currentMode: ViewMode
    
    var body: some View {
        let isActive = currentMode == .camera
        Button {
            withAnimation {
                currentMode = .camera
            }
        } label: {
            Image(systemName: isActive ? "rotate.3d.fill" : "rotate.3d")
        }
        .tint(isActive ? Color.accentColor : nil)
    }
}

struct PlaybackSpeedControl: View {
    @Binding var playbackSpeed: Float
    
    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: "gauge.open.with.lines.needle.33percent")
            Slider(value: $playbackSpeed, in: 1.0...40.0) {
                Text("Playback Speed")
            }
            .frame(maxWidth: 200)
        }
    }
}

struct PlayPauseButton: View {
    @Binding var isPlaying: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    
    var body: some View {
        Button {
            isPlaying.toggle()
            if isPlaying {
                onPlay()
            } else {
                onPause()
            }
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
        }
    }
}

struct TutorialButton: View {
    @Binding var isTutorialActive: Bool
    @Binding var currentStepNumber: Int
    @Binding var currentMode: ViewMode
    
    var body: some View {
        Button {
            isTutorialActive = true
            currentStepNumber = 0
            currentMode = .edit
        } label: {
            Image(systemName: "questionmark")
        }
    }
}

struct ExportButton: View {
    @Binding var document: BufferFile
    let prepareDocument: () throws -> Void
    @State var successfulIcon: Bool = false
    @State var isExporting: Bool = false
    @State var isShowingAlert: Bool = false
    @State var exportErrorMessage: String = ""
    let heightMapBuffer: MTLBufferPair
    
    var body: some View {
        Button {
            isExporting = true
            do {
                try prepareDocument()
            } catch {
                exportErrorMessage = error.localizedDescription
                isShowingAlert = true
            }
        } label: {
            Image(systemName: successfulIcon ? "checkmark.circle" : "square.and.arrow.up")
                .foregroundStyle(successfulIcon ? Color.green : Color.primary)
        }
        .animation(.default, value: successfulIcon)
        .fileExporter(
            isPresented: $isExporting,
            documents: [document],
            contentType: UTType.data
        ) { result in
            switch result {
            case .success(_):
                successfulIcon = true
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    successfulIcon = false
                }
            case .failure(let error):
                exportErrorMessage = error.localizedDescription
                isShowingAlert = true
            }
        }
        .alert(
            "Couldn't export the file: \(exportErrorMessage)",
            isPresented: $isShowingAlert
        ) {
            if #available(iOS 26, macOS 26, *) {
                Button("OK", role: .confirm) {}
            } else {
                Button("OK") {}
            }
        }
    }
}

struct LoadButton: View {
    @Binding var document: BufferFile
    @State var isImporting: Bool = false
    @State var isShowingAlert: Bool = false
    @State var importErrorMessage: String = ""
    let loadCallback: () throws -> Void
    
    var body: some View {
        Button {
            isImporting = true
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [UTType.data]) { result in
            switch result {
            case .success(let url):
                guard let data = try? Data(contentsOf: url) else { return }
                document = BufferFile(data: data)
                
                do {
                    try loadCallback()
                } catch {
                    importErrorMessage = error.localizedDescription
                    isShowingAlert = true
                }
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                isShowingAlert = true
            }
        }
        .alert(
            "Couldn't import the file: \(importErrorMessage)",
            isPresented: $isShowingAlert
        ) {
            if #available(iOS 26, macOS 26, *) {
                Button("OK", role: .confirm) {}
            } else {
                Button("OK") {}
            }
        }
    }
}
