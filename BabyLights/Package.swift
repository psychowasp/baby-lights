// swift-tools-version: 6.2

import PackageDescription

// Baby Lights on NucleantSwiftUI. The library is taken from the sibling
// checkout; in a standalone clone replace the path dependency with
//   .package(url: "https://github.com/NucleantUI/NucleantSwiftUI.git", branch: "master")
let package = Package(
    name: "BabyLights",
    platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [
        .package(path: "../../NucleantSwiftUI"),
    ],
    targets: [
        .executableTarget(
            name: "BabyLights",
            dependencies: [.product(name: "NucleantSwiftUI", package: "NucleantSwiftUI")]
        ),
    ]
)
