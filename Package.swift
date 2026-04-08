// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Feather",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Feather",
            targets: ["Feather"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Feather",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6]
)
