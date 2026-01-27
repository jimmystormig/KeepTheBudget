//
//  SettingsView.swift
//  KeepTheBudget
//
//  Settings/Preferences window with tabs
//

import SwiftUI

struct SettingsView: View {
    let storageManager: StorageManager
    let authManager: AuthManager
    let graphAPIService: GraphAPIService
    let onCalendarChange: () -> Void
    let timeSummary: TimeSummary?

    @State private var preferences: AppPreferences
    @State private var selectedTab = 0

    init(storageManager: StorageManager, authManager: AuthManager, graphAPIService: GraphAPIService, timeSummary: TimeSummary?, onCalendarChange: @escaping () -> Void) {
        self.storageManager = storageManager
        self.authManager = authManager
        self.graphAPIService = graphAPIService
        self.onCalendarChange = onCalendarChange
        self.timeSummary = timeSummary
        _preferences = State(initialValue: storageManager.loadPreferences())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 0) {
                TabButton(title: "Goals", icon: "target", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "Calendar", icon: "calendar", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(title: "Account", icon: "person.circle", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                TabButton(title: "Configuration", icon: "gear", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                TabButton(title: "About", icon: "info.circle", isSelected: selectedTab == 4) {
                    selectedTab = 4
                }
                TabButton(title: "AI", icon: "brain", isSelected: selectedTab == 5) {
                    selectedTab = 5
                }
            }
            .frame(height: 44)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content area
            Group {
                switch selectedTab {
                case 0:
                    GoalsTab(preferences: $preferences, storageManager: storageManager, timeSummary: timeSummary)
                case 1:
                    CalendarTab(onCalendarChange: onCalendarChange)
                case 2:
                    AccountTab(authManager: authManager, graphAPIService: graphAPIService)
                case 3:
                    ConfigurationTab(storageManager: storageManager, authManager: authManager)
                case 4:
                    AboutTab()
                case 5:
                    AISettingsTab(storageManager: storageManager)
                default:
                    GoalsTab(preferences: $preferences, storageManager: storageManager, timeSummary: timeSummary)
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .blue : .secondary)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Goals Tab

struct GoalsTab: View {
    @Binding var preferences: AppPreferences
    let storageManager: StorageManager
    let timeSummary: TimeSummary?

    var allCategories: [String] {
        guard let summary = timeSummary else { return [] }
        return Array(Set(summary.weeklyCategoryMinutes.keys)).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Daily Goal Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Daily Goal")
                        .font(.headline)

                    HStack {
                        Stepper(value: $preferences.dailyGoalHours, in: 0...24) {
                            HStack {
                                Text("Hours:")
                                TextField("", value: $preferences.dailyGoalHours, format: .number)
                                    .frame(width: 50)
                            }
                        }

                        Stepper(value: $preferences.dailyGoalRemainingMinutes, in: 0...59, step: 15) {
                            HStack {
                                Text("Minutes:")
                                TextField("", value: $preferences.dailyGoalRemainingMinutes, format: .number)
                                    .frame(width: 50)
                            }
                        }
                    }

                    Text("Total: \(TimeFormatter.format(minutes: preferences.dailyGoalMinutes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Weekly Goal Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Weekly Goal")
                        .font(.headline)

                    HStack {
                        Stepper(value: $preferences.weeklyGoalHours, in: 0...168) {
                            HStack {
                                Text("Hours:")
                                TextField("", value: $preferences.weeklyGoalHours, format: .number)
                                    .frame(width: 50)
                            }
                        }

                        Stepper(value: $preferences.weeklyGoalRemainingMinutes, in: 0...59, step: 15) {
                            HStack {
                                Text("Minutes:")
                                TextField("", value: $preferences.weeklyGoalRemainingMinutes, format: .number)
                                    .frame(width: 50)
                            }
                        }
                    }

                    Text("Total: \(TimeFormatter.format(minutes: preferences.weeklyGoalMinutes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Update Interval Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Update Interval")
                        .font(.headline)

                    Stepper(value: $preferences.refreshIntervalMinutes, in: 1...60) {
                        HStack {
                            Text("Refresh every:")
                            TextField("", value: $preferences.refreshIntervalMinutes, format: .number)
                                .frame(width: 50)
                            Text("minutes")
                        }
                    }
                }

                Divider()

                // Category Filtering Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Category-Based Goal Filtering")
                        .font(.headline)

                    Toggle("Enable category filtering for goals", isOn: $preferences.categoryFilteringEnabled)
                        .toggleStyle(.switch)

                    if preferences.categoryFilteringEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select which categories count toward your goals:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)

                            if !allCategories.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(allCategories, id: \.self) { category in
                                            HStack {
                                                Toggle(isOn: Binding(
                                                    get: { preferences.goalEligibleCategories.contains(category) },
                                                    set: { enabled in
                                                        if enabled {
                                                            preferences.goalEligibleCategories.insert(category)
                                                        } else {
                                                            preferences.goalEligibleCategories.remove(category)
                                                        }
                                                    }
                                                )) {
                                                    HStack {
                                                        Text(category)
                                                        Spacer()
                                                        if let weeklyMinutes = timeSummary?.weeklyCategoryMinutes[category] {
                                                            Text(TimeFormatter.format(minutes: weeklyMinutes))
                                                                .foregroundColor(.secondary)
                                                                .font(.caption)
                                                        }
                                                    }
                                                }
                                                .toggleStyle(.checkbox)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 150)
                                .border(Color.gray.opacity(0.2), width: 1)
                                .padding(.vertical, 5)
                            } else {
                                Text("No categories found. Events with \" - \" in their subject will appear here.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 5)
                            }

                            Toggle("Include uncategorized events", isOn: $preferences.includeUncategorizedInGoals)
                                .toggleStyle(.checkbox)
                                .help("Events without \" - \" in subject")

                            if let summary = timeSummary, preferences.categoryFilteringEnabled {
                                Divider()
                                    .padding(.vertical, 5)

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Total Time:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(TimeFormatter.format(minutes: summary.weeklyMinutes))
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Goal-Eligible:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(TimeFormatter.format(minutes: summary.weeklyGoalEligibleMinutes))
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(10)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onChange(of: preferences) { newValue in
            storageManager.savePreferences(newValue)
        }
    }
}

// MARK: - Calendar Tab

struct CalendarTab: View {
    let onCalendarChange: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Calendar Settings")
                .font(.headline)

            Text("To change which calendar is tracked, click the button below to select a different calendar.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Change Calendar") {
                onCalendarChange()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Account Tab

struct AccountTab: View {
    let authManager: AuthManager
    let graphAPIService: GraphAPIService

    @State private var userEmail: String = "Loading..."
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Account")
                .font(.headline)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Text("Signed in as:")
                    .foregroundColor(.secondary)
                Text(userEmail)
                    .fontWeight(.medium)
            }

            Button("Sign Out") {
                authManager.signOut()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)

            Text("Signing out will quit the application. You'll need to sign in again when you restart.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .task {
            // Fetch user email from Graph API
            do {
                let userProfile = try await graphAPIService.fetchUserProfile()
                userEmail = userProfile.mail
            } catch {
                errorMessage = "Failed to load user profile"
                userEmail = "Unknown"
                print("❌ Failed to fetch user profile: \(error)")
            }
        }
    }
}

// MARK: - Configuration Tab

struct ConfigurationTab: View {
    let storageManager: StorageManager
    let authManager: AuthManager

    @State private var showReconfigureSheet = false
    @State private var clientId: String = ""
    @State private var tenantId: String = ""
    @State private var newClientId: String = ""
    @State private var newTenantId: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear.badge.checkmark")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("MSAL Configuration")
                .font(.headline)

            // Display current values (masked)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Client ID:")
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Text(maskValue(clientId))
                        .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Text("Tenant ID:")
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Text(maskValue(tenantId))
                        .font(.system(.body, design: .monospaced))
                }
            }

            Divider()
                .padding(.horizontal, 40)

            Button("Reconfigure") {
                showReconfigureSheet = true
            }
            .buttonStyle(.bordered)

            Text("Changing configuration will sign you out and require an app restart.")
                .font(.caption)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .task {
            loadConfiguration()
        }
        .sheet(isPresented: $showReconfigureSheet) {
            reconfigureSheet
        }
    }

    private var reconfigureSheet: some View {
        VStack(spacing: 20) {
            Text("Reconfigure MSAL")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 15) {
                // Client ID field
                VStack(alignment: .leading, spacing: 5) {
                    Text("Client ID")
                        .font(.headline)
                    TextField("00000000-0000-0000-0000-000000000000", text: $newClientId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                }

                // Tenant ID field
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tenant ID")
                        .font(.headline)
                    TextField("00000000-0000-0000-0000-000000000000", text: $newTenantId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 15) {
                Button("Cancel") {
                    showReconfigureSheet = false
                    errorMessage = nil
                }
                .buttonStyle(.bordered)

                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Save & Restart") {
                        saveNewConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newClientId.isEmpty || newTenantId.isEmpty)
                }
            }

            Text("This will clear your current session and quit the app.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(30)
        .frame(width: 500, height: 400)
        .onAppear {
            newClientId = clientId
            newTenantId = tenantId
        }
    }

    private func loadConfiguration() {
        clientId = storageManager.loadClientId() ?? "Not configured"
        tenantId = storageManager.loadTenantId() ?? "Not configured"
    }

    private func maskValue(_ value: String) -> String {
        guard value.count > 8 else { return value }
        let prefix = String(value.prefix(8))
        return "\(prefix)-****-****-****-************"
    }

    private func saveNewConfiguration() {
        errorMessage = nil

        // Trim whitespace
        let trimmedClientId = newClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTenantId = newTenantId.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate inputs
        guard ConfigurationValidator.isValidClientId(trimmedClientId) else {
            errorMessage = "Invalid Client ID. Must be a valid UUID format."
            return
        }

        guard ConfigurationValidator.isValidTenantId(trimmedTenantId) else {
            errorMessage = "Invalid Tenant ID. Must be a UUID or 'common', 'organizations', or 'consumers'."
            return
        }

        isSaving = true

        // Save to Keychain
        let clientIdSaved = storageManager.saveClientId(trimmedClientId)
        let tenantIdSaved = storageManager.saveTenantId(trimmedTenantId)

        if clientIdSaved && tenantIdSaved {
            print("✅ Configuration updated successfully")

            // Clear tokens and quit
            authManager.signOut()

            // Show alert and quit
            let alert = NSAlert()
            alert.messageText = "Configuration Updated"
            alert.informativeText = "The app will now quit. Please restart to use the new configuration."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Quit")

            alert.runModal()
            NSApplication.shared.terminate(nil)
        } else {
            isSaving = false
            errorMessage = "Failed to save configuration. Please try again."
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("KeepTheBudget")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            Text("Office 365 Calendar Time Tracker")
                .font(.headline)

            Text("Track your daily and weekly scheduled time from Office 365 Calendar with visual warnings when you exceed your goals.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 40)

            Text("© 2026 Nexer")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }
}
