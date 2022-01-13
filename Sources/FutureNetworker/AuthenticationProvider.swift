import Foundation

public enum Authentication {
    case bearer(username: String, password: String)
}

public protocol AuthenticationProvider {
    var authentication: Authentication? { get }
}
