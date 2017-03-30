import GraphQL
import Graphiti
import Vapor
import HTTP

public let noRootValue: Void = Void()

//extension MediaType {
//    public static var html: MediaType {
//        return MediaType(type: "text", subtype: "html", parameters: ["charset": "utf-8"])
//    }
//}
@_exported import struct Foundation.URL
@_exported import struct Foundation.URLQueryItem
import struct Foundation.URLComponents

extension URL {
	public var queryItems: [URLQueryItem] {
		return URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems ?? []
	}
}

public struct GraphQLResponder<Root, Context> : Responder {
    let schema: Schema<Root, Context>
    let graphiQL: Bool
    let rootValue: Root
    let context: Context?
	
    public init(
        schema: Schema<Root, Context>,
        graphiQL: Bool = false,
        rootValue: Root,
        context: Context? = nil
    ) {
        self.schema = schema
        self.graphiQL = graphiQL
        self.rootValue = rootValue
        self.context = context
    }

    public func respond(to request: Request) throws -> Response {
        var query: String? = nil
        var variables: [String: GraphQL.Map]? = nil
        var operationName: String? = nil
        var raw: Bool? = nil
		
		if let url = URL(string: request.uri.path) {
			loop: for queryItem in url.queryItems {
				switch queryItem.name {
				case "query":
					query = queryItem.value
				case "variables":
					// TODO: parse variables as JSON
					break
				case "operationName":
					operationName = queryItem.value
				case "raw":
					raw = queryItem.value.flatMap({ Bool($0) })
				default:
					continue loop
				}
			}
		}

        // Get data from ContentNegotiationMiddleware

        if query == nil {
            query = request.data["query"]?.string
        }

        if variables == nil {
			
            if let vars = request.query?.nodeObject?["variables"]?.nodeObject {
                var newVariables: [String: GraphQL.Map] = [:]

                for (key, value) in vars {
                    newVariables[key] = convert(node: value)
                }

                variables = newVariables
            }
        }

        if operationName == nil {
            operationName = request.data["operationName"]?.string
        }

        if raw == nil {
            raw = request.data["raw"]?.bool
        }

        // TODO: Parse the body from Content-Type

        let showGraphiql = graphiQL &&
			!(raw ?? false) &&
			request.accept.contains(where: { $0.mediaType == "text/html" })

        if !showGraphiql {
            guard let graphQLQuery = query else {
                throw Abort.custom(status: .badRequest, message: "Must provide query string.")
            }

            let result: GraphQL.Map

            if Context.self is Request.Type && context == nil {
                result = try schema.execute(
                    request: graphQLQuery,
                    rootValue: rootValue,
                    context: request as! Context,
                    variables: variables ?? [:],
                    operationName: operationName
                )
            } else if let context = context {
                result = try schema.execute(
                    request: graphQLQuery,
                    rootValue: rootValue,
                    context: context,
                    variables: variables ?? [:],
                    operationName: operationName
                )
            } else {
                result = try schema.execute(
                    request: graphQLQuery,
                    rootValue: rootValue,
                    variables: variables ?? [:],
                    operationName: operationName
                )
            }

			return try JSON(node: convert(map: result)).makeResponse()
        } else {
            var result: GraphQL.Map? = nil

            if let graphQLQuery = query {
                if Context.self is Request.Type && context == nil {
                    result = try schema.execute(
                        request: graphQLQuery,
                        rootValue: rootValue,
                        context: request as! Context,
                        variables: variables ?? [:],
                        operationName: operationName
                    )
                } else if let context = context {
                    result = try schema.execute(
                        request: graphQLQuery,
                        rootValue: rootValue,
                        context: context,
                        variables: variables ?? [:],
                        operationName: operationName
                    )
                } else {
                    result = try schema.execute(
                        request: graphQLQuery,
                        rootValue: rootValue,
                        variables: variables ?? [:],
                        operationName: operationName
                    )
                }
            }

            let html = renderGraphiQL(
                query: query,
                variables: variables,
                operationName: operationName,
                result: result
            )

            // TODO: Add an initializer that takes body and contentType to HTTP
            return Response(headers: [HeaderKey.contentType : "text/html"], body: html)
        }
    }
}

func convert(node: Vapor.Node) -> GraphQL.Map {
    switch node {
    case .null:
        return .null
    case .bool(let bool):
        return .bool(bool)
	case .number(let number):
		switch number {
		case .double(let double):
			return .double(double)
		case .int(let int):
			return .int(int)
		case .uint(let uint):
			return .int(Int(uint))
		}
    case .string(let string):
        return .string(string)
    case .array(let array):
        return .array(array.map({ convert(node: $0) }))
    case .object(let dictionary):
        var dict: [String: GraphQL.Map] = [:]

        for (key, value) in dictionary {
            dict[key] = convert(node: value)
        }

        return .dictionary(dict)
    default:
        return .null
    }
}

func convert(map: GraphQL.Map) -> Vapor.Node {
    switch map {
    case .null:
        return .null
    case .bool(let bool):
        return .bool(bool)
    case .double(let double):
        return .number(Vapor.Node.Number(double))
    case .int(let int):
        return .number(Vapor.Node.Number(int))
    case .string(let string):
        return .string(string)
    case .array(let array):
        return .array(array.map({ convert(map: $0) }))
    case .dictionary(let dictionary):
        var dict: [String: Vapor.Node] = [:]
        
        for (key, value) in dictionary {
            dict[key] = convert(map: value)
        }
        
        return .object(dict)
    }
}
