//
//  AppError.swift
//  KeepTheBudget
//
//  Structured error types for better error handling and user communication
//

import Foundation

enum AppError: LocalizedError {
    case authenticationExpired
    case authenticationFailed(String)
    case networkError(String)
    case graphAPIError(Int, String)
    case noCalendar
    case configurationError(String)

    var errorDescription: String? {
        switch self {
        case .authenticationExpired:
            return "Authentication token has expired"
        case .authenticationFailed(let details):
            return "Authentication failed: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .graphAPIError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .noCalendar:
            return "No calendar selected"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        }
    }

    /// User-facing message for display in UI
    var userFacingMessage: String {
        switch self {
        case .authenticationExpired:
            return "Session expired. Please sign in again."
        case .authenticationFailed(let details):
            return "Sign-in failed: \(details)"
        case .networkError:
            return "Network connection issue. Please check your internet connection."
        case .graphAPIError(let statusCode, _):
            if statusCode == 403 {
                return "Access denied. Please check calendar permissions."
            } else if statusCode >= 500 {
                return "Server error. Please try again later."
            } else {
                return "Unable to fetch calendar data (error \(statusCode))."
            }
        case .noCalendar:
            return "No calendar selected. Please select a calendar in Settings."
        case .configurationError:
            return "App configuration error. Please check Settings."
        }
    }

    /// Whether re-authentication can potentially fix this error
    var canRetryWithReauth: Bool {
        switch self {
        case .authenticationExpired, .authenticationFailed:
            return true
        case .networkError, .graphAPIError, .noCalendar, .configurationError:
            return false
        }
    }

    /// Whether this is an authentication-related error
    var isAuthenticationError: Bool {
        switch self {
        case .authenticationExpired, .authenticationFailed:
            return true
        case .networkError, .graphAPIError, .noCalendar, .configurationError:
            return false
        }
    }
}
