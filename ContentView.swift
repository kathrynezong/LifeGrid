import SwiftUI
import CoreData
import PhotosUI
import Charts
#if os(iOS)
import AVFoundation
import Speech
#endif
#if canImport(AppKit)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("morningHour") private var morningHour = 8
    @AppStorage("morningMinute") private var morningMinute = 0
    @AppStorage("eveningHour") private var eveningHour = 20
    @AppStorage("eveningMinute") private var eveningMinute = 0

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.createdAt, ascending: true)],
        animation: .default
    ) private var profiles: FetchedResults<UserProfile>

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView(profile: profile)
            } else {
                OnboardingView { birthDate, country, gender, isSmoker, hasChronicCondition in
                    createProfile(
                        birthDate: birthDate,
                        country: country,
                        gender: gender,
                        isSmoker: isSmoker,
                        hasChronicCondition: hasChronicCondition
                    )
                }
            }
        }
        .onAppear {
            NotificationService.shared.requestAuthorization { _ in
                NotificationService.shared.scheduleDailyReminders(
                    morningHour: morningHour,
                    morningMinute: morningMinute,
                    eveningHour: eveningHour,
                    eveningMinute: eveningMinute
                )
            }
        }
    }

    private func createProfile(
        birthDate: Date,
        country: String,
        gender: String,
        isSmoker: Bool,
        hasChronicCondition: Bool
    ) {
        let profile = UserProfile(context: viewContext)
        profile.birthDate = birthDate
        profile.country = country
        profile.gender = gender
        profile.isSmoker = isSmoker
        profile.hasChronicCondition = hasChronicCondition
        profile.createdAt = Date()

        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
        }
    }
}

private struct MainTabView: View {
    @ObservedObject var profile: UserProfile

