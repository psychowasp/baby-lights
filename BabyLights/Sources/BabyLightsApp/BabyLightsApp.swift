//
//  BabyLightsApp.swift
//  BabyLightsApp
//
//  The entry point: `swift run BabyLightsApp`. The app itself is the
//  `BabyLights` library; the Xcode project compiles this same file over it.
//

import BabyLights
import NucleantSwiftUI

@main
struct BabyLightsApp: NucleantApp {
    var body: some Scene {
        WindowGroup("Baby Lights", width: 420, height: 800) {
            RootView()
        }
        .commands { BabyLightsCommands() }
    }
}
