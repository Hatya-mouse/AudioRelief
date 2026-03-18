//
//  File.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/28.
//

import SwiftUI

struct BrushControl: View {
    @Binding var brush: BrushMode
    
    let currentMode: ViewMode
    
    var body: some View {
        if currentMode == .edit {
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Brush")
                    Picker("Brush", selection: $brush.brushType) {
                        ForEach(BrushType.allCases, id: \.self) { brushType in
                            Label {
                                Text(brushType.displayName)
                            } icon: {
                                Image(brushType.imageName)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                            }
                            .labelStyle(.iconOnly)
                            .tag(brushType)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                
                VStack(alignment: .leading) {
                    Text("Radius")
                    Slider(value: $brush.radius, in: 0.1...0.8) {
                        Text("Radius")
                    } minimumValueLabel: {
                        Image(systemName: "minus")
                    } maximumValueLabel: {
                        Image(systemName: "plus")
                    }
                    .frame(maxWidth: 300)
                }
                
                VStack(alignment: .leading) {
                    Text("Strength")
                    Slider(value: $brush.strength, in: -0.02...0.02) {
                        Text("Strength")
                    } minimumValueLabel: {
                        Image(systemName: "arrow.down")
                    } maximumValueLabel: {
                        Image(systemName: "arrow.up")
                    }
                    .frame(maxWidth: 300)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.thickMaterial)
            )
            .padding(20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(1)
        }
    }
}
