import Foundation

public protocol ResponseHandler {
    
    var decoder: JSONDecoder { get }
    
    func handleResponse<T: Decodable>(_ data: Data?, urlResponse: URLResponse?) throws -> T
    func decode<T: Decodable>(data: Data) throws -> T
    
}

public class DefaultResponseHandler: ResponseHandler {
    
    public let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = .init()) {
        self.decoder = decoder
    }
    
    public func handleResponse<T>(_ data: Data?, urlResponse: URLResponse?) throws -> T where T : Decodable {
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw NetworkError.unknown
        }
        
        let statusCode = httpResponse.statusCode
        switch statusCode {
        case 400..<500:
            throw NetworkError.clientError(
                statusCode: statusCode,
                description: httpResponse.description
            )
        case 500..<600:
            throw NetworkError.serverError(
                statusCode: statusCode,
                description: httpResponse.description
            )
        default: break
        }
        
        guard let data = data else {
            throw NetworkError.decoding
        }
        
        let result: T = try decode(data: data)
        return result
    }
    
    public func decode<T: Decodable>(data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
    
}
