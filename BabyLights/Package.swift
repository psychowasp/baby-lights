// swift-tools-version: 6.2

import PackageDescription

// Baby Lights on NucleantSwiftUI. The library is taken from the sibling
// checkout; in a standalone clone replace the path dependency with
//   .package(url: "https://github.com/NucleantUI/NucleantSwiftUI.git", branch: "master")
let package = Package(
    name: "BabyLights",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // The app as a library — what the Xcode project links.
        .library(name: "BabyLights", targets: ["BabyLights"]),
        .executable(name: "BabyLightsApp", targets: ["BabyLightsApp"]),
    ],
    dependencies: [
        .package(path: "../../NucleantSwiftUI"),
    ],
    targets: [
        .target(
            name: "BabyLights",
            dependencies: [.product(name: "NucleantSwiftUI", package: "NucleantSwiftUI")],
            // The PyShader sources, read through `Bundle.module`.
            resources: [.process("Resources")]
        ),
        // `@main` alone; the Xcode app compiles this same file.
        .executableTarget(
            name: "BabyLightsApp",
            dependencies: ["BabyLights"]
        ),
    ]
)
