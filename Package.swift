// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeepTheBudget",
    platforms: [
        .macOS(.v12)
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
            from: "1.3.0"
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
