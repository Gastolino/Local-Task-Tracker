import SwiftUI

/// Main view: month calendar heatmap on the left, day detail on the right.
struct CalendarView: View {

    @EnvironmentObject var appState: AppState

    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var monthData: [DayActivity] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        HStack(spacing: 0) {
            // ── Left panel: calendar ───────────────────────────────────────
            VStack(spacing: 16) {
                monthHeader
                weekdayRow
                dayGrid
                Spacer()
            }
            .padding(20)
            .frame(width: 320)
            .background(.background)

            Divider()

            // ── Right panel: day detail ────────────────────────────────────
            DayDetailView(date: selectedDate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { reload() }
        .onChange(of: currentMonth) { _ in reload() }
    }

    // MARK: - Sub-views

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            Text(currentMonth, format: .dateTime.month(.wide).year())
                .font(.title3.bold())

            Spacer()

            Button { shiftMonth(+1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month))
        }
    }

    private var weekdayRow: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            // Blank cells before the first day of the month.
            ForEach(0..<firstWeekday, id: \.self) { _ in
                Color.clear.frame(height: 36)
            }

            // Day cells.
            ForEach(daysInMonth, id: \.self) { date in
                DayCellView(
                    date: date,
                    activity: activityFor(date),
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                    isToday: Calendar.current.isDateInToday(date)
                )
                .onTapGesture { selectedDate = date }
            }
        }
    }

    // MARK: - Helpers

    private func reload() {
        let cal = Calendar.current
        let y = cal.component(.year,  from: currentMonth)
        let m = cal.component(.month, from: currentMonth)
        monthData = DatabaseService.shared.monthActivities(year: y, month: m)
    }

    private func activityFor(_ date: Date) -> DayActivity? {
        let key = ymd(date)
        return monthData.first { $0.id == key }
    }

    private var firstWeekday: Int {
        let first = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: currentMonth)
        )!
        return Calendar.current.component(.weekday, from: first) - 1
    }

    private var daysInMonth: [Date] {
        let cal   = Calendar.current
        let range = cal.range(of: .day, in: .month, for: currentMonth)!
        let first = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth))!
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    private func shiftMonth(_ delta: Int) {
        currentMonth = Calendar.current.date(
            byAdding: .month, value: delta, to: currentMonth
        ) ?? currentMonth
    }

    private func ymd(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }
}

// MARK: - Day cell

struct DayCellView: View {

    let date: Date
    let activity: DayActivity?
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(cellBackground)

            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? .accentColor : .primary))

                // Tiny dot if there's activity.
                if let a = activity, a.activePolls > 0 {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.8) : .accentColor.opacity(0.7))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 40)
    }

    private var cellBackground: Color {
        if isSelected { return .accentColor }
        guard let a = activity, a.intensity > 0 else {
            return Color.clear
        }
        return Color.accentColor.opacity(0.12 + a.intensity * 0.55)
    }
}
