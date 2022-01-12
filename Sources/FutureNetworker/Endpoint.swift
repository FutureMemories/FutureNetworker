import Foundation

protocol URLRequestConvertible {
    func asURLRequest() throws -> URLRequest
}

extension URLRequestConvertible {
    public var urlRequest: URLRequest? { try? asURLRequest() }
}

final class Endpoint<T: Decodable>: URLRequestConvertible {

    private let host: String
    private var method: Method
    private var path: String
    private var parameters: RequestParameters
    private var authenticationProvider: AuthenticationProvider?

    init(method: Method = .get,
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

        return urlRequest
    }

    private func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

}

enum RequestParameters {
    case body(Parameters)
    case query(Parameters)
    case none
}

enum Method: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

typealias Parameters = [String : ParameterValueConvertible?]

protocol ParameterValueConvertible {
    var parameterValue: String { get }
}

extension Int: ParameterValueConvertible {
    var parameterValue: String { String(self) }
}

extension UInt: ParameterValueConvertible {
    var parameterValue: String { String(self) }
}

extension Int64: ParameterValueConvertible {
    var parameterValue: String { String(self) }
}

extension Array: ParameterValueConvertible where Element: ParameterValueConvertible {
    var parameterValue: String { map(\.parameterValue).joined(separator: ",") }
}

extension String: ParameterValueConvertible {
    var parameterValue: String { self }
}

extension Double: ParameterValueConvertible {
    var parameterValue: String { String(self) }
}

extension Bool: ParameterValueConvertible {
    var parameterValue: String { self ? "true" : "false" }
}

extension Date: ParameterValueConvertible {
    var parameterValue: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

extension Dictionary: ParameterValueConvertible where Key: Encodable, Value: Encodable {
    var parameterValue: String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return ""
    }
}