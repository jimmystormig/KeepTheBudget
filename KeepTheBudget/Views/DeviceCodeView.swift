//
//  DeviceCodeView.swift
//  KeepTheBudget
//
//  Displays authentication flow to user
//

import SwiftUI
import AppKit

struct DeviceCodeView: View {
    let authManager: AuthManager
    let onComplete: (Bool) -> Void

    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Sign in to Office 365")
                .font(.title)
                .fontWeight(.bold)

            Text("Click the button below to sign in with your Microsoft account. A browser window will open for authentication.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if isAuthenticating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Signing in...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)
            } else {
                Button("Sign In") {
                    startAuthentication()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
        .frame(width: 400, height: 350)
    }

    private func startAuthentication() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                // Find the parent window for MSAL authentication
                let parentWindow = await MainActor.run {
                    NSApp.keyWindow ?? NSApp.windows.first
                }

                _ = try await authManager.startInteractiveAuth(parentWindow: parentWindow)

                // Authentication successful
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.onComplete(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
