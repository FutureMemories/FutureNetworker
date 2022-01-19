import Foundation

public protocol Session {
    
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
    
}

extension URLSession: Session {}

public class Client {

    let session: Session

    public static let shared: Client = .init()
    
    private let responseHandler: ResponseHandler

    public init(session: Session = URLSession.shared, responseHandler: ResponseHandler = DefaultResponseHandler()) {
        self.session = session
        self.responseHandler = responseHandler
    }
    
    @discardableResult
    public func request<T: Decodable>(_ endpoint: Endpoint<T>) async throws -> T {
        guard var urlRequest = endpoint.urlRequest else {
            throw NetworkError.unknown
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60 // temporary. This should be 20
        
        let (data, urlResponse) = try await data(for: urlRequest)
        return try responseHandler.handleResponse(data, urlResponse: urlResponse)
    }
    
    public func request<T: Decodable>(_ endpoint: Endpoint<T>, completion: @escaping (Result<T, Error>) -> Void) {
        Task {
            do {
                let response = try await request(endpoint)
                completion(.success(response))
            }
            catch {
                completion(.failure(error))
            }
        }
    }
    
    private func data(for urlRequest: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: NetworkError.unknown)
                }
            }.resume()
        }
    }

}
