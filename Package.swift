import PackageDescription

let package = Package(
    name: "GraphQLResponder",
    dependencies: [
        .Package(url: "https://github.com/iAlirezaKML/Graphiti.git", majorVersion: 0, minor: 2),
//        .Package(url: "https://github.com/Zewo/HTTP.git", majorVersion: 0, minor: 14),
		.Package(url: "https://github.com/vapor/vapor.git", majorVersion: 1, minor: 5),
		]
)