    var body: some View {
        TabView {
            LifeGridView(profile: profile)
                .tabItem { Label("Grid", systemImage: "square.grid.3x3") }

            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar") }

            SettingsView(profile: profile)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

private struct OnboardingView: View {
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var country = "United States"
    @State private var gender = "Female"
    @State private var isSmoker = false
    @State private var hasChronicCondition = false

    let onComplete: (Date, String, String, Bool, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)
                    TextField("Country", text: $country)
                    Picker("Gender", selection: $gender) {
                        Text("Female").tag("Female")
                        Text("Male").tag("Male")
                        Text("Other").tag("Other")
                    }
                }

                Section("Health Factors") {
                    Toggle("Smoker", isOn: $isSmoker)
                    Toggle("Chronic Condition", isOn: $hasChronicCondition)
                }

                Section {
                    Button("Get Started") {
                        onComplete(birthDate, country, gender, isSmoker, hasChronicCondition)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Welcome to LifeGrid")
        }
    }
}

private struct LifeGridView: View {
    @ObservedObject var profile: UserProfile

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DayEntry.date, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<DayEntry>

    @State private var selectedDay: SelectedDay?
    @State private var displayedMonth = LifeGridView.startOfCurrentMonth()

    private let monthColumns = Array(repeating: GridItem(.flexible(minimum: 28, maximum: 52), spacing: 6), count: 7)

    private var expectancyRange: LifeExpectancyCalculator.ExpectancyRange {
        LifeExpectancyCalculator.estimateRange(
            birthDate: profile.birthDate ?? Date(),
            country: profile.country ?? "United States",
            gender: profile.gender ?? "Other",
            isSmoker: profile.isSmoker,
            hasChronicCondition: profile.hasChronicCondition
        )
    }

    private var age: Int {
        Calendar.current.dateComponents([.year], from: profile.birthDate ?? Date(), to: Date()).year ?? 0
    }

    private var daysLived: Int {
        max(Calendar.current.dateComponents([.day], from: profile.birthDate ?? Date(), to: Date()).day ?? 0, 0)
    }

    private var averageTotalDays: Int {
        max(expectancyRange.averageYears * 365, daysLived + 1)
    }

    private var lowerTotalDays: Int {
        max(expectancyRange.lowerYears * 365, daysLived + 1)
    }

    private var upperTotalDays: Int {
        max(expectancyRange.upperYears * 365, averageTotalDays + 1)
    }

    private var averageDaysLeft: Int {
        max(averageTotalDays - daysLived, 0)
    }

    private var daysLeftRange: ClosedRange<Int> {
        max(lowerTotalDays - daysLived, 0)...max(upperTotalDays - daysLived, 0)
    }

    private var livedRatio: Double {
        min(max(Double(daysLived) / Double(upperTotalDays), 0), 1)
    }

    private var totalLoggedDays: Int {
        let loggedDays: Set<Date> = Set(entries.compactMap { entry in
            guard let date = entry.date else { return nil }
            return Calendar.current.startOfDay(for: date)
        })
        return loggedDays.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        StatCard(title: "Age", value: "\(age)")
                        StatCard(
                            title: "Estimate Life Expectancy",
                            value: "\(expectancyRange.lowerYears)-\(expectancyRange.upperYears)"
                        )
                        StatCard(title: "Logged", value: "\(totalLoggedDays)")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Lived: \(daysLived) days")
                                .font(.subheadline)
                            Spacer()
                            Text("Left: \(daysLeftRange.lowerBound)-\(daysLeftRange.upperBound) days (avg \(averageDaysLeft))")
                                .font(.subheadline)
                        }

                        GeometryReader { geometry in
                            let livedWidth = geometry.size.width * livedRatio
                            let remainingWidth = max(geometry.size.width - livedWidth, 0)
                            let sigmaDays = max(expectancyRange.stdDevYears * 365, 1)
                            let averageRemaining = Double(averageTotalDays - daysLived)
                            let remainingHorizon = max(Double(upperTotalDays - daysLived), 1)
                            let mean = min(max(averageRemaining / remainingHorizon, 0), 1)
                            let oneLow = min(max((averageRemaining - sigmaDays) / remainingHorizon, 0), 1)
                            let oneHigh = min(max((averageRemaining + sigmaDays) / remainingHorizon, 0), 1)
                            let twoLow = min(max((averageRemaining - (2 * sigmaDays)) / remainingHorizon, 0), 1)
                            let twoHigh = min(max((averageRemaining + (2 * sigmaDays)) / remainingHorizon, 0), 1)
                            let markerLabelWidth: CGFloat = 80
                            let milestones: [(position: Double, label: String)] = [
                                (min(max(Double(daysLived) / Double(upperTotalDays), 0), 1), "Now \(age)y"),
                                (min(max(Double(lowerTotalDays) / Double(upperTotalDays), 0), 1), "-2σ \(expectancyRange.lowerYears)y"),
                                (min(max(Double(averageTotalDays) / Double(upperTotalDays), 0), 1), "Avg \(expectancyRange.averageYears)y"),
                                (min(max(Double(upperTotalDays) / Double(upperTotalDays), 0), 1), "+2σ \(expectancyRange.upperYears)y")
                            ]

                            ZStack(alignment: .topLeading) {
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: livedWidth)
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: Color.green.opacity(0.12), location: 0),
                                                    .init(color: Color.green.opacity(0.28), location: twoLow),
                                                    .init(color: Color.green.opacity(0.52), location: oneLow),
                                                    .init(color: Color.green.opacity(1.0), location: mean),
                                                    .init(color: Color.green.opacity(0.52), location: oneHigh),
                                                    .init(color: Color.green.opacity(0.28), location: twoHigh),
                                                    .init(color: Color.green.opacity(0.12), location: 1)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: remainingWidth)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 0.75)
                                )

                                ForEach(Array(milestones.enumerated()), id: \.offset) { _, marker in
                                    let rawX = CGFloat(marker.position) * geometry.size.width
                                    let clampedX = min(max(rawX, markerLabelWidth / 2), geometry.size.width - markerLabelWidth / 2)
                                    ZStack(alignment: .topLeading) {
                                        Rectangle()
                                            .fill(Color.primary.opacity(0.7))
                                            .frame(width: 1, height: 16)
                                            .position(x: rawX, y: 8)

                                        Text(marker.label)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .frame(width: markerLabelWidth, alignment: .center)
                                            .position(x: clampedX, y: 25)
                                    }
                                }
                            }
                        }
                        .frame(height: 42)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(monthTitle(for: displayedMonth))
                                .font(.headline)
                            Spacer()
                            Button("Today") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    displayedMonth = currentMonthStart
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .disabled(isSameMonth(displayedMonth, currentMonthStart))
                        }

                        HStack(spacing: 10) {
                            Button {
                                shiftMonth(by: -1)
                            } label: {
                                Label("Previous", systemImage: "chevron.left")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                shiftMonth(by: 1)
                            } label: {
                                Label("Next", systemImage: "chevron.right")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.bordered)
                        }

                        monthSection(for: displayedMonth)
                    }

                    Text("Use arrows, then tap any day to open details.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Life Grid")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                ToolbarItem(placement: .principal) {
                    Text("Make Every Day Meaningful!")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 10) {
                        Text("Life Grid")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("Make Every Day Meaningful!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            #endif
            #if os(iOS)
            .fullScreenCover(item: $selectedDay) { day in
                DayEntryEditorView(
                    date: day.date,
                    existingEntry: entryForDay(day.date),
                    onClose: { selectedDay = nil }
                )
            }
            #else
            .sheet(item: $selectedDay) { day in
                DayEntryEditorView(
                    date: day.date,
                    existingEntry: entryForDay(day.date),
                    onClose: { selectedDay = nil }
                )
                    .frame(minWidth: 560, minHeight: 640)
            }
            #endif
        }
    }

    private static func startOfCurrentMonth() -> Date {
        let calendar = Calendar.current
        let today = Date()
        return calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
    }

    private var currentMonthStart: Date {
        Self.startOfCurrentMonth()
    }

    private func shiftMonth(by value: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = newMonth
        }
    }

    private func isSameMonth(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, equalTo: rhs, toGranularity: .month)
            && Calendar.current.isDate(lhs, equalTo: rhs, toGranularity: .year)
    }

    private func entryForDay(_ day: Date) -> DayEntry? {
        entries.first { entry in
            guard let date = entry.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: day)
        }
    }

    private func isSelected(_ day: Date) -> Bool {
        guard let selectedDay else { return false }
        return Calendar.current.isDate(selectedDay.date, inSameDayAs: day)
    }

    private func isToday(_ day: Date) -> Bool {
        Calendar.current.isDateInToday(day)
    }

    private func color(for entry: DayEntry?) -> Color {
        guard let entry else { return Color.gray.opacity(0.2) }
        switch entry.qualityScore {
        case 9...10: return Color.green
        case 7...8: return Color.mint
        case 5...6: return Color.yellow
        case 3...4: return Color.orange
            default: return Color.red.opacity(0.8)
        }
    }

    private func monthSection(for month: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: monthColumns, spacing: 8) {
                ForEach(weekdaySymbols(), id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(daysInMonth(for: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        let entry = entryForDay(day)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color(for: entry))
                            .frame(height: 38)
                            .overlay(
                                Text(day.formatted(.dateTime.day()))
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isSelected(day) ? Color.accentColor : (isToday(day) ? Color.secondary.opacity(0.5) : Color.clear),
                                        lineWidth: isSelected(day) ? 1.8 : 1.1
                                    )
                            )
                            .scaleEffect(isSelected(day) ? 1.06 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: selectedDay?.id)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    selectedDay = SelectedDay(date: day)
                                }
                            }
                    } else {
                        Color.clear
                            .frame(height: 38)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func monthTitle(for day: Date) -> String {
        day.formatted(.dateTime.month(.wide).year())
    }

    private func weekdaySymbols() -> [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func daysInMonth(for day: Date) -> [Date?] {
        let calendar = Calendar.current
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: day)),
            let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingSpaces = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingSpaces)

        for dayNumber in dayRange {
            if let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart) {
                days.append(calendar.startOfDay(for: date))
            }
        }
        return days
    }

    private struct SelectedDay: Identifiable {
        let date: Date
        var id: Date { date }
    }
}

