//
//  ParameterInputView.swift
//  Clippy
//
//  Created by Gemini Code Assist on 4.10.2025.
//

import SwiftUI

struct ParameterInputView: View {
    let parameters: [String]
    let onConfirm: ([String: String]) -> Void
    let onCancel: () -> Void

    @State private var values: [String]
    @EnvironmentObject var settings: SettingsManager
    @FocusState private var focusedField: Int?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
        _values = State(initialValue: Array(repeating: "", count: parameters.count))
    }

    var body: some View {
        VStack(spacing: 15) {
            Text(L("Fill in the Parameters", settings: settings))
                .font(.title2)
                .fontWeight(.semibold)

            ForEach(Array(parameters.enumerated()), id: \.offset) { index, param in
                inputView(for: param, at: index)
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
        .padding(20)
        .frame(minWidth: 300)
        .onAppear {
            // İlk alanı otomatik olarak odakla
            focusedField = 0
        }
    }

    @ViewBuilder
    private func inputView(for parameter: String, at index: Int) -> some View {
        VStack(alignment: .leading) {
            Text(parameter.capitalized)
                .font(.headline)
            
            let lowercasedParam = parameter.lowercased()
            
            if lowercasedParam.contains("date") || lowercasedParam.contains("tarih") {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dateFormatter.date(from: values[index]) ?? Date() },
                        set: { values[index] = dateFormatter.string(from: $0) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .onAppear { if values[index].isEmpty { values[index] = dateFormatter.string(from: Date()) } }
            } else if lowercasedParam.contains("time") || lowercasedParam.contains("saat") {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { timeFormatter.date(from: values[index]) ?? Date() },
                        set: { values[index] = timeFormatter.string(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .onAppear { if values[index].isEmpty { values[index] = timeFormatter.string(from: Date()) } }
            } else {
                TextField("", text: $values[index])
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: index)
            }
        }
    }

    private func confirm() {
        let filledParameters = Dictionary(uniqueKeysWithValues: zip(parameters, values))
        onConfirm(filledParameters)
    }
}