import Foundation

public struct IdentityAndTrust {
    public var identityRef: SecIdentity
    public var trust: SecTrust
    public var certArray: NSArray
}

public struct MTLSInfo {
    public let p12Path: URL
    public let password: String
    public let derPath: URL
    
    public init(p12Path: URL, password: String, derPath: URL) {
        self.p12Path = p12Path
        self.password = password
        self.derPath = derPath
    }
}

public class Client: NSObject {
    public typealias Percentage = Double
    public typealias ProgressHandler = (Percentage) -> Void

    public lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    
    public static let shared: Client = .init()

    public var mTLSInfo: MTLSInfo?
    
    private let responseHandler: ResponseHandler
    
    private var progressHandlersByTaskID = [Int : ProgressHandler]()
    
    public init(responseHandler: ResponseHandler = DefaultResponseHandler()) {
        self.responseHandler = responseHandler
    }
    
    @discardableResult
    public func request<T: Decodable>(_ endpoint: Endpoint<T>, progressHandler: ProgressHandler? = nil) async throws -> T {
        guard var urlRequest = endpoint.urlRequest else {
            throw NetworkError.unknown
        }

        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 20
    
        if case .upload(let data) = endpoint.parameters {
            let (data, urlResponse) = try await upload(for: urlRequest, data: data, progressHandler: progressHandler)
            return try responseHandler.handleResponse(data, urlResponse: urlResponse)
        } else {
            let (data, urlResponse) = try await data(for: urlRequest, progressHandler: progressHandler)
            return try responseHandler.handleResponse(data, urlResponse: urlResponse)
        }
        
        
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
    
    private func data(for urlRequest: URLRequest, progressHandler: ProgressHandler?) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
           let task = session.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: NetworkError.unknown)
                }
            }
            progressHandlersByTaskID[task.taskIdentifier] = progressHandler
            
            task.resume()
        }
    }

    private func upload(for urlRequest: URLRequest, data: Data, progressHandler: ProgressHandler?) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in

            let task = session.uploadTask(with: urlRequest, from: data) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: NetworkError.unknown)
                }
            }
            progressHandlersByTaskID[task.taskIdentifier] = progressHandler
            task.resume()
        }
    }
    
}

extension Client: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let handler = progressHandlersByTaskID[task.taskIdentifier]
        handler?(progress)
    }
}

extension Client: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let mTLSInfo = mTLSInfo else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let localCertPath = mTLSInfo.p12Path
        
        if let localCertData = try? Data(contentsOf: localCertPath) {
            let identityAndTrust: IdentityAndTrust = extractIdentity(certData: localCertData as NSData, certPassword: mTLSInfo.password)

            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
                && challenge.protectionSpace.serverTrust != nil {
                
                let pem = mTLSInfo.derPath
                if let trust = challenge.protectionSpace.serverTrust,
                   let data = NSData(contentsOf: pem),
                   let cert = SecCertificateCreateWithData(nil, data) {
                    
                    let certs = [cert]
                    SecTrustSetAnchorCertificates(trust, certs as CFArray)
                    let result = SecTrustResultType.invalid
                    
                    if SecTrustEvaluateWithError(trust, nil) {
                        
                        if result == SecTrustResultType.proceed || result == SecTrustResultType.unspecified {
                            let proposedCredential = URLCredential(trust: trust)
                            completionHandler(.useCredential,proposedCredential)
                            return
                        }
                    }
                    
                }
                completionHandler(.performDefaultHandling, nil)
            }
            
            
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
                
                let urlCredential:URLCredential = URLCredential(
                    identity: identityAndTrust.identityRef,
                    certificates: identityAndTrust.certArray as [AnyObject],
                    persistence: URLCredential.Persistence.permanent)
                
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, urlCredential)
                return
            }
            
        }
        
        challenge.sender?.cancel(challenge)
        completionHandler(URLSession.AuthChallengeDisposition.rejectProtectionSpace, nil)
    }
    
    private func extractIdentity(certData:NSData, certPassword:String) -> IdentityAndTrust {
        
        var identityAndTrust: IdentityAndTrust!
        var securityError: OSStatus = errSecSuccess
        
        var items: CFArray!
        let certOptions: Dictionary = [ kSecImportExportPassphrase as String : certPassword ]
        
        securityError = SecPKCS12Import(certData, certOptions as CFDictionary, &items)
        
        if securityError == errSecSuccess {
            
            let certItems:CFArray = items as CFArray
            let certItemsArray:Array = certItems as Array
            let dict:AnyObject? = certItemsArray.first
            
            if let certEntry:Dictionary = dict as? Dictionary<String, AnyObject> {
                let identityPointer:AnyObject? = certEntry["identity"]
                let secIdentityRef:SecIdentity = identityPointer as! SecIdentity
                
                let trustPointer:AnyObject? = certEntry["trust"]
                let trustRef:SecTrust = trustPointer as! SecTrust
                
                var certRef: SecCertificate!
                SecIdentityCopyCertificate(secIdentityRef, &certRef)
                let certArray:NSMutableArray = NSMutableArray()
                certArray.add(certRef as SecCertificate)
                
                identityAndTrust = IdentityAndTrust(identityRef: secIdentityRef, trust: trustRef, certArray: certArray);
            }
        }
        
        return identityAndTrust
    }

}