private struct TodayView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DayEntry.date, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<DayEntry>

    var body: some View {
        DayEntryEditorView(
            date: Date(),
            existingEntry: todayEntry(),
            onClose: {},
            title: "Today",
            showsCloseButton: false
        )
    }

    private func todayEntry() -> DayEntry? {
        entries.first { entry in
            guard let date = entry.date else { return false }
            return Calendar.current.isDateInToday(date)
        }
    }

}

private struct AnalyticsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DayEntry.date, ascending: true)],
        animation: .default
    ) private var entries: FetchedResults<DayEntry>

    @State private var searchText = ""
    @State private var selectedMoodFilter = "All"
    @State private var selectedTagFilter = "All"
    @State private var minimumScoreFilter = 0
    @State private var selectedDay: SelectedDay?

    private let moods = ["Great", "Good", "Okay", "Low", "Exhausted"]

    private var historyEntries: [DayEntry] {
        entries
            .filter { $0.date != nil }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private var availableTags: [String] {
        var seen = Set<String>()
        for entry in historyEntries {
            for tag in tags(from: entry.activities) {
                seen.insert(tag)
            }
        }
        return Array(seen).sorted()
    }

    private var filteredHistoryEntries: [DayEntry] {
        historyEntries.filter { entry in
            if selectedMoodFilter != "All" && canonicalMood(entry.mood) != canonicalMood(selectedMoodFilter) {
                return false
            }
            if minimumScoreFilter > 0 && Int(entry.qualityScore) < minimumScoreFilter {
                return false
            }
            if selectedTagFilter != "All" && !tags(from: entry.activities).contains(selectedTagFilter) {
                return false
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            let haystack = [
                entry.morningPlan ?? "",
                entry.eveningReflection ?? "",
                entry.diaryText ?? "",
                entry.activities ?? "",
                entry.mood ?? ""
            ]
            .joined(separator: " ")
            .lowercased()
            return haystack.contains(query.lowercased())
        }
    }

    private var last30DaysData: [TrendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<30).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let matching = entries.first { entry in
                guard let date = entry.date else { return false }
                return calendar.isDate(date, inSameDayAs: day)
            }
            return TrendPoint(date: day, score: Int(matching?.qualityScore ?? 0))
        }
        .reversed()
    }

    private var streak: Int {
        var running = 0
        var cursor = Calendar.current.startOfDay(for: Date())
        while let entry = entries.first(where: { entry in
            guard let date = entry.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: cursor)
        }) {
            _ = entry
            running += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return running
    }

    private var qualityDistribution: [QualityBucket] {
        (1...10).map { score in
            let count = entries.filter { Int($0.qualityScore) == score }.count
            return QualityBucket(score: score, count: count)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("30-Day Trend") {
                    Chart(last30DaysData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.score)
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.score)
                        )
                    }
                    .frame(height: 180)
                }

                Section("Quality Distribution") {
                    Chart(qualityDistribution) { bucket in
                        BarMark(
                            x: .value("Score", bucket.score),
                            y: .value("Days", bucket.count)
                        )
                    }
                    .frame(height: 180)
                }

                Section("Stats") {
                    HStack {
                        Text("Current Streak")
                        Spacer()
                        Text("\(streak) days")
                            .font(.headline)
                    }

                    HStack {
                        Text("Total Logged Days")
                        Spacer()
                        Text("\(entries.count)")
                            .font(.headline)
                    }
                }

                Section("History Filters") {
                    Picker("Mood", selection: $selectedMoodFilter) {
                        Text("All").tag("All")
                        ForEach(moods, id: \.self) { mood in
                            Text(mood).tag(mood)
                        }
                    }

                    Picker("Tag", selection: $selectedTagFilter) {
                        Text("All").tag("All")
                        ForEach(availableTags, id: \.self) { tag in
                            Text(tag).tag(tag)
                        }
                    }

                    Picker("Minimum Score", selection: $minimumScoreFilter) {
                        Text("Any").tag(0)
                        ForEach(1...10, id: \.self) { score in
                            Text("\(score)+").tag(score)
                        }
                    }
                }

                Section("History") {
                    if filteredHistoryEntries.isEmpty {
                        Text("No entries match your filters.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredHistoryEntries, id: \.objectID) { entry in
                            if let day = entry.date {
                                Button {
                                    selectedDay = SelectedDay(date: day)
                                } label: {
                                    historyRow(entry: entry, day: day)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Analytics")
            .searchable(text: $searchText, prompt: "Search notes, mood, or tags")
            #if os(iOS)
            .fullScreenCover(item: $selectedDay) { day in
                DayEntryEditorView(
                    date: day.date,
                    existingEntry: entryForDay(day.date),
                    onClose: { selectedDay = nil }
                )
            }
            #else
            .sheet(item: $selectedDay) { day in
                DayEntryEditorView(
                    date: day.date,
                    existingEntry: entryForDay(day.date),
                    onClose: { selectedDay = nil }
                )
                .frame(minWidth: 560, minHeight: 640)
            }
            #endif
        }
    }

    @ViewBuilder
    private func historyRow(entry: DayEntry, day: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                Spacer()
                Text("\(entry.qualityScore)/10")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }

            Text(entry.mood ?? "No mood")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let tagText = tags(from: entry.activities)
            if !tagText.isEmpty {
                Text(tagText.joined(separator: "  •  "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let morningPlan = entry.morningPlan, !morningPlan.isEmpty {
                Text("Plan: \(morningPlan)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let reflection = entry.eveningReflection ?? entry.diaryText, !reflection.isEmpty {
                Text("Reflection: \(reflection)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func entryForDay(_ day: Date) -> DayEntry? {
        entries.first { entry in
            guard let date = entry.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: day)
        }
    }

    private struct SelectedDay: Identifiable {
        let date: Date
        var id: Date { date }
    }
}

private struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var profile: UserProfile

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DayEntry.date, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<DayEntry>

    @AppStorage("morningHour") private var morningHour = 8
    @AppStorage("morningMinute") private var morningMinute = 0
    @AppStorage("eveningHour") private var eveningHour = 20
    @AppStorage("eveningMinute") private var eveningMinute = 0
    @AppStorage("geminiApiKey") private var geminiAPIKey = ""
    @AppStorage("geminiModel") private var geminiModel = "gemini-2.5-flash"

    @State private var showDeleteAlert = false
    @State private var showReminderResultAlert = false
    @State private var reminderResultTitle = ""
    @State private var reminderResultMessage = ""

    private var lifeExpectancyRange: LifeExpectancyCalculator.ExpectancyRange {
        LifeExpectancyCalculator.estimateRange(
            birthDate: profile.birthDate ?? Date(),
            country: profile.country ?? "United States",
            gender: profile.gender ?? "Other",
            isSmoker: profile.isSmoker,
            hasChronicCondition: profile.hasChronicCondition
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    row("Country", profile.country ?? "-")
                    row("Gender", profile.gender ?? "-")
                    row(
                        "Estimated Life Expectancy",
                        "\(lifeExpectancyRange.lowerYears)-\(lifeExpectancyRange.upperYears) years (avg \(lifeExpectancyRange.averageYears))"
                    )
                }

                Section("Notifications") {
                    DatePicker(
                        "Morning Reminder Time",
                        selection: timeBinding(hour: $morningHour, minute: $morningMinute),
                        displayedComponents: .hourAndMinute
                    )
                    Text("Morning Reminder: \(formatTime(hour: morningHour, minute: morningMinute))")
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "Evening Reminder Time",
                        selection: timeBinding(hour: $eveningHour, minute: $eveningMinute),
                        displayedComponents: .hourAndMinute
                    )
                    Text("Evening Reminder: \(formatTime(hour: eveningHour, minute: eveningMinute))")
                        .foregroundStyle(.secondary)

                    Button("Apply Reminder Schedule") {
                        NotificationService.shared.scheduleDailyReminders(
                            morningHour: morningHour,
                            morningMinute: morningMinute,
                            eveningHour: eveningHour,
                            eveningMinute: eveningMinute
                        ) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    reminderResultTitle = "Reminders Updated"
                                    reminderResultMessage = "Morning at \(formatTime(hour: morningHour, minute: morningMinute)), evening at \(formatTime(hour: eveningHour, minute: eveningMinute))."
                                case .failure(let error):
                                    reminderResultTitle = "Could Not Update Reminders"
                                    reminderResultMessage = error.localizedDescription
                                }
                                showReminderResultAlert = true
                            }
                        }
                    }
                }

                Section("AI Reflection Guide") {
                    SecureField("Gemini API Key", text: $geminiAPIKey)

                    TextField("Model", text: $geminiModel)

                    Text("Used by Day Details > Reflection > Guide Reflection. If empty, GOOGLE_API_KEY is used.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    row("Saved Entries", "\(entries.count)")

                    Button("Delete All Entries", role: .destructive) {
                        showDeleteAlert = true
                    }
                }
            }
            .alert("Delete all entries?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteAllEntries()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(reminderResultTitle, isPresented: $showReminderResultAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(reminderResultMessage)
            }
            .navigationTitle("Settings")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return formatter.string(from: date)
    }

    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    from: DateComponents(
                        year: 2000,
                        month: 1,
                        day: 1,
                        hour: hour.wrappedValue,
                        minute: minute.wrappedValue
                    )
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                hour.wrappedValue = components.hour ?? 0
                minute.wrappedValue = components.minute ?? 0
            }
        )
    }

    private func deleteAllEntries() {
        entries.forEach(viewContext.delete)
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
        }
    }
}

