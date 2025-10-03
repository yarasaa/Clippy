//
//  ClipboardItem.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//

import Foundation
import SwiftUI

struct ClipboardItem: Identifiable, Equatable, Hashable, Codable {
    enum ContentType: Codable {
        case text(String)
        case image(imagePath: String)
    }

    var id: UUID
    var contentType: ContentType
    var date: Date
    var isFavorite: Bool = false
    var isCode: Bool = false
    var title: String?
    var isEncrypted: Bool = false
    var keyword: String?
    var sourceAppName: String?
    var sourceAppBundleIdentifier: String?
    let isURL: Bool
    let isHexColor: Bool
    let detectedDate: Date?
    let color: Color?

    var content: String {
        if case .text(let string) = contentType {
            return string
        }
        if case .image(let path) = contentType { return "Image: \(path)" }
        return ""
    }

    var isText: Bool {
        if case .text = contentType {
            return true
        }
        return false
    }
    
    var isImage: Bool {
        if case .image = contentType {
            return true
        }
        return false
    }

    var isJSON: Bool {
        guard isText,
              let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines) as String?,
              (trimmedContent.hasPrefix("{") && trimmedContent.hasSuffix("}")) || (trimmedContent.hasPrefix("[") && trimmedContent.hasSuffix("]")),
              let data = trimmedContent.data(using: .utf8) else { return false }
        
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }

    init(id: UUID = UUID(), contentType: ContentType, date: Date, isFavorite: Bool = false, isCode: Bool = false, title: String? = nil, isEncrypted: Bool = false, keyword: String? = nil, sourceAppName: String? = nil, sourceAppBundleIdentifier: String? = nil) {
        let contentString: String
        if case .text(let string) = contentType {
            contentString = string
        } else {
            contentString = ""
        }

        self.id = id
        self.contentType = contentType
        self.date = date
        self.isFavorite = isFavorite
        self.isCode = isCode
        self.title = title
        self.isEncrypted = isEncrypted
        self.keyword = keyword
        self.sourceAppName = sourceAppName
        self.sourceAppBundleIdentifier = sourceAppBundleIdentifier

        self.isURL = Self.checkIfURL(contentString)
        self.isHexColor = Self.checkIfHexColor(contentString)
        self.detectedDate = Self.detectDate(in: contentString)
        self.color = Self.createColor(from: contentString)
    }

    init(content: String, date: Date) {
        self.init(contentType: .text(content), date: date)
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Codable Conformance
extension ClipboardItem {
    enum CodingKeys: String, CodingKey {
        case id, contentType, date, isFavorite, isCode, sourceAppName, sourceAppBundleIdentifier, detectedDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let decodedContentType = try container.decode(ContentType.self, forKey: .contentType)
        let contentString: String
        if case .text(let string) = decodedContentType {
            contentString = string
        } else {
            contentString = ""
        }

        self.id = try container.decode(UUID.self, forKey: .id)
        self.contentType = decodedContentType
        self.date = try container.decode(Date.self, forKey: .date)
        self.isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        self.isCode = try container.decodeIfPresent(Bool.self, forKey: .isCode) ?? false
        self.title = nil
        self.isEncrypted = false
        self.sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        self.keyword = nil
        self.sourceAppBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleIdentifier)
        self.detectedDate = try container.decodeIfPresent(Date.self, forKey: .detectedDate)

        self.isURL = Self.checkIfURL(contentString)
        self.isHexColor = Self.checkIfHexColor(contentString)
        self.color = Self.createColor(from: contentString)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(date, forKey: .date)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(isCode, forKey: .isCode)
        // try container.encodeIfPresent(keyword, forKey: .keyword) // Henüz kaydetmiyoruz.
        try container.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
        try container.encodeIfPresent(sourceAppBundleIdentifier, forKey: .sourceAppBundleIdentifier)
        try container.encodeIfPresent(detectedDate, forKey: .detectedDate)
    }
}

private extension ClipboardItem {
    static func checkIfURL(_ content: String) -> Bool {
        guard let url = URL(string: content),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme) else {
            return false
        }
        return true
    }

    static func checkIfHexColor(_ content: String) -> Bool {
        let hexColorPattern = #"^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$"#
        return content.trimmingCharacters(in: .whitespacesAndNewlines).range(of: hexColorPattern, options: .regularExpression) != nil
    }

    static func detectDate(in text: String) -> Date? {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            return matches.first?.date
        } catch {
            print("❌ NSDataDetector oluşturulamadı: \(error)")
            return nil
        }
    }

    static func createColor(from content: String) -> Color? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedContent.hasPrefix("#") {
            let hex = trimmedContent.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            let a, r, g, b: UInt64
            switch hex.count {
            case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            default: return nil
            }
            return Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
        }

        if trimmedContent.lowercased().hasPrefix("rgb") {
            let pattern = #"rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)"#
            if let match = trimmedContent.range(of: pattern, options: .regularExpression) {
                let components = trimmedContent[match].replacingOccurrences(of: "rgba", with: "").replacingOccurrences(of: "rgb", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard components.count >= 3 else { return nil }
                let r = Double(components[0]) ?? 0
                let g = Double(components[1]) ?? 0
                let b = Double(components[2]) ?? 0
                let a = components.count > 3 ? Double(components[3]) ?? 1.0 : 1.0
                return Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
            }
        }
        return nil
    }
}
