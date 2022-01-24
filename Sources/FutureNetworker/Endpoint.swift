import Foundation

protocol URLRequestConvertible {
    func asURLRequest() throws -> URLRequest
}

extension URLRequestConvertible {
    public var urlRequest: URLRequest? { try? asURLRequest() }
}

public final class Endpoint<T: Decodable>: URLRequestConvertible {
    
    public enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    private let host: String
    private var method: Method
    private var path: String
    internal var parameters: RequestParameters
    private var authenticationProvider: AuthenticationProvider?

    public init(method: Method = .get,
         host: String,
         path: String,
         parameters: RequestParameters = .none,
         authenticationProvider: AuthenticationProvider? = nil) {
        self.method = method
        self.host = host
        self.path = path
        self.parameters = parameters
        self.authenticationProvider = authenticationProvider
    }

    func asURLRequest() throws -> URLRequest {

        var urlComponents = URLComponents(string: host + path)!

        if case let .query(parameters) = parameters {
            urlComponents.queryItems = parameters.compactMapValues { $0 }.map {
                URLQueryItem(name: $0.key, value: $0.value.parameterValue)
            }
        }

        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = method.rawValue

        if let authenticationProvider = authenticationProvider {
            if case let .bearer(username, password) = authenticationProvider.authentication {
                let credentialsData = "\(username):\(password)".data(using: .utf8)
                if let credentialsEncoded = credentialsData?.base64EncodedString() {
                    let basicAuthString = "Basic \(credentialsEncoded)"
                    urlRequest.addValue(basicAuthString, forHTTPHeaderField: "Authorization")
                } else {
                    throw NetworkError.authentication
                }
            } else {
                throw NetworkError.authentication
            }
        }

        if case let .body(parameters) = parameters {
            let json = try? JSONSerialization.data(withJSONObject: parameters, options: .fragmentsAllowed)
            urlRequest.httpBody = json
        }

        if case let .data(data) = parameters {
            urlRequest.httpBody = data
        }
        
        return urlRequest
    }

    private func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

}
