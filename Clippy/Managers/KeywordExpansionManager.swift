//
//  KeywordExpansionManager.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 29.09.2025.
//


import AppKit
import Combine
import CoreData

class KeywordExpansionManager {
    private var eventMonitor: Any?
    private var currentBuffer = ""
    private var bufferResetTimer: Timer?
    private let triggerCharacter: Character = ";"
    private var isBuffering = false
    weak var appDelegate: AppDelegate?
    private(set) var isEnabled = false
    private var cancellable: AnyCancellable?

    private var keywordCache: [String: String] = [:]
    private var contextualRulesCache: [String: [String]] = [:]
    private var categoriesCache: [String: String] = [:]
    private let viewContext = PersistenceController.shared.container.viewContext

    // Cached formatters for performance
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    // Cached regex patterns for performance
    private static let parameterRegex = try! NSRegularExpression(pattern: "\\{([^{}]+)\\}")
    private static let nestedSnippetRegex = try! NSRegularExpression(pattern: #"\{\{;([a-zA-Z0-9_-]+)\}\}"#)
    private static let randomPlaceholderRegex = try! NSRegularExpression(pattern: #"\{\{RANDOM:(\d+)-(\d+)\}\}"#)
    private static let filePlaceholderRegex = try! NSRegularExpression(pattern: #"\{\{FILE:([^}]+)\}\}"#)
    private static let shellPlaceholderRegex = try! NSRegularExpression(pattern: #"\{\{SHELL:([^}]+)\}\}"#)

    init() {
        cancellable = SettingsManager.shared.$isKeywordExpansionEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldBeEnabled in
                guard let self = self, shouldBeEnabled != self.isEnabled else { return }
                if shouldBeEnabled {
                    self.startMonitoring()
                } else {
                    self.stopMonitoring()
                }
            }
    }
    func startMonitoring() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        reloadCache()

        NotificationCenter.default.addObserver(self, selector: #selector(handleKeywordsChanged), name: .keywordsDidChange, object: nil)
        isEnabled = true

    }

    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            NotificationCenter.default.removeObserver(self, name: .keywordsDidChange, object: nil)
        }
        bufferResetTimer?.invalidate()
        bufferResetTimer = nil
        isEnabled = false
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return }

        let typedChar = characters.first!

        if event.keyCode == 51 {
            if isBuffering && !currentBuffer.isEmpty {
                if currentBuffer.count == 1 {
                    resetBuffer()
                } else {
                    currentBuffer.removeLast()
                    resetTimer()
                }
            }
            return
        }

        if event.keyCode == 53 {
            if isBuffering {
                resetBuffer()
            }
            return
        }

        if typedChar == triggerCharacter {
            isBuffering = true
            currentBuffer = String(triggerCharacter)
            resetTimer()
            return
        }

        guard isBuffering else { return }

        guard !typedChar.isWhitespace && !typedChar.isNewline else {
            resetBuffer()
            return
        }
        currentBuffer.append(typedChar)
        checkBufferForKeyword()
        resetTimer()
    }

    private func checkBufferForKeyword() {
        let keywordToFind = currentBuffer

        guard let rawContent = keywordCache[keywordToFind] else { return }

        if let allowedApps = contextualRulesCache[keywordToFind], !allowedApps.isEmpty {
            guard let frontmostAppId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                  allowedApps.contains(frontmostAppId) else {
                return
            }
        }

        updateSnippetStatistics(for: keywordToFind)
        processAndPasteContent(rawContent, keywordLength: keywordToFind.count)
    }

    private func updateSnippetStatistics(for keyword: String) {
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "keyword == %@", keyword)
        fetchRequest.fetchLimit = 1  // We only need one result
        fetchRequest.propertiesToFetch = ["usageCount", "lastUsedDate"]