private struct DayEntryEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let existingEntry: DayEntry?
    let onClose: () -> Void
    let title: String
    let showsCloseButton: Bool

    @AppStorage("geminiApiKey") private var geminiAPIKey = ""
    @AppStorage("geminiModel") private var geminiModel = "gemini-2.5-flash"

    @State private var qualityScore = 5.0
    @State private var mood = "Good"
    @State private var activities = ""
    @State private var morningPlan = ""
    @State private var eveningReflection = ""
    @State private var selectedEditorSection: DayEditorSection = .planning
    @State private var reflectionGuide = ""
    @State private var reflectionGuideError: String?
    @State private var isGeneratingReflectionGuide = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoDatas: [Data] = []
    #if os(iOS)
    @StateObject private var morningVoiceEntry = VoiceEntryController()
    @StateObject private var eveningVoiceEntry = VoiceEntryController()
    @State private var isPolishingEveningReflection = false
    @State private var eveningReflectionPolishError: String?
    @State private var shouldPolishEveningReflectionOnStop = false
    #endif

    private let moods = ["Great", "Good", "Okay", "Low", "Exhausted"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    #if os(macOS)
                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "x.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Close")

                        Button {
                            currentWindow()?.miniaturize(nil)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.plain)
                        .help("Minimize")

                        Button {
                            currentWindow()?.zoom(nil)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                        .help("Expand")

                        Spacer()
                    }
                    #endif

                    GroupBox("Date") {
                        Text(date, format: .dateTime.weekday(.wide).month().day().year())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Picker("Section", selection: $selectedEditorSection) {
                        ForEach(DayEditorSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedEditorSection == .planning {
                        GroupBox("Morning Planning") {
                            VStack(alignment: .leading, spacing: 12) {
                                #if os(iOS)
                                HStack(spacing: 10) {
                                    Button {
                                        morningVoiceEntry.toggle(for: morningPlan) { updatedText in
                                            morningPlan = updatedText
                                        }
                                    } label: {
                                        Label(
                                            morningVoiceEntry.isRecording ? "Stop Voice Entry" : "Voice Entry",
                                            systemImage: morningVoiceEntry.isRecording ? "stop.circle.fill" : "mic.fill"
                                        )
                                    }
                                    .buttonStyle(.bordered)

                                    if morningVoiceEntry.isRecording {
                                        Text("Listening...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let error = morningVoiceEntry.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                                #endif

                                TextEditor(text: $morningPlan)
                                    .frame(minHeight: 160)
                            }
                        }
                    }

                    if selectedEditorSection == .reflection {
                        GroupBox("Evening Reflection") {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading) {
                                    Text("Quality: \(Int(qualityScore))/10")
                                    Slider(value: $qualityScore, in: 1...10, step: 1)
                                }

                                Picker("Mood", selection: $mood) {
                                    ForEach(moods, id: \.self) { value in
                                        Text(value).tag(value)
                                    }
                                }

                                TagOrganizerView(activities: $activities)

                                HStack(spacing: 10) {
                                    Button {
                                        Task {
                                            await generateReflectionGuide()
                                        }
                                    } label: {
                                        if isGeneratingReflectionGuide {
                                            ProgressView()
                                        } else {
                                            Label("AI Guided Self-reflection", systemImage: "sparkles")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isGeneratingReflectionGuide)

                                    if !reflectionGuide.isEmpty {
                                        Button("Insert into Reflection") {
                                            insertReflectionGuide()
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }

                                if let reflectionGuideError {
                                    Text(reflectionGuideError)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }

                                if !reflectionGuide.isEmpty {
                                    Text(reflectionGuide)
                                        .font(.footnote)
                                        .padding(10)
                                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                }

                                #if os(iOS)
                                HStack(spacing: 10) {
                                    Button {
                                        handleEveningVoiceEntryTap()
                                    } label: {
                                        Label(
                                            eveningVoiceEntry.isRecording ? "Stop Voice Entry" : "Voice Entry",
                                            systemImage: eveningVoiceEntry.isRecording ? "stop.circle.fill" : "mic.fill"
                                        )
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isPolishingEveningReflection)

                                    if eveningVoiceEntry.isRecording {
                                        Text("Listening...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if isPolishingEveningReflection {
                                        ProgressView()
                                        Text("Polishing...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let error = eveningVoiceEntry.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }

                                if let eveningReflectionPolishError {
                                    Text(eveningReflectionPolishError)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                                #endif

                                TextEditor(text: $eveningReflection)
                                    .frame(minHeight: 160)
                            }
                        }
                    }

                    GroupBox("Photo") {
                        VStack(alignment: .leading, spacing: 10) {
                            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 8, matching: .images) {
                                Label("Select Photos", systemImage: "photo.on.rectangle.angled")
                            }

                            if photoDatas.isEmpty {
                                Text("No photos selected.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(Array(photoDatas.enumerated()), id: \.offset) { index, data in
                                            ZStack(alignment: .topTrailing) {
                                                if let image = platformSwiftUIImage(from: data) {
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 110, height: 110)
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                }

                                                Button {
                                                    photoDatas.remove(at: index)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(.white, .black.opacity(0.7))
                                                }
                                                .offset(x: 4, y: -4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .toolbar {
                #if os(iOS)
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            closeEditor()
                        }
                    }
                }
                #endif
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
            .onAppear {
                if let existingEntry {
                    qualityScore = Double(existingEntry.qualityScore)
                    mood = canonicalMood(existingEntry.mood)
                    activities = existingEntry.activities ?? ""
                    morningPlan = existingEntry.morningPlan ?? ""
                    eveningReflection = existingEntry.eveningReflection ?? existingEntry.diaryText ?? ""
                    photoDatas = decodePhotoArray(from: existingEntry.photoData)
                }
            }
            .task(id: selectedPhotoItems) {
                guard !selectedPhotoItems.isEmpty else { return }
                for item in selectedPhotoItems {
                    if let data = try? await item.loadTransferable(type: Data.self), !photoDatas.contains(data) {
                        photoDatas.append(data)
                    }
                }
                selectedPhotoItems.removeAll()
            }
            .onDisappear {
                #if os(iOS)
                shouldPolishEveningReflectionOnStop = false
                morningVoiceEntry.stopRecording()
                eveningVoiceEntry.stopRecording()
                #endif
            }
            #if os(iOS)
            .onChange(of: eveningVoiceEntry.isRecording) { _, isRecording in
                guard !isRecording, shouldPolishEveningReflectionOnStop else { return }
                shouldPolishEveningReflectionOnStop = false
                Task {
                    await polishEveningReflectionFromVoice()
                }
            }
            #endif
        }
    }

    init(
        date: Date,
        existingEntry: DayEntry?,
        onClose: @escaping () -> Void,
        title: String = "Day Details",
        showsCloseButton: Bool = true
    ) {
        self.date = date
        self.existingEntry = existingEntry
        self.onClose = onClose
        self.title = title
        self.showsCloseButton = showsCloseButton
    }

    private func save() {
        let entry = existingEntry ?? DayEntry(context: viewContext)
        entry.date = Calendar.current.startOfDay(for: date)
        entry.qualityScore = Int16(qualityScore)
        entry.mood = canonicalMood(mood)
        entry.activities = normalizedTagCSV(activities)
        entry.morningPlan = morningPlan
        entry.eveningReflection = eveningReflection
        entry.diaryText = eveningReflection
        entry.photoData = encodePhotoArray(photoDatas)
        if entry.createdAt == nil {
            entry.createdAt = Date()
        }

        do {
            try viewContext.save()
            closeEditor()
        } catch {
            viewContext.rollback()
        }
    }

    private func closeEditor() {
        onClose()
        dismiss()
    }

    @MainActor
    private func generateReflectionGuide() async {
        reflectionGuideError = nil
        isGeneratingReflectionGuide = true
        defer { isGeneratingReflectionGuide = false }

        do {
            reflectionGuide = try await GeminiService.shared.generateReflectionGuide(
                apiKey: geminiAPIKey,
                model: geminiModel.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date,
                qualityScore: Int(qualityScore),
                mood: mood,
                activities: activities,
                morningPlan: morningPlan,
                eveningReflection: eveningReflection
            )
        } catch {
            reflectionGuideError = error.localizedDescription
        }
    }

    private func insertReflectionGuide() {
        guard !reflectionGuide.isEmpty else { return }
        if eveningReflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            eveningReflection = reflectionGuide
        } else {
            eveningReflection += "\n\n\(reflectionGuide)"
        }
    }

    #if os(iOS)
    private func handleEveningVoiceEntryTap() {
        eveningReflectionPolishError = nil

        if eveningVoiceEntry.isRecording {
            eveningVoiceEntry.stopRecording()
            return
        }

        shouldPolishEveningReflectionOnStop = true
        eveningVoiceEntry.toggle(for: eveningReflection) { updatedText in
            eveningReflection = updatedText
        }
    }

    @MainActor
    private func polishEveningReflectionFromVoice() async {
        let transcript = eveningReflection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }

        eveningReflectionPolishError = nil
        isPolishingEveningReflection = true
        defer { isPolishingEveningReflection = false }

        do {
            let polished = try await GeminiService.shared.polishReflectionTranscript(
                apiKey: geminiAPIKey,
                model: geminiModel.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date,
                qualityScore: Int(qualityScore),
                mood: mood,
                activities: activities,
                morningPlan: morningPlan,
                rawReflection: transcript
            )
            eveningReflection = polished
        } catch {
            eveningReflectionPolishError = "Could not polish reflection: \(error.localizedDescription)"
        }
    }
    #endif

    #if os(macOS)
    private func currentWindow() -> NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow
    }
    #endif

    private enum DayEditorSection: String, CaseIterable, Identifiable {
        case planning
        case reflection

        var id: String { rawValue }
        var title: String { self == .planning ? "Planning" : "Reflection" }
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct TrendPoint: Identifiable {
    let date: Date
    let score: Int
    var id: Date { date }
}

private struct QualityBucket: Identifiable {
    let score: Int
    let count: Int
    var id: Int { score }
}

#if os(iOS)
@MainActor
private final class VoiceEntryController: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var suppressCancellationError = false

    private var baseText = ""
    private var latestTranscript = ""
    private var onTextUpdate: ((String) -> Void)?

    func toggle(for existingText: String, onTextUpdate: @escaping (String) -> Void) {
        if isRecording {
            stopRecording(suppressCancellationError: true)
        } else {
            startRecording(baseText: existingText, onTextUpdate: onTextUpdate)
        }
    }

    func stopRecording(suppressCancellationError: Bool = true) {
        self.suppressCancellationError = suppressCancellationError
        let finalText = composedText()
        if !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onTextUpdate?(finalText)
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignore deactivation errors.
        }
    }

    private func startRecording(baseText: String, onTextUpdate: @escaping (String) -> Void) {
        self.baseText = baseText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.onTextUpdate = onTextUpdate
        self.errorMessage = nil

        requestPermissions { [weak self] granted, message in
            guard let self else { return }
            guard granted else {
                self.errorMessage = message
                return
            }

            do {
                try self.beginRecognition()
            } catch {
                self.errorMessage = "Voice input could not start: \(error.localizedDescription)"
                self.stopRecording(suppressCancellationError: true)
            }
        }
    }

    private func beginRecognition() throws {
        stopRecording(suppressCancellationError: true)

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        guard let speechRecognizer else {
            throw NSError(domain: "VoiceEntry", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable."])
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        latestTranscript = ""
        isRecording = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    let candidate = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !candidate.isEmpty {
                        self.latestTranscript = candidate
                        self.onTextUpdate?(self.composedText())
                    }
                    if result.isFinal {
                        self.stopRecording(suppressCancellationError: true)
                    }
                }
            }

            if let error {
                Task { @MainActor in
                    if self.shouldIgnoreRecognitionError(error) {
                        self.stopRecording(suppressCancellationError: true)
                        return
                    }
                    self.errorMessage = "Voice input error: \(error.localizedDescription)"
                    self.stopRecording(suppressCancellationError: true)
                }
            }
        }
    }

    private func shouldIgnoreRecognitionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let message = nsError.localizedDescription.lowercased()
        if suppressCancellationError && message.contains("cancel") {
            return true
        }
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }
        if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 216 || nsError.code == 301) {
            return true
        }
        return false
    }

    private func composedText() -> String {
        let spoken = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseText.isEmpty {
            return spoken
        }
        if spoken.isEmpty {
            return baseText
        }
        return "\(baseText)\n\(spoken)"
    }

    private func requestPermissions(completion: @escaping (Bool, String?) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    completion(false, "Enable Speech Recognition access in iPhone Settings.")
                    return
                }

                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted {
                            completion(true, nil)
                        } else {
                            completion(false, "Enable Microphone access in iPhone Settings.")
                        }
                    }
                }
            }
        }
    }
}
#endif

