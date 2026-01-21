//
//  UserProfile.swift
//  KeepTheBudget
//
//  Represents a user profile from Microsoft Graph
//

import Foundation

struct UserProfile: Codable {
    let id: String
    let mail: String
    let displayName: String?
    let userPrincipalName: String?
}
