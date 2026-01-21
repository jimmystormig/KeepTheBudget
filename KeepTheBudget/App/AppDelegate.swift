//
//  AppDelegate.swift
//  KeepTheBudget
//
//  Manages the menu bar status item and application lifecycle
//

import Cocoa
import SwiftUI
import MSAL

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var authWindow: NSWindow?
    private var calendarWindow: NSWindow?
    private var configWindow: NSWindow?

    // Services
    private var authManager: AuthManager!
    private var graphAPIService: GraphAPIService!
    private var timeCalculator: TimeCalculator!
    private var updateScheduler: UpdateScheduler!
    private var storageManager: StorageManager!

    // State
    @Published private var timeSummary: TimeSummary?
    @Published private var isLoading = false
    @Published private var lastUpdateTime: Date?
    @Published private var errorMessage: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize basic services
        storageManager = StorageManager()
        timeCalculator = TimeCalculator()

        // DON'T initialize AuthManager yet - it will be initialized after config check

        // Setup menu bar
        setupMenuBar()

        // Setup popover
        setupPopover()

        // Auto-migrate existing users
        MigrationManager.migrateConfigurationIfNeeded(storageManager: storageManager)

        // Check configuration status FIRST
        Task {
            await checkConfigurationAndInitialize()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateStatusItemDisplay(summary: nil, isLoading: true)
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
    }

    private func checkConfigurationAndInitialize() async {
        print("🔍 checkConfigurationAndInitialize() called")

        // Check if MSAL configuration exists
        let hasConfig = storageManager.hasConfiguration()
        print("   Has configuration: \(hasConfig)")

        guard hasConfig else {
            print("   → Showing configuration setup")
            await showConfigurationSetup()
            return
        }

        // Initialize AuthManager with config
        print("   → Creating AuthManager")
        authManager = AuthManager(storageManager: storageManager)

        do {
            print("   → Initializing AuthManager")
            try authManager.initialize()

            // Initialize GraphAPIService
            print("   → Creating GraphAPIService")
            graphAPIService = GraphAPIService(authManager: authManager)

            // Continue with existing flow
            print("   → Proceeding to authentication check")
            await checkAuthenticationAndInitialize()
        } catch {
            print("❌ Failed to initialize AuthManager: \(error)")

            await MainActor.run {
                errorMessage = "Configuration error: \(error.localizedDescription)"

                // Offer to reconfigure
                let alert = NSAlert()
                alert.messageText = "Configuration Error"
                alert.informativeText = "Failed to initialize. Reconfigure?"
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Reconfigure")
                alert.addButton(withTitle: "Quit")

                if alert.runModal() == .alertFirstButtonReturn {
                    Task { await self.showConfigurationSetup() }
                } else {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func showConfigurationSetup() async {
        await MainActor.run {
            let configView = ConfigurationSetupView(
                storageManager: storageManager
            ) { [weak self] in
                print("✅ Configuration saved")

                // Close config window
                self?.configWindow?.close()
                self?.configWindow = nil

                // Restart initialization
                Task {
                    await self?.checkConfigurationAndInitialize()
                }
            }

            configWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            configWindow?.center()
            configWindow?.title = "Setup Required"
            configWindow?.contentView = NSHostingView(rootView: configView)
            configWindow?.makeKeyAndOrderFront(nil)

            // Disable close button until configured
            configWindow?.standardWindowButton(.closeButton)?.isEnabled = false
        }
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // Update popover content with current state before showing
                popover.contentViewController = NSHostingController(
                    rootView: PopoverView(
                        timeSummary: timeSummary,
                        lastUpdateTime: lastUpdateTime,
                        isLoading: isLoading,
                        errorMessage: errorMessage,
                        onRefresh: { [weak self] in
                            Task { await self?.refreshData() }
                        },
                        onOpenSettings: { [weak self] in
                            self?.openSettings()
                        },
                        onQuit: {
                            NSApplication.shared.terminate(nil)
                        }
                    )
                )
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    private func updateStatusItemDisplay(summary: TimeSummary?, isLoading: Bool) {
        guard let button = statusItem.button else { return }

        if isLoading {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Loading")
            button.title = " Loading..."
            return
        }

        guard let summary = summary else {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
            button.title = " Error"
            return
        }

        // Always use clock icon (no dot)
        let icon = NSImage(systemSymbolName: "clock", accessibilityDescription: summary.showWarning ? "Over Goal" : "Normal")
        icon?.isTemplate = true
        button.image = icon

        // Format time display: "6h 30m / 32h 15m"
        let dailyStr = TimeFormatter.format(minutes: summary.dailyMinutes)
        let weeklyStr = TimeFormatter.format(minutes: summary.weeklyMinutes)

        // Build attributed string with selective red coloring
        let attributedTitle = NSMutableAttributedString()

        // Add space
        attributedTitle.append(NSAttributedString(string: " "))

        // Add daily time (red if over goal)
        let dailyAttributes: [NSAttributedString.Key: Any] = summary.dailyStatus == .overGoal ?
            [.foregroundColor: NSColor.red] : [:]
        attributedTitle.append(NSAttributedString(string: dailyStr, attributes: dailyAttributes))

        // Add separator (always normal color)
        attributedTitle.append(NSAttributedString(string: " / "))

        // Add weekly time (red if over goal)
        let weeklyAttributes: [NSAttributedString.Key: Any] = summary.weeklyStatus == .overGoal ?
            [.foregroundColor: NSColor.red] : [:]
        attributedTitle.append(NSAttributedString(string: weeklyStr, attributes: weeklyAttributes))

        button.attributedTitle = attributedTitle
    }

    private func checkAuthenticationAndInitialize() async {
        print("🔍 checkAuthenticationAndInitialize() called")

        let hasTokens = authManager.hasValidTokens()
        print("   Has valid tokens: \(hasTokens)")

        guard hasTokens else {
            print("   → Showing device code flow")
            await showDeviceCodeFlow()
            return
        }

        // Check if calendar is selected
        let preferences = storageManager.loadPreferences()
        let calendarId = preferences.selectedCalendarId
        print("   Calendar ID: \(calendarId ?? "nil")")

        guard calendarId != nil else {
            print("   → Showing calendar selection")
            await showCalendarSelection()
            return
        }

        // Initialize update scheduler
        print("   → Setting up update scheduler")
        setupUpdateScheduler()

        // Fetch initial data
        print("   → Calling refreshData()")
        await refreshData()
    }

    private func showDeviceCodeFlow() async {
        await MainActor.run {
            let deviceCodeView = DeviceCodeView(authManager: authManager) { [weak self] success in
                print("🎉 Auth callback - success: \(success)")
                if success {
                    // Close auth window
                    self?.authWindow?.close()
                    self?.authWindow = nil

                    Task {
                        await self?.showCalendarSelection()
                    }
                }
            }

            authWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            authWindow?.center()
            authWindow?.title = "Sign In to Office 365"
            authWindow?.contentView = NSHostingView(rootView: deviceCodeView)
            authWindow?.makeKeyAndOrderFront(nil)
        }
    }

    private func showCalendarSelection() async {
        do {
            print("📅 Fetching calendars...")
            let calendars = try await graphAPIService.fetchCalendars()
            print("✅ Found \(calendars.count) calendars")

            // Ensure we're on main thread and give a moment for any pending operations
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

            await MainActor.run {
                print("   📱 Creating calendar selection window on main thread...")

                // Close any existing calendar window first
                if let existingWindow = calendarWindow {
                    existingWindow.close()
                    calendarWindow = nil
                }

                let selectionView = CalendarSelectionView(
                    calendars: calendars,
                    onSelect: { [weak self] calendarId in
                        print("📌 Calendar selected: \(calendarId)")

                        var prefs = self?.storageManager.loadPreferences() ?? AppPreferences()
                        prefs.selectedCalendarId = calendarId
                        self?.storageManager.savePreferences(prefs)

                        // Close calendar window
                        self?.calendarWindow?.close()
                        self?.calendarWindow = nil

                        Task {
                            print("🔄 Setting up scheduler and refreshing data...")
                            self?.setupUpdateScheduler()
                            await self?.refreshData()
                        }
                    }
                )

                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                    styleMask: [.titled, .closable],
                    backing: .buffered,
                    defer: false
                )
                window.center()
                window.title = "Select Calendar"
                window.contentView = NSHostingView(rootView: selectionView)
                window.makeKeyAndOrderFront(nil)

                calendarWindow = window
                print("   ✅ Calendar window created and shown")
            }
        } catch {
            print("❌ Failed to fetch calendars: \(error)")
            await MainActor.run {
                errorMessage = "Failed to fetch calendars: \(error.localizedDescription)"
            }
        }
    }

    private func setupUpdateScheduler() {
        // Stop existing scheduler if running
        updateScheduler?.stop()

        let preferences = storageManager.loadPreferences()
        updateScheduler = UpdateScheduler(intervalMinutes: preferences.refreshIntervalMinutes) { [weak self] in
            await self?.refreshData()
        }
        updateScheduler.start()
    }

    private func refreshData() async {
        // Prevent concurrent refreshes
        let wasLoading = await MainActor.run { isLoading }
        if wasLoading {
            print("⏭️  Skipping refresh - already in progress")
            return
        }

        print("🔄 refreshData called")
        await MainActor.run {
            isLoading = true
        }

        do {
            let preferences = storageManager.loadPreferences()
            guard let calendarId = preferences.selectedCalendarId else {
                throw NSError(domain: "KeepTheBudget", code: 1, userInfo: [NSLocalizedDescriptionKey: "No calendar selected"])
            }
            print("   Calendar ID: \(calendarId)")

            // Get user email for filtering
            print("   Fetching user profile...")
            let userProfile = try await graphAPIService.fetchUserProfile()
            print("   User email: \(userProfile.mail)")

            // Calculate date ranges
            let (dailyStart, dailyEnd) = timeCalculator.getDailyRange()
            let (weeklyStart, weeklyEnd) = timeCalculator.getWeeklyRange()
            print("   Daily range: \(dailyStart) to \(dailyEnd)")
            print("   Weekly range: \(weeklyStart) to \(weeklyEnd)")

            // Fetch events
            print("   Fetching daily events...")
            let dailyEvents = try await graphAPIService.fetchEvents(
                calendarId: calendarId,
                from: dailyStart,
                to: dailyEnd
            )
            print("   Found \(dailyEvents.count) daily events")

            let weeklyEvents = try await graphAPIService.fetchEvents(
                calendarId: calendarId,
                from: weeklyStart,
                to: weeklyEnd
            )
            print("   Found \(weeklyEvents.count) weekly events")

            // Debug: Show organizer emails
            print("   🔍 User email: \(userProfile.mail)")
            if let firstEvent = dailyEvents.first {
                print("   🔍 First event organizer: \(firstEvent.organizerEmail)")
                print("   🔍 First event subject: \(firstEvent.subject)")
            }

            // Filter own events
            let ownDailyEvents = dailyEvents.filter { $0.organizerEmail.caseInsensitiveCompare(userProfile.mail) == .orderedSame }
            let ownWeeklyEvents = weeklyEvents.filter { $0.organizerEmail.caseInsensitiveCompare(userProfile.mail) == .orderedSame }

            print("   ✅ After filtering: \(ownDailyEvents.count) daily events, \(ownWeeklyEvents.count) weekly events")

            // Debug: Show first event details
            if let firstEvent = ownDailyEvents.first {
                print("   📅 First event: \(firstEvent.subject)")
                print("      Start: \(firstEvent.start)")
                print("      End: \(firstEvent.end)")
                print("      Duration: \(firstEvent.durationMinutes) minutes")
                print("      All-day: \(firstEvent.isAllDay)")
            }

            // Calculate totals
            let dailyMinutes = timeCalculator.calculateTotalMinutes(events: ownDailyEvents)
            let weeklyMinutes = timeCalculator.calculateTotalMinutes(events: ownWeeklyEvents)
            print("   ⏱️  Calculated: \(dailyMinutes) daily minutes, \(weeklyMinutes) weekly minutes")

            // Create summary
            let summary = TimeSummary(
                dailyMinutes: dailyMinutes,
                weeklyMinutes: weeklyMinutes,
                dailyGoalMinutes: preferences.dailyGoalMinutes,
                weeklyGoalMinutes: preferences.weeklyGoalMinutes
            )

            await MainActor.run {
                timeSummary = summary
                lastUpdateTime = Date()
                errorMessage = nil
                isLoading = false

                // Update menu bar display
                updateStatusItemDisplay(summary: summary, isLoading: false)
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                updateStatusItemDisplay(summary: nil, isLoading: false)
            }
        }
    }

    private func openSettings() {
        // Always recreate the window to avoid state issues
        let settingsView = SettingsView(
            storageManager: storageManager,
            authManager: authManager,
            graphAPIService: graphAPIService,
            onCalendarChange: { [weak self] in
                print("🔧 Calendar change requested from settings")
                Task {
                    // Close settings window first to avoid conflicts
                    await MainActor.run {
                        self?.settingsWindow?.close()
                        self?.settingsWindow = nil
                    }
                    await self?.showCalendarSelection()
                }
            }
        )

        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow?.center()
        settingsWindow?.title = "KeepTheBudget Settings"
        settingsWindow?.contentView = NSHostingView(rootView: settingsView)
        settingsWindow?.isReleasedWhenClosed = false

        // Set up close notification to clean up window reference
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: settingsWindow,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Handle URL callbacks from authentication
    func application(_ application: NSApplication, open urls: [URL]) {
        print("🔗 Received URL callback:")
        for url in urls {
            print("   URL: \(url.absoluteString)")
        }
        // Note: MSAL handles the callback internally when using interactive auth
        // The completion handler in acquireToken will be called
    }
}

// Extension to tint NSImage
extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()

        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)

        image.unlockFocus()
        return image
    }
}
