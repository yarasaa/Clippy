//
//  AIService.swift
//  Clippy
//

import Foundation

enum AIError: LocalizedError {
    case notConfigured
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI is not configured. Please check Settings > AI."
        case .invalidURL: return "Invalid API URL."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response from AI provider."
        case .apiError(let msg): return "AI error: \(msg)"
        case .noContent: return "No content in AI response."
        }
    }
}

enum AIAction: String, CaseIterable {
    case summarize = "summarize"
    case expand = "expand"
    case fixGrammar = "fixGrammar"
    case translate = "translate"
    case bulletPoints = "bulletPoints"
    case draftEmail = "draftEmail"
    case explainCode = "explainCode"
    case addComments = "addComments"
    case findBugs = "findBugs"
    case optimizeCode = "optimizeCode"
    case freePrompt = "freePrompt"

    var systemPrompt: String {
        switch self {
        case .summarize:
            return "You are a helpful assistant. Summarize the given text concisely. Return only the summary, no explanations."
        case .expand:
            return "You are a helpful assistant. Expand and elaborate on the given text while keeping the same tone and style. Return only the expanded text."
        case .fixGrammar:
            return "You are a grammar and spelling expert. Fix all grammar, spelling, and punctuation errors in the given text. Return only the corrected text without explanations."
        case .translate:
            return "You are a professional translator. Translate the given text to the requested language. Return only the translation, nothing else."
        case .bulletPoints:
            return "You are a helpful assistant. Convert the given text into clear, organized bullet points. Return only the bullet points."
        case .draftEmail:
            return "You are a professional email writer. Transform the given text into a well-structured professional email. Return only the email body."
        case .explainCode:
            return "You are a senior software developer. Explain what the given code does in clear, simple terms. Be concise but thorough."
        case .addComments:
            return "You are a senior software developer. Add clear, helpful comments to the given code. Return the code with comments added."
        case .findBugs:
            return "You are a senior software developer and code reviewer. Analyze the given code for bugs, potential issues, and improvements. Be specific and concise."
        case .optimizeCode:
            return "You are a senior software developer. Optimize the given code for better performance and readability. Return only the optimized code."
        case .freePrompt:
            return "You are a helpful assistant. Follow the user's instructions precisely."
        }
    }

    func buildUserMessage(text: String, targetLanguage: String? = nil, customPrompt: String? = nil) -> String {
        switch self {
        case .translate:
            let lang = targetLanguage ?? "English"
            return "Translate the following text to \(lang):\n\n\(text)"
        case .freePrompt:
            let prompt = customPrompt ?? "Process this text"
            return "\(prompt)\n\n\(text)"
        default:
            return text
        }
    }
}

