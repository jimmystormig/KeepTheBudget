//
//  AIReportAnalyzer.swift
//  KeepTheBudget
//
//  Service for analyzing time reports using Azure OpenAI
//

import Foundation

class AIReportAnalyzer {
    private struct ParsedReportContext {
        var summaryLine: String?
        var workGroups: [WorkGroup] = []
        var emailThreads: [String] = []
        var chatTopics: [String] = []
        var todayPriorities: [String] = []
        var upcomingEvents: [String] = []
        var unreadEmailThreads: [String] = []
        var unreadChatConversations: [String] = []
    }

    private struct WorkGroup {
        let name: String
        let duration: String
        let details: [String]
    }

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

        // 4. Parse full report text first (before truncation so "today" section at end isn't cut off),
        //    then sanitize only what we send to the AI.
        let parsedContext = parseReportContext(from: text)
        let structuredPromptInput = structuredPromptInput(from: parsedContext)
        print("📝 Parsed full report (\(text.count) chars), structured input: \(structuredPromptInput.count) chars")

        // 5. Build prompt
        let systemPrompt = "You are an assistant that prepares concise daily standup notes. Be concrete and specific."
        let userPrompt = """
        Analyze this work report for a daily standup meeting. The user's name is Jimmy Stormig.

        Work report, already extracted into structured sections:
        \(structuredPromptInput)

        Respond in JSON format:
        {
            "yesterdayWork": ["Up to 7 bullet points: what I did yesterday, based on calendar events, email communication, and Teams chats"],
            "todayWork": ["Up to 7 bullet points: what I should do today, based on upcoming calendar events, unread email, and unread Teams messages"],
            "correlations": [],
            "priorities": []
        }

        Rules:
        - Every bullet should say something concrete and specific.
        - yesterdayWork: Summarize what was done based on calendar events, email discussions, and Teams chats. Group related work items together into one bullet each. Sort bullets by effort — highest time spent first. For email and Teams threads, identify the topic/subject and mention what was discussed or decided — use Jimmy Stormig's perspective (what he sent, replied to, or was involved in).
        - todayWork: Based on the upcoming calendar events, unread email, and unread Teams messages — identify what to focus on today. For each unread email or Teams thread, mention the topic and what action or response may be needed from Jimmy. If data is available, always produce bullets. Prioritize by importance/urgency.
        - Use relevant emojis at the start of each bullet to make the text expressive and easy to scan.
        - If a section truly has nothing to report, return an empty array.
        - Respond in the same language as the report content.
        """

        let requestBody: [String: Any] = [
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_completion_tokens": 1600,
            "temperature": 0.3,
            "response_format": [
                "type": "json_object"
            ]
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

        let content = extractResponseText(from: json)
        guard !content.isEmpty else {
            print("❌ No readable AI content found in response")
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("   Raw response: \(rawResponse)")
            }

            return fallbackAnalysis(
                from: "",
                context: parsedContext
            )
        }

        print("✅ Received AI response")
        print("   Full content: \(content)")

        // 9. Parse JSON from content (handle markdown-wrapped or text-wrapped JSON)
        var jsonContent = content

        // Strategy 1: Remove markdown code block if present (```json ... ``` or ``` ... ```)
        if jsonContent.contains("```") {
            let pattern = "```(?:json)?\\s*([\\s\\S]*?)```"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: jsonContent, options: [], range: NSRange(jsonContent.startIndex..., in: jsonContent)),
               let range = Range(match.range(at: 1), in: jsonContent) {
                jsonContent = String(jsonContent[range])
                print("   📋 Extracted JSON from markdown code block")
            }
        }

        jsonContent = jsonContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strategy 2: If not valid JSON yet, find the outermost { ... } in the content
        if jsonContent.data(using: .utf8).flatMap({ try? JSONSerialization.jsonObject(with: $0) }) == nil {
            if let firstBrace = jsonContent.firstIndex(of: "{"),
               let lastBrace = jsonContent.lastIndex(of: "}") {
                jsonContent = String(jsonContent[firstBrace...lastBrace])
                print("   📋 Extracted JSON by finding outermost braces")
            }
        }

        jsonContent = jsonContent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let contentData = jsonContent.data(using: .utf8),
              let contentJson = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            // Fallback: treat entire content as summary if JSON parsing fails
            print("⚠️  Failed to parse JSON, using content as summary")
            print("   Attempted to parse: \(String(jsonContent.prefix(200)))...")
            return fallbackAnalysis(from: content, context: parsedContext)
        }

        // Extract the two standup sections
        var yesterdayWork = extractStringArray(from: contentJson["yesterdayWork"])
        var todayWork = extractStringArray(from: contentJson["todayWork"])

        print("✅ Parsed \(yesterdayWork.count) yesterday bullets and \(todayWork.count) today bullets")

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

        yesterdayWork = deduplicatedItems(yesterdayWork)
        todayWork = deduplicatedItems(todayWork)

        return AIReportAnalysis(
            yesterdayWork: yesterdayWork,
            todayWork: todayWork,
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

    private func parseReportContext(from text: String) -> ParsedReportContext {
        enum Section {
            case none
            case historicalCalendar
            case email
            case teams
            case todayPriorities
            case todayCalendar
            case todayEmail
            case todayTeams
        }

        var context = ParsedReportContext()
        var section: Section = .none
        var currentWorkGroupName: String?
        var currentWorkGroupDuration = ""
        var currentWorkGroupDetails: [String] = []

        func flushWorkGroup() {
            guard let workGroupName = currentWorkGroupName else { return }
            context.workGroups.append(
                WorkGroup(
                    name: workGroupName,
                    duration: currentWorkGroupDuration,
                    details: currentWorkGroupDetails
                )
            )
            self.resetWorkGroupState(
                name: &currentWorkGroupName,
                duration: &currentWorkGroupDuration,
                details: &currentWorkGroupDetails
            )
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("Summary: ") && context.summaryLine == nil {
                context.summaryLine = String(line.dropFirst("Summary: ".count))
                continue
            }

            switch line {
            case "📅 CALENDAR EVENTS":
                flushWorkGroup()
                section = .historicalCalendar
                continue
            case let value where value.hasPrefix("📧 EMAIL COMMUNICATIONS"):
                flushWorkGroup()
                section = .email
                continue
            case let value where value.hasPrefix("💬 TEAMS CHATS"):
                flushWorkGroup()
                section = .teams
                continue
            case "PRIORITIES":
                flushWorkGroup()
                section = .todayPriorities
                continue
            case let value where value.hasPrefix("📅 UPCOMING CALENDAR"):
                flushWorkGroup()
                section = .todayCalendar
                continue
            case let value where value.hasPrefix("📧 UNREAD EMAIL"):
                flushWorkGroup()
                section = .todayEmail
                continue
            case let value where value.hasPrefix("💬 UNREAD TEAMS MESSAGES"):
                flushWorkGroup()
                section = .todayTeams
                continue
            case let value where value.hasPrefix("✅ WHAT TO DO TODAY"):
                flushWorkGroup()
                section = .none
                continue
            case let value where value.hasPrefix("End of Report"):
                flushWorkGroup()
                section = .none
                continue
            default:
                break
            }

            switch section {
            case .historicalCalendar:
                if let group = parseWorkGroupHeader(line) {
                    flushWorkGroup()
                    currentWorkGroupName = group.name
                    currentWorkGroupDuration = group.duration
                } else if let detail = parseWorkGroupDetail(line) {
                    currentWorkGroupDetails.append(detail)
                }
            case .email:
                if let item = parseNumberedEntry(line), isUsefulCommunicationItem(item) {
                    context.emailThreads.append(item)
                }
            case .teams:
                if let item = parseNumberedEntry(line), isUsefulCommunicationItem(item) {
                    context.chatTopics.append(item)
                }
            case .todayPriorities:
                if let item = parseNumberedEntry(line), isUsefulTodayItem(item) {
                    context.todayPriorities.append(item)
                }
            case .todayCalendar:
                if let item = parseNumberedEntry(line), isUsefulTodayItem(item) {
                    context.upcomingEvents.append(item)
                }
            case .todayEmail:
                if let item = parseNumberedEntry(line), isUsefulCommunicationItem(item) {
                    context.unreadEmailThreads.append(item)
                }
            case .todayTeams:
                if let item = parseNumberedEntry(line), isUsefulCommunicationItem(item) {
                    context.unreadChatConversations.append(item)
                }
            case .none:
                break
            }
        }

        flushWorkGroup()
        context.emailThreads = deduplicatedItems(context.emailThreads)
        context.chatTopics = deduplicatedItems(context.chatTopics)
        context.todayPriorities = deduplicatedItems(context.todayPriorities)
        context.upcomingEvents = deduplicatedItems(context.upcomingEvents)
        context.unreadEmailThreads = deduplicatedItems(context.unreadEmailThreads)
        context.unreadChatConversations = deduplicatedItems(context.unreadChatConversations)
        return context
    }

    private func structuredPromptInput(from context: ParsedReportContext) -> String {
        var lines: [String] = []

        if let summaryLine = context.summaryLine, !summaryLine.isEmpty {
            lines.append("Overall summary: \(summaryLine)")
        }

        lines.append("Yesterday work groups:")
        if context.workGroups.isEmpty {
            lines.append("- none")
        } else {
            for group in context.workGroups {
                let detailText = group.details.isEmpty ? "" : " | details: \(group.details.joined(separator: "; "))"
                lines.append("- \(group.name) (\(group.duration))\(detailText)")
            }
        }

        lines.append("Historical email threads:")
        lines.append(context.emailThreads.isEmpty ? "- none" : context.emailThreads.prefix(8).map { "- \($0)" }.joined(separator: "\n"))

        lines.append("Historical Teams conversations:")
        lines.append(context.chatTopics.isEmpty ? "- none" : context.chatTopics.prefix(8).map { "- \($0)" }.joined(separator: "\n"))

        lines.append("Today priorities:")
        lines.append(context.todayPriorities.isEmpty ? "- none" : context.todayPriorities.prefix(8).map { "- \($0)" }.joined(separator: "\n"))

        lines.append("Today upcoming calendar:")
        lines.append(context.upcomingEvents.isEmpty ? "- none" : context.upcomingEvents.prefix(8).map { "- \($0)" }.joined(separator: "\n"))

        lines.append("Today unread email:")
        lines.append(context.unreadEmailThreads.isEmpty ? "- none" : context.unreadEmailThreads.prefix(8).map { "- \($0)" }.joined(separator: "\n"))

        lines.append("Today unread Teams:")
        lines.append(context.unreadChatConversations.isEmpty ? "- none" : context.unreadChatConversations.prefix(8).map { "- \($0)" }.joined(separator: "\n"))

        return lines.joined(separator: "\n")
    }

    private func extractResponseText(from json: [String: Any]) -> String {
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first {
            print("📦 First choice: \(firstChoice)")

            if let message = firstChoice["message"] as? [String: Any] {
                print("📦 Message: \(message)")
                let messageContent = extractMessageContent(from: message)
                if !messageContent.isEmpty {
                    return messageContent
                }
            }

            for key in ["text", "content"] {
                if let value = extractString(from: firstChoice[key]), !value.isEmpty {
                    return value
                }
            }
        }

        if let outputText = extractString(from: json["output_text"]), !outputText.isEmpty {
            return outputText
        }

        if let output = json["output"] as? [[String: Any]] {
            let joined = output
                .compactMap { item -> String? in
                    if let content = item["content"] as? [[String: Any]] {
                        let text = content.compactMap { extractString(from: $0) }.joined(separator: "\n")
                        return text.isEmpty ? nil : text
                    }
                    return extractString(from: item)
                }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !joined.isEmpty {
                return joined
            }
        }

        return ""
    }

    private func parseWorkGroupHeader(_ line: String) -> (name: String, duration: String)? {
        let pattern = #"^(.+?)\s+\(([^()]+)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let nameRange = Range(match.range(at: 1), in: line),
              let durationRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let name = line[nameRange].trimmingCharacters(in: .whitespacesAndNewlines)
        let duration = line[durationRange].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !duration.isEmpty,
              !name.hasPrefix("Report:"),
              !name.hasPrefix("Total:"),
              !name.hasPrefix("Period:") else {
            return nil
        }

        return (name, duration)
    }

    private func parseWorkGroupDetail(_ line: String) -> String? {
        let trimmed = line
            .replacingOccurrences(of: #"^[•\-]+\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*[•\-]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              trimmed.range(of: #"^[═\-=]{3,}$"#, options: .regularExpression) == nil,
              !trimmed.hasPrefix("Week of"),
              !trimmed.hasPrefix("Report:"),
              !trimmed.hasPrefix("Total:") else {
            return nil
        }

        return trimmed
    }

    private func parseNumberedEntry(_ line: String) -> String? {
        guard let matchRange = line.range(of: #"^\d+\.\s+"#, options: .regularExpression) else {
            return nil
        }
        let cleaned = String(line[matchRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func isUsefulCommunicationItem(_ item: String) -> Bool {
        let lowercase = item.lowercased()
        if lowercase.hasPrefix("summary:") ||
            lowercase.contains("email communications") ||
            lowercase.contains("teams chats") ||
            lowercase.contains("unread teams messages") ||
            lowercase.contains("upcoming calendar") ||
            lowercase == "no unread email." ||
            lowercase == "no unread teams messages." ||
            lowercase == "no chats in this period." ||
            lowercase == "no emails in this period." {
            return false
        }

        if lowercase == "prevented spam messages" || lowercase.contains("ny aktivitet i teams") {
            return false
        }

        return true
    }

    private func isUsefulTodayItem(_ item: String) -> Bool {
        let lowercase = item.lowercased()
        if lowercase.hasPrefix("summary:") ||
            lowercase.contains("calendar events") ||
            lowercase.contains("email communications") ||
            lowercase.contains("teams chats") ||
            lowercase.contains("unread teams messages") {
            return false
        }

        if lowercase == "prevented spam messages" {
            return false
        }

        return true
    }

    private func resetWorkGroupState(
        name: inout String?,
        duration: inout String,
        details: inout [String]
    ) {
        name = nil
        duration = ""
        details = []
    }

    private func extractMessageContent(from message: [String: Any]) -> String {
        if let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let parts = message["content"] as? [[String: Any]] {
            let joined = parts.compactMap { part -> String? in
                if let text = part["text"] as? String {
                    return text
                }

                if let textObject = part["text"] as? [String: Any],
                   let value = textObject["value"] as? String {
                    return value
                }

                return nil
            }
            .joined(separator: "\n")

            return joined.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ""
    }

    private func extractString(from value: Any?) -> String? {
        guard let value else { return nil }

        if let string = value as? String {
            let cleaned = cleanedBulletLine(string)
            return cleaned.isEmpty ? nil : cleaned
        }

        if let dictionary = value as? [String: Any] {
            for key in ["text", "summary", "content", "value", "title", "reason", "description"] {
                if let result = extractString(from: dictionary[key]) {
                    return result
                }
            }
        }

        return nil
    }

    private func extractStringArray(from value: Any?) -> [String] {
        guard let value else { return [] }

        if let strings = value as? [String] {
            return normalizeBulletItems(strings)
        }

        if let string = value as? String {
            return splitBulletText(string)
        }

        if let dictionaries = value as? [[String: Any]] {
            let items = dictionaries.compactMap { dictionary -> String? in
                for key in ["text", "summary", "content", "value", "title", "reason", "description"] {
                    if let result = extractString(from: dictionary[key]) {
                        return result
                    }
                }
                return nil
            }
            return normalizeBulletItems(items)
        }

        if let dictionary = value as? [String: Any] {
            for key in ["items", "bullets", "entries", "values"] {
                let nested = extractStringArray(from: dictionary[key])
                if !nested.isEmpty {
                    return nested
                }
            }

            if let single = extractString(from: dictionary) {
                return [single]
            }
        }

        return []
    }

    private func splitBulletText(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count > 1 {
            return normalizeBulletItems(lines)
        }

        let components = trimmed.components(separatedBy: .init(charactersIn: "•"))
        let bulletLike = components.count > 1 ? components : trimmed.components(separatedBy: " - ")
        if bulletLike.count > 1 {
            return normalizeBulletItems(bulletLike)
        }

        let cleaned = cleanedBulletLine(trimmed)
        return cleaned.isEmpty ? [] : [cleaned]
    }

    private func normalizeBulletItems(_ items: [String]) -> [String] {
        items
            .map(cleanedBulletLine)
            .filter { !$0.isEmpty }
    }

    private func cleanedBulletLine(_ item: String) -> String {
        var cleaned = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        cleaned = cleaned.replacingOccurrences(
            of: #"^\s*(?:[-*•]\s+|\d+[\.\)]\s+)"#,
            with: "",
            options: .regularExpression
        )

        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"' \t\r\n"))

        if cleaned.range(of: #"^\d+[\.\)]?$"#, options: .regularExpression) != nil {
            return ""
        }

        return cleaned
    }

    private func cleanedSummary(from content: String) -> String {
        splitBulletText(content).first ?? content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deduplicatedItems(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { item in
            let key = item.lowercased()
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    private func fallbackAnalysis(from content: String, context: ParsedReportContext) -> AIReportAnalysis {
        let cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackBullets = Array(splitBulletText(cleanedContent).prefix(5))

        let primaryGroups = Array(context.workGroups.prefix(3))
        let secondaryGroups = Array(context.workGroups.dropFirst(3).prefix(3))

        let yesterday = fallbackBullets.isEmpty
            ? buildYesterdayBullets(from: primaryGroups, others: secondaryGroups, summaryLine: context.summaryLine)
            : fallbackBullets

        let today = buildTodayBullets(from: context)

        return AIReportAnalysis(
            yesterdayWork: yesterday,
            todayWork: today,
            correlations: [],
            priorities: [],
            generatedAt: Date(),
            error: nil
        )
    }

    private func buildYesterdayBullets(
        from primaryGroups: [WorkGroup],
        others: [WorkGroup],
        summaryLine: String?
    ) -> [String] {
        var bullets: [String] = []

        if !primaryGroups.isEmpty {
            bullets.append(contentsOf: primaryGroups.prefix(3).map { summarizeWorkGroup($0, includeDetails: true) })
        }

        if !others.isEmpty {
            let names = others.prefix(3).map { "\($0.name) (\($0.duration))" }
            bullets.append("Other work moved forward in \(names.joined(separator: ", ")).")
        }

        if bullets.isEmpty, let summaryLine, !summaryLine.isEmpty {
            bullets.append(summaryLine)
        }

        return Array(deduplicatedItems(bullets).prefix(5))
    }

    private func buildTodayBullets(from context: ParsedReportContext) -> [String] {
        var bullets: [String] = []

        bullets.append(contentsOf: context.todayPriorities.prefix(3))

        if bullets.count < 5 {
            bullets.append(contentsOf: context.upcomingEvents.prefix(5 - bullets.count))
        }

        if bullets.count < 5 {
            bullets.append(contentsOf: context.unreadEmailThreads.prefix(5 - bullets.count))
        }

        if bullets.count < 5 {
            bullets.append(contentsOf: context.unreadChatConversations.prefix(5 - bullets.count))
        }

        return Array(deduplicatedItems(bullets).prefix(5))
    }

    private func summarizeWorkGroup(_ group: WorkGroup, includeDetails: Bool) -> String {
        if includeDetails, let detail = group.details.first, !detail.isEmpty {
            return "\(group.name) (\(group.duration)): \(detail)."
        }

        return "\(group.name) (\(group.duration))."
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
