import Foundation

public enum RequestParameters {
    case body(Parameters)
    case query(Parameters)
    case data(Data)
    case upload(Data)
    case none
}

public typealias Parameters = [String : ParameterValueConvertible?]

public protocol ParameterValueConvertible {
    var parameterValue: String { get }
}

extension Int: ParameterValueConvertible {
    public var parameterValue: String { String(self) }
}

extension UInt: ParameterValueConvertible {
    public var parameterValue: String { String(self) }
}

extension Int64: ParameterValueConvertible {
    public var parameterValue: String { String(self) }
}

extension Array: ParameterValueConvertible where Element: ParameterValueConvertible {
    public var parameterValue: String { map(\.parameterValue).joined(separator: ",") }
}

extension String: ParameterValueConvertible {
    public var parameterValue: String { self }
}

extension Double: ParameterValueConvertible {
    public var parameterValue: String { String(self) }
}

extension Bool: ParameterValueConvertible {
    public var parameterValue: String { self ? "true" : "false" }
}

extension Date: ParameterValueConvertible {
    public var parameterValue: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

extension Dictionary: ParameterValueConvertible where Key: Encodable, Value: Encodable {
    public var parameterValue: String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return ""
    }
}
