//
//  JSONTreeView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 25.09.2025.
//

import SwiftUI

struct JSONTreeView: View {
    let key: String?
    let value: JSONValue
    let currentPath: String
    private var fullPath: String
    @EnvironmentObject var settings: SettingsManager
    
    @State private var isExpanded: Bool = true

    init(key: String?, value: JSONValue, currentPath: String) {
        self.key = key
        self.value = value
        self.currentPath = currentPath
        self.fullPath = currentPath.isEmpty ? (key ?? "") : "\(currentPath).\(key ?? "")".replacingOccurrences(of: ".[", with: "[")
    }

    var body: some View {
        Group {
            switch value {
            case .dictionary(let dictionary):
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(dictionary.keys.sorted(), id: \.self) { childKey in
                            if let childValue = dictionary[childKey] {
                                JSONTreeView(key: childKey, value: childValue, currentPath: fullPath)
                            }
                        }
                    }
                    .padding(.leading, 15)
                } label: {
                    HStack {
                        if let key = key {
                            Text(key).foregroundColor(.primary) + Text(": ")
                        }
                        Text("{...}").foregroundColor(.secondary)
                    Spacer()
                    }
                }
            case .array(let array):
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                            JSONTreeView(key: "[\(index)]", value: item, currentPath: fullPath)
                        }
                    }
                    .padding(.leading, 15)
                } label: {
                    HStack {
                        if let key = key {
                            Text(key).foregroundColor(.primary) + Text(": ")
                        }
                        Text("[...]").foregroundColor(.secondary)
                    Spacer()
                    }
                }
            default:
                HStack(alignment: .top) {
                    if let key = key {
                        Text(key).foregroundColor(.primary) + Text(": ")
                    }
                    valueText
                    Spacer()
                }
            }
        }
        .contextMenu {
            if let key = key, !key.starts(with: "[") {
                Button(action: {
                    copyToClipboard(key)
                }) {
                    Label(String(format: L("Copy Key \"%@\"", settings: settings), key), systemImage: "key.fill")
                }
            }
            if !fullPath.isEmpty {
                Button(action: {
                    copyToClipboard(fullPath)
                }) {
                    Label(L("Copy Path", settings: settings), systemImage: "link")
                }
            }
            Button(action: {
                copyToClipboard(value.stringValue)
            }) {
                Label(L("Copy Value", settings: settings), systemImage: "doc.on.doc")
            }
        }
    }
    
    @ViewBuilder
    private var valueText: some View {
        switch value {
        case .string(let val): Text("\"\(val)\"").foregroundColor(.red)
        case .number: Text(value.stringValue).foregroundColor(.blue)
        case .bool(let val): Text(val ? "true" : "false").foregroundColor(.purple)
        case .null: Text("null").foregroundColor(.gray)
        default: EmptyView()
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        pasteboard.addTypes([PasteManager.pasteFromClippyType], owner: nil)
    }
}