import Foundation
import CoreData

class SnippetExportManager {
    static let shared = SnippetExportManager()
    private let viewContext = PersistenceController.shared.container.viewContext

    // Cached encoder for performance - reused across all export operations
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // Cached decoder for performance - reused across all import operations
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    struct ExportableSnippet: Codable {
        let keyword: String
        let content: String
        let category: String?
        let applicationRules: String?
    }

    struct SnippetExport: Codable {
        let version: String
        let exportDate: Date
        let snippets: [ExportableSnippet]

        init(exportDate: Date, snippets: [ExportableSnippet]) {
            self.version = "1.0"
            self.exportDate = exportDate
            self.snippets = snippets
        }
    }

    func exportSnippet(item: ClipboardItemEntity, to url: URL) throws {
        guard let keyword = item.keyword, let content = item.content else {
            throw NSError(domain: "SnippetExportManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid snippet: missing keyword or content"])
        }

        let exportableSnippet = ExportableSnippet(
            keyword: keyword,
            content: content,
            category: item.category,
            applicationRules: item.applicationRules
        )

        let export = SnippetExport(exportDate: Date(), snippets: [exportableSnippet])
        let data = try jsonEncoder.encode(export)
        try data.write(to: url)
    }

    func exportSnippets(to url: URL) throws {
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "keyword != nil AND keyword != ''")
        // Only fetch required properties for performance
        fetchRequest.propertiesToFetch = ["keyword", "content", "category", "applicationRules"]

        let items = try viewContext.fetch(fetchRequest)
        let exportableSnippets = items.compactMap { item -> ExportableSnippet? in
            guard let keyword = item.keyword, let content = item.content else { return nil }
            return ExportableSnippet(
                keyword: keyword,
                content: content,
                category: item.category,
                applicationRules: item.applicationRules
            )
        }

        let export = SnippetExport(exportDate: Date(), snippets: exportableSnippets)
        let data = try jsonEncoder.encode(export)
        try data.write(to: url)
    }

    func importSnippets(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let export = try jsonDecoder.decode(SnippetExport.self, from: data)

        var importedCount = 0

        // Batch fetch existing keywords for better performance
        let existingKeywords = Set(export.snippets.map { $0.keyword })
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "keyword IN %@", existingKeywords)
        fetchRequest.propertiesToFetch = ["keyword"]

        let existingItems = try viewContext.fetch(fetchRequest)
        let existingKeywordsSet = Set(existingItems.compactMap { $0.keyword })

        for snippet in export.snippets {
            if !existingKeywordsSet.contains(snippet.keyword) {
                let newItem = ClipboardItemEntity(context: viewContext)
                newItem.id = UUID()
                newItem.keyword = snippet.keyword
                newItem.content = snippet.content
                newItem.category = snippet.category
                newItem.applicationRules = snippet.applicationRules
                newItem.date = Date()
                newItem.contentType = "text"
                newItem.isFavorite = false
                newItem.isCode = false
                newItem.isPinned = false
                newItem.isEncrypted = false
                newItem.usageCount = 0
                importedCount += 1
            }
        }

        if importedCount > 0 {
            try viewContext.save()
            NotificationCenter.default.post(name: .keywordsDidChange, object: nil)
        }

        return importedCount
    }

    func exportSnippetsAsJSON() -> String? {
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "keyword != nil AND keyword != ''")
        fetchRequest.propertiesToFetch = ["keyword", "content", "category", "applicationRules"]

        guard let items = try? viewContext.fetch(fetchRequest) else { return nil }
        let exportableSnippets = items.compactMap { item -> ExportableSnippet? in
            guard let keyword = item.keyword, let content = item.content else { return nil }
            return ExportableSnippet(
                keyword: keyword,
                content: content,
                category: item.category,
                applicationRules: item.applicationRules
            )
        }

        let export = SnippetExport(exportDate: Date(), snippets: exportableSnippets)

        guard let data = try? jsonEncoder.encode(export),
              let jsonString = String(data: data, encoding: .utf8) else { return nil }
        return jsonString
    }

    func importSnippetsFromJSON(_ jsonString: String) throws -> Int {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "SnippetExportManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }

        let export = try jsonDecoder.decode(SnippetExport.self, from: data)

        var importedCount = 0

        // Batch fetch existing keywords for better performance
        let existingKeywords = Set(export.snippets.map { $0.keyword })
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "keyword IN %@", existingKeywords)
        fetchRequest.propertiesToFetch = ["keyword"]

        let existingItems = try viewContext.fetch(fetchRequest)
        let existingKeywordsSet = Set(existingItems.compactMap { $0.keyword })

        for snippet in export.snippets {
            if !existingKeywordsSet.contains(snippet.keyword) {
                let newItem = ClipboardItemEntity(context: viewContext)
                newItem.id = UUID()
                newItem.keyword = snippet.keyword
                newItem.content = snippet.content
                newItem.category = snippet.category
                newItem.applicationRules = snippet.applicationRules
                newItem.date = Date()
                newItem.contentType = "text"
                newItem.isFavorite = false
                newItem.isCode = false
                newItem.isPinned = false
                newItem.isEncrypted = false
                newItem.usageCount = 0
                importedCount += 1
            }
        }

        if importedCount > 0 {
            try viewContext.save()
            NotificationCenter.default.post(name: .keywordsDidChange, object: nil)
        }

        return importedCount
    }
}
