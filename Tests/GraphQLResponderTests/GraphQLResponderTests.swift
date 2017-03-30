import XCTest
import Graphiti
import Vapor
import HTTP
@testable import GraphQLResponder

let schema = try! Schema<NoRoot, Request> { schema in
    try schema.query { query in
        try query.field(name: "hello", type: String.self) { _, _, request, _ in
            XCTAssertEqual(request.method, .get)
            XCTAssertEqual(request.uri.scheme, "graphql")
            return "world"
        }
    }
}

let graphql = GraphQLResponder(schema: schema, rootValue: noRootValue)

class GraphQLResponderTests : XCTestCase {
    func testHello() throws {
        let query: Vapor.Node = [
            "query": "{ hello }"
        ]

        let expected: Vapor.Node = [
            "data": [
                "hello": "world"
            ]
        ]
		
		let request = try Request(method: .get, uri: "graphql", version: Version.init(major: 1), headers: [HeaderKey.contentType : "application/json"], body: JSON(query).makeBody())
//        let request = try Request(uri: "/graphql", content: query)
        let response = try graphql.respond(to: request)
        XCTAssertEqual(response.json?.node, expected)
    }

    func testBoyhowdy() throws {
        let query: Vapor.Node = [
            "query": "{ boyhowdy }"
        ]

        let expected: Vapor.Node = [
            "errors": [
                [
                    "message": "Cannot query field \"boyhowdy\" on type \"Query\".",
                    "locations": [["line": 1, "column": 3]]
                ]
            ]
        ]

		let request = try Request(method: .get, uri: "graphql", version: Version.init(major: 1), headers: [HeaderKey.contentType : "application/json"], body: JSON(query).makeBody())
//        let request = Request(url: "/graphql", content: query)!
        let response = try graphql.respond(to: request)
        XCTAssertEqual(response.json?.node, expected)
    }

    func testNoRequestContext() throws {
        let schema = try Schema<NoRoot, NoContext> { schema in
            try schema.query { query in
                try query.field(name: "hello", type: String.self) { _, _, _, _ in
                    return "world"
                }
            }
        }

        let graphql = GraphQLResponder(schema: schema, rootValue: noRootValue)

        let query: Vapor.Node = [
            "query": "{ boyhowdy }"
        ]

        let expected: Vapor.Node = [
            "errors": [
                [
                    "message": "Cannot query field \"boyhowdy\" on type \"Query\".",
                    "locations": [["line": 1, "column": 3]]
                ]
            ]
        ]

		let request = try Request(method: .get, uri: "graphql", version: Version.init(major: 1), headers: [HeaderKey.contentType : "application/json"], body: JSON(query).makeBody())
//        let request = Request(url: "/graphql", content: query)!
        let response = try graphql.respond(to: request)
        XCTAssertEqual(response.json?.node, expected)
    }

    static var allTests : [(String, (GraphQLResponderTests) -> () throws -> Void)] {
        return [
            ("testHello", testHello),
            ("testBoyhowdy", testBoyhowdy),
        ]
    }
}
