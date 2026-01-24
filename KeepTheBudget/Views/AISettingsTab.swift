//
//  AISettingsTab.swift
//  KeepTheBudget
//
//  Settings tab for configuring Azure OpenAI integration
//

import SwiftUI

struct AISettingsTab: View {
    let storageManager: StorageManager

    @State private var endpoint: String = ""
    @State private var apiKey: String = ""
    @State private var deploymentName: String = ""
    @State private var showSaved = false
    @State private var showTestSuccess = false
    @State private var showTestError = false
    @State private var testErrorMessage = ""
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Analysis (Optional)")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Configure Azure OpenAI to enable AI-powered report analysis. This feature provides intelligent summaries and insights from your time reports.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Configuration form
            VStack(alignment: .leading, spacing: 16) {
                // Endpoint URL
                VStack(alignment: .leading, spacing: 6) {
                    Text("Endpoint URL:")
                        .fontWeight(.medium)
                    TextField("https://xxx.openai.azure.com/", text: $endpoint)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("Your Azure OpenAI service endpoint URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // API Key
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key:")
                        .fontWeight(.medium)
                    SecureField("Enter your API key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("Your Azure OpenAI API key (stored securely in Keychain)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Deployment Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Deployment Name:")
                        .fontWeight(.medium)
                    TextField("gpt-4", text: $deploymentName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("The name of your deployed model")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Buttons
            HStack(spacing: 12) {
                // Test Connection button
                Button(action: testConnection) {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text(isTesting ? "Testing..." : "Test Connection")
                    }
                }
                .disabled(isTesting || !isFormValid)

                // Save button
                Button(action: saveConfiguration) {
                    HStack(spacing: 6) {
                        Image(systemName: showSaved ? "checkmark" : "square.and.arrow.down")
                        Text(showSaved ? "Saved!" : "Save")
                    }
                }
                .disabled(!isFormValid)

                // Clear button
                Button(action: clearConfiguration) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                }
                .disabled(endpoint.isEmpty && apiKey.isEmpty && deploymentName.isEmpty)

                Spacer()
            }

            // Feedback messages
            if showTestSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connection successful!")
                        .foregroundColor(.green)
                }
            }

            if showTestError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(testErrorMessage)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadConfiguration()
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !endpoint.isEmpty && !apiKey.isEmpty && !deploymentName.isEmpty
    }

    // MARK: - Actions

    private func loadConfiguration() {
        if let config = storageManager.loadAzureOpenAIConfig() {
            endpoint = config.endpoint
            apiKey = config.apiKey
            deploymentName = config.deploymentName
        }
    }

    private func saveConfiguration() {
        let config = AzureOpenAIConfiguration(
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            deploymentName: deploymentName.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let success = storageManager.saveAzureOpenAIConfig(config)

        if success {
            showSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSaved = false
            }
        }
    }

    private func clearConfiguration() {
        endpoint = ""
        apiKey = ""
        deploymentName = ""
        storageManager.deleteAzureOpenAIConfig()
        showTestSuccess = false
        showTestError = false
    }

    private func testConnection() {
        // Reset feedback
        showTestSuccess = false
        showTestError = false
        isTesting = true

        let config = AzureOpenAIConfiguration(
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            deploymentName: deploymentName.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        Task {
            do {
                // Simple test: try to make a minimal request
                guard var urlComponents = URLComponents(string: config.endpoint) else {
                    throw AIAnalysisError.invalidConfiguration
                }

                // Explicitly set the path (don't append to avoid issues with existing paths)
                urlComponents.path = "/openai/deployments/\(config.deploymentName)/chat/completions"
                urlComponents.queryItems = [URLQueryItem(name: "api-version", value: "2024-08-01-preview")]

                guard let url = urlComponents.url else {
                    throw AIAnalysisError.invalidConfiguration
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 10

                let requestBody: [String: Any] = [
                    "messages": [
                        ["role": "user", "content": "Hello"]
                    ],
                    "max_completion_tokens": 5
                ]

                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                print("🧪 Testing Azure OpenAI connection...")
                print("   URL: \(url.absoluteString)")
                print("   Deployment: \(config.deploymentName)")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIAnalysisError.networkError
                }

                if httpResponse.statusCode == 200 {
                    print("✅ Test successful")
                    await MainActor.run {
                        showTestSuccess = true
                        isTesting = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showTestSuccess = false
                        }
                    }
                } else {
                    print("❌ Test failed: HTTP \(httpResponse.statusCode)")

                    // Try to extract error message from Azure's response
                    var detailedError = "HTTP \(httpResponse.statusCode)"
                    if let errorBody = String(data: data, encoding: .utf8) {
                        print("   Response: \(errorBody)")

                        // Try to parse Azure's error message
                        if let jsonData = errorBody.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            detailedError = message
                        } else {
                            detailedError = errorBody
                        }
                    }

                    await MainActor.run {
                        showTestError = true
                        testErrorMessage = detailedError
                        isTesting = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            showTestError = false
                        }
                    }
                    return
                }
            } catch {
                await MainActor.run {
                    showTestError = true
                    testErrorMessage = error.localizedDescription
                    isTesting = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        showTestError = false
                    }
                }
            }
        }
    }
}
