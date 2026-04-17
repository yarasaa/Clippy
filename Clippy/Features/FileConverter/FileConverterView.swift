//
//  FileConverterView.swift
//  Clippy
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - ViewModel

class FileConverterViewModel: ObservableObject {
    @Published var files: [ConvertibleFile] = []
    @Published var isConverting: Bool = false
    @Published var overallProgress: Double = 0.0
    @Published var selectedFileID: UUID?
    @Published var isPinnedOnTop: Bool = false

    func togglePinOnTop() {
        isPinnedOnTop.toggle()
        FileConverterPanelController.shared.setWindowLevel(floating: isPinnedOnTop)
    }

    var selectedFile: ConvertibleFile? {
        files.first { $0.id == selectedFileID }
    }

    func addFiles(urls: [URL]) {
        for url in urls {
            // Skip duplicates
            guard !files.contains(where: { $0.url == url }) else { continue }

            let ext = url.pathExtension.lowercased()
            let (category, formats) = FileConversionService.shared.categorize(fileURL: url)
            guard !formats.isEmpty else { continue }

            let baseName = url.deletingPathExtension().lastPathComponent
            let file = ConvertibleFile(
                url: url,
                fileName: url.lastPathComponent,
                fileExtension: ext,
                category: category,
                availableOutputFormats: formats,
                selectedOutputFormat: formats.first,
                customOutputName: baseName
            )
            files.append(file)
        }

        if selectedFileID == nil {
            selectedFileID = files.first?.id
        }
    }

    func removeFile(id: UUID) {
        files.removeAll { $0.id == id }
        if selectedFileID == id {
            selectedFileID = files.first?.id
        }
    }

    func clearAll() {
        files.removeAll()
        selectedFileID = nil
        overallProgress = 0
    }

    func setOutputFormat(for fileID: UUID, format: OutputFormat) {
        if let idx = files.firstIndex(where: { $0.id == fileID }) {
            files[idx].selectedOutputFormat = format
        }
    }

    func setOutputName(for fileID: UUID, name: String) {
        if let idx = files.firstIndex(where: { $0.id == fileID }) {
            files[idx].customOutputName = name
        }
    }

    func setOutputFormatForAll(_ format: OutputFormat) {
        for i in files.indices {
            if files[i].availableOutputFormats.contains(format) {
                files[i].selectedOutputFormat = format
            }
        }
    }

    func startConversion(onlySelected: Bool = false) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose output folder"
        panel.prompt = "Convert"

        panel.begin { [weak self] response in
            guard response == .OK, let outputDir = panel.url else { return }
            Task { @MainActor in
                await self?.performBatchConversion(to: outputDir, onlySelected: onlySelected)
            }
        }
    }

    @MainActor
    private func performBatchConversion(to outputDir: URL, onlySelected: Bool = false) async {
        isConverting = true
        overallProgress = 0

        let filesToConvert: [ConvertibleFile]
        if onlySelected, let selectedID = selectedFileID {
            filesToConvert = files.filter { $0.id == selectedID && $0.selectedOutputFormat != nil }
        } else {
            filesToConvert = files.filter { $0.selectedOutputFormat != nil }
        }
        let totalCount = Double(filesToConvert.count)
        guard totalCount > 0 else {
            isConverting = false
            return
        }

        for (index, file) in filesToConvert.enumerated() {
            guard let outputFormat = file.selectedOutputFormat else { continue }

            let fileID = file.id
            if let idx = files.firstIndex(where: { $0.id == fileID }) {
                files[idx].conversionState = .converting
                files[idx].conversionProgress = 0
            }

            let baseName = file.outputBaseName
            var destinationURL = outputDir.appendingPathComponent("\(baseName).\(outputFormat.fileExtension)")

            // Handle name conflicts
            var counter = 1
            while FileManager.default.fileExists(atPath: destinationURL.path) {
                destinationURL = outputDir.appendingPathComponent("\(baseName)-\(counter).\(outputFormat.fileExtension)")
                counter += 1
            }

            do {
                try await FileConversionService.shared.convert(
                    input: file.url,
                    outputFormat: outputFormat,
                    destination: destinationURL,
                    progress: { [weak self] prog in
                        guard let self else { return }
                        if let idx = self.files.firstIndex(where: { $0.id == fileID }) {
                            self.files[idx].conversionProgress = prog
                        }
                        // Update overall: completed files + current file fraction
                        self.overallProgress = (Double(index) + prog) / totalCount
                    }
                )
                if let idx = files.firstIndex(where: { $0.id == fileID }) {
                    files[idx].conversionState = .completed
                    files[idx].conversionProgress = 1.0
                }
            } catch {
                if let idx = files.firstIndex(where: { $0.id == fileID }) {
                    files[idx].conversionState = .failed(error.localizedDescription)
                }
            }

            overallProgress = Double(index + 1) / totalCount
        }

        isConverting = false
    }
}

// MARK: - Main View

struct FileConverterView: View {
    @ObservedObject var viewModel: FileConverterViewModel
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leftPanel
                    .frame(minWidth: 240, idealWidth: 280)

