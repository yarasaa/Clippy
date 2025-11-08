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
    private let viewContext = PersistenceController.shared.container.viewContext

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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

        processAndPasteContent(rawContent, keywordLength: keywordToFind.count)
    }

    private func processAndPasteContent(_ content: String, keywordLength: Int) {
        let processedContent = processDynamicPlaceholders(in: content)

        let parameters = findParameters(in: processedContent)
        if !parameters.isEmpty {
            let targetApp = NSWorkspace.shared.frontmostApplication

            PasteManager.shared.deleteBackward(times: keywordLength) {
                DispatchQueue.main.async {
                    self.appDelegate?.showParameterInputDialog(parameters: parameters) { [weak self] filledValues in
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

        if content.contains("{{DATE}}") {
            processedContent = processedContent.replacingOccurrences(of: "{{DATE}}", with: dateFormatter.string(from: Date()))
        }

        if content.contains("{{TIME}}") {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            processedContent = processedContent.replacingOccurrences(of: "{{TIME}}", with: timeFormatter.string(from: Date()))
        }

        if content.contains("{{DATETIME}}") {
            let dateTimeFormatter = DateFormatter()
            dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            processedContent = processedContent.replacingOccurrences(of: "{{DATETIME}}", with: dateTimeFormatter.string(from: Date()))
        }

        if content.contains("{{UUID}}") {
            processedContent = processedContent.replacingOccurrences(of: "{{UUID}}", with: UUID().uuidString)
        }

        if content.contains("{{CLIPBOARD}}") {
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string) ?? ""
            processedContent = processedContent.replacingOccurrences(of: "{{CLIPBOARD}}", with: clipboardContent) 
        }
        return processedContent
    }

    private func findParameters(in content: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: "\\{([^{}]+)\\}")
            let results = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            return results.map {
                String(content[Range($0.range(at: 1), in: content)!]).trimmingCharacters(in: .whitespaces)
            }
        } catch {
            print("❌ Parametre bulma regex hatası: \(error)")
            return []
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
        var newCache: [String: String] = [:]
        var newRulesCache: [String: [String]] = [:]

        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "keyword != nil AND keyword != ''")

        do {
            let results = try viewContext.fetch(fetchRequest)
            for item in results {
                if let keyword = item.keyword, !keyword.isEmpty, let content = item.content {
                    newCache[keyword] = content

                    if let rules = item.applicationRules, !rules.isEmpty {
                        let appIdentifiers = rules.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                        newRulesCache[keyword] = appIdentifiers
                    }
                }
            }
            self.keywordCache = newCache
            self.contextualRulesCache = newRulesCache
            print("✅ Anahtar kelime önbelleği yeniden yüklendi. Toplam \(keywordCache.count) öğe.")
        } catch {
            print("❌ Anahtar kelime önbelleğini yükleme hatası: \(error)")
        }
    }
}
