//
//  ParameterInputView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 4.10.2025.
//


import SwiftUI

nonisolated struct ParameterDefinition {
    let rawValue: String
    let name: String
    let type: String
    let options: [String]
    let defaultValue: String?

    init(parameterString: String) {
        self.rawValue = parameterString

        let defaultValueParts = parameterString.split(separator: "=", maxSplits: 1).map(String.init)
        let mainPart = defaultValueParts[0]
        self.defaultValue = defaultValueParts.count > 1 ? defaultValueParts[1] : nil

        let typeParts = mainPart.split(separator: ":", maxSplits: 2).map(String.init)
        self.name = typeParts[0]

        self.type = typeParts.count > 1 ? typeParts[1].lowercased() : "text"

        if self.type == "choice", typeParts.count > 2 {
            self.options = typeParts[2].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        } else {
            self.options = []
        }
    }
}

struct ParameterInputView: View {
    let parameters: [String]
    let snippetTemplate: String?
    let onConfirm: ([String: String]) -> Void
    let onCancel: () -> Void

    @State private var values: [String]
    @State private var isPreviewExpanded: Bool = true
    @EnvironmentObject var settings: SettingsManager
    @FocusState private var focusedField: Int?

    private let definitions: [ParameterDefinition]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    init(parameters: [String], snippetTemplate: String? = nil, onConfirm: @escaping ([String: String]) -> Void, onCancel: @escaping () -> Void) {
        self.parameters = parameters
        self.snippetTemplate = snippetTemplate
        self.onConfirm = onConfirm
        self.onCancel = onCancel

        let defs = parameters.map { ParameterDefinition(parameterString: $0) }
        self.definitions = defs

        _values = State(initialValue: defs.map { $0.defaultValue ?? "" })
    }

    var body: some View {
        VStack(spacing: 15) {
            Text(L("Fill in the Parameters", settings: settings))
                .font(.title2)
                .fontWeight(.semibold)

            ForEach(Array(definitions.enumerated()), id: \.offset) { index, definition in
                inputView(for: definition, at: index)
            }

            if let template = snippetTemplate {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPreviewExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.blue)
                            Text(L("Preview", settings: settings))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: isPreviewExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    if isPreviewExpanded {
                        let previewText = generatePreview(template: template)

                        ScrollView {
                            Text(previewText)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .frame(minHeight: 100, maxHeight: 200)
                        .border(Color.blue.opacity(0.3), width: 1)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 8)
            }

            HStack {
                Button(L("Cancel", settings: settings)) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(L("Paste", settings: settings)) {
                    confirm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(values.contains(where: { $0.isEmpty }))
            }
            .padding(.top)
        }
        .preferredColorScheme(colorScheme)
        .padding(20)
        .frame(minWidth: 400)
        .onAppear {
            focusedField = 0
        }
    }

    @ViewBuilder
    private func inputView(for definition: ParameterDefinition, at index: Int) -> some View {
        VStack(alignment: .leading) {
            Text(definition.name.capitalized)
                .font(.headline)

            switch definition.type {
            case "date":
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dateFormatter.date(from: values[index]) ?? Date() },
                        set: { values[index] = dateFormatter.string(from: $0) }
                    ),
                    displayedComponents: .date)
                    .labelsHidden()
                    .onAppear { if values[index].isEmpty { values[index] = dateFormatter.string(from: Date()) } }

            case "time":
                DatePicker(
                    "",
                    selection: Binding(
                        get: { timeFormatter.date(from: values[index]) ?? Date() },
                        set: { values[index] = timeFormatter.string(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onAppear { if values[index].isEmpty { values[index] = timeFormatter.string(from: Date()) } }

            case "choice":
                Picker("", selection: $values[index]) {
                    ForEach(definition.options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
                .onAppear { if values[index].isEmpty { values[index] = definition.options.first ?? "" } }

            default:
                TextField("", text: $values[index])
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: index)
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    private func confirm() {
        let filledParameters = Dictionary(uniqueKeysWithValues: zip(definitions.map { $0.rawValue }, values))
        onConfirm(filledParameters)
    }

    private func generatePreview(template: String) -> String {
        var preview = template

        if preview.contains("{{DATE}}") {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            preview = preview.replacingOccurrences(of: "{{DATE}}", with: dateFormatter.string(from: Date()))
        }

        if preview.contains("{{TIME}}") {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            preview = preview.replacingOccurrences(of: "{{TIME}}", with: timeFormatter.string(from: Date()))
        }

        if preview.contains("{{DATETIME}}") {
            let dateTimeFormatter = DateFormatter()
            dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            preview = preview.replacingOccurrences(of: "{{DATETIME}}", with: dateTimeFormatter.string(from: Date()))
        }

        if preview.contains("{{UUID}}") {
            preview = preview.replacingOccurrences(of: "{{UUID}}", with: "[UUID]")
        }

        if preview.contains("{{CLIPBOARD}}") {
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string) ?? "[clipboard empty]"
            preview = preview.replacingOccurrences(of: "{{CLIPBOARD}}", with: clipboardContent.prefix(50) + (clipboardContent.count > 50 ? "..." : ""))
        }

        let randomPattern = #"\{\{RANDOM:(\d+)-(\d+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: randomPattern) {
            let matches = regex.matches(in: preview, range: NSRange(preview.startIndex..., in: preview))
            for match in matches.reversed() {
                if match.numberOfRanges == 3,
                   let fullRange = Range(match.range, in: preview),
                   let minRange = Range(match.range(at: 1), in: preview),
                   let maxRange = Range(match.range(at: 2), in: preview) {
                    let minStr = String(preview[minRange])
                    let maxStr = String(preview[maxRange])
                    preview.replaceSubrange(fullRange, with: "[RANDOM:\(minStr)-\(maxStr)]")
                }
            }
        }

        let shellPattern = #"\{\{SHELL:([^}]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: shellPattern) {
            let matches = regex.matches(in: preview, range: NSRange(preview.startIndex..., in: preview))
            for match in matches.reversed() {
                if match.numberOfRanges == 2,
                   let fullRange = Range(match.range, in: preview),
                   let commandRange = Range(match.range(at: 1), in: preview) {
                    let command = String(preview[commandRange])
                    preview.replaceSubrange(fullRange, with: "[SHELL:\(command)]")
                }
            }
        }

        let nestedPattern = #"\{\{;([a-zA-Z0-9_-]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: nestedPattern) {
            let matches = regex.matches(in: preview, range: NSRange(preview.startIndex..., in: preview))
            for match in matches.reversed() {
                if match.numberOfRanges == 2,
                   let fullRange = Range(match.range, in: preview),
                   let keywordRange = Range(match.range(at: 1), in: preview) {
                    let keyword = String(preview[keywordRange])
                    preview.replaceSubrange(fullRange, with: "[snippet:\(keyword)]")
                }
            }
        }

        for (index, definition) in definitions.enumerated() {
            let value = values[index].isEmpty ? "[\(definition.name)]" : values[index]
            preview = preview.replacingOccurrences(of: "{\(definition.rawValue)}", with: value)
        }

        return preview
    }
}
