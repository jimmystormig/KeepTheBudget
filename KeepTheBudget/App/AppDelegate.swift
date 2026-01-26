//
//  AppDelegate.swift
//  KeepTheBudget
//
//  Manages the menu bar status item and application lifecycle
//

import Cocoa
import SwiftUI
import MSAL

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var authWindow: NSWindow?
    private var calendarWindow: NSWindow?
    private var configWindow: NSWindow?
    private var reportWindow: NSWindow?
    private var dailyReportWindow: NSWindow?

    // Services
    private var authManager: AuthManager!
    private var graphAPIService: GraphAPIService!
    private var timeCalculator: TimeCalculator!
    private var updateScheduler: UpdateScheduler!
    private var storageManager: StorageManager!
    private var calendarDataSource: CalendarDataSource!
    private var emailDataSource: EmailDataSource!
    private var chatDataSource: ChatDataSource!
    private lazy var aiAnalyzer = AIReportAnalyzer(storageManager: storageManager)

    // State
    @Published private var timeSummary: TimeSummary?
    @Published private var isLoading = false
    @Published private var lastUpdateTime: Date?
    @Published private var errorMessage: String?
    private var servicesInitialized = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize basic services
        storageManager = StorageManager()
        timeCalculator = TimeCalculator()

        // DON'T initialize AuthManager yet - it will be initialized after config check

        // Setup menu bar
        setupMenuBar()

        // Setup popover
        setupPopover()

        // CRITICAL: Load all keychain configuration in ONE operation to minimize prompts
        print("🔑 Loading keychain configuration snapshot...")
        let configSnapshot = storageManager.loadConfigurationSnapshot()

        // Auto-migrate existing users using the snapshot
        MigrationManager.migrateConfigurationIfNeeded(
            storageManager: storageManager,
            snapshot: configSnapshot
        )

        // Check configuration status FIRST
        Task {
            await checkConfigurationAndInitialize(configSnapshot: configSnapshot)
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
        popover.contentSize = NSSize(width: 300, height: 500)
        popover.behavior = .transient
    }

    private func checkConfigurationAndInitialize(configSnapshot: ConfigurationSnapshot) async {
        print("🔍 checkConfigurationAndInitialize() called")

        // Use snapshot to check configuration (no additional keychain access)
        let hasConfig = configSnapshot.hasConfiguration
        print("   Has configuration: \(hasConfig)")

        guard hasConfig else {
            print("   → Showing configuration setup")
            await showConfigurationSetup()
            return
        }

        // Initialize AuthManager with pre-loaded config from snapshot
        print("   → Creating AuthManager")
        authManager = AuthManager(storageManager: storageManager)

        do {
            print("   → Initializing AuthManager with snapshot values")
            try authManager.initialize(
                clientId: configSnapshot.clientId,
                tenantId: configSnapshot.tenantId
            )

            // Initialize GraphAPIService
            print("   → Creating GraphAPIService")
            graphAPIService = GraphAPIService(authManager: authManager)

            // Initialize data sources that depend on GraphAPIService
            print("   → Creating CalendarDataSource")
            calendarDataSource = CalendarDataSource(graphAPIService: graphAPIService, storageManager: storageManager)
            print("   → Creating EmailDataSource")
            emailDataSource = EmailDataSource(graphAPIService: graphAPIService, storageManager: storageManager)
            print("   → Creating ChatDataSource")
            chatDataSource = ChatDataSource(graphAPIService: graphAPIService, storageManager: storageManager)

            print("   ✅ Services created (but not fully initialized until auth + calendar selection)")

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

                // Restart initialization with fresh snapshot
                Task {
                    guard let self = self else { return }
                    let configSnapshot = self.storageManager.loadConfigurationSnapshot()
                    await self.checkConfigurationAndInitialize(configSnapshot: configSnapshot)
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
            configWindow?.isReleasedWhenClosed = false // Prevent premature deallocation
            configWindow?.makeKeyAndOrderFront(nil)

            // Disable close button until configured
            configWindow?.standardWindowButton(.closeButton)?.isEnabled = false
        }
    }

    private func updatePopoverContent() {
        guard popover.isShown else { return }

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
                onShowReport: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.openWeeklyReport()
                },
                onShowDailyReport: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.openDailyMeetingReport()
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                },
                onReauthenticate: { [weak self] in
                    self?.popover.performClose(nil)
                    Task { @MainActor in
                        self?.showReauthenticationPrompt(error: AppError.authenticationExpired)
                    }
                }
            )
        )
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
                        onShowReport: { [weak self] in
                            self?.popover.performClose(nil)
                            self?.openWeeklyReport()
                        },
                        onShowDailyReport: { [weak self] in
                            self?.popover.performClose(nil)
                            self?.openDailyMeetingReport()
                        },
                        onQuit: {
                            NSApplication.shared.terminate(nil)
                        },
                        onReauthenticate: { [weak self] in
                            self?.popover.performClose(nil)
                            Task { @MainActor in
                                self?.showReauthenticationPrompt(error: AppError.authenticationExpired)
                            }
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

        // Mark services as fully initialized (auth + calendar selection complete)
        servicesInitialized = true
        print("   ✅ All services FULLY initialized (auth + calendar complete)")

        // Initialize update scheduler
        print("   → Setting up update scheduler")
        setupUpdateScheduler()

        // Fetch initial data
        print("   → Calling refreshData()")
        await refreshData()
    }

    private func showDeviceCodeFlow() async {
        await MainActor.run {
            // Close any existing auth window first
            if let existingWindow = authWindow {
                existingWindow.close()
                authWindow = nil
            }

            let deviceCodeView = DeviceCodeView(authManager: authManager) { [weak self] success in
                print("🎉 Auth callback - success: \(success)")
                if success {
                    Task { @MainActor in
                        // Close auth window on main thread
                        self?.authWindow?.close()
                        self?.authWindow = nil

                        // Small delay to ensure window cleanup completes
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

                        await self?.showCalendarSelection()
                    }
                }
            }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Sign In to Office 365"
            window.contentView = NSHostingView(rootView: deviceCodeView)
            window.isReleasedWhenClosed = false // Prevent premature deallocation
            window.makeKeyAndOrderFront(nil)

            authWindow = window
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
                            // Mark services as fully initialized
                            self?.servicesInitialized = true
                            print("   ✅ Services FULLY initialized (after calendar selection)")
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
                window.isReleasedWhenClosed = false // Prevent premature deallocation
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
            updatePopoverContent()
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

            // Filter for events containing " - "
            let validDailyEvents = ownDailyEvents.filter { $0.isValidForTracking }
            let validWeeklyEvents = ownWeeklyEvents.filter { $0.isValidForTracking }

            print("   ✅ After organizer filter: \(ownDailyEvents.count) daily events, \(ownWeeklyEvents.count) weekly events")
            print("   ✅ After category filter: \(validDailyEvents.count) daily events, \(validWeeklyEvents.count) weekly events")
            if validDailyEvents.isEmpty && !ownDailyEvents.isEmpty {
                print("   ⚠️  WARNING: All daily events filtered out - no events contain ' - '")
            }

            // Debug: Show first event details
            if let firstEvent = ownDailyEvents.first {
                print("   📅 First event: \(firstEvent.subject)")
                print("      Start: \(firstEvent.start)")
                print("      End: \(firstEvent.end)")
                print("      Duration: \(firstEvent.durationMinutes) minutes")
                print("      All-day: \(firstEvent.isAllDay)")
            }

            // Calculate totals
            let dailyMinutes = timeCalculator.calculateTotalMinutes(events: validDailyEvents)
            let weeklyMinutes = timeCalculator.calculateTotalMinutes(events: validWeeklyEvents)
            print("   ⏱️  Calculated: \(dailyMinutes) daily minutes, \(weeklyMinutes) weekly minutes")

            // Calculate category breakdowns
            let dailyCategoryMinutes = timeCalculator.calculateCategoryBreakdown(events: validDailyEvents)
            let weeklyCategoryMinutes = timeCalculator.calculateCategoryBreakdown(events: validWeeklyEvents)
            print("   📊 Daily categories: \(dailyCategoryMinutes.keys.sorted().joined(separator: ", "))")
            print("   📊 Weekly categories: \(weeklyCategoryMinutes.keys.sorted().joined(separator: ", "))")

            // Create summary
            let summary = TimeSummary(
                dailyMinutes: dailyMinutes,
                weeklyMinutes: weeklyMinutes,
                dailyGoalMinutes: preferences.dailyGoalMinutes,
                weeklyGoalMinutes: preferences.weeklyGoalMinutes,
                dailyCategoryMinutes: dailyCategoryMinutes,
                weeklyCategoryMinutes: weeklyCategoryMinutes
            )

            await MainActor.run {
                timeSummary = summary
                lastUpdateTime = Date()
                errorMessage = nil
                isLoading = false

                // Update menu bar display
                updateStatusItemDisplay(summary: summary, isLoading: false)

                // Update popover if it's open
                updatePopoverContent()
            }

        } catch let error as AppError {
            // Handle structured errors
            print("   ❌ AppError: \(error.errorDescription ?? "Unknown error")")
            print("   📝 User-facing message: \(error.userFacingMessage)")
            print("   🔐 Can retry with reauth: \(error.canRetryWithReauth)")
            await MainActor.run {
                timeSummary = nil  // Clear old data to show error
                errorMessage = error.userFacingMessage
                isLoading = false
                updateStatusItemDisplay(summary: nil, isLoading: false)

                print("   📱 Error message set to: \(self.errorMessage ?? "nil")")
                print("   🔄 Updating popover content...")
                // Update popover if it's open
                updatePopoverContent()

                if error.canRetryWithReauth {
                    print("   🔐 Authentication error detected - offering re-auth")
                    showReauthenticationPrompt(error: error)
                }
            }
        } catch {
            // Handle unexpected errors
            print("   ❌ Unexpected error: \(error.localizedDescription)")
            print("   ❌ Error type: \(type(of: error))")
            print("   ❌ Error domain: \((error as NSError).domain)")
            await MainActor.run {
                timeSummary = nil  // Clear old data to show error
                errorMessage = "Unexpected error: \(error.localizedDescription)"
                isLoading = false
                updateStatusItemDisplay(summary: nil, isLoading: false)

                print("   📱 Error message set to: \(self.errorMessage ?? "nil")")
                // Update popover if it's open
                updatePopoverContent()
            }
        }
    }

    @MainActor
    private func showReauthenticationPrompt(error: AppError) {
        let alert = NSAlert()
        alert.messageText = "Authentication Required"
        alert.informativeText = error.userFacingMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Sign In Again")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User clicked "Sign In Again"
            print("🔐 User requested re-authentication")

            // Close any existing windows first to avoid conflicts
            authWindow?.close()
            authWindow = nil
            calendarWindow?.close()
            calendarWindow = nil

            authManager.signOut()
            Task {
                await self.showDeviceCodeFlow()
            }
        } else {
            // User clicked "Cancel"
            print("   User cancelled re-authentication")
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

    private func openWeeklyReport() {
        Task {
            await MainActor.run {
                // Get default date range (current week)
                let (weekStart, weekEnd) = timeCalculator.getWeeklyRange()

                let reportView = WeeklyReportView(
                    defaultStartDate: weekStart,
                    defaultEndDate: weekEnd,
                    onGenerateReport: { [weak self] startDate, endDate in
                        await self?.generateTimeReport(from: startDate, to: endDate)
                    },
                    onClose: { [weak self] in
                        self?.reportWindow?.close()
                        self?.reportWindow = nil
                    }
                )

                reportWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 550, height: 650),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                reportWindow?.center()
                reportWindow?.title = "Weekly Report"
                reportWindow?.contentView = NSHostingView(rootView: reportView)
                reportWindow?.isReleasedWhenClosed = false
                reportWindow?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func openDailyMeetingReport() {
        Task {
            await MainActor.run {
                // Get default date range (09:00 last workday → 09:00 today)
                let defaultStart = WorkdayCalculator.lastWorkdayAt(hour: 9, minute: 0)
                let defaultEnd = Date()

                let reportView = DailyMeetingReportView(
                    defaultStartDate: defaultStart,
                    defaultEndDate: defaultEnd,
                    onGenerateReport: { [weak self] startDate, endDate in
                        await self?.generateReport(from: startDate, to: endDate)
                    },
                    aiAnalyzer: aiAnalyzer,
                    storageManager: storageManager,
                    onClose: { [weak self] in
                        self?.dailyReportWindow?.close()
                        self?.dailyReportWindow = nil
                    }
                )

                dailyReportWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 600, height: 750),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                dailyReportWindow?.center()
                dailyReportWindow?.title = "Daily Meeting Report"
                dailyReportWindow?.contentView = NSHostingView(rootView: reportView)
                dailyReportWindow?.isReleasedWhenClosed = false
                dailyReportWindow?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func fetchEventsForReport(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        let preferences = storageManager.loadPreferences()
        guard let calendarId = preferences.selectedCalendarId else {
            throw NSError(domain: "KeepTheBudget", code: 1, userInfo: [NSLocalizedDescriptionKey: "No calendar selected"])
        }

        // Get user email for filtering
        let userProfile = try await graphAPIService.fetchUserProfile()

        // Fetch events for the date range
        let events = try await graphAPIService.fetchEvents(
            calendarId: calendarId,
            from: startDate,
            to: endDate
        )

        // Filter to only user's own events with valid tracking format
        let ownEvents = events.filter { $0.organizerEmail.caseInsensitiveCompare(userProfile.mail) == .orderedSame }
        let validEvents = ownEvents.filter { $0.isValidForTracking }

        return validEvents
    }

    // Generate TimeReport only (for WeeklyReportView)
    private func generateTimeReport(from startDate: Date, to endDate: Date) async -> TimeReport? {
        print("📊 AppDelegate.generateTimeReport() called")
        print("   servicesInitialized: \(servicesInitialized)")

        // Ensure services are initialized
        guard servicesInitialized, graphAPIService != nil else {
            print("❌ Services not initialized yet")
            return nil
        }

        do {
            print("   Generating time report from \(startDate) to \(endDate)")
            let events = try await fetchEventsForReport(from: startDate, to: endDate)
            print("   Found \(events.count) valid events")

            let reportGenerator = TimeReportGenerator(timeCalculator: timeCalculator)
            let report = reportGenerator.generateReport(from: events, startDate: startDate, endDate: endDate)
            print("   Generated report with \(report.firstLevelGroups.count) top-level groups")

            return report
        } catch {
            print("❌ Failed to generate report: \(error.localizedDescription)")
            return nil
        }
    }

    // Generate comprehensive report with emails (for DailyMeetingReportView)
    private func generateReport(from startDate: Date, to endDate: Date) async -> ComprehensiveReport? {
        print("📊 AppDelegate.generateReport() called")
        print("   servicesInitialized: \(servicesInitialized)")

        // Ensure services are initialized
        guard servicesInitialized, graphAPIService != nil, emailDataSource != nil, chatDataSource != nil else {
            print("❌ Services not ready")
            return nil
        }

        print("   ✅ All services confirmed initialized")

        do {
            print("   📡 Fetching calendar events, emails, and chats in parallel...")

            // Fetch calendar events, email threads, and chat conversations in parallel
            async let eventsTask = fetchEventsForReport(from: startDate, to: endDate)
            async let emailThreadsTask = emailDataSource.fetchEmailThreads(from: startDate, to: endDate)
            async let chatConversationsTask = chatDataSource.fetchChatConversations(from: startDate, to: endDate)

            let (events, emailThreads, chatConversations) = try await (eventsTask, emailThreadsTask, chatConversationsTask)

            print("   ✅ Found \(events.count) valid events")
            print("   ✅ Found \(emailThreads.count) email threads")
            print("   ✅ Found \(chatConversations.count) chat conversations")

            // Generate time report from calendar events
            let reportGenerator = TimeReportGenerator(timeCalculator: timeCalculator)
            let timeReport = reportGenerator.generateReport(from: events, startDate: startDate, endDate: endDate)
            print("   ✅ Generated report with \(timeReport.firstLevelGroups.count) top-level groups")

            // Create comprehensive report
            let comprehensiveReport = ComprehensiveReport(
                timeReport: timeReport,
                emailThreads: emailThreads,
                chatConversations: chatConversations,
                startDate: startDate,
                endDate: endDate
            )

            print("   🎉 Comprehensive report created successfully")
            return comprehensiveReport
        } catch {
            print("❌ Failed to generate report: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Localized: \(error.localizedDescription)")

            // Extract more details from AppError or DecodingError
            var detailedMessage = error.localizedDescription

            if let decodingError = error as? DecodingError {
                detailedMessage = "JSON Decoding Error:\n"
                switch decodingError {
                case .keyNotFound(let key, let context):
                    detailedMessage += "Missing key: '\(key.stringValue)'\nPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))"
                case .typeMismatch(let type, let context):
                    detailedMessage += "Type mismatch: expected \(type)\nPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))"
                case .valueNotFound(let type, let context):
                    detailedMessage += "Value not found: \(type)\nPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))"
                case .dataCorrupted(let context):
                    detailedMessage += "Data corrupted\n\(context.debugDescription)"
                @unknown default:
                    detailedMessage += "Unknown decoding error"
                }
            } else if let appError = error as? AppError {
                switch appError {
                case .graphAPIError(let statusCode, let message):
                    detailedMessage = """
                    HTTP Status: \(statusCode)
                    Response: \(message)

                    Status 403 = Missing Mail.Read permission
                    Status 401 = Authentication expired
                    """
                case .authenticationExpired:
                    detailedMessage = "Authentication token expired or invalid"
                case .networkError(let message):
                    detailedMessage = "Network error: \(message)"
                default:
                    break
                }
            }

            // Show error to user
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Report Generation Failed"
                alert.informativeText = """
                \(detailedMessage)

                Type: \(type(of: error))

                Solution:
                1. Go to Settings → Account
                2. Click "Sign Out"
                3. Quit the app completely (⌘Q)
                4. Restart the app
                5. Sign in again (you SHOULD see a consent prompt for Mail.Read)
                """
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }

            return nil
        }
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