                Divider()

                rightPanel
                    .frame(minWidth: 260, idealWidth: 380)
            }

            Divider()

            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                ClippyMark(size: 14)
                Text("Input Files")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if !viewModel.files.isEmpty {
                    Text("\(viewModel.files.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(Ember.Palette.amber))
                }
                Spacer()
                Button(action: pickFiles) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundColor(Ember.Palette.amber)
                }
                .buttonStyle(.plain)
                .help("Add files")

                if !viewModel.files.isEmpty {
                    Button(action: viewModel.clearAll) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(Ember.Palette.rust.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Clear all files")
                }
            }
            .padding(12)

            Divider()

            // Content area
            if viewModel.files.isEmpty {
                dropZoneEmpty
            } else {
                fileList
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private var dropZoneEmpty: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Ember.Palette.amber.opacity(isDragOver ? 0.22 : 0.1))
                    .frame(width: 92, height: 92)
                    .blur(radius: 12)

                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(isDragOver ? Ember.Palette.amber : Ember.Palette.amber.opacity(0.7))
            }
            .animation(.easeInOut(duration: 0.2), value: isDragOver)

            VStack(spacing: 4) {
                Text(isDragOver ? "Release to add" : "Drop files here")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Text("Images · Docs · Audio · Video · Data")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Button("Select Files") { pickFiles() }
                .buttonStyle(SecondaryActionButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Ember.Radius.lg)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6])
                )
                .foregroundColor(isDragOver ? Ember.Palette.amber : Ember.Palette.smoke.opacity(0.3))
                .padding(10)
        )
    }

    private var fileList: some View {
        List(selection: $viewModel.selectedFileID) {
            ForEach(viewModel.files) { file in
                FileRowView(file: file, onRemove: {
                    viewModel.removeFile(id: file.id)
                })
                .tag(file.id)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .foregroundColor(Ember.Palette.amber)
                Text("Output Format")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Button(action: { viewModel.togglePinOnTop() }) {
                    Image(systemName: viewModel.isPinnedOnTop ? "pin.fill" : "pin")
                        .font(.title3)
                        .foregroundColor(viewModel.isPinnedOnTop ? Ember.Palette.amber : .secondary)
                }
                .buttonStyle(.plain)
                .help(viewModel.isPinnedOnTop ? "Unpin from top" : "Pin on top")
            }
            .padding(12)

            Divider()

            if let file = viewModel.selectedFile {
                formatSelectionView(for: file)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.left")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Select a file to see conversion options")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func formatSelectionView(for file: ConvertibleFile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Current file info
                HStack {
                    Image(systemName: file.category.icon)
                        .foregroundColor(.accentColor)
                    Text(file.fileName)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Text(file.fileExtension.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.secondary.opacity(0.15)))
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                // Output file name
                HStack(spacing: 6) {
                    Text("Name:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Output file name", text: Binding(
                        get: { file.customOutputName },
                        set: { viewModel.setOutputName(for: file.id, name: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    if let ext = file.selectedOutputFormat?.fileExtension {
                        Text(".\(ext)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)

                Text("Convert to:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)

                // Format grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(file.availableOutputFormats) { format in
                        FormatButton(
                            format: format,
                            isSelected: file.selectedOutputFormat == format
                        ) {
                            viewModel.setOutputFormat(for: file.id, format: format)
                        }
                    }
                }
                .padding(.horizontal, 14)

                // Apply to all
                if viewModel.files.count > 1, let selected = file.selectedOutputFormat {
                    Button {
                        viewModel.setOutputFormatForAll(selected)
                    } label: {
                        Label("Apply to all compatible files", systemImage: "arrow.down.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: Ember.Space.md) {
            if viewModel.isConverting {
                HStack(spacing: Ember.Space.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Ember.Palette.smoke.opacity(0.15))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Ember.Palette.amber, Ember.Palette.amberGlow],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * viewModel.overallProgress)
                        }
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 180)

                    Text("\(Int(viewModel.overallProgress * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Ember.Palette.amber)
                        .frame(width: 36, alignment: .trailing)

                    Text("Converting…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                let completed = viewModel.files.filter { $0.conversionState == .completed }.count
                let failed = viewModel.files.filter {
                    if case .failed = $0.conversionState { return true }
                    return false
                }.count

                if completed > 0 || failed > 0 {
                    HStack(spacing: Ember.Space.sm) {
                        if completed > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("\(completed) done")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Ember.Palette.moss)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Ember.Palette.moss.opacity(0.12)))
                        }
                        if failed > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.octagon.fill")
                                Text("\(failed) failed")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Ember.Palette.rust)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Ember.Palette.rust.opacity(0.12)))
                        }
                    }
                } else if !viewModel.files.isEmpty {
                    Text("\(viewModel.files.count) file\(viewModel.files.count == 1 ? "" : "s") ready")
                        .font(Ember.Font.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if viewModel.files.count > 1, viewModel.selectedFileID != nil {
                Button("Convert Selected") {
                    viewModel.startConversion(onlySelected: true)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(
                    viewModel.isConverting ||
                    viewModel.selectedFile?.selectedOutputFormat == nil
                )
            }

            Button {
                viewModel.startConversion()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                    Text("Convert All")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(
                viewModel.files.isEmpty ||
                viewModel.isConverting ||
                viewModel.files.allSatisfy { $0.selectedOutputFormat == nil }
            )
        }
    }

    // MARK: - Helpers

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "Select files to convert"
        panel.begin { response in
            if response == .OK {
                viewModel.addFiles(urls: panel.urls)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        viewModel.addFiles(urls: [url])
                    }
                }
            }
        }
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let file: ConvertibleFile
    let onRemove: () -> Void
    @Environment(\.colorScheme) var scheme
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor(file.category).opacity(0.14))
                        .frame(width: 32, height: 32)

                    Image(systemName: file.category.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(categoryColor(file.category))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.fileName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Ember.primaryText(scheme))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(file.fileExtension.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(categoryColor(file.category))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(categoryColor(file.category).opacity(0.12))
                            )

                        if let output = file.selectedOutputFormat {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(Ember.tertiaryText(scheme))

                            Text(output.displayName)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                )
                        }
                    }
                }

                Spacer()

                stateIndicator

                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Ember.secondaryText(scheme))
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Ember.Palette.smoke.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }

            if file.conversionState == .converting {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Ember.Palette.smoke.opacity(0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Ember.Palette.amber, Ember.Palette.amberGlow],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * file.conversionProgress)
                    }
                }
                .frame(height: 3)
                .padding(.leading, 42)
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch file.conversionState {
        case .pending:
            EmptyView()
        case .converting:
            Text("\(Int(file.conversionProgress * 100))%")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Ember.Palette.amber)
                .frame(width: 36, alignment: .trailing)
        case .completed:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("Done")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(Ember.Palette.moss)
        case .failed(let message):
            Image(systemName: "xmark.octagon.fill")
                .foregroundColor(Ember.Palette.rust)
                .font(.system(size: 11))
                .help(message)
        }
    }

    private func categoryColor(_ category: FileFormatCategory) -> Color {
        switch category {
        case .image:    return Color(red: 0.28, green: 0.55, blue: 0.92)
        case .document: return Ember.Palette.amber
        case .audio:    return Color(red: 0.72, green: 0.33, blue: 0.95)
        case .video:    return Color(red: 0.92, green: 0.38, blue: 0.60)
        case .data:     return Ember.Palette.moss
        case .unknown:  return Ember.Palette.smoke
        }
    }
}

