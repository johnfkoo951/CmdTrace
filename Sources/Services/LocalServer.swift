import Foundation
import Network

// MARK: - LocalServer

@Observable
final class LocalServer {
    var isRunning = false
    var port: UInt16 = 19840
    var connectedClients: Int = 0
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.cmdtrace.localserver", qos: .userInitiated)
    
    private var routeHandler: ((HTTPRequest) async -> HTTPResponse)?
    
    // MARK: - Public API
    
    func start(handler: @escaping (HTTPRequest) async -> HTTPResponse) {
        self.routeHandler = handler
        
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                    case .failed, .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: queue)
        } catch {
            print("[LocalServer] Failed to start: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        for conn in connections {
            conn.cancel()
        }
        connections.removeAll()
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectedClients = 0
        }
    }
    
    // MARK: - Connection Handling
    
    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        DispatchQueue.main.async { self.connectedClients = self.connections.count }
        
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                self?.removeConnection(connection)
            } else if case .failed = state {
                self?.removeConnection(connection)
            }
        }
        
        connection.start(queue: queue)
        receiveData(on: connection)
    }
    
    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
        DispatchQueue.main.async { self.connectedClients = self.connections.count }
    }
    
    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                if isComplete || error != nil {
                    connection.cancel()
                }
                return
            }
            
            if let request = HTTPRequest.parse(from: data) {
                Task {
                    let response = await self.routeHandler?(request) ?? HTTPResponse.notFound()
                    self.sendResponse(response, on: connection)
                }
            } else {
                self.sendResponse(HTTPResponse.badRequest(), on: connection)
            }
        }
    }
    
    private func sendResponse(_ response: HTTPResponse, on connection: NWConnection) {
        let responseData = response.serialize()
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

// MARK: - HTTP Request

struct HTTPRequest {
    let method: String
    let path: String
    let queryParams: [String: String]
    let headers: [String: String]
    let body: Data?
    
    var fullPath: String { path }
    
    /// Extract path components: "/api/sessions/abc" -> ["api", "sessions", "abc"]
    var pathComponents: [String] {
        path.split(separator: "/").map(String.init)
    }
    
    /// Get query parameter
    func query(_ key: String) -> String? {
        queryParams[key]
    }
    
    static func parse(from data: Data) -> HTTPRequest? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        
        let method = String(parts[0])
        let fullPath = String(parts[1])
        
        // Parse path and query string
        var path = fullPath
        var queryParams: [String: String] = [:]
        
        if let queryStart = fullPath.firstIndex(of: "?") {
            path = String(fullPath[fullPath.startIndex..<queryStart])
            let queryString = String(fullPath[fullPath.index(after: queryStart)...])
            for param in queryString.split(separator: "&") {
                let kv = param.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                    let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                    queryParams[key] = value
                }
            }
        }
        
        // Parse headers
        var headers: [String: String] = [:]
        for i in 1..<lines.count {
            let line = lines[i]
            if line.isEmpty {
                break
            }
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key.lowercased()] = value
            }
        }
        
        // Parse body
        var body: Data?
        if let headerEnd = raw.range(of: "\r\n\r\n") {
            let bodyString = String(raw[headerEnd.upperBound...])
            if !bodyString.isEmpty {
                body = bodyString.data(using: .utf8)
            }
        }
        
        return HTTPRequest(
            method: method,
            path: path,
            queryParams: queryParams,
            headers: headers,
            body: body
        )
    }
}

// MARK: - HTTP Response

struct HTTPResponse {
    let statusCode: Int
    let statusMessage: String
    let headers: [String: String]
    let body: Data?
    
    func serialize() -> Data {
        var response = "HTTP/1.1 \(statusCode) \(statusMessage)\r\n"
        
        // Default headers
        var allHeaders = headers
        allHeaders["Connection"] = "close"
        allHeaders["Access-Control-Allow-Origin"] = "*"
        allHeaders["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        allHeaders["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        
        if let body = body {
            allHeaders["Content-Length"] = "\(body.count)"
        }
        
        for (key, value) in allHeaders {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"
        
        var data = response.data(using: .utf8) ?? Data()
        if let body = body {
            data.append(body)
        }
        return data
    }
    
    // MARK: - Convenience Constructors
    
    static func json(_ value: Any, statusCode: Int = 200) -> HTTPResponse {
        let body: Data
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) {
            body = data
        } else {
            body = "{}".data(using: .utf8)!
        }
        return HTTPResponse(
            statusCode: statusCode,
            statusMessage: "OK",
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: body
        )
    }
    
    static func jsonEncodable<T: Encodable>(_ value: T, statusCode: Int = 200) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let body: Data
        if let data = try? encoder.encode(value) {
            body = data
        } else {
            body = "{}".data(using: .utf8)!
        }
        return HTTPResponse(
            statusCode: statusCode,
            statusMessage: statusCode == 200 ? "OK" : "Created",
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: body
        )
    }
    
    static func ok(_ message: String = "OK") -> HTTPResponse {
        HTTPResponse.json(["status": message])
    }
    
    static func notFound(_ message: String = "Not Found") -> HTTPResponse {
        HTTPResponse(
            statusCode: 404,
            statusMessage: "Not Found",
            headers: ["Content-Type": "application/json"],
            body: "{\"error\": \"\(message)\"}".data(using: .utf8)
        )
    }
    
    static func badRequest(_ message: String = "Bad Request") -> HTTPResponse {
        HTTPResponse(
            statusCode: 400,
            statusMessage: "Bad Request",
            headers: ["Content-Type": "application/json"],
            body: "{\"error\": \"\(message)\"}".data(using: .utf8)
        )
    }
    
    static func error(_ message: String, statusCode: Int = 500) -> HTTPResponse {
        HTTPResponse(
            statusCode: statusCode,
            statusMessage: "Internal Server Error",
            headers: ["Content-Type": "application/json"],
            body: "{\"error\": \"\(message)\"}".data(using: .utf8)
        )
    }
    
    static func cors() -> HTTPResponse {
        HTTPResponse(
            statusCode: 204,
            statusMessage: "No Content",
            headers: [:],
            body: nil
        )
    }
}
