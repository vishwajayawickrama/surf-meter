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
        .target(name: "SurfMeterCore", path: "sources/surf-meter-core", resources: [.copy("resources/public_suffix_list.dat")]),
        .executableTarget(name: "SurfMeterApp", dependencies: ["SurfMeterCore"], path: "sources/surf-meter-app"),
        .executableTarget(name: "SurfMeterVerification", dependencies: ["SurfMeterCore"], path: "sources/surf-meter-verification"),
        .executableTarget(name: "SurfMeterNativeHost", dependencies: ["SurfMeterCore"], path: "sources/surf-meter-native-host"),
        .testTarget(name: "SurfMeterCoreTests", dependencies: ["SurfMeterCore"], path: "tests/surf-meter-core-tests")
    ],
    swiftLanguageModes: [.v5]
)
