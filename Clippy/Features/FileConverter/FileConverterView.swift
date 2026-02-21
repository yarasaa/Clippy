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
            HStack {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(.accentColor)
                Text("Input Files")
                    .font(.headline)
                Spacer()
                Button(action: pickFiles) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Add files")

                if !viewModel.files.isEmpty {
                    Button(action: viewModel.clearAll) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red.opacity(0.7))
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
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Drop files here")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("or")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))

            Button("Select Files") {
                pickFiles()
            }
            .buttonStyle(.bordered)

            Text("Images, Documents, Audio, Video, Data files")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(isDragOver ? .accentColor : .secondary.opacity(0.3))
                .padding(8)
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
            HStack {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .foregroundColor(.accentColor)
                Text("Output Format")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.togglePinOnTop() }) {
                    Image(systemName: viewModel.isPinnedOnTop ? "pin.fill" : "pin")
                        .font(.title3)
                        .foregroundColor(viewModel.isPinnedOnTop ? .accentColor : .secondary)
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
        HStack {
            if viewModel.isConverting {
                ProgressView(value: viewModel.overallProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 140)
                Text("\(Int(viewModel.overallProgress * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
                Text("Converting...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let completed = viewModel.files.filter { $0.conversionState == .completed }.count
                let failed = viewModel.files.filter {
                    if case .failed = $0.conversionState { return true }
                    return false
                }.count

                if completed > 0 || failed > 0 {
                    HStack(spacing: 8) {
                        if completed > 0 {
                            Label("\(completed) completed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        if failed > 0 {
                            Label("\(failed) failed", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                } else if !viewModel.files.isEmpty {
                    Text("\(viewModel.files.count) file\(viewModel.files.count == 1 ? "" : "s") selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if viewModel.files.count > 1, viewModel.selectedFileID != nil {
                Button("Convert Selected") {
                    viewModel.startConversion(onlySelected: true)
                }
                .disabled(
                    viewModel.isConverting ||
                    viewModel.selectedFile?.selectedOutputFormat == nil
                )
            }

            Button("Convert All") {
                viewModel.startConversion()
            }
            .buttonStyle(.borderedProminent)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: file.category.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.fileName)
                        .font(.caption)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(file.fileExtension.uppercased())
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if let output = file.selectedOutputFormat {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(output.displayName)
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                Spacer()

                // State indicator
                switch file.conversionState {
                case .pending:
                    EmptyView()
                case .converting:
                    Text("\(Int(file.conversionProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Per-file progress bar
            if file.conversionState == .converting {
                ProgressView(value: file.conversionProgress)
                    .progressViewStyle(.linear)
                    .frame(height: 3)
                    .padding(.leading, 28)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Format Button

struct FormatButton: View {
    let format: OutputFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconForFormat(format))
                    .font(.title3)
                Text(format.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
}