        do {
            if let item = try viewContext.fetch(fetchRequest).first {
                item.usageCount += 1
                item.lastUsedDate = Date()
                try viewContext.save()
            }
        } catch {
            print("❌ Snippet istatistiklerini güncelleme hatası: \(error)")
        }
    }

    private func processAndPasteContent(_ content: String, keywordLength: Int) {
        let processedContent = processDynamicPlaceholders(in: content)

        let parameters = findParameters(in: processedContent)
        if !parameters.isEmpty {
            let targetApp = NSWorkspace.shared.frontmostApplication

            PasteManager.shared.deleteBackward(times: keywordLength) {
                DispatchQueue.main.async {
                    self.appDelegate?.showParameterInputDialog(parameters: parameters, snippetTemplate: processedContent) { [weak self] filledValues in
                        guard let self = self, let values = filledValues else {
                            self?.resetBuffer()
                            return
                        }

                        var finalContent = processedContent
                        for (key, value) in values {
                            finalContent = finalContent.replacingOccurrences(of: "{\(key)}", with: value)
                        }

                        PasteManager.shared.pasteText(finalContent, into: targetApp)
                        self.resetBuffer()
                    }
                }
            }
        } else {
            replaceKeywordWith(content: processedContent, keywordLength: keywordLength)
            resetBuffer()
        }
    }

    private func processDynamicPlaceholders(in content: String) -> String {
        var processedContent = content
        var recursionDepth = 0
        let maxRecursionDepth = 5

        // Early exit if no placeholders detected
        guard processedContent.contains("{{") else { return processedContent }

        let currentDate = Date() // Cache date for all formatters

        while recursionDepth < maxRecursionDepth {
            let beforeProcessing = processedContent

            // Only process if placeholder exists (lazy evaluation)
            if processedContent.contains("{{DATE}}") {
                processedContent = processedContent.replacingOccurrences(of: "{{DATE}}", with: dateFormatter.string(from: currentDate))
            }

            if processedContent.contains("{{TIME}}") {
                processedContent = processedContent.replacingOccurrences(of: "{{TIME}}", with: timeFormatter.string(from: currentDate))
            }

            if processedContent.contains("{{DATETIME}}") {
                processedContent = processedContent.replacingOccurrences(of: "{{DATETIME}}", with: dateTimeFormatter.string(from: currentDate))
            }

            if processedContent.contains("{{UUID}}") {
                processedContent = processedContent.replacingOccurrences(of: "{{UUID}}", with: UUID().uuidString)
            }

            if processedContent.contains("{{CLIPBOARD}}") {
                // Get latest item from Clippy's database instead of system pasteboard
                let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "contentType == %@", "text")
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)]
                fetchRequest.fetchLimit = 1
                fetchRequest.propertiesToFetch = ["content"]

                if let latestItem = try? viewContext.fetch(fetchRequest).first,
                   let content = latestItem.content {
                    processedContent = processedContent.replacingOccurrences(of: "{{CLIPBOARD}}", with: content)
                } else {
                    // Fallback to system pasteboard if no items in database
                    let pasteboard = NSPasteboard.general
                    let clipboardContent = pasteboard.string(forType: .string) ?? ""
                    processedContent = processedContent.replacingOccurrences(of: "{{CLIPBOARD}}", with: clipboardContent)
                }
            }

            if processedContent.contains("{{RANDOM:") {
                processedContent = processRandomPlaceholders(in: processedContent)
            }
            if processedContent.contains("{{FILE:") {
                processedContent = processFilePlaceholders(in: processedContent)
            }
            if processedContent.contains("{{SHELL:") {
                processedContent = processShellPlaceholders(in: processedContent)
            }
            if processedContent.contains("{{;") {
                processedContent = processNestedSnippets(in: processedContent)
            }

            // Process snippet variables
            for variable in SettingsManager.shared.snippetVariables {
                let placeholder = variable.placeholder
                if processedContent.contains(placeholder) {
                    processedContent = processedContent.replacingOccurrences(of: placeholder, with: variable.value)
                }
            }

            if beforeProcessing == processedContent {
                break
            }

            recursionDepth += 1
        }

        return processedContent
    }

    private func processNestedSnippets(in content: String) -> String {
        var result = content
        let matches = Self.nestedSnippetRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let fullRange = Range(match.range, in: content),
                  let keywordRange = Range(match.range(at: 1), in: content) else { continue }

            let nestedKeyword = ";\(content[keywordRange])"
            if let nestedContent = keywordCache[nestedKeyword] {
                result.replaceSubrange(fullRange, with: nestedContent)
            }
        }
        return result
    }

    private func processRandomPlaceholders(in content: String) -> String {
        var result = content
        let matches = Self.randomPlaceholderRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        for match in matches.reversed() {
            guard match.numberOfRanges == 3,
                  let fullRange = Range(match.range, in: content),
                  let minRange = Range(match.range(at: 1), in: content),
                  let maxRange = Range(match.range(at: 2), in: content),
                  let min = Int(content[minRange]),
                  let max = Int(content[maxRange]),
                  min <= max else { continue }

            let randomValue = Int.random(in: min...max)
            result.replaceSubrange(fullRange, with: String(randomValue))
        }
        return result
    }

    private func processFilePlaceholders(in content: String) -> String {
        var result = content
        let matches = Self.filePlaceholderRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let fullRange = Range(match.range, in: content),
                  let pathRange = Range(match.range(at: 1), in: content) else { continue }

            let filePath = String(content[pathRange]).trimmingCharacters(in: .whitespaces)
            let expandedPath = NSString(string: filePath).expandingTildeInPath

            if let fileContent = try? String(contentsOfFile: expandedPath, encoding: .utf8) {
                result.replaceSubrange(fullRange, with: fileContent)
            } else {
                result.replaceSubrange(fullRange, with: "")
            }
        }
        return result
    }

    private func processShellPlaceholders(in content: String) -> String {
        var result = content
        let matches = Self.shellPlaceholderRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let fullRange = Range(match.range, in: content),
                  let commandRange = Range(match.range(at: 1), in: content) else { continue }

            let command = String(content[commandRange]).trimmingCharacters(in: .whitespaces)
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", command]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    result.replaceSubrange(fullRange, with: output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    result.replaceSubrange(fullRange, with: "")
                }
            } catch {
                result.replaceSubrange(fullRange, with: "")
            }
        }
        return result
    }

    private func findParameters(in content: String) -> [String] {
        let results = Self.parameterRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        let parameters = results.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range]).trimmingCharacters(in: .whitespaces)
        }
        var seen = Set<String>()
        return parameters.filter { parameter in
            if seen.contains(parameter) {
                return false
            } else {
                seen.insert(parameter)
                return true
            }
        }
    }

    private func replaceKeywordWith(content: String, keywordLength: Int) {
        PasteManager.shared.deleteBackward(times: keywordLength) {
            PasteManager.shared.pasteText(content)
        }
    }

    private func resetTimer() {
        bufferResetTimer?.invalidate()
        bufferResetTimer = Timer.scheduledTimer(withTimeInterval: SettingsManager.shared.snippetTimeoutDuration, repeats: false) { [weak self] _ in
            self?.resetBuffer()
        }
    }

    private func resetBuffer() {
        isBuffering = false
        currentBuffer = ""
        bufferResetTimer?.invalidate()
    }

    @objc private func handleKeywordsChanged() {
        print("🔄 Anahtar kelimeler değişti, önbellek yeniden yükleniyor...")
        reloadCache()
    }

    private func reloadCache() {
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "keyword != nil AND keyword != ''")
        // Only fetch the properties we need for better performance
        fetchRequest.propertiesToFetch = ["keyword", "content", "category", "applicationRules"]

        do {
            let results = try viewContext.fetch(fetchRequest)

            // Pre-allocate dictionaries with estimated capacity for better performance
            var newCache: [String: String] = Dictionary(minimumCapacity: results.count)
            var newRulesCache: [String: [String]] = Dictionary(minimumCapacity: results.count / 4)  // Estimate ~25% have rules
            var newCategoriesCache: [String: String] = Dictionary(minimumCapacity: results.count / 2)  // Estimate ~50% have categories

            for item in results {
                if let keyword = item.keyword, !keyword.isEmpty, let content = item.content {
                    newCache[keyword] = content

                    if let rules = item.applicationRules, !rules.isEmpty {
                        let appIdentifiers = rules.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                        newRulesCache[keyword] = appIdentifiers
                    }

                    if let category = item.category, !category.isEmpty {
                        newCategoriesCache[keyword] = category
                    }
                }
            }
            self.keywordCache = newCache
            self.contextualRulesCache = newRulesCache
            self.categoriesCache = newCategoriesCache
            print("✅ Anahtar kelime önbelleği yeniden yüklendi. Toplam \(keywordCache.count) öğe.")
        } catch {
            print("❌ Anahtar kelime önbelleğini yükleme hatası: \(error)")
        }
    }

    func getSnippetsByCategory(_ category: String) -> [String] {
        return categoriesCache.filter { $0.value == category }.map { $0.key }
    }

    func getAllCategories() -> [String] {
        return Array(Set(categoriesCache.values)).sorted()
    }
}