private struct TagOrganizerView: View {
    @Binding var activities: String

    private var selectedTags: Set<String> {
        Set(tags(from: activities).map { $0.lowercased() })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(defaultQuickTagGroups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                        ForEach(group.tags, id: \.self) { tag in
                            Button(tag) {
                                activities = toggleTag(tag, in: activities)
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedTags.contains(tag.lowercased()) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 9)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(
                                        selectedTags.contains(tag.lowercased()) ? Color.accentColor : Color.secondary.opacity(0.2),
                                        lineWidth: selectedTags.contains(tag.lowercased()) ? 1.3 : 0.7
                                    )
                            )
                        }
                    }
                }
            }

            TextField("Tags (comma-separated): Work, Exercise, Family", text: $activities)
                .textInputAutocapitalization(.words)
        }
    }
}

private struct QuickTagGroup: Identifiable {
    let title: String
    let tags: [String]
    var id: String { title }
}

private let defaultQuickTagGroups: [QuickTagGroup] = [
    QuickTagGroup(title: "Focus", tags: ["Work", "Study", "Reading", "Project"]),
    QuickTagGroup(title: "Wellness", tags: ["Exercise", "Health", "Rest", "Meditation"]),
    QuickTagGroup(title: "People", tags: ["Family", "Friends", "Partner", "Social"]),
    QuickTagGroup(title: "Life", tags: ["Travel", "Nature", "Home", "Errands"])
]

