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
        request.timeoutInterval = 30

        // 4. Build prompt
        let systemPrompt = "You are a helpful assistant that analyzes time tracking reports. Provide concise, actionable insights."
        let userPrompt = """
        Analyze this time report and provide:
        1. A brief summary (1-2 sentences)
        2. 3-5 key highlights or insights

        Report:
        \(text)

        Respond in JSON format:
        {
            "summary": "...",
            "highlights": ["...", "...", "..."]
        }
        """

        let requestBody: [String: Any] = [
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_completion_tokens": 500,
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // 5. Make request
        print("🤖 Sending request to Azure OpenAI...")
        print("   URL: \(url.absoluteString)")
        print("   Deployment: \(config.deploymentName)")
        let (data, response) = try await URLSession.shared.data(for: request)

        // 6. Check HTTP status
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

        // 7. Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIAnalysisError.invalidResponse
        }

        print("✅ Received AI response")

        // 8. Parse JSON from content
        guard let contentData = content.data(using: .utf8),
              let contentJson = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
              let summary = contentJson["summary"] as? String,
              let highlights = contentJson["highlights"] as? [String] else {
            // Fallback: treat entire content as summary if JSON parsing fails
            return AIReportAnalysis(
                summary: content,
                highlights: [],
                generatedAt: Date(),
                error: nil
            )
        }

        return AIReportAnalysis(
            summary: summary,
            highlights: highlights,
            generatedAt: Date(),
            error: nil
        )
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
