// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SurfMeter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SurfMeterCore", targets: ["SurfMeterCore"]),
        .executable(name: "SurfMeterApp", targets: ["SurfMeterApp"]),
        .executable(name: "SurfMeterNativeHost", targets: ["SurfMeterNativeHost"])
    ],
    targets: [
        .target(name: "SurfMeterCore", resources: [.copy("Resources/public_suffix_list.dat")]),
        .executableTarget(name: "SurfMeterApp", dependencies: ["SurfMeterCore"]),
        .executableTarget(name: "SurfMeterVerification", dependencies: ["SurfMeterCore"]),
        .executableTarget(name: "SurfMeterNativeHost", dependencies: ["SurfMeterCore"]),
        .testTarget(name: "SurfMeterCoreTests", dependencies: ["SurfMeterCore"])
    ],
    swiftLanguageModes: [.v5]
)
