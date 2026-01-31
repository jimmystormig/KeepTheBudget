//
//  OAuthModels.swift
//  KeepTheBudget
//
//  OAuth 2.0 response models for device code flow and token management
//

import Foundation

/// Response from device code initiation endpoint
struct DeviceCodeResponse: Codable {
    let userCode: String
    let deviceCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case userCode = "user_code"
        case deviceCode = "device_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

/// Response from token endpoints (both device code and refresh token)
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

/// Error response from OAuth endpoints
struct OAuthErrorResponse: Codable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
