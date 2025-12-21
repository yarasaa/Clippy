//
//  SnippetVariable.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 15.11.2025.
//

import Foundation

struct SnippetVariable: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String  // e.g., "MY_NAME"
    var value: String // e.g., "Mehmet Akbaba"

    var placeholder: String {
        "{{\(name)}}"
    }

    init(id: UUID = UUID(), name: String, value: String) {
        self.id = id
        self.name = name
        self.value = value
    }
}
