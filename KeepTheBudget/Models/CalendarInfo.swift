//
//  CalendarInfo.swift
//  KeepTheBudget
//
//  Represents a calendar from Office 365
//

import Foundation

struct CalendarInfo: Codable, Identifiable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}
