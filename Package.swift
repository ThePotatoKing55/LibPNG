// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LibPNG",
    products: [
        .library(name: "LibPNG", targets: ["LibPNG"]),
    ],
    targets: [
        .systemLibrary(name: "CPNG", path: "Libraries/CPNG", pkgConfig: "libpng", providers: [ .brew(["libpng"]), .apt(["libpng"])]),
        .target(name: "LibPNG", dependencies: ["CPNG"]),
        .testTarget(name: "LibPNGTests", dependencies: ["LibPNG"]),
    ]
)
