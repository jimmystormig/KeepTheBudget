//
//  KeepTheBudgetApp.swift
//  KeepTheBudget
//
//  Office 365 Calendar Time Tracker
//

import SwiftUI

@main
struct KeepTheBudgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