private func tags(from text: String?) -> [String] {
    guard let text else { return [] }
    let parts = text
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    var seen = Set<String>()
    var ordered: [String] = []
    for tag in parts {
        let key = tag.lowercased()
        if !seen.contains(key) {
            seen.insert(key)
            ordered.append(tag)
        }
    }
    return ordered
}

private func normalizedTagCSV(_ text: String) -> String {
    tags(from: text).joined(separator: ", ")
}

private func addTag(_ tag: String, to existing: String) -> String {
    var current = tags(from: existing)
    if !current.map({ $0.lowercased() }).contains(tag.lowercased()) {
        current.append(tag)
    }
    return current.joined(separator: ", ")
}

private func toggleTag(_ tag: String, in existing: String) -> String {
    var current = tags(from: existing)
    if let index = current.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
        current.remove(at: index)
    } else {
        current.append(tag)
    }
    return current.joined(separator: ", ")
}

private func canonicalMood(_ mood: String?) -> String {
    let normalized = (mood ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    switch normalized {
    case "great": return "Great"
    case "good": return "Good"
    case "okay", "ok": return "Okay"
    case "low": return "Low"
    case "exhausted": return "Exhausted"
    default: return normalized.isEmpty ? "Good" : normalized.capitalized
    }
}

private func encodePhotoArray(_ photos: [Data]) -> Data? {
    guard !photos.isEmpty else { return nil }
    if photos.count == 1 {
        return photos[0]
    }
    let payload = ["photos": photos.map { $0.base64EncodedString() }]
    return try? JSONSerialization.data(withJSONObject: payload)
}

private func decodePhotoArray(from data: Data?) -> [Data] {
    guard let data else { return [] }
    if
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let base64Photos = object["photos"] as? [String]
    {
        let decoded = base64Photos.compactMap { Data(base64Encoded: $0) }
        if !decoded.isEmpty {
            return decoded
        }
    }
    return [data]
}

private func platformSwiftUIImage(from data: Data) -> Image? {
#if canImport(UIKit)
    guard let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
#elseif canImport(AppKit)
    guard let image = NSImage(data: data) else { return nil }
    return Image(nsImage: image)
#else
    return nil
#endif
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
