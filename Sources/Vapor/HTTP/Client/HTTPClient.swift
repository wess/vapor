import Socks
import SocksCore

public enum HTTPClientError: ErrorProtocol {
    case missingHost
    case missingPort
}

public final class HTTPClient<ClientStreamType: ClientStream>: Client {
    public init() {}
    
    public func request(
        _ method: Method,
        uri: URI,
        headers: Headers = [:],
        query q: [String: String] = [:],
        body: HTTPBody = .data([])) throws -> HTTPResponse
    {
        var query: [String: StructuredData] = [:]
        for (key, val) in q {
            query[key] = .string(val)
        }

        // TODO: Is it worth exposing Version? We don't support alternative serialization/parsing
        let version = Version(major: 1, minor: 1)
        let request = HTTPRequest(method: method, uri: uri, version: version, headers: headers, body: body)
        request.query = .dictionary(query)
        let connection = try makeConnection(to: uri)
        return try perform(request, with: connection)
    }

    private func perform(_ request: HTTPRequest, with connection: Vapor.Stream) throws -> HTTPResponse {
        let serializer = HTTPSerializer<Request>(stream: connection)
        try serializer.serialize(request)
        let parser = HTTPParser<HTTPResponse>(stream: connection)
        let response = try parser.parse()
        _ = try? connection.close() // TODO: Support keep-alive?
        return response
    }

    private func makeConnection(to uri: URI) throws -> Vapor.Stream {
        guard let host = uri.host else { throw HTTPClientError.missingHost }
        guard let port = uri.port ?? uri.schemePort else { throw HTTPClientError.missingPort }

        let client = try ClientStreamType(host: host, port: port)

        //let useSSL = uri.scheme?.hasSuffix("s") == true
        //let client = try Stream.makeConnection(host: host, port: port, secure: useSSL)

        let stream = try client.connect()
        return StreamBuffer(stream)
    }
}