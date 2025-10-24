//
//  ParameterInputView.swift
//  Clippy
//
//  Created by Gemini Code Assist on 4.10.2025.
//

import SwiftUI

/// Parametre string'ini ayrıştırarak adı, tipi, varsayılan değeri ve seçenekleri içeren bir yapı.
struct ParameterDefinition {
    let rawValue: String
    let name: String
    let type: String
    let options: [String]
    let defaultValue: String?

    init(parameterString: String) {
        self.rawValue = parameterString
        
        // Varsayılan değeri ayır: {isim=değer:tip}
        let defaultValueParts = parameterString.split(separator: "=", maxSplits: 1).map(String.init)
        let mainPart = defaultValueParts[0]
        self.defaultValue = defaultValueParts.count > 1 ? defaultValueParts[1] : nil

        // Tip ve seçenekleri ayır: {isim:tip:seçenekler}
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
    let onConfirm: ([String: String]) -> Void
    let onCancel: () -> Void

    @State private var values: [String]
    @EnvironmentObject var settings: SettingsManager
    @FocusState private var focusedField: Int?

    private let definitions: [ParameterDefinition]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // ISO 8601 formatı, farklı lokasyonlarda tutarlılık sağlar.
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    init(parameters: [String], onConfirm: @escaping ([String: String]) -> Void, onCancel: @escaping () -> Void) {
        self.parameters = parameters
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        
        let defs = parameters.map(ParameterDefinition.init)
        self.definitions = defs
        
        // Varsayılan değerleri ata
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
        .frame(minWidth: 300)
        .onAppear {
            // İlk alanı otomatik olarak odakla
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

            default: // "text" ve diğer her şey
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
}