// swift-tools-version:5.5
import PackageDescription

let package = Package(
	name: "VoteServer",
	platforms: [
		.macOS(.v12)
	],
	dependencies: [
		// 💧 A server-side Swift web framework.
		.package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
		.package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
		// Fluent
		.package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
		.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
		// VoteKit definitions
		.package(url: "https://git.smkid.dk/Harcker/VoteKit", from: "0.3.0"), //HTTPS
		.package(url: "https://git.smkid.dk/Harcker/AltVoteKit", branch: "main"), //HTTPS
		// VoteExchangeFormat, defines API protocols
		.package(url: "https://git.smkid.dk/Harcker/VoteExchangeFormat", branch: "main"),
	],
	targets: [
		.target(
			name: "App",
			dependencies: [
				.product(name: "Leaf", package: "leaf"),
				.product(name: "Vapor", package: "vapor"),
				.product(name: "Fluent", package: "fluent"),
				.product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
				.product(name: "AltVoteKit", package: "AltVoteKit"),
				.product(name: "VoteKit", package: "VoteKit"),
				.product(name: "VoteExchangeFormat", package: "VoteExchangeFormat")
				
			],
			swiftSettings: [
				// Enable better optimizations when building in Release configuration. Despite the use of
				// the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
				// builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
				.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
				.unsafeFlags(["-Xfrontend", "-warn-long-function-bodies=40", "-Xfrontend", "-warn-long-expression-type-checking=40"])
			]
		),
		.executableTarget(name: "Run", dependencies: [.target(name: "App")]),
		.testTarget(name: "AppTests", dependencies: [
			.target(name: "App"),
			.product(name: "XCTVapor", package: "vapor"),
		])
	]
)
