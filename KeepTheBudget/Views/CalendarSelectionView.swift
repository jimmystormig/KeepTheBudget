//
//  CalendarSelectionView.swift
//  KeepTheBudget
//
//  Allows user to select which calendar to track
//

import SwiftUI

struct CalendarSelectionView: View {
    let calendars: [CalendarInfo]
    let onSelect: (String) -> Void

    @State private var selectedCalendarId: String?
    @State private var isInitialized = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Select Calendar to Track")
                .font(.title)
                .fontWeight(.bold)

            Text("Choose which calendar you want to track time from")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(calendars) { calendar in
                        CalendarRow(
                            calendar: calendar,
                            isSelected: selectedCalendarId == calendar.id
                        )
                        .onTapGesture {
                            selectedCalendarId = calendar.id
                        }
                    }
                }
                .padding(.horizontal)
            }

            Divider()

            Button("Continue") {
                if let calendarId = selectedCalendarId {
                    onSelect(calendarId)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedCalendarId == nil)

            Spacer()
        }
        .padding(30)
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            guard !isInitialized else { return }
            isInitialized = true

            // Pre-select first calendar if available
            if let firstCalendar = calendars.first {
                selectedCalendarId = firstCalendar.id
            }
        }
    }
}

struct CalendarRow: View {
    let calendar: CalendarInfo
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(isSelected ? .blue : .gray)

            Text(calendar.name)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .goldenGateSurface(cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}
