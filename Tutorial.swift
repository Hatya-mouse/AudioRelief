//
//  Tutorial.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/28.
//

import SwiftUI

struct TutorialStep {
    let viewID: String
    let title: String
    let description: String
}

let tutorialSteps: [TutorialStep] = [
    TutorialStep(viewID: "height_map_view", title: "3D Model", description: "Drag on the 3D model to sculpt its surface. The shape of the surface determines the sound."),
    TutorialStep(viewID: "brush_control", title: "Brush Control", description: "Select the brush shape, and adjust the radius and strength of the brush here."),
    TutorialStep(viewID: "edit_mode_button", title: "Edit Mode", description: "Press this button to enter the edit mode, where you can sculpt the 3D model."),
    TutorialStep(viewID: "camera_mode_button", title: "Camera Rotation Mode", description: "Press this button to enter the camera rotation mode."),
    TutorialStep(viewID: "play_pause_button", title: "Play / Pause Button", description: "Press this button to play / pause the audio."),
    TutorialStep(viewID: "playback_speed", title: "Playback Speed Slider", description: "Drag this slider to adjust the speed of the playback."),
    TutorialStep(viewID: "export_button", title: "Export Button", description: "Press this button to save the file which can be opened later."),
    TutorialStep(viewID: "load_button", title: "Open Button", description: "Press this button to open a saved file."),
    TutorialStep(viewID: "tutorial_button", title: "Tutorial Button", description: "Press this button to show this tutorial again later."),
]

class TutorialModel: ObservableObject {
    @Published var isTutorialActive: Bool
    @Published var currentStep: Int = 0
    
    init() {
        let shouldShowTutorial = UserDefaults.standard.value(forKey: "shouldShowTutorial") as? Bool
        isTutorialActive = shouldShowTutorial ?? true
    }
    
    func nextStep() {
        if currentStep < tutorialSteps.count - 1 {
            currentStep += 1
        } else if currentStep == tutorialSteps.count - 1 {
            isTutorialActive = false
            // Set the tutorialCompleted flag true
            UserDefaults.standard.set(false, forKey: "shouldShowTutorial")
        }
    }
}
