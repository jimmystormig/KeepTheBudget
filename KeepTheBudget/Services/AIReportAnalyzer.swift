//
//  AIReportAnalyzer.swift
//  KeepTheBudget
//
//  Service for analyzing time reports using Azure OpenAI
//

import Foundation

class AIReportAnalyzer {
    let storageManager: StorageManager

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
    }

    /// Analyze a time report using Azure OpenAI
    /// - Parameter text: Text representation of the report
    /// - Returns: AIReportAnalysis with summary and highlights
    /// - Throws: AIAnalysisError if analysis fails
    func analyzeReport(_ text: String) async throws -> AIReportAnalysis {
        // 1. Load Azure OpenAI config from StorageManager
        guard let config = storageManager.loadAzureOpenAIConfig(), config.isConfigured else {
            throw AIAnalysisError.notConfigured
        }

        // 2. Build request URL
        guard var urlComponents = URLComponents(string: config.endpoint) else {
            throw AIAnalysisError.invalidConfiguration
        }

        // Explicitly set the path (don't append to avoid issues with existing paths)
        urlComponents.path = "/openai/deployments/\(config.deploymentName)/chat/completions"
        urlComponents.queryItems = [URLQueryItem(name: "api-version", value: "2024-08-01-preview")]

        guard let url = urlComponents.url else {
            throw AIAnalysisError.invalidConfiguration
        }

        // 3. Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120  // Longer timeout for reasoning models (gpt-5.2 needs time to reason)

        // 4. Sanitize report content to avoid content filter issues
        let sanitizedText = sanitizeReportContent(text)
        print("📝 Report sanitized: \(text.count) → \(sanitizedText.count) characters")

        // 5. Build prompt
        let systemPrompt = "You are a helpful assistant that analyzes comprehensive work reports including calendar events, emails, and Teams chats. Identify correlations, priorities, and actionable insights."
        let userPrompt = """
        Analyze this comprehensive work report and provide:
        1. A brief summary (1-2 sentences) of the overall activity
        2. 3-5 key highlights or insights
        3. Correlations: Identify connections between calendar events, emails, and chats (e.g., meetings followed by email discussions, chat conversations about scheduled events)
        4. Priorities: Identify high-priority items requiring attention based on urgency, importance, or follow-up needs

        Report:
        \(sanitizedText)

        Respond in JSON format:
        {
            "summary": "...",
            "highlights": ["...", "...", "..."],
            "correlations": [
                {
                    "type": "eventToEmail | eventToChat | emailToChat | multiChannel",
                    "title": "Brief title",
                    "description": "What's connected and why it matters",
                    "items": ["Reference to specific event/email/chat"]
                }
            ],
            "priorities": [
                {
                    "level": "high | medium | low",
                    "title": "What needs attention",
                    "reason": "Why it's a priority",
                    "relatedItems": ["References to related events/emails/chats"]
                }
            ]
        }
        """

        let requestBody: [String: Any] = [
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_completion_tokens": 2000,  // Higher limit for reasoning models (gpt-5.2 uses reasoning tokens)
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // 6. Make request
        print("🤖 Sending request to Azure OpenAI...")
        print("   URL: \(url.absoluteString)")
        print("   Deployment: \(config.deploymentName)")
        let (data, response) = try await URLSession.shared.data(for: request)

        // 7. Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ Azure OpenAI error: HTTP \(httpResponse.statusCode)")
            if let errorBody = String(data: data, encoding: .utf8) {
                print("   Response: \(errorBody)")
            }
            throw AIAnalysisError.apiError(statusCode: httpResponse.statusCode)
        }

        // 8. Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Failed to parse response as JSON")
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("   Raw response: \(rawResponse)")
            }
            throw AIAnalysisError.invalidResponse
        }

        print("📦 Full JSON response: \(json)")

        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first else {
            print("❌ No choices in response")
            throw AIAnalysisError.invalidResponse
        }

        print("📦 First choice: \(firstChoice)")

        guard let message = firstChoice["message"] as? [String: Any] else {
            print("❌ No message in choice")
            throw AIAnalysisError.invalidResponse
        }

        print("📦 Message: \(message)")

        guard let content = message["content"] as? String else {
            print("❌ No content in message (may be filtered)")
            // Check if there's a content filter result
            if let finishReason = firstChoice["finish_reason"] as? String {
                print("   Finish reason: \(finishReason)")
            }
            if let contentFilterResults = firstChoice["content_filter_results"] as? [String: Any] {
                print("   Content filter results: \(contentFilterResults)")
            }
            throw AIAnalysisError.invalidResponse
        }

        print("✅ Received AI response")
        print("   Full content: \(content)")

        // 9. Parse JSON from content (handle markdown-wrapped JSON)
        var jsonContent = content

        // Remove markdown code block if present (```json ... ``` or ``` ... ```)
        if jsonContent.contains("```") {
            // Extract content between ```json and ``` or between ``` and ```
            let pattern = "```(?:json)?\\s*([\\s\\S]*?)```"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: jsonContent, options: [], range: NSRange(jsonContent.startIndex..., in: jsonContent)),
               let range = Range(match.range(at: 1), in: jsonContent) {
                jsonContent = String(jsonContent[range])
                print("   📋 Extracted JSON from markdown code block")
            }
        }

        jsonContent = jsonContent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let contentData = jsonContent.data(using: .utf8),
              let contentJson = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            // Fallback: treat entire content as summary if JSON parsing fails
            print("⚠️  Failed to parse JSON, using content as summary")
            print("   Attempted to parse: \(String(jsonContent.prefix(200)))...")
            return AIReportAnalysis(
                summary: content,
                highlights: [],
                correlations: [],
                priorities: [],
                generatedAt: Date(),
                error: nil
            )
        }

        // Extract summary and highlights (required)
        let summary = contentJson["summary"] as? String ?? content
        let highlights = contentJson["highlights"] as? [String] ?? []

        print("✅ Parsed summary and \(highlights.count) highlights")

        // Parse correlations (Phase 3 - optional)
        var correlations: [Correlation] = []
        if let correlationsJson = contentJson["correlations"] as? [[String: Any]] {
            for corrJson in correlationsJson {
                guard let typeStr = corrJson["type"] as? String,
                      let title = corrJson["title"] as? String,
                      let description = corrJson["description"] as? String,
                      let items = corrJson["items"] as? [String] else {
                    continue
                }
                // Map type string to enum
                let type: CorrelationType
                switch typeStr.lowercased() {
                case "eventtoemail": type = .eventToEmail
                case "eventtochat": type = .eventToChat
                case "emailtochat": type = .emailToChat
                case "multichannel": type = .multiChannel
                default: type = .multiChannel  // Default fallback
                }
                correlations.append(Correlation(type: type, title: title, description: description, items: items))
            }
            print("✅ Parsed \(correlations.count) correlations")
        } else {
            print("ℹ️  No correlations in AI response")
        }

        // Parse priorities (Phase 3 - optional)
        var priorities: [Priority] = []
        if let prioritiesJson = contentJson["priorities"] as? [[String: Any]] {
            for prioJson in prioritiesJson {
                guard let levelStr = prioJson["level"] as? String,
                      let title = prioJson["title"] as? String,
                      let reason = prioJson["reason"] as? String,
                      let relatedItems = prioJson["relatedItems"] as? [String] else {
                    continue
                }
                // Map level string to enum
                let level: PriorityLevel
                switch levelStr.lowercased() {
                case "high": level = .high
                case "medium": level = .medium
                case "low": level = .low
                default: level = .medium  // Default fallback
                }
                priorities.append(Priority(level: level, title: title, reason: reason, relatedItems: relatedItems))
            }
            print("✅ Parsed \(priorities.count) priorities")
        } else {
            print("ℹ️  No priorities in AI response")
        }

        return AIReportAnalysis(
            summary: summary,
            highlights: highlights,
            correlations: correlations,
            priorities: priorities,
            generatedAt: Date(),
            error: nil
        )
    }

    /// Sanitize report content to avoid Azure OpenAI content filter issues
    /// - Parameter text: Raw report text
    /// - Returns: Sanitized and truncated text safe for AI analysis
    private func sanitizeReportContent(_ text: String) -> String {
        var sanitized = text

        // 1. Truncate to reasonable length (5000 chars) to reduce content filter exposure
        let maxLength = 5000
        if sanitized.count > maxLength {
            // Try to find a natural break point (newline) near the limit
            let truncateAt = sanitized.index(sanitized.startIndex, offsetBy: maxLength)
            if let lastNewline = sanitized[..<truncateAt].lastIndex(of: "\n") {
                sanitized = String(sanitized[..<lastNewline])
            } else {
                sanitized = String(sanitized.prefix(maxLength))
            }
            sanitized += "\n\n[Report truncated for analysis]"
        }

        // 2. Remove potentially problematic patterns (very conservative)
        // Note: We want to keep most business content intact, only remove obvious issues

        // 3. Normalize excessive whitespace
        sanitized = sanitized.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)

        return sanitized
    }
}

/// Errors specific to AI analysis
enum AIAnalysisError: Error, LocalizedError {
    case notConfigured
    case invalidConfiguration
    case invalidResponse
    case apiError(statusCode: Int)
    case networkError
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Azure OpenAI is not configured. Please configure it in Settings."
        case .invalidConfiguration:
            return "Invalid Azure OpenAI configuration. Please check Settings."
        case .invalidResponse:
            return "Failed to parse AI response. Please try again."
        case .apiError(let statusCode):
            switch statusCode {
            case 401:
                return "Invalid API key. Please check AI Settings."
            case 429:
                return "API quota exceeded. Please try again later."
            case 404:
                return "Deployment not found. Please check deployment name in Settings."
            default:
                return "AI service error (HTTP \(statusCode)). Please try again."
            }
        case .networkError:
            return "Network error. Please check your connection."
        case .timeout:
            return "Analysis timed out. Please try again."
        }
    }
}
