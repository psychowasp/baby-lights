//
//  LightsScreen.swift
//  BabyLights
//
//  The black screen the baby gets. One `Shader` per glow, stacked in a
//  `ZStack`, each sized to its own glow rather than the screen: the Kivy
//  glow reaches 0.25 of the screen height from the touch, so a box of half
//  the height around it holds all of it, at a fraction of a full-screen
//  image. Each fades on its own clock: a shader's `time` is seconds since
//  that shader appeared, so the fade needs no per-frame writes from Swift.
//

import NucleantSwiftUI

/// The Kivy glow, in its own box: the touch is the centre, and a distance
/// of 1 across the box is 0.5 of the screen height, so the original's
/// fall-off radius (0.25) and hue ring spacing (`d * 3.0`) are scaled by
/// two to read the same. Straight alpha — the composite blends
/// `fragColor.a` over what is beneath.
let glowShader = ShaderFunction("""
    float d = distance(uv, vec2(0.5)) * 0.5;
    float glow = smoothstep(0.25, 0.0, d);

    float hue = mod((seed + time) * 0.07 + d * 3.0, 1.0);
    vec3 col = clamp(vec3(
        abs(hue * 6.0 - 3.0) - 1.0,
        2.0 - abs(hue * 6.0 - 2.0),
        2.0 - abs(hue * 6.0 - 4.0)
    ), 0.0, 1.0);

    float fade = max(0.0, 1.0 - time / \(TouchManager.glowSeconds));
    fragColor = vec4(col, glow * fade);
""")

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
        let size = touchManager.viewSize
        let side = size.height * 0.5
        ZStack(alignment: .topLeading) {
            Color.black
            ForEach(touchManager.touches) { touch in
                Shader(glowShader, arguments: [.float("seed", touch.seed)])
                    .frame(width: side, height: side)
                    .offset(x: touch.x * size.width - side / 2, y: touch.y * size.height - side / 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A glow near an edge reaches past it; the clip scissors its slot.
        .clipped()
        .gesture(
            DragGesture()
                .onChanged { value in
                    // One pointer for now — the host does not hand out
                    // touch ids yet, so every finger is pointer 0.
                    touchManager.pointer(id: 0, at: value.location, in: value.bounds.size)
                }
                .onEnded { _ in touchManager.released(id: 0) }
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
