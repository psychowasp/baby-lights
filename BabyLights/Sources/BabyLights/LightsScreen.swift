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

import NucleantSwiftUI

/// The Kivy glow, per instance. `touches` holds `x, y, seed, started` per
/// glow, with `x` and `y` as y-up fractions of the view and `started` in the
/// shader's seconds; `count` is how many are live. The box is square in
/// pixels, so a distance of 1 across it is 0.5 of the screen height and the
/// original's fall-off radius (0.25) and hue ring spacing (`d * 3.0`) are
/// scaled by two to read the same. Straight alpha — the composite blends
/// `fragColor.a` over what is beneath.
let glowShader = VertexShaderFunction(
    functions: """
        const vec2 QUAD[6] = vec2[](
            vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0),
            vec2(-1.0, 1.0), vec2(1.0, -1.0), vec2(1.0, 1.0)
        );
        """,
    varyings: "vec2 local; float seed; float started;",
    vertex: """
        int t = gl_InstanceIndex * 4;
        vec2 corner = QUAD[gl_VertexIndex];
        vec2 centre = vec2(touches(t), touches(t + 1));
        vec2 extent = vec2(0.25 * resolution.y / resolution.x, 0.25);
        gl_Position = vec4((centre + corner * extent) * 2.0 - 1.0, 0.0, 1.0);
        local = corner * 0.5 + 0.5;
        seed = touches(t + 2);
        started = touches(t + 3);
        """,
    fragment: """
        float d = distance(local, vec2(0.5)) * 0.5;
        float glow = smoothstep(0.25, 0.0, d);

        float hue = mod((seed + time) * 0.07 + d * 3.0, 1.0);
        vec3 col = clamp(vec3(
            abs(hue * 6.0 - 3.0) - 1.0,
            2.0 - abs(hue * 6.0 - 2.0),
            2.0 - abs(hue * 6.0 - 4.0)
        ), 0.0, 1.0);

        float fade = max(0.0, 1.0 - (time - started) / glowSeconds);
        fragColor = vec4(col, glow * fade);
        """)

/// The same glow in PyShader: one module, `vertex` returning the position and
/// the varyings `fragment` takes by name. `touches` and `glowSeconds` arrive
/// as parameters by their `ShaderArgument` names.
let glowPyShader = VertexShaderFunction(pyshader: """
    QUAD = [float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0),
            float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0)]

    class Glow:
        position: float4
        local: float2
        seed: float
        started: float

    def vertex(vertex_index: int, instance_index: int, resolution: float2, touches: FloatArray) -> Glow:
        t = instance_index * 4
        quad = QUAD
        corner = quad[vertex_index]
        centre = float2(touches[t], touches[t + 1])
        extent = float2(0.25 * resolution.y / resolution.x, 0.25)
        return Glow(
            position=float4((centre + corner * extent) * 2.0 - 1.0, 0.0, 1.0),
            local=corner * 0.5 + 0.5,
            seed=touches[t + 2],
            started=touches[t + 3],
        )

    def fragment(local: float2, seed: float, started: float, time: float, glowSeconds: float) -> float4:
        d = distance(local, float2(0.5)) * 0.5
        glow = smoothstep(0.25, 0.0, d)

        hue = mod((seed + time) * 0.07 + d * 3.0, 1.0)
        col = clamp(float3(
            abs(hue * 6.0 - 3.0) - 1.0,
            2.0 - abs(hue * 6.0 - 2.0),
            2.0 - abs(hue * 6.0 - 4.0)
        ), 0.0, 1.0)

        fade = max(0.0, 1.0 - (time - started) / glowSeconds)
        return float4(col, glow * fade)
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
        ZStack {
            Color.black
            VertexShader(glowPyShader, vertices: 6, instances: touchManager.touches.count, arguments: [
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
