
# rewrite baby-lights in with NucleantSwiftUI

original is located in baby-lights/kivy-version

normally i guess we would be vertex shader + fragment shader to express multi fingers
but we dont realy handle it yet in the shaders or atleast not atm 
so lets just test it with stacking Shaders for each touch for now to see how that preforms

```swift
@Observable
final class TouchData {
    // fill in what is needed
}

@Observable
final class TouchManager {
    var touches: [TouchData]
}
```

```swift

@View
struct ParticlesView {

    @Environment(TouchManager.self) var touchManager
    // parent or whatever holds it as @State and passed by .environment

    var body: some View {
        ZStack {
            ForEach(touchManager.touches) { touch
                // Shader
            }
        }
    }

}
```

plenty of examples in NucleantSwiftUI/Examples
how to write the swift code, but follows real SwiftUI very close
only diff is i wanted @View macro instead, which just helps generate how View updates etc, nothing you need to worry about .. 

