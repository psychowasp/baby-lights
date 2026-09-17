"""The Baby Lights glow, per instance.

One module, two stages: `vertex` returns the position and the varyings
`fragment` takes by name. `touches` holds x, y, seed, started per glow,
with x and y as y-up fractions of the view and started in the shader's
seconds; `glowSeconds` is how long a glow takes to fade. The box is square
in pixels, so a distance of 1 across it is 0.5 of the screen height and the
Kivy original's fall-off radius (0.25) and hue ring spacing (`d * 3.0`) are
scaled by two to read the same. Straight alpha: the composite blends the
result over what is beneath.
"""
from pyshader import *

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
