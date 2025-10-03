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
    private(set) var isEnabled = false
    
    private var keywordCache: [String: String] = [:]
    private let viewContext = PersistenceController.shared.container.viewContext

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
        if isEnabled {
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
        if let contentToPaste = keywordCache[keywordToFind] {
            print("✅ Anahtar kelime önbellekte bulundu: '\(keywordToFind)'. İçerik yapıştırılıyor.")
            replaceKeywordWith(content: contentToPaste, keywordLength: keywordToFind.count)
            resetBuffer()
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
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "keyword != nil AND keyword != ''")

        do {
            let results = try viewContext.fetch(fetchRequest)
            for item in results {
                if let keyword = item.keyword, let content = item.content {
                    newCache[keyword] = content
                }
            }
            self.keywordCache = newCache
            print("✅ Anahtar kelime önbelleği yeniden yüklendi. Toplam \(keywordCache.count) öğe.")
        } catch {
            print("❌ Anahtar kelime önbelleğini yükleme hatası: \(error)")
        }
    }
}