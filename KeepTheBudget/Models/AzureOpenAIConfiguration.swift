//
//  AzureOpenAIConfiguration.swift
//  KeepTheBudget
//
//  Configuration model for Azure OpenAI service credentials
//

import Foundation

struct AzureOpenAIConfiguration {
    let endpoint: String         // e.g., https://xxx.openai.azure.com/
    let apiKey: String
    let deploymentName: String   // e.g., gpt-4

    var isConfigured: Bool {
        !endpoint.isEmpty && !apiKey.isEmpty && !deploymentName.isEmpty
    }

    /// Validate endpoint URL format
    var hasValidEndpoint: Bool {
        guard let url = URL(string: endpoint) else { return false }
        return url.scheme == "https" && url.host != nil
    }
}
