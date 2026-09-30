// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeepTheBudget",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .executable(
            name: "KeepTheBudget",
            targets: ["KeepTheBudget"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc",
            from: "2.14.1"
        )
    ],
    targets: [
        .executableTarget(
            name: "KeepTheBudget",
            dependencies: [
                .product(name: "MSAL", package: "microsoft-authentication-library-for-objc")
            ],
            path: "KeepTheBudget"
        )
    ]
)
