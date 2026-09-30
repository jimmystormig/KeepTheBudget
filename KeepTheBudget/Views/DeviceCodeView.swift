//
//  DeviceCodeView.swift
//  KeepTheBudget
//
//  Displays device code authentication flow to user
//

import SwiftUI
import AppKit

struct DeviceCodeView: View {
    let authManager: AuthManager
    let onComplete: (Bool) -> Void

    @State private var deviceCodeResponse: DeviceCodeResponse?
    @State private var isLoadingCode = false
    @State private var isPolling = false
    @State private var errorMessage: String?
    @State private var timeRemaining: Int?
    @State private var pollingTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            if deviceCodeResponse == nil {
                // Initial state - show sign in button
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Sign in to Office 365")
                    .font(.title)
                    .fontWeight(.bold)

                Text("This app uses device code authentication. You'll receive a code to enter in your browser.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if isLoadingCode {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Requesting code...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                } else {
                    Button("Get Sign-In Code") {
                        startDeviceCodeFlow()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                // Device code received - show code and instructions
                Image(systemName: "key.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)

                Text("Sign in to Office 365")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Visit this URL:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(deviceCodeResponse?.verificationUri ?? "")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)

                        Button(action: openBrowser) {
                            Image(systemName: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderless)
                        .help("Open in browser")
                    }

                    Text("2. Enter this code:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    HStack {
                        Text(deviceCodeResponse?.userCode ?? "")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .goldenGateSurface(cornerRadius: 10)

                        Button(action: copyCode) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy code")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .goldenGateSurface(cornerRadius: 16)

                if isPolling {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Waiting for you to sign in...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let remaining = timeRemaining {
                    Text("Code expires in \(formatTime(remaining))")
                        .font(.caption)
                        .foregroundColor(remaining < 300 ? .red : .secondary)
                }

                Button("Cancel") {
                    cancelAuthentication()
                }
                .buttonStyle(.borderless)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(30)
        .frame(minWidth: 450, minHeight: 450)
    }

    private func startDeviceCodeFlow() {
        isLoadingCode = true
        errorMessage = nil

        Task {
            do {
                let response = try await authManager.startDeviceCodeAuth()

                await MainActor.run {
                    self.deviceCodeResponse = response
                    self.isLoadingCode = false
                    self.timeRemaining = response.expiresIn
                    startPolling(response: response)
                    startExpiryTimer()
                }
            } catch {
                await MainActor.run {
                    self.isLoadingCode = false
                    self.errorMessage = "Failed to get device code: \(error.localizedDescription)"
                }
            }
        }
    }

    private func startPolling(response: DeviceCodeResponse) {
        isPolling = true
        pollingTask = Task {
            let interval = TimeInterval(response.interval)
            let deviceCode = response.deviceCode

            while !Task.isCancelled {
                // Wait for polling interval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                guard !Task.isCancelled else { break }

                // Poll for completion
                do {
                    _ = try await authManager.pollForDeviceCodeCompletion(deviceCode: deviceCode)

                    // Success!
                    await MainActor.run {
                        self.isPolling = false
                        self.onComplete(true)
                    }
                    break
                } catch {
                    let nsError = error as NSError
                    if nsError.code == -1 {
                        // authorization_pending - continue polling
                        continue
                    } else if nsError.code == -2 {
                        // slow_down - increase interval (handled by server, just continue)
                        continue
                    } else {
                        // Real error
                        await MainActor.run {
                            self.isPolling = false
                            self.errorMessage = error.localizedDescription
                        }
                        break
                    }
                }
            }
        }
    }

    private func startExpiryTimer() {
        Task {
            guard let expiresIn = deviceCodeResponse?.expiresIn else { return }

            for countdown in (0...expiresIn).reversed() {
                await MainActor.run {
                    self.timeRemaining = countdown
                }

                if countdown == 0 {
                    await MainActor.run {
                        self.errorMessage = "Code expired. Please try again."
                        self.isPolling = false
                        self.pollingTask?.cancel()
                    }
                    break
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }

    private func openBrowser() {
        guard let urlString = deviceCodeResponse?.verificationUri,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyCode() {
        guard let code = deviceCodeResponse?.userCode else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
    }

    private func cancelAuthentication() {
        pollingTask?.cancel()
        onComplete(false)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
