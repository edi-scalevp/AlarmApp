// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AlarmApp",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AlarmApp", targets: ["AlarmApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
    ],
    targets: [
        .target(
            name: "AlarmApp",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk")
            ]
        )
    ]
)
