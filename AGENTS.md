# AGENTS.md

This file is the agent-facing working guide for `KeepTheBudget`. It consolidates what is accurate from `CLAUDE.md` and updates it to match the current codebase.

## 1) Project Snapshot

- App type: macOS menu bar app (`SwiftUI + AppKit`) for Microsoft 365 work activity tracking.
- Primary capabilities: calendar-based daily/weekly tracking, category-based goal filtering, weekly hierarchical reports, daily comprehensive reports (calendar+email+chat), optional Azure OpenAI analysis.
- Stack: Swift 5.9, macOS 12.0 target, MSAL via SwiftPM, Microsoft Graph v1.0.

## 2) Current Architecture (Code-Accurate)

- Coordinator: `KeepTheBudget/App/AppDelegate.swift` owns window lifecycle, menu bar state, auth/config/setup flow, refresh loop, and report generation.
- Services:
- `KeepTheBudget/Services/AuthManager.swift`: configuration-aware auth, token lifecycle, refresh, sign-out.
- `KeepTheBudget/Services/GraphAPIService.swift`: Graph calls for profile, calendars, events, emails, chats.
- `KeepTheBudget/Services/StorageManager.swift`: Keychain + UserDefaults, including configuration bundle snapshot loading.
- `KeepTheBudget/Services/TimeCalculator.swift`: date ranges, minutes, category and goal-eligible calculations.
- `KeepTheBudget/Services/UpdateScheduler.swift`: periodic refresh timer.
- `KeepTheBudget/Services/EmailDataSource.swift`: groups emails into `EmailThread`.
- `KeepTheBudget/Services/ChatDataSource.swift`: fetches/sorts chat conversations.
- `KeepTheBudget/Services/AIReportAnalyzer.swift`: Azure OpenAI request/response handling for report analysis.
- Models: calendar/time models (`CalendarEvent`, `TimeSummary`, `TimeReport`), communication models (`EmailMessage`, `EmailThread`, `ChatConversation`), AI models (`AIReportAnalysis`, correlation/priority types, config).
- Views: menu bar popover (`PopoverView`), settings tabs (`SettingsView` + `AISettingsTab`), setup views (`ConfigurationSetupView`, `DeviceCodeView`, `CalendarSelectionView`), report views (`WeeklyReportView`, `DailyMeetingReportView`).

## 3) Launch and Data Flow

1. App starts and loads a keychain configuration snapshot once.
2. Migration runs (`MigrationManager`) for legacy users.
3. If no Client ID/Tenant ID: show configuration setup window.
4. `AuthManager.initialize(clientId:tenantId:)` runs after config exists.
5. If no valid tokens: show device code auth flow.
6. If no selected calendar: show calendar selection.
7. Mark services initialized, start scheduler, run initial refresh.
8. Refresh fetches user profile + daily/weekly events, filters to organizer == current user, computes totals/category metrics, and updates menu UI.
9. Weekly report uses calendar events only.
10. Daily meeting report fetches calendar + email + chats in parallel and can run AI analysis.

## 4) Graph + Scopes (Current)

- Endpoints in `KeepTheBudget/Utilities/Constants.swift`: `/me`, `/me/calendars`, `/me/calendars/{id}/events`, `/me/messages`, `/me/chats`, `/me/chats/{id}/messages`.
- Current scopes (`GraphConstants.scopes`): `Calendars.Read`, `User.Read`, `Mail.Read`, `Chat.Read`.
- OAuth scopes (`OAuthConstants.scopes`) include `offline_access`.

## 5) State/Threading Rules

- AppKit/UI work must stay on main thread (`MainActor.run`) for NSWindow/NSView operations.
- `AppDelegate` updates published UI state and window operations from main actor paths.
- `refreshData()` has a reentry guard via `isLoading`.

## 6) Time/Goal Logic

- Daily range: start of local day to now.
- Weekly range: Monday-start week via date extensions.
- All-day events: fixed 480 minutes.
- Goal status is based on goal-eligible minutes, not always raw total minutes.
- Category extraction: text before `" - "` in event subject.
- If category filtering is disabled, all events count toward goals.

## 7) Important Config/Storage Behavior

- Secrets/config in Keychain: access token, refresh token, token expiry, MSAL Client ID/Tenant ID, Azure OpenAI endpoint/key/deployment.
- `StorageManager` uses a keychain configuration bundle for single-shot startup reads to reduce repeated keychain prompts.
- User preferences in `UserDefaults` (goals, selected calendar, refresh interval, category filtering options).

## 8) Build/Run Commands

```bash
# Build
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Debug build

# Open in Xcode
open KeepTheBudget.xcodeproj

# Regenerate project after project.yml changes
xcodegen generate
```

## 9) CLAUDE.md Drift Notes (Important)

`CLAUDE.md` is mostly accurate on core auth/threading architecture, but these parts are outdated versus current code:

- App scope has expanded beyond calendar-only tracking: email and Teams chat ingestion exists (`EmailDataSource`, `ChatDataSource`, Graph email/chat endpoints), and AI analysis exists (Azure OpenAI config + analyzer + UI).
- Scope list changed:
- `GraphConstants.scopes` now includes `Mail.Read` and `Chat.Read`.
- `TimeSummary` status values are `.normal` / `.overGoal` (not `underGoal/onTarget/overGoal`).
- Menu display has single-line and conditional two-line modes when category filtering is enabled and totals differ from goal-eligible totals.
- Reports are first-class features (weekly + daily comprehensive), not just popover summaries.

## 10) Agent Working Rules for This Repo

- Prefer updating `project.yml` for project config changes, then regenerate Xcode project.
- Keep AppKit window creation and SwiftUI-to-`NSHostingView` bridging on main thread.
- Do not hardcode Client ID/Tenant ID/API keys in source.
- Preserve organizer-based filtering unless explicitly requested otherwise.
- When changing auth/scopes, verify interactions across `KeepTheBudget/Utilities/Constants.swift`, `KeepTheBudget/Services/AuthManager.swift`, `KeepTheBudget/Services/GraphAPIService.swift`, settings/configuration UI, and storage.
- For report changes, verify both report paths: `KeepTheBudget/Views/Components/WeeklyReportView.swift` (`TimeReport`) and `KeepTheBudget/Views/Components/DailyMeetingReportView.swift` (`ComprehensiveReport` + optional AI analysis).