class AIService {
    static let shared = AIService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)
    }

    var isConfigured: Bool {
        let settings = SettingsManager.shared
        guard settings.enableAI else { return false }

        switch settings.aiProvider {
        case "ollama":
            return !settings.ollamaURL.isEmpty && !settings.ollamaModel.isEmpty
        case "openai", "anthropic", "google":
            return !settings.aiAPIKey.isEmpty
        default:
            return false
        }
    }

    /// Validates the API key / connection by sending a minimal request.
    /// Returns nil on success, or a user-readable error string on failure.
    func validateConnection() async -> String? {
        let settings = SettingsManager.shared

        do {
            switch settings.aiProvider {
            case "ollama":
                return await validateOllama()
            case "openai":
                if settings.aiAPIKey.isEmpty { return "API Key boş." }
                _ = try await callOpenAI(system: "Reply with OK", user: "test")
                return nil
            case "anthropic":
                if settings.aiAPIKey.isEmpty { return "API Key boş." }
                _ = try await callAnthropic(system: "Reply with OK", user: "test")
                return nil
            case "google":
                if settings.aiAPIKey.isEmpty { return "API Key boş." }
                _ = try await callGoogle(system: "Reply with OK", user: "test")
                return nil
            default:
                return "Bilinmeyen sağlayıcı."
            }
        } catch let error as AIError {
            return error.errorDescription
        } catch {
            return error.localizedDescription
        }
    }

    private func validateOllama() async -> String? {
        let settings = SettingsManager.shared
        let baseURL = settings.ollamaURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            return "Geçersiz Ollama URL."
        }
        do {
            let (data, response) = try await session.data(for: URLRequest(url: url))
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return "Ollama bağlantısı başarısız (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))."
            }
            // Check if model exists
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let names = models.compactMap { $0["name"] as? String }
                let targetModel = settings.ollamaModel
                if !names.contains(where: { $0.hasPrefix(targetModel) }) {
                    return "'\(targetModel)' modeli bulunamadı. Mevcut modeller: \(names.joined(separator: ", "))"
                }
            }
            return nil
        } catch {
            return "Ollama'ya bağlanılamadı: \(error.localizedDescription)"
        }
    }

    func process(text: String, action: AIAction, targetLanguage: String? = nil, customPrompt: String? = nil) async throws -> String {
        let settings = SettingsManager.shared
        guard settings.enableAI else { throw AIError.notConfigured }

        let systemPrompt = action.systemPrompt
        let userMessage = action.buildUserMessage(text: text, targetLanguage: targetLanguage, customPrompt: customPrompt)

        switch settings.aiProvider {
        case "ollama":
            return try await callOllama(system: systemPrompt, user: userMessage)
        case "openai":
            return try await callOpenAI(system: systemPrompt, user: userMessage)
        case "anthropic":
            return try await callAnthropic(system: systemPrompt, user: userMessage)
        case "google":
            return try await callGoogle(system: systemPrompt, user: userMessage)
        default:
            throw AIError.notConfigured
        }
    }

    // MARK: - Error Parsing

    private func parseAPIError(data: Data, statusCode: Int, provider: String) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // OpenAI format: { "error": { "message": "..." } }
            if let errorObj = json["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                return message
            }
            // Anthropic format: { "error": { "type": "...", "message": "..." } }
            if let errorObj = json["error"] as? [String: Any],
               let type = errorObj["type"] as? String {
                let msg = errorObj["message"] as? String ?? type
                return msg
            }
            // Google format: { "error": { "message": "...", "status": "..." } }
            if let errorObj = json["error"] as? [String: Any],
               let status = errorObj["status"] as? String {
                let msg = errorObj["message"] as? String ?? status
                return msg
            }
            // Ollama format: { "error": "..." }
            if let errorStr = json["error"] as? String {
                return errorStr
            }
        }
        // Fallback
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            // Truncate overly long error responses
            let truncated = text.count > 200 ? String(text.prefix(200)) + "..." : text
            return "\(provider) HTTP \(statusCode): \(truncated)"
        }
        return "\(provider) HTTP \(statusCode)"
    }

    // MARK: - Ollama

    private func callOllama(system: String, user: String) async throws -> String {
        let settings = SettingsManager.shared
        let baseURL = settings.ollamaURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw AIError.invalidURL
        }

        let body: [String: Any] = [
            "model": settings.ollamaModel,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AIError.apiError(parseAPIError(data: data, statusCode: code, provider: "Ollama"))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - OpenAI

    private func callOpenAI(system: String, user: String) async throws -> String {
        let settings = SettingsManager.shared
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        let model = settings.aiModel.isEmpty ? "gpt-4o-mini" : settings.aiModel

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": 0.3
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.aiAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.apiError(parseAPIError(data: data, statusCode: httpResponse.statusCode, provider: "OpenAI"))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Anthropic

    private func callAnthropic(system: String, user: String) async throws -> String {
        let settings = SettingsManager.shared
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIError.invalidURL
        }

        let model = settings.aiModel.isEmpty ? "claude-sonnet-4-5-20250929" : settings.aiModel

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": system,
            "messages": [
                ["role": "user", "content": user]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.aiAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.apiError(parseAPIError(data: data, statusCode: httpResponse.statusCode, provider: "Anthropic"))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let first = contentArray.first,
              let text = first["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Google Gemini

    private func callGoogle(system: String, user: String) async throws -> String {
        let settings = SettingsManager.shared
        let model = settings.aiModel.isEmpty ? "gemini-2.0-flash" : settings.aiModel
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(settings.aiAPIKey)") else {
            throw AIError.invalidURL
        }

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": [
                ["parts": [["text": user]]]
            ],
            "generationConfig": [
                "temperature": 0.3
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.apiError(parseAPIError(data: data, statusCode: httpResponse.statusCode, provider: "Google Gemini"))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