// MARK: - Format Button

struct FormatButton: View {
    let format: OutputFormat
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var scheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: iconForFormat(format))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : formatColor(format))

                Text(format.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : Ember.primaryText(scheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Ember.Radius.md)
                            .fill(
                                LinearGradient(
                                    colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: Ember.Radius.md)
                            .fill(isHovered ? Ember.Palette.amber.opacity(0.06) : Color.clear)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Ember.Radius.md)
                    .strokeBorder(
                        isSelected ? Color.clear : Ember.Palette.smoke.opacity(isHovered ? 0.4 : 0.22),
                        lineWidth: isSelected ? 0 : 1
                    )
            )
            .shadow(
                color: isSelected ? Ember.Palette.amber.opacity(0.3) : .clear,
                radius: 6,
                y: 2
            )
            .scaleEffect(isHovered && !isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }

    private func iconForFormat(_ format: OutputFormat) -> String {
        switch format.fileExtension {
        case "png", "jpg", "jpeg", "tiff", "bmp", "gif", "heic", "webp": return "photo"
        case "pdf": return "doc.richtext"
        case "txt": return "doc.plaintext"
        case "rtf", "docx": return "doc.text"
        case "html": return "globe"
        case "mp4", "mov", "m4v": return "film"
        case "m4a", "wav", "caf", "aac", "aiff", "mp3", "flac": return "waveform"
        case "json": return "curlybraces"
        case "xml": return "chevron.left.forwardslash.chevron.right"
        case "csv": return "tablecells"
        case "plist": return "list.bullet.rectangle"
        default: return "doc"
        }
    }

    private func formatColor(_ format: OutputFormat) -> Color {
        switch format.fileExtension {
        case "png", "jpg", "jpeg", "tiff", "bmp", "gif", "heic", "webp":
            return Color(red: 0.28, green: 0.55, blue: 0.92)
        case "pdf", "txt", "rtf", "docx", "html":
            return Ember.Palette.amber
        case "mp4", "mov", "m4v":
            return Color(red: 0.92, green: 0.38, blue: 0.60)
        case "m4a", "wav", "caf", "aac", "aiff", "mp3", "flac":
            return Color(red: 0.72, green: 0.33, blue: 0.95)
        case "json", "xml", "csv", "plist":
            return Ember.Palette.moss
        default:
            return Ember.Palette.smoke
        }
    }
}
