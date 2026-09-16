//
//  BabyLightsApp.swift
//  BabyLights
//
//  Baby Lights on NucleantSwiftUI: a black screen that answers a touch
//  with a soft glow, behind a start screen for the parent. Each glow is
//  its own stacked `Shader` — see LightsScreen.swift.
//

import NucleantSwiftUI
import Observation

/// Which screen is up and which dialog, if any, is over it. One per app:
/// the menu command that leaves the lights screen has no view to write
/// through, so it reaches this the way the examples' Appearance menu does.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    enum Screen { case main, lights }

    enum Modal {
        case startConfirmation, about, exitConfirmation

        var title: String {
            switch self {
            case .startConfirmation: return "Start Baby Lights"
            case .about:             return "About Baby Lights"
            case .exitConfirmation:  return "Exit Baby Lights"
            }
        }

        var message: String {
            switch self {
            case .startConfirmation:
                return """
                    This will start immersive mode.

                    To exit later, press and hold both corners
                    (top-left and bottom-right) for 0.5 seconds.
                    """
            case .about:
                return """
                    Baby Lights is designed to
                    provide a distraction-free,
                    non-addictive visual for
                    babies who briefly handle
                    a parent's phone, preventing
                    accidental actions.

                    No data is collected.
                    No sounds, ads, or tracking.
                    """
            case .exitConfirmation:
                return "Are you sure you want to exit the app?"
            }
        }
    }

    var screen = Screen.main
    var modal: Modal?
}

@View
struct RootView {
    let model: AppModel
    @State private var touchManager = TouchManager()

    var body: some View {
        ZStack {
            switch model.screen {
            case .main:
                MainScreen(model: model)
            case .lights:
                LightsScreen()
            }
            if let modal = model.modal {
                Dialog(modal)
            }
        }
        .environment(\.touchManager, touchManager)
        .colorScheme(.light)
    }
}

/// The exit gesture needs two fingers, which a mouse does not have — so on
/// the desktop the lights screen is also left from the menu bar.
struct BabyLightsCommands: Commands {
    var body: some Commands {
        CommandMenu("Lights") {
            Button("Exit Baby Lights") {
                AppModel.shared.modal = nil
                AppModel.shared.screen = .main
            }
        }
    }
}

@main
struct BabyLightsApp: NucleantApp {
    var body: some Scene {
        WindowGroup("Baby Lights", width: 420, height: 800) {
            RootView(model: AppModel.shared)
        }
        .commands { BabyLightsCommands() }
    }
}
