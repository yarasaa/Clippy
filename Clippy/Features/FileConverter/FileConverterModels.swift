//
//  FileConverterModels.swift
//  Clippy
//

import Foundation
import UniformTypeIdentifiers

// MARK: - File Format Category

enum FileFormatCategory: String, CaseIterable {
    case image
    case document
    case audio
    case video
    case data
    case unknown

    var icon: String {
        switch self {
        case .image: return "photo"
        case .document: return "doc.text"
        case .audio: return "waveform"
        case .video: return "film"
        case .data: return "doc.badge.gearshape"
        case .unknown: return "questionmark.circle"
        }
    }

    var displayName: String {
        switch self {
        case .image: return "Image"
        case .document: return "Document"
        case .audio: return "Audio"
        case .video: return "Video"
        case .data: return "Data"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Output Format

struct OutputFormat: Identifiable, Hashable {
    let id: String
    let displayName: String
    let fileExtension: String
    let category: FileFormatCategory

    init(displayName: String, fileExtension: String, category: FileFormatCategory) {
        self.id = fileExtension
        self.displayName = displayName
        self.fileExtension = fileExtension
        self.category = category
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: OutputFormat, rhs: OutputFormat) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Predefined Output Formats

extension OutputFormat {
    // Image
    static let png = OutputFormat(displayName: "PNG", fileExtension: "png", category: .image)
    static let jpeg = OutputFormat(displayName: "JPEG", fileExtension: "jpg", category: .image)
    static let tiff = OutputFormat(displayName: "TIFF", fileExtension: "tiff", category: .image)
    static let bmp = OutputFormat(displayName: "BMP", fileExtension: "bmp", category: .image)
    static let gif = OutputFormat(displayName: "GIF", fileExtension: "gif", category: .image)
    static let heic = OutputFormat(displayName: "HEIC", fileExtension: "heic", category: .image)
    static let pdf = OutputFormat(displayName: "PDF", fileExtension: "pdf", category: .document)

    // Document
    static let txt = OutputFormat(displayName: "TXT", fileExtension: "txt", category: .document)
    static let rtf = OutputFormat(displayName: "RTF", fileExtension: "rtf", category: .document)
    static let html = OutputFormat(displayName: "HTML", fileExtension: "html", category: .document)

    // Image (additional)
    static let webp = OutputFormat(displayName: "WEBP", fileExtension: "webp", category: .image)

    // Document (additional)
    static let docx = OutputFormat(displayName: "DOCX", fileExtension: "docx", category: .document)

    // Audio/Video
    static let mp4 = OutputFormat(displayName: "MP4", fileExtension: "mp4", category: .video)
    static let mov = OutputFormat(displayName: "MOV", fileExtension: "mov", category: .video)
    static let m4v = OutputFormat(displayName: "M4V", fileExtension: "m4v", category: .video)
    static let m4a = OutputFormat(displayName: "M4A", fileExtension: "m4a", category: .audio)
    static let wav = OutputFormat(displayName: "WAV", fileExtension: "wav", category: .audio)
    static let caf = OutputFormat(displayName: "CAF", fileExtension: "caf", category: .audio)
    static let aac = OutputFormat(displayName: "AAC", fileExtension: "aac", category: .audio)
    static let aiff = OutputFormat(displayName: "AIFF", fileExtension: "aiff", category: .audio)
    static let mp3 = OutputFormat(displayName: "MP3", fileExtension: "mp3", category: .audio)
    static let flac = OutputFormat(displayName: "FLAC", fileExtension: "flac", category: .audio)

    // Data
    static let json = OutputFormat(displayName: "JSON", fileExtension: "json", category: .data)
    static let yaml = OutputFormat(displayName: "YAML", fileExtension: "yaml", category: .data)
    static let xml = OutputFormat(displayName: "XML", fileExtension: "xml", category: .data)
    static let csv = OutputFormat(displayName: "CSV", fileExtension: "csv", category: .data)
    static let plist = OutputFormat(displayName: "PLIST", fileExtension: "plist", category: .data)
}

// MARK: - Conversion State

enum ConversionState: Equatable {
    case pending
    case converting
    case completed
    case failed(String)

    static func == (lhs: ConversionState, rhs: ConversionState) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending), (.converting, .converting), (.completed, .completed):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Convertible File

struct ConvertibleFile: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let fileExtension: String
    let category: FileFormatCategory
    let availableOutputFormats: [OutputFormat]
    var selectedOutputFormat: OutputFormat?
    var conversionState: ConversionState = .pending
    var conversionProgress: Double = 0.0
    var customOutputName: String // base name without extension

    var outputBaseName: String {
        customOutputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? url.deletingPathExtension().lastPathComponent
            : customOutputName
    }
}
