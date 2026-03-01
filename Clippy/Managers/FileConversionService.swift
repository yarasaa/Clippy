//
//  FileConversionService.swift
//  Clippy
//

import Foundation
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import ImageIO

// MARK: - Conversion Error

enum ConversionError: LocalizedError {
    case unsupportedFormat(String)
    case readFailed(String)
    case writeFailed(String)
    case exportFailed(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let msg): return "Unsupported format: \(msg)"
        case .readFailed(let msg): return "Read failed: \(msg)"
        case .writeFailed(let msg): return "Write failed: \(msg)"
        case .exportFailed(let msg): return "Export failed: \(msg)"
        case .invalidData(let msg): return "Invalid data: \(msg)"
        }
    }
}

// MARK: - FileConversionService

class FileConversionService {
    static let shared = FileConversionService()
    private init() {}

    // MARK: - Format Map

    private static let allImageOutputs: [OutputFormat] = [.png, .jpeg, .tiff, .bmp, .gif, .heic, .pdf]

    private static let formatMap: [String: [OutputFormat]] = [
        // Image — every raster format can convert to all others (minus itself, filtered at runtime)
        "png":  allImageOutputs,
        "jpg":  allImageOutputs,
        "jpeg": allImageOutputs,
        "tiff": allImageOutputs,
        "tif":  allImageOutputs,
        "bmp":  allImageOutputs,
        "gif":  allImageOutputs,
        "heic": allImageOutputs,
        "heif": allImageOutputs,
        "ico":  allImageOutputs,
        "svg":  allImageOutputs,
        "webp": allImageOutputs,

        // Document
        "rtf":  [.txt, .html, .pdf],
        "html": [.txt, .rtf, .pdf],
        "htm":  [.txt, .rtf, .pdf],
        "txt":  [.rtf, .html, .pdf],
        "rtfd": [.txt, .html, .rtf, .pdf],
        "md":   [.html, .rtf, .txt, .pdf],
        "markdown": [.html, .rtf, .txt, .pdf],
        "docx": [.txt, .html, .rtf, .pdf],

        // Audio
        "m4a":  [.wav, .caf, .aiff],
        "wav":  [.m4a, .caf, .aiff],
        "aac":  [.m4a, .wav, .caf, .aiff],
        "aiff": [.m4a, .wav, .caf],
        "aif":  [.m4a, .wav, .caf],
        "mp3":  [.m4a, .wav, .caf, .aiff],
        "flac": [.m4a, .wav, .caf, .aiff],

        // Video
        "mov":  [.mp4, .m4v],
        "mp4":  [.mov, .m4v],
        "m4v":  [.mp4, .mov],
        "avi":  [.mp4, .mov, .m4v],

        // Data
        "json":  [.yaml, .xml, .csv, .plist],
        "yaml":  [.json, .xml, .plist],
        "yml":   [.json, .xml, .plist],
        "xml":   [.json, .yaml, .plist],
        "plist": [.json, .yaml, .xml],
        "csv":   [.json, .yaml],
    ]

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "tif", "bmp", "gif", "heic", "heif", "ico", "svg", "webp"]
    private static let documentExtensions: Set<String> = ["rtf", "html", "htm", "txt", "rtfd", "md", "markdown", "docx"]
    private static let audioExtensions: Set<String> = ["m4a", "wav", "aac", "aiff", "aif", "mp3", "flac"]
    private static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi"]
    private static let dataExtensions: Set<String> = ["json", "yaml", "yml", "xml", "plist", "csv"]

    // MARK: - Public API

    func categorize(fileURL: URL) -> (category: FileFormatCategory, formats: [OutputFormat]) {
        let ext = fileURL.pathExtension.lowercased()
        let category = categoryForExtension(ext)
        let allFormats = Self.formatMap[ext] ?? []
        // Filter out the same format as input
        let formats = allFormats.filter { $0.fileExtension != ext }
        return (category, formats)
    }

    func categoryForExtension(_ ext: String) -> FileFormatCategory {
        if Self.imageExtensions.contains(ext) { return .image }
        if Self.documentExtensions.contains(ext) { return .document }
        if Self.audioExtensions.contains(ext) { return .audio }
        if Self.videoExtensions.contains(ext) { return .video }
        if Self.dataExtensions.contains(ext) { return .data }
        return .unknown
    }

    func convert(input: URL, outputFormat: OutputFormat, destination: URL, progress: @escaping (Double) -> Void) async throws {
        let ext = input.pathExtension.lowercased()
        let category = categoryForExtension(ext)

        switch category {
        case .image:
            await MainActor.run { progress(0.1) }
            if outputFormat.fileExtension == "pdf" {
                try convertImageToPDF(input: input, destination: destination)
            } else {
                try convertImage(input: input, outputExtension: outputFormat.fileExtension, destination: destination)
            }
            await MainActor.run { progress(1.0) }
        case .document:
            await MainActor.run { progress(0.1) }
            if outputFormat.fileExtension == "pdf" {
                try convertDocumentToPDF(input: input, inputExtension: ext, destination: destination)
            } else {
                try convertDocument(input: input, inputExtension: ext, outputExtension: outputFormat.fileExtension, destination: destination)
            }
            await MainActor.run { progress(1.0) }
        case .audio, .video:
            try await convertMedia(input: input, outputExtension: outputFormat.fileExtension, destination: destination, progress: progress)
        case .data:
            await MainActor.run { progress(0.1) }
            try convertData(input: input, inputExtension: ext, outputExtension: outputFormat.fileExtension, destination: destination)
            await MainActor.run { progress(1.0) }
        case .unknown:
            throw ConversionError.unsupportedFormat(ext)
        }
    }

    // MARK: - Image Conversion

    private func convertImage(input: URL, outputExtension: String, destination: URL) throws {
        guard let image = NSImage(contentsOf: input) else {
            throw ConversionError.readFailed("Could not load image: \(input.lastPathComponent)")
        }

        // HEIC output uses ImageIO
        if outputExtension == "heic" {
            try convertImageToHEIC(image: image, destination: destination)
            return
        }

        guard let tiffData = image.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffData) else {
            throw ConversionError.readFailed("Could not create bitmap representation")
        }

        let fileType: NSBitmapImageRep.FileType
        switch outputExtension {
        case "png": fileType = .png
        case "jpg", "jpeg": fileType = .jpeg
        case "tiff", "tif": fileType = .tiff
        case "bmp": fileType = .bmp
        case "gif": fileType = .gif
        default:
            throw ConversionError.unsupportedFormat(outputExtension)
        }

        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if fileType == .jpeg {
            properties[.compressionFactor] = 0.9
        }

        guard let outputData = imageRep.representation(using: fileType, properties: properties) else {
            throw ConversionError.writeFailed("Could not create \(outputExtension) data")
        }

        try outputData.write(to: destination)
    }

    private func convertImageToHEIC(image: NSImage, destination: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffData),
              let cgImage = imageRep.cgImage else {
            throw ConversionError.readFailed("Could not create CGImage")
        }

        guard let dest = CGImageDestinationCreateWithURL(destination as CFURL, UTType.heic.identifier as CFString, 1, nil) else {
            throw ConversionError.writeFailed("Could not create HEIC destination")
        }

        CGImageDestinationAddImage(dest, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.writeFailed("Could not finalize HEIC output")
        }
    }

    private func convertImageToPDF(input: URL, destination: URL) throws {
        guard let image = NSImage(contentsOf: input) else {
            throw ConversionError.readFailed("Could not load image: \(input.lastPathComponent)")
        }

        let imageSize = image.size
        var mediaBox = CGRect(origin: .zero, size: imageSize)

        guard let context = CGContext(destination as CFURL, mediaBox: &mediaBox, nil) else {
            throw ConversionError.writeFailed("Could not create PDF context")
        }

        context.beginPDFPage(nil)

        guard let tiffData = image.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffData),
              let cgImage = imageRep.cgImage else {
            throw ConversionError.readFailed("Could not create CGImage for PDF")
        }

        context.draw(cgImage, in: mediaBox)
        context.endPDFPage()
        context.closePDF()
    }

    // MARK: - Document Conversion

    private func convertDocument(input: URL, inputExtension: String, outputExtension: String, destination: URL) throws {
        let attributedString = try loadAttributedString(from: input, extension: inputExtension)

        let range = NSRange(location: 0, length: attributedString.length)

        let outputType: NSAttributedString.DocumentType
        switch outputExtension {
        case "txt": outputType = .plain
        case "rtf": outputType = .rtf
        case "html": outputType = .html
        default:
            throw ConversionError.unsupportedFormat(outputExtension)
        }

        let data = try attributedString.data(from: range, documentAttributes: [.documentType: outputType])
        try data.write(to: destination)
    }

    private func convertDocumentToPDF(input: URL, inputExtension: String, destination: URL) throws {
        let attributedString = try loadAttributedString(from: input, extension: inputExtension)

        // Create a temporary text view to render the attributed string
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792)) // US Letter
        textView.textStorage?.setAttributedString(attributedString)
        textView.sizeToFit()

        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 612, height: 792)
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destination

        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false
        printOperation.run()
    }

    private func loadAttributedString(from url: URL, extension ext: String) throws -> NSAttributedString {
        if ext == "md" || ext == "markdown" {
            let markdownText = try String(contentsOf: url, encoding: .utf8)
            if let attrStr = try? NSAttributedString(markdown: markdownText) {
                return attrStr
            }
            // Fallback: treat as plain text
            return NSAttributedString(string: markdownText)
        }

        let docType: NSAttributedString.DocumentType?
        switch ext {
        case "rtf": docType = .rtf
        case "rtfd": docType = .rtfd
        case "html", "htm": docType = .html
        case "txt": docType = .plain
        case "docx", "doc": docType = nil // NSAttributedString auto-detects
        default: docType = nil
        }

        var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [:]
        if let docType = docType {
            options[.documentType] = docType
        }

        return try NSAttributedString(url: url, options: options, documentAttributes: nil)
    }

    // MARK: - Audio/Video Conversion

    private func convertMedia(input: URL, outputExtension: String, destination: URL, progress: @escaping (Double) -> Void) async throws {
        let asset = AVAsset(url: input)

        // PCM formats (WAV, AIFF, CAF) need AVAssetWriter
        let pcmFormats: Set<String> = ["wav", "aiff", "aif", "caf"]
        if pcmFormats.contains(outputExtension) {
            try await convertMediaWithAssetWriter(asset: asset, outputExtension: outputExtension, destination: destination, progress: progress)
            return
        }

        let fileType: AVFileType
        switch outputExtension {
        case "mp4": fileType = .mp4
        case "mov": fileType = .mov
        case "m4v": fileType = .m4v
        case "m4a": fileType = .m4a
        case "aac": fileType = .m4a // AAC wrapped in M4A container
        default:
            throw ConversionError.unsupportedFormat(outputExtension)
        }

        // Choose appropriate preset
        let presetName: String
        let audioOnly = ["m4a", "aac"].contains(outputExtension)
        if audioOnly {
            presetName = AVAssetExportPresetAppleM4A
        } else {
            presetName = AVAssetExportPresetHighestQuality
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
            throw ConversionError.exportFailed("Could not create export session")
        }

        exportSession.outputURL = destination
        exportSession.outputFileType = fileType

        // Start progress polling
        let progressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                await MainActor.run {
                    progress(Double(exportSession.progress))
                }
            }
        }

        await exportSession.export()
        progressTask.cancel()

        switch exportSession.status {
        case .completed:
            await MainActor.run { progress(1.0) }
        case .failed:
            throw ConversionError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown export error")
        case .cancelled:
            throw ConversionError.exportFailed("Export was cancelled")
        default:
            throw ConversionError.exportFailed("Unexpected export status: \(exportSession.status.rawValue)")
        }
    }

    private func convertMediaWithAssetWriter(asset: AVAsset, outputExtension: String, destination: URL, progress: @escaping (Double) -> Void) async throws {
        let fileType: AVFileType
        switch outputExtension {
        case "wav": fileType = .wav
        case "aiff", "aif": fileType = .aiff
        case "caf": fileType = .caf
        default:
            throw ConversionError.unsupportedFormat(outputExtension)
        }

        let writer = try AVAssetWriter(outputURL: destination, fileType: fileType)

        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ConversionError.readFailed("No audio track found")
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        // PCM output settings
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: (outputExtension == "aiff" || outputExtension == "aif"),
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
        ]

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false

        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
        ])

        let reader = try AVAssetReader(asset: asset)
        reader.add(readerOutput)
        writer.add(writerInput)

        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.clippy.audioWriter")) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let currentSeconds = CMTimeGetSeconds(timestamp)
                        let prog = durationSeconds > 0 ? min(currentSeconds / durationSeconds, 1.0) : 0
                        DispatchQueue.main.async { progress(prog) }
                        writerInput.append(sampleBuffer)
                    } else {
                        writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }

        await writer.finishWriting()
        await MainActor.run { progress(1.0) }

        if writer.status == .failed {
            throw ConversionError.exportFailed(writer.error?.localizedDescription ?? "Asset writer failed")
        }
    }

    // MARK: - Data Conversion

    private func convertData(input: URL, inputExtension: String, outputExtension: String, destination: URL) throws {
        let inputData = try Data(contentsOf: input)

        // Parse input
        let object: Any
        switch inputExtension {
        case "json":
            object = try JSONSerialization.jsonObject(with: inputData, options: [.fragmentsAllowed])
        case "yaml", "yml":
            guard let yamlString = String(data: inputData, encoding: .utf8) else {
                throw ConversionError.invalidData("Could not read YAML as UTF-8")
            }
            object = try parseYAML(yamlString)
        case "xml":
            object = try parseXMLToDictionary(data: inputData)
        case "plist":
            object = try PropertyListSerialization.propertyList(from: inputData, options: [], format: nil)
        case "csv":
            object = parseCSVToArray(data: inputData)
        default:
            throw ConversionError.unsupportedFormat(inputExtension)
        }

        // Write output
        let outputData: Data
        switch outputExtension {
        case "json":
            outputData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        case "yaml", "yml":
            let yamlString = objectToYAML(object, indent: 0)
            guard let data = yamlString.data(using: .utf8) else {
                throw ConversionError.writeFailed("Could not encode YAML as UTF-8")
            }
            outputData = data
        case "xml":
            let xmlString = objectToXML(object, rootElement: "root")
            guard let data = xmlString.data(using: .utf8) else {
                throw ConversionError.writeFailed("Could not encode XML as UTF-8")
            }
            outputData = data
        case "plist":
            outputData = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
        case "csv":
            let csvString = objectToCSV(object)
            guard let data = csvString.data(using: .utf8) else {
                throw ConversionError.writeFailed("Could not encode CSV as UTF-8")
            }
            outputData = data
        default:
            throw ConversionError.unsupportedFormat(outputExtension)
        }

        try outputData.write(to: destination)
    }

    // MARK: - XML Parsing

    private func parseXMLToDictionary(data: Data) throws -> [String: Any] {
        let xmlDoc = try XMLDocument(data: data, options: [])
        guard let root = xmlDoc.rootElement() else {
            throw ConversionError.invalidData("No root element in XML")
        }
        return xmlElementToDictionary(root)
    }

    private func xmlElementToDictionary(_ element: XMLElement) -> [String: Any] {
        var dict: [String: Any] = [:]

        // Attributes
        if let attributes = element.attributes {
            for attr in attributes {
                if let name = attr.name, let value = attr.stringValue {
                    dict["@\(name)"] = value
                }
            }
        }

        // Children
        if let children = element.children {
            var childGroups: [String: [Any]] = [:]

            for child in children {
                if let element = child as? XMLElement {
                    let name = element.name ?? "unknown"
                    let childValue: Any
                    if element.children?.count == 1, let textNode = element.children?.first as? XMLNode, textNode.kind == .text {
                        childValue = textNode.stringValue ?? ""
                    } else {
                        childValue = xmlElementToDictionary(element)
                    }
                    childGroups[name, default: []].append(childValue)
                }
            }

            for (key, values) in childGroups {
                dict[key] = values.count == 1 ? values[0] : values
            }
        }

        // Text content (leaf node)
        if dict.isEmpty, let text = element.stringValue, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ["#text": text]
        }

        return dict
    }

    // MARK: - Object to XML

    private func objectToXML(_ object: Any, rootElement: String, indent: Int = 0) -> String {
        let indentStr = String(repeating: "  ", count: indent)
        var xml = ""

        if indent == 0 {
            xml += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        }

        if let dict = object as? [String: Any] {
            xml += "\(indentStr)<\(rootElement)>\n"
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                if let array = value as? [Any] {
                    for item in array {
                        xml += objectToXML(item, rootElement: key, indent: indent + 1)
                    }
                } else {
                    xml += objectToXML(value, rootElement: key, indent: indent + 1)
                }
            }
            xml += "\(indentStr)</\(rootElement)>\n"
        } else if let array = object as? [Any] {
            xml += "\(indentStr)<\(rootElement)>\n"
            for item in array {
                xml += objectToXML(item, rootElement: "item", indent: indent + 1)
            }
            xml += "\(indentStr)</\(rootElement)>\n"
        } else {
            let escaped = String(describing: object)
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            xml += "\(indentStr)<\(rootElement)>\(escaped)</\(rootElement)>\n"
        }

        return xml
    }

    // MARK: - CSV Parsing

    private func parseCSVToArray(data: Data) -> [[String: String]] {
        guard let content = String(data: data, encoding: .utf8) else { return [] }

        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return [] }

        let headers = parseCSVLine(lines[0])
        var result: [[String: String]] = []

        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])
            var row: [String: String] = [:]
            for (j, header) in headers.enumerated() {
                row[header] = j < values.count ? values[j] : ""
            }
            result.append(row)
        }

        return result
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))

        return result
    }

    // MARK: - Object to CSV

    private func objectToCSV(_ object: Any) -> String {
        guard let array = object as? [[String: Any]], let first = array.first else {
            // Single object
            if let dict = object as? [String: Any] {
                let keys = dict.keys.sorted()
                let header = keys.joined(separator: ",")
                let values = keys.map { escapeCSV(String(describing: dict[$0] ?? "")) }.joined(separator: ",")
                return "\(header)\n\(values)"
            }
            return String(describing: object)
        }

        let keys = first.keys.sorted()
        var csv = keys.map { escapeCSV($0) }.joined(separator: ",") + "\n"

        for row in array {
            let values = keys.map { escapeCSV(String(describing: row[$0] ?? "")) }
            csv += values.joined(separator: ",") + "\n"
        }

        return csv
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    // MARK: - YAML Serialization

    private func objectToYAML(_ object: Any, indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)

        if let dict = object as? [String: Any] {
            if dict.isEmpty { return "{}" }
            var lines: [String] = []
            for key in dict.keys.sorted() {
                let value = dict[key]!
                if let arr = value as? [Any] {
                    lines.append("\(prefix)\(yamlKey(key)):")
                    for item in arr {
                        if item is [String: Any] || item is [Any] {
                            let sub = objectToYAML(item, indent: indent + 2)
                            lines.append("\(prefix)  -")
                            lines.append(sub)
                        } else {
                            lines.append("\(prefix)  - \(yamlScalar(item))")
                        }
                    }
                } else if let subDict = value as? [String: Any] {
                    lines.append("\(prefix)\(yamlKey(key)):")
                    lines.append(objectToYAML(subDict, indent: indent + 1))
                } else {
                    lines.append("\(prefix)\(yamlKey(key)): \(yamlScalar(value))")
                }
            }
            return lines.joined(separator: "\n")
        } else if let arr = object as? [Any] {
            if arr.isEmpty { return "[]" }
            var lines: [String] = []
            for item in arr {
                if item is [String: Any] || item is [Any] {
                    let sub = objectToYAML(item, indent: indent + 1)
                    lines.append("\(prefix)-")
                    lines.append(sub)
                } else {
                    lines.append("\(prefix)- \(yamlScalar(item))")
                }
            }
            return lines.joined(separator: "\n")
        } else {
            return "\(prefix)\(yamlScalar(object))"
        }
    }

    private func yamlKey(_ key: String) -> String {
        if key.contains(":") || key.contains("#") || key.contains("'") || key.contains("\"") ||
           key.hasPrefix("- ") || key.hasPrefix("? ") {
            return "'\(key.replacingOccurrences(of: "'", with: "''"))'"
        }
        return key
    }

    private func yamlScalar(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if let b = value as? Bool { return b ? "true" : "false" }
        if let n = value as? NSNumber {
            if CFNumberIsFloatType(n) { return "\(n.doubleValue)" }
            return "\(n.intValue)"
        }
        if let s = value as? String {
            if s.isEmpty { return "''" }
            if s == "true" || s == "false" || s == "null" || s == "~" ||
               s.contains("\n") || s.contains(":") || s.contains("#") ||
               s.hasPrefix("'") || s.hasPrefix("\"") || s.hasPrefix("- ") ||
               s.hasPrefix("? ") || s.hasPrefix("{ ") || s.hasPrefix("[ ") {
                let escaped = s.replacingOccurrences(of: "'", with: "''")
                return "'\(escaped)'"
            }
            if let _ = Double(s), !s.contains(" ") { return "'\(s)'" }
            return s
        }
        return String(describing: value)
    }

    // MARK: - YAML Parsing

    private func parseYAML(_ yaml: String) throws -> Any {
        let lines = yaml.components(separatedBy: "\n")
        var index = 0
        let result = try parseYAMLValue(lines: lines, index: &index, baseIndent: 0)
        return result
    }

    private func parseYAMLValue(lines: [String], index: inout Int, baseIndent: Int) throws -> Any {
        skipEmptyAndComments(lines: lines, index: &index)
        guard index < lines.count else { return [:] as [String: Any] }

        let line = lines[index]
        let indent = lineIndent(line)
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Array item
        if trimmed.hasPrefix("- ") || trimmed == "-" {
            return try parseYAMLArray(lines: lines, index: &index, baseIndent: indent)
        }

        // Key: value (dictionary)
        if trimmed.contains(": ") || trimmed.hasSuffix(":") {
            return try parseYAMLDict(lines: lines, index: &index, baseIndent: indent)
        }

        // Inline flow: {} or []
        if trimmed.hasPrefix("{") { return parseFlowDict(trimmed) }
        if trimmed.hasPrefix("[") { return parseFlowArray(trimmed) }

        // Single scalar
        index += 1
        return parseScalarValue(trimmed)
    }

    private func parseYAMLDict(lines: [String], index: inout Int, baseIndent: Int) throws -> [String: Any] {
        var dict: [String: Any] = [:]

        while index < lines.count {
            skipEmptyAndComments(lines: lines, index: &index)
            guard index < lines.count else { break }

            let line = lines[index]
            let indent = lineIndent(line)
            if indent < baseIndent { break }
            if indent != baseIndent { break }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colonRange = findKeyColonSplit(trimmed) else {
                index += 1
                continue
            }

            let key = unquoteYAML(String(trimmed[trimmed.startIndex..<colonRange.lowerBound]))
            let afterColon = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            if afterColon.isEmpty {
                // Value on next lines
                index += 1
                if index < lines.count {
                    let nextIndent = lineIndent(lines[index])
                    if nextIndent > baseIndent {
                        dict[key] = try parseYAMLValue(lines: lines, index: &index, baseIndent: nextIndent)
                    } else {
                        dict[key] = NSNull()
                    }
                } else {
                    dict[key] = NSNull()
                }
            } else {
                index += 1
                if afterColon.hasPrefix("{") {
                    dict[key] = parseFlowDict(afterColon)
                } else if afterColon.hasPrefix("[") {
                    dict[key] = parseFlowArray(afterColon)
                } else {
                    dict[key] = parseScalarValue(afterColon)
                }
            }
        }
        return dict
    }

    private func parseYAMLArray(lines: [String], index: inout Int, baseIndent: Int) throws -> [Any] {
        var arr: [Any] = []

        while index < lines.count {
            skipEmptyAndComments(lines: lines, index: &index)
            guard index < lines.count else { break }

            let line = lines[index]
            let indent = lineIndent(line)
            if indent < baseIndent { break }
            if indent != baseIndent { break }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") || trimmed == "-" else { break }

            let afterDash = trimmed == "-" ? "" : String(trimmed.dropFirst(2))

            if afterDash.isEmpty {
                index += 1
                if index < lines.count {
                    let nextIndent = lineIndent(lines[index])
                    if nextIndent > baseIndent {
                        arr.append(try parseYAMLValue(lines: lines, index: &index, baseIndent: nextIndent))
                    } else {
                        arr.append(NSNull())
                    }
                }
            } else if afterDash.contains(": ") || afterDash.hasSuffix(":") {
                // Inline dict start after dash
                let subLine = String(repeating: " ", count: baseIndent + 2) + afterDash
                var tempLines = [subLine]
                index += 1
                while index < lines.count {
                    let nextLine = lines[index]
                    let nextIndent = lineIndent(nextLine)
                    if nextIndent <= baseIndent { break }
                    tempLines.append(nextLine)
                    index += 1
                }
                var tempIndex = 0
                let subDict = try parseYAMLDict(lines: tempLines, index: &tempIndex, baseIndent: baseIndent + 2)
                arr.append(subDict)
            } else {
                index += 1
                if afterDash.hasPrefix("{") {
                    arr.append(parseFlowDict(afterDash))
                } else if afterDash.hasPrefix("[") {
                    arr.append(parseFlowArray(afterDash))
                } else {
                    arr.append(parseScalarValue(afterDash))
                }
            }
        }
        return arr
    }

    private func skipEmptyAndComments(lines: [String], index: inout Int) {
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "---" || trimmed == "..." {
                index += 1
            } else {
                break
            }
        }
    }

    private func lineIndent(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " { count += 1 }
            else { break }
        }
        return count
    }

    private func findKeyColonSplit(_ s: String) -> Range<String.Index>? {
        if s.hasPrefix("'") || s.hasPrefix("\"") {
            let quote = s.first!
            if let endIdx = s.dropFirst().firstIndex(of: quote) {
                let afterQuote = s.index(after: endIdx)
                if afterQuote < s.endIndex, s[afterQuote] == ":" {
                    let colonEnd = s.index(after: afterQuote)
                    return afterQuote..<colonEnd
                }
            }
            return nil
        }
        if let range = s.range(of: ": ") { return range }
        if s.hasSuffix(":") {
            let idx = s.index(before: s.endIndex)
            return idx..<s.endIndex
        }
        return nil
    }

    private func unquoteYAML(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
           (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private func parseScalarValue(_ s: String) -> Any {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed == "null" || trimmed == "~" || trimmed.isEmpty { return NSNull() }
        if trimmed == "true" || trimmed == "True" || trimmed == "TRUE" { return true }
        if trimmed == "false" || trimmed == "False" || trimmed == "FALSE" { return false }

        // Unquote
        if (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
           (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) {
            return String(trimmed.dropFirst().dropLast())
        }

        if let intVal = Int(trimmed) { return intVal }
        if let doubleVal = Double(trimmed) { return doubleVal }
        return trimmed
    }

    private func parseFlowDict(_ s: String) -> [String: Any] {
        var str = s.trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("{") { str = String(str.dropFirst()) }
        if str.hasSuffix("}") { str = String(str.dropLast()) }

        var dict: [String: Any] = [:]
        let pairs = str.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: ":")
            if parts.count >= 2 {
                let key = unquoteYAML(parts[0])
                let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    dict[key] = parseScalarValue(value)
                }
            }
        }
        return dict
    }

    private func parseFlowArray(_ s: String) -> [Any] {
        var str = s.trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("[") { str = String(str.dropFirst()) }
        if str.hasSuffix("]") { str = String(str.dropLast()) }

        return str.components(separatedBy: ",").map { parseScalarValue($0) }
    }
}
