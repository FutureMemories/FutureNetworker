import Foundation

enum Authentication {
    case bearer(username: String, password: String)
}

protocol AuthenticationProvider {
    var authentication: Authentication? { get }
}

extension AuthenticationProvider where Self == UserSettings {

    static var `default`: Self { .shared }

}
