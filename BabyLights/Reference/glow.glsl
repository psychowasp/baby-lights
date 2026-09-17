// The Baby Lights glow in GLSL — a reference next to the PyShader form the
// app ships (Sources/BabyLights/Resources/glow.py); not bundled or loaded.
//
// Four parts, as `VertexShaderFunction(functions:varyings:vertex:fragment:)`
// takes them: what comes before the first `#section` is shared by both
// stages; then the varyings the vertex stage writes and the fragment stage
// reads, and the two bodies. `touches` holds x, y, seed, started per
// glow, with x and y as y-up fractions of the view and started in the
// shader's seconds; `glowSeconds` is how long a glow takes to fade. The box
// is square in pixels, so a distance of 1 across it is 0.5 of the screen
// height and the Kivy original's fall-off radius (0.25) and hue ring
// spacing (`d * 3.0`) are scaled by two to read the same. Straight alpha:
// the composite blends fragColor.a over what is beneath.

const vec2 QUAD[6] = vec2[](
    vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0),
    vec2(-1.0, 1.0), vec2(1.0, -1.0), vec2(1.0, 1.0)
);

#section varyings
vec2 local; float seed; float started;

#section vertex
int t = gl_InstanceIndex * 4;
vec2 corner = QUAD[gl_VertexIndex];
vec2 centre = vec2(touches(t), touches(t + 1));
vec2 extent = vec2(0.25 * resolution.y / resolution.x, 0.25);
gl_Position = vec4((centre + corner * extent) * 2.0 - 1.0, 0.0, 1.0);
local = corner * 0.5 + 0.5;
seed = touches(t + 2);
started = touches(t + 3);

#section fragment
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
