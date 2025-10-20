//
//  KeywordExpansionManager.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 29.09.2025.
//

import AppKit
import CoreData

class KeywordExpansionManager {
    private var eventMonitor: Any?
    private var currentBuffer = ""
    private var bufferResetTimer: Timer?
    private let triggerCharacter: Character = ";"
    private var isBuffering = false
    weak var appDelegate: AppDelegate?
    private(set) var isEnabled = false
    
    private var keywordCache: [String: String] = [:]
    private var contextualRulesCache: [String: [String]] = [:]
    private let viewContext = PersistenceController.shared.container.viewContext

    // Dinamik içerik için formatlayıcı
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func startMonitoring() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        reloadCache()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeywordsChanged), name: .keywordsDidChange, object: nil)
        isEnabled = true

        print("✅ Anahtar Kelime Yöneticisi başlatıldı.")
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
        print("🛑 Anahtar Kelime Yöneticisi durduruldu.")
    }

    func toggleMonitoring() {
        let shouldBeEnabled = SettingsManager.shared.isKeywordExpansionEnabled
        
        // Eğer durum zaten doğruysa bir şey yapma
        guard shouldBeEnabled != isEnabled else { return }
        if shouldBeEnabled {
            stopMonitoring()
        } else {
            startMonitoring()
        }
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

        if typedChar.isWhitespace || typedChar.isNewline {
            checkBufferForKeyword()
            resetBuffer()
            return
        }

        currentBuffer.append(typedChar)
        resetTimer()
        
        checkBufferForKeyword()
    }

    private func checkBufferForKeyword() {
        let keywordToFind = currentBuffer
        
        // 1. Anahtar kelime önbellekte var mı?
        guard let rawContent = keywordCache[keywordToFind] else { return }
        
        // 2. Bağlamsal Kural Kontrolü
        if let allowedApps = contextualRulesCache[keywordToFind], !allowedApps.isEmpty {
            guard let frontmostAppId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, // Mevcut aktif uygulamanın kimliğini al
                  allowedApps.contains(frontmostAppId) else {
                print("⚠️ Anahtar kelime '\(keywordToFind)' bu uygulama için aktif değil.")
                return
            }
        }
        
        // 3. İçerik İşleme (Dinamik ve Parametreli)
        processAndPasteContent(rawContent, keywordLength: keywordToFind.count)
    }
    
    private func processAndPasteContent(_ content: String, keywordLength: Int) {
        // Dinamik içerik işleme (örn: {{DATE}})
        let processedContent = processDynamicPlaceholders(in: content)

        // Parametreli genişletme kontrolü (örn: {parametre})
        let parameters = findParameters(in: processedContent)
        if !parameters.isEmpty {
            // Diyalog penceresi açılmadan ÖNCE aktif olan uygulamayı sakla.
            let targetApp = NSWorkspace.shared.frontmostApplication
            
            print("✨ Parametreli genişletme algılandı: \(parameters)")
            
            // Silme işlemini yapıp diyalog penceresini göster
            PasteManager.shared.deleteBackward(times: keywordLength) {
                DispatchQueue.main.async {
                    self.appDelegate?.showParameterInputDialog(parameters: parameters) { [weak self] filledValues in
                        guard let self = self, let values = filledValues else { // Kullanıcı iptal ettiğinde veya self nil olduğunda.
                            self?.resetBuffer()
                            return
                        }
                        
                        var finalContent = processedContent
                        // Değerleri yer tutucularla değiştir
                        for (key, value) in values {
                            finalContent = finalContent.replacingOccurrences(of: "{\(key)}", with: value)
                        }
                        
                        // Son metni yapıştır
                        PasteManager.shared.pasteText(finalContent, into: targetApp)
                        self.resetBuffer()
                    }
                }
            }
        } else {
            // Parametre yoksa, doğrudan yapıştır
            print("✅ Anahtar kelime '\(currentBuffer)' bulundu. İçerik yapıştırılıyor.")
            replaceKeywordWith(content: processedContent, keywordLength: keywordLength)
            resetBuffer()
        }
    }
    
    /// Dinamik yer tutucuları gerçek verilerle değiştirir.
    private func processDynamicPlaceholders(in content: String) -> String {
        var processedContent = content
        
        // {{DATE}} -> 2025-10-04
        if content.contains("{{DATE}}") {
            processedContent = processedContent.replacingOccurrences(of: "{{DATE}}", with: dateFormatter.string(from: Date()))
        }
        
        // {{TIME}} -> 15:30:25
        if content.contains("{{TIME}}") {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            processedContent = processedContent.replacingOccurrences(of: "{{TIME}}", with: timeFormatter.string(from: Date()))
        }
        
        // {{DATETIME}} -> 2025-10-04 15:30
        if content.contains("{{DATETIME}}") {
            let dateTimeFormatter = DateFormatter()
            dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            processedContent = processedContent.replacingOccurrences(of: "{{DATETIME}}", with: dateTimeFormatter.string(from: Date()))
        }
        
        // {{UUID}} -> Yeni bir UUID
        if content.contains("{{UUID}}") {
            processedContent = processedContent.replacingOccurrences(of: "{{UUID}}", with: UUID().uuidString)
        }
        
        // {{CLIPBOARD}} -> Panodaki mevcut metin
        if content.contains("{{CLIPBOARD}}") {
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string) ?? ""
            processedContent = processedContent.replacingOccurrences(of: "{{CLIPBOARD}}", with: clipboardContent) 
        }
        return processedContent
    }

    /// İçerikteki {parametre} formatındaki yer tutucuları bulur.
    private func findParameters(in content: String) -> [String] {
        do {
            // Regex'i güncelleyerek sadece basit alfanümerik parametreleri ({param_name}) yakalamasını sağla.
            let regex = try NSRegularExpression(pattern: "\\{([a-zA-Z0-9_]+)\\}")
            let results = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            return results.map {
                String(content[Range($0.range(at: 1), in: content)!])
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
        bufferResetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
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