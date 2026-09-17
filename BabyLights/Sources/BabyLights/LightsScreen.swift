//
//  LightsScreen.swift
//  BabyLights
//
//  The black screen the baby gets. One `VertexShader` for every glow: each
//  touch is an instance, the vertex stage places a quad around it (half the
//  screen height on a side — the Kivy glow reaches 0.25 of the height from
//  the touch, so that box holds all of it) and the fragment stage shades only
//  the pixels inside. The touches reach the GPU as one float array, four
//  numbers each; the fade runs on the shader's own clock, so nothing is
//  written from Swift per frame.
//

import Foundation
import NucleantSwiftUI

/// The Kivy glow, per instance, loaded from the bundled `glow.py`: one
/// PyShader module, `vertex` returning the position and the varyings
/// `fragment` takes by name. `touches` and `glowSeconds` arrive as
/// parameters by their `ShaderArgument` names. `Reference/glow.glsl` is
/// the same shader in GLSL, for reading.
let glowShader = VertexShaderFunction(pyshader: bundledShader("glow"))

/// The text of `Resources/<name>.py`. A missing file is a packaging error,
/// not a runtime condition, so it stops the app with the name.
func bundledShader(_ name: String) -> String {
    guard let url = Bundle.module.url(forResource: name, withExtension: "py"),
          let source = try? String(contentsOf: url, encoding: .utf8)
    else {
        fatalError("BabyLights: shader resource \(name).py is not in the bundle")
    }
    return source
}

private struct TouchManagerKey: EnvironmentKey {
    static let defaultValue = TouchManager()
}

extension EnvironmentValues {
    var touchManager: TouchManager {
        get { self[TouchManagerKey.self] }
        set { self[TouchManagerKey.self] = newValue }
    }
}

@View
struct ParticlesView {
    @Environment(\.touchManager) private var touchManager

    var body: some View {
        ZStack {
            Color.black
            VertexShader(glowShader, vertices: 6, instances: touchManager.touches.count, arguments: [
                .floatArray("touches", touchManager.packedTouches),
                .float("glowSeconds", touchManager.glowSeconds),
            ])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(
            DragGesture()
                .onChanged { value in
                    touchManager.pointer(id: value.id, at: value.location, in: value.bounds.size)
                }
                .onEnded { value in touchManager.released(id: value.id) }
        )
    }
}

@View
struct LightsScreen {
    @Environment(\.touchManager) private var touchManager

    var body: some View {
        ZStack {
            ParticlesView()
            if touchManager.exitRequested {
                Dialog(.exitConfirmation)
            }
        }
    }
}
