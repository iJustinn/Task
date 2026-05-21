import SwiftUI

struct CalendarPicker: View {
    enum Mode {
        case single(Binding<Date?>)
        case range(Binding<Date?>, Binding<Date?>)
    }

    let mode: Mode
    var minimumDate: Date? = nil
    var maximumDate: Date? = nil

    @State private var visibleMonthStart: Date

    private let calendar: Calendar = .current
    private let dayCellHeight: CGFloat = 50

    init(selectedDate: Binding<Date?>, minimumDate: Date? = nil, maximumDate: Date? = nil) {
        self.mode = .single(selectedDate)
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        let initial = selectedDate.wrappedValue ?? Date()
        self._visibleMonthStart = State(initialValue: Self.monthStart(for: initial))
    }

    init(rangeStart: Binding<Date?>, rangeEnd: Binding<Date?>, minimumDate: Date? = nil, maximumDate: Date? = nil) {
        self.mode = .range(rangeStart, rangeEnd)
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        let initial = rangeStart.wrappedValue ?? rangeEnd.wrappedValue ?? Date()
        self._visibleMonthStart = State(initialValue: Self.monthStart(for: initial))
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 30), spacing: 0), count: 7)
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
        }
        .onChange(of: focusDate) { _, newValue in
            guard let newValue else { return }
            let monthStart = Self.monthStart(for: newValue)
            if !calendar.isDate(monthStart, equalTo: visibleMonthStart, toGranularity: .month) {
                visibleMonthStart = monthStart
            }
        }
    }

    private var focusDate: Date? {
        switch mode {
        case .single(let binding): return binding.wrappedValue
        case .range(let start, let end): return start.wrappedValue ?? end.wrappedValue
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text(monthTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 8) {
                todayButton
                monthButton(systemName: "chevron.left", isEnabled: canMovePrev) { moveMonth(by: -1) }
                monthButton(systemName: "chevron.right", isEnabled: canMoveNext) { moveMonth(by: 1) }
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.35))
                .frame(width: 34, height: 34)
                .background(Color.primary.opacity(isEnabled ? 0.09 : 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var todayButton: some View {
        let enabled = isSelectable(Date())
        return Button {
            guard enabled else { return }
            jumpToToday()
        } label: {
            Text("Today")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(enabled ? .primary : .secondary.opacity(0.35))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color.primary.opacity(enabled ? 0.09 : 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func jumpToToday() {
        let today = calendar.startOfDay(for: Date())
        visibleMonthStart = Self.monthStart(for: today)
        switch mode {
        case .single(let binding):
            binding.wrappedValue = today
        case .range(let startBinding, let endBinding):
            startBinding.wrappedValue = today
            endBinding.wrappedValue = nil
        }
    }

    // MARK: - Day cells

    @ViewBuilder
    private func dayCell(_ day: Int?) -> some View {
        if let day, let date = date(forDay: day) {
            let isEnabled = isSelectable(date)
            let state = cellState(for: date)
            Button {
                guard isEnabled else { return }
                tap(date)
            } label: {
                cellContent(day: day, date: date, state: state, isEnabled: isEnabled)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        } else {
            Color.clear.frame(height: dayCellHeight)
        }
    }

    private func cellContent(day: Int, date: Date, state: CellState, isEnabled: Bool) -> some View {
        let isToday = calendar.isDateInToday(date)
        return ZStack {
            stripBackground(state: state)
            endpointBackground(state: state, isToday: isToday, isEnabled: isEnabled)
            Text("\(day)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(textColor(state: state, isEnabled: isEnabled))
        }
        .frame(maxWidth: .infinity)
        .frame(height: dayCellHeight)
    }

    private func stripBackground(state: CellState) -> some View {
        let stripColor = Color.accentColor.opacity(0.18)
        return HStack(spacing: 0) {
            Rectangle()
                .fill(state.hasLeftStrip ? stripColor : Color.clear)
            Rectangle()
                .fill(state.hasRightStrip ? stripColor : Color.clear)
        }
        .frame(height: 40)
    }

    @ViewBuilder
    private func endpointBackground(state: CellState, isToday: Bool, isEnabled: Bool) -> some View {
        switch state {
        case .none where isEnabled:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isToday ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                )
        case .none:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .frame(width: 44, height: 44)
        case .singleSelected, .start, .end:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor)
                .frame(width: 44, height: 44)
        case .between:
            EmptyView()
        }
    }

    private func textColor(state: CellState, isEnabled: Bool) -> Color {
        guard isEnabled else { return .secondary.opacity(0.35) }
        switch state {
        case .singleSelected, .start, .end: return .white
        case .between: return .primary
        case .none: return .primary
        }
    }

    // MARK: - State

    private enum CellState {
        case none
        case singleSelected
        case start
        case between
        case end

        var hasLeftStrip: Bool {
            switch self {
            case .between, .end: return true
            default: return false
            }
        }

        var hasRightStrip: Bool {
            switch self {
            case .between, .start: return true
            default: return false
            }
        }
    }

    private func cellState(for date: Date) -> CellState {
        let day = calendar.startOfDay(for: date)
        switch mode {
        case .single(let binding):
            if let selected = binding.wrappedValue, calendar.isDate(day, inSameDayAs: selected) {
                return .singleSelected
            }
            return .none
        case .range(let startBinding, let endBinding):
            let start = startBinding.wrappedValue.map { calendar.startOfDay(for: $0) }
            let end = endBinding.wrappedValue.map { calendar.startOfDay(for: $0) }
            guard let start else { return .none }
            if let end {
                if calendar.isDate(day, inSameDayAs: start) && calendar.isDate(start, inSameDayAs: end) {
                    return .singleSelected
                }
                if calendar.isDate(day, inSameDayAs: start) { return .start }
                if calendar.isDate(day, inSameDayAs: end) { return .end }
                if day > start && day < end { return .between }
                return .none
            } else {
                if calendar.isDate(day, inSameDayAs: start) { return .singleSelected }
                return .none
            }
        }
    }

    // MARK: - Tap

    private func tap(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        switch mode {
        case .single(let binding):
            if let current = binding.wrappedValue, calendar.isDate(current, inSameDayAs: day) {
                binding.wrappedValue = nil
            } else {
                binding.wrappedValue = day
            }
        case .range(let startBinding, let endBinding):
            tapRange(day: day, startBinding: startBinding, endBinding: endBinding)
        }
    }

    private func tapRange(day: Date, startBinding: Binding<Date?>, endBinding: Binding<Date?>) {
        let start = startBinding.wrappedValue.map { calendar.startOfDay(for: $0) }
        let end = endBinding.wrappedValue.map { calendar.startOfDay(for: $0) }

        if start == nil && end == nil {
            startBinding.wrappedValue = day
            return
        }

        if let s = start, end == nil {
            if calendar.isDate(day, inSameDayAs: s) {
                startBinding.wrappedValue = nil
            } else if day < s {
                startBinding.wrappedValue = day
            } else {
                endBinding.wrappedValue = day
            }
            return
        }

        if let s = start, let e = end {
            if calendar.isDate(day, inSameDayAs: e) {
                endBinding.wrappedValue = nil
                return
            }
            if calendar.isDate(day, inSameDayAs: s) {
                startBinding.wrappedValue = e
                endBinding.wrappedValue = nil
                return
            }
            startBinding.wrappedValue = day
            endBinding.wrappedValue = nil
        }
    }

    // MARK: - Helpers

    private var calendarDays: [Int?] {
        guard let days = calendar.range(of: .day, in: .month, for: visibleMonthStart) else { return [] }
        return Array(repeating: nil, count: leadingEmptyDays) + days.map { Optional($0) }
    }

    private var leadingEmptyDays: Int {
        let weekday = calendar.component(.weekday, from: visibleMonthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var monthTitle: String {
        visibleMonthStart.formatted(.dateTime.month(.wide).year())
    }

    private var canMovePrev: Bool {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: visibleMonthStart) else { return false }
        if let min = minimumDate {
            return Self.monthStart(for: prev) >= Self.monthStart(for: min)
        }
        return true
    }

    private var canMoveNext: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: visibleMonthStart) else { return false }
        if let max = maximumDate {
            return Self.monthStart(for: next) <= Self.monthStart(for: max)
        }
        return true
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
    }

    private func date(forDay day: Int) -> Date? {
        let comps = calendar.dateComponents([.year, .month], from: visibleMonthStart)
        return calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: day))
    }

    private func isSelectable(_ date: Date) -> Bool {
        if let min = minimumDate, calendar.startOfDay(for: date) < calendar.startOfDay(for: min) { return false }
        if let max = maximumDate, calendar.startOfDay(for: date) > calendar.startOfDay(for: max) { return false }
        return true
    }

    private func moveMonth(by offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: visibleMonthStart) else { return }
        visibleMonthStart = next
    }

    private static func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }
}
