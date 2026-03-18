//
//  TutorialView.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/28.
//

import SwiftUI

struct TutorialView<Content: View>: View {
    @Binding var isActive: Bool
    @Binding var currentStepNumber: Int
    let onNextStep: (() -> Void)?
    
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        let currentStep = tutorialSteps[currentStepNumber]
        content()
            .overlayPreferenceValue(SpotlightKey.self) { values in
                GeometryReader { geometry in
                    let preference = values.first(where: { $0.key == currentStep.viewID })
                    if let preference {
                        let rect = geometry[preference.value]
                        ZStack(alignment: .top) {
                            Rectangle()
                                .background(Color.black)
                                .opacity(0.2)
                                .reverseMask(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .frame(width: rect.width, height: rect.height)
                                        .offset(x: rect.minX, y: rect.minY)
                                }
                                .onTapGesture {
                                    onNextStep?()
                                }
                            
                            let shouldPlaceTop = rect.minY > 100
                            let contentWidth: CGFloat = 400
                            let padding: CGFloat = 10
                            HStack(alignment: shouldPlaceTop ? .bottom : .top) {
                                Image(systemName: shouldPlaceTop ? "arrow.down" : "arrow.up")
                                VStack(alignment: .leading) {
                                    Text(currentStep.title)
                                        .bold()
                                    Text(currentStep.description)
                                }
                                Button {
                                    onNextStep?()
                                } label: {
                                    HStack {
                                        let isLastStep = currentStepNumber == tutorialSteps.count - 1
                                        Text(isLastStep ? "Get Started" : "Next")
                                        Image(systemName: isLastStep ? "checkmark": "arrow.right")
                                    }
                                    .padding(10)
                                    .background(Color.accentColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.ultraThinMaterial)
                                            .environment(\.colorScheme, .dark)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .shadow(radius: 5)
                            .padding()
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: contentWidth)
                            .position(
                                x: max(padding + (contentWidth / 2), min(rect.midX, geometry.size.width - padding - (contentWidth / 2))),
                                y: shouldPlaceTop ? rect.minY - 50 : rect.maxY + 50
                            )
                        }
                    }
                }
                .ignoresSafeArea()
                .opacity(isActive ? 1 : 0)
                .allowsHitTesting(isActive)
                .animation(.easeInOut, value: isActive)
                .animation(.easeInOut, value: currentStepNumber)
            }
    }
}

struct SpotlightKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func addSpotlight(id: String, isToolbarItem: Bool = false) -> some View {
        self.anchorPreference(key: SpotlightKey.self, value: .bounds) { [id: $0] }
    }
    
    func reverseMask<T: View>(alignment contentAlignment: Alignment, _ content: () -> T) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: contentAlignment) {
                    content()
                        .blendMode(.destinationOut)
                }
        }
    }
}
