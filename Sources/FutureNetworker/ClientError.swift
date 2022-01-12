import Foundation

enum NetworkError: LocalizedError {

    case unknown
    case responseError(_ status: String?, _ message: String?)
    case clientError(_ code: Int, localizedDescription: String)
    case serverError(_ code: Int, localizedDescription: String)
    case decoding
    case authentication

    var errorCode: Int? {
        switch self {
        case .clientError(let code, _): return code
        default: return nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .unknown:
            return "Unknown error"
        case .responseError(_, let message):
            return message ?? "Okänt fel"
        case .clientError(let code, let localizedDescription):
            return "Klientfel (\(code)): \(localizedDescription)"
        case .serverError(let code, let localizedDescription):
            return "Serverfel (\(code)): \(localizedDescription)"
        case .decoding:
            return "Korrupt data"
        case .authentication:
            return "Du behöver logga in"
        }
    }
}

struct ResponseError: Decodable {
    let status: String
    let message: String?
}
