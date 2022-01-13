import Foundation

public class Client {

    let session: URLSession

    public static let shared = Client()

    public init(session: URLSession = .shared) {
        self.session = session
    }

//    func request<T>(_ endpoint: Endpoint<T>, completion: @escaping (Result<T, NetworkError>) -> Void) where T: Decodable {
//        guard var urlRequest = endpoint.urlRequest else {
//            completion(.failure(.unknown))
//            return
//        }
//        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
//        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        urlRequest.timeoutInterval = 20
//
//        session.dataTask(with: urlRequest) { data, urlResponse, error in
//            self.handleResponse(data, urlResponse: urlResponse, error: error, completion: completion)
//        }.resume()
//    }
    
    @discardableResult
    public func request<T: Decodable>(_ endpoint: Endpoint<T>) async throws -> T {
        guard var urlRequest = endpoint.urlRequest else {
            throw NetworkError.unknown
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 20
        
        let (data, urlResponse) = try await data(for: urlRequest)
        return try handleResponse(data, urlResponse: urlResponse)
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

    private func handleResponse<T: Decodable>(
        _ data: Data?,
        urlResponse: URLResponse?,
        error: Error?,
        completion: @escaping (Result<T, NetworkError>
        ) -> Void) {
        var result: Result<T, NetworkError> = .failure(.unknown)
        defer {
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            return
        }
        
        var errorData: [String : String]?
        if let data = data {
            errorData = try? JSONDecoder().decode([String : String].self, from: data)
        }
        
        let statusCode = httpResponse.statusCode
        guard (200..<300).contains(statusCode) else {
            let description = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            if (400..<500).contains(statusCode) {
                let error: NetworkError = .clientError(statusCode, localizedDescription: errorData?["error"] ?? errorData?["message"] ?? description)
                result = .failure(error)
            } else if (500..<600).contains(httpResponse.statusCode) {
                let error: NetworkError = .serverError(statusCode, localizedDescription: errorData?["error"] ?? description)
                result = .failure(error)
            }
            return
        }
        
        if let error = error {
            result = .failure(.serverError(500, localizedDescription: error.localizedDescription))
            return
        }
        
        guard let data = data else {
            result = .failure(NetworkError.decoding)
            return
        }
        
        result = decode(data: data)
    }
    
    private func handleResponse<T: Decodable>(_ data: Data?, urlResponse: URLResponse?) throws -> T {
        
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw NetworkError.unknown
        }
        
        var errorData: [String : String]?
        if let data = data {
            errorData = try? JSONDecoder().decode([String : String].self, from: data)
        }
        
        let statusCode = httpResponse.statusCode
        guard (200..<300).contains(statusCode) else {
            let description = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            if (400..<500).contains(statusCode) {
                let error: NetworkError = .clientError(statusCode, localizedDescription: errorData?["error"] ?? errorData?["message"] ?? description)
                throw error
            } else if (500..<600).contains(httpResponse.statusCode) {
                let error: NetworkError = .serverError(statusCode, localizedDescription: errorData?["error"] ?? description)
                throw error
            } else {
                throw NetworkError.unknown
            }
        }
        
        guard let data = data else {
            throw NetworkError.decoding
        }
        
        let result: T = try decode(data: data)
     
        return result
    }
    
    private func decode<T: Decodable>(data: Data) -> Result<T, NetworkError> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        do {
            let result = try decoder.decode(T.self, from: data)
            return .success(result)
        } catch {
            print(error)
            assertionFailure()
            return .failure(.decoding)
        }
    }
    
    private func decode<T: Decodable>(data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let dateFormatter = DateFormatter()
            // possible date strings: "2016-05-01",  "2016-07-04T17:37:21.119229Z", "2018-05-20T15:00:00Z"
            if dateString.count == 10 {
                dateFormatter.dateFormat = "yyyy-MM-dd"
            } else {
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            }
            guard let date = dateFormatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
            }
            return date
        })
        do {
            let result = try decoder.decode(T.self, from: data)
            return result
        } catch {
            print(error)
            assertionFailure()
            throw error
        }
    }

}
