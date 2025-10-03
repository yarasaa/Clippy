//
//  JSONValue.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 25.09.2025.
//

import Foundation

enum JSONValue: Hashable, Identifiable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case dictionary([String: JSONValue])

    var id: UUID { UUID() }

    init?(from any: Any) {
        if let string = any as? String {
            self = .string(string)
        } else if let bool = any as? Bool {
            self = .bool(bool)
        } else if let number = any as? NSNumber {
            if String(cString: number.objCType) == "c" {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        } else if any is NSNull {
            self = .null
        } else if let array = any as? [Any] {
            let jsonArray = array.compactMap { JSONValue(from: $0) }
            self = .array(jsonArray)
        } else if let dictionary = any as? [String: Any] {
            var jsonDict: [String: JSONValue] = [:]
            for (key, value) in dictionary {
                if let jsonValue = JSONValue(from: value) {
                    jsonDict[key] = jsonValue
                }
            }
            self = .dictionary(jsonDict)
        } else {
            return nil
        }
    }
    
    var hasChildren: Bool {
        switch self {
        case .array(let array): return !array.isEmpty
        case .dictionary(let dict): return !dict.isEmpty
        default: return false
        }
    }
    
    var stringValue: String {
        switch self {
        case .string(let val):
            return val
        case .number(let val):
            if val == floor(val) {
                return String(Int(val))
            }
            return String(val)
        case .bool(let val):
            return val ? "true" : "false"
        case .null:
            return "null"
        case .array, .dictionary:
            return self.jsonString ?? ""
        }
    }
    
    var jsonString: String? {
        let anyValue = self.toAny()
        guard let data = try? JSONSerialization.data(withJSONObject: anyValue, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    private func toAny() -> Any {
        switch self {
        case .string(let val): return val
        case .number(let val): return NSNumber(value: val)
        case .bool(let val): return NSNumber(value: val)
        case .null: return NSNull()
        case .array(let array): return array.map { $0.toAny() }
        case .dictionary(let dict): return dict.mapValues { $0.toAny() }
        }
    }
}