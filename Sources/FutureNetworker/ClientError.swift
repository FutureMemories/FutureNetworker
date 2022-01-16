import Foundation

public enum NetworkError: LocalizedError {

    case clientError(statusCode: Int, description: String)
    case serverError(statusCode: Int, description: String)
    case decoding
    case authentication
    case unknown
    
}
