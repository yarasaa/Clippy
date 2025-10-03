//
//  Codable+Extensions.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 2.10.2025.
//

import Foundation

// MARK: - JSON Codable Helpers

extension Encodable {
    /// Nesneyi JSON formatında bir metne dönüştürür.
    /// - Parameter pretty: `true` ise, okunabilirliği artırmak için metin formatlanır.
    /// - Returns: JSON formatında bir String veya hata durumunda `nil`.
    func toJSONString(pretty: Bool = false) -> String? {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension String {
    /// JSON metnini belirtilen `Decodable` türde bir nesneye dönüştürür.
    /// - Returns: Oluşturulan nesne veya hata durumunda `nil`.
    func fromJSON<T: Decodable>() -> T? {
        guard let data = self.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}