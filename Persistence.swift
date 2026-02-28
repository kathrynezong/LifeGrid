import CoreData
import Foundation
import UserNotifications

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        let profile = UserProfile(context: viewContext)
        profile.birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        profile.country = "United States"
        profile.gender = "Female"
        profile.isSmoker = false
        profile.hasChronicCondition = false
        profile.createdAt = Date()

        for offset in 0..<30 {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let entry = DayEntry(context: viewContext)
            entry.date = Calendar.current.startOfDay(for: day)
            entry.qualityScore = Int16(Int.random(in: 4...9))
            entry.moodScore = Int16(Int.random(in: 4...9))
            entry.energyScore = Int16(Int.random(in: 4...9))
            entry.progressScore = Int16(Int.random(in: 4...9))
            entry.mood = ["Great", "Good", "Okay", "Low"].randomElement() ?? "Good"
            entry.activities = "Work, Exercise"
            entry.morningPlan = "Top priorities and focus blocks."
            entry.eveningReflection = "Sample day reflection."
            entry.diaryText = "Sample day reflection."
            entry.createdAt = day
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "LifeGrid")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.forEach { description in
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

struct LifeExpectancyCalculator {
    struct ExpectancyRange {
        let averageYears: Int
        let lowerYears: Int
        let upperYears: Int
        let stdDevYears: Double
    }

    static func estimateRange(
        birthDate: Date,
        country: String,
        gender: String,
        isSmoker: Bool,
        hasChronicCondition: Bool
    ) -> ExpectancyRange {
        let base = baseExpectancy(country: country, gender: gender)
        let smokingPenalty = isSmoker ? 5 : 0
        let chronicPenalty = hasChronicCondition ? 5 : 0
        let stdDev = demographicStandardDeviation(country: country, gender: gender)
        let currentAge = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        let average = max(base - smokingPenalty - chronicPenalty, currentAge + 1)
        let lower = max(Int((Double(average) - (2 * stdDev)).rounded()), currentAge + 1)
        let upper = max(Int((Double(average) + (2 * stdDev)).rounded()), average + 1)
        return ExpectancyRange(
            averageYears: average,
            lowerYears: lower,
            upperYears: upper,
            stdDevYears: stdDev
        )
    }

    static func estimateYears(
        birthDate: Date,
        country: String,
        gender: String,
        isSmoker: Bool,
        hasChronicCondition: Bool
    ) -> Int {
        estimateRange(
            birthDate: birthDate,
            country: country,
            gender: gender,
            isSmoker: isSmoker,
            hasChronicCondition: hasChronicCondition
        ).averageYears
    }

    private static func baseExpectancy(country: String, gender: String) -> Int {
        let normalizedCountry = country.lowercased()
        let normalizedGender = gender.lowercased()

        if normalizedCountry.contains("japan") {
            return normalizedGender == "male" ? 81 : 87
        }
        if normalizedCountry.contains("united states") || normalizedCountry == "us" || normalizedCountry == "usa" {
            return normalizedGender == "male" ? 76 : 81
        }
        if normalizedCountry.contains("canada") {
            return normalizedGender == "male" ? 80 : 84
        }

        return normalizedGender == "male" ? 75 : 80
    }

    private static func demographicStandardDeviation(country: String, gender: String) -> Double {
        let normalizedCountry = country.lowercased()
        let normalizedGender = gender.lowercased()

        if normalizedCountry.contains("japan") {
            return normalizedGender == "male" ? 4.8 : 4.6
        }
        if normalizedCountry.contains("united states") || normalizedCountry == "us" || normalizedCountry == "usa" {
            return normalizedGender == "male" ? 6.2 : 6.0
        }
        if normalizedCountry.contains("canada") {
            return normalizedGender == "male" ? 5.5 : 5.2
        }

        return normalizedGender == "male" ? 6.5 : 6.2
    }
}

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    enum NotificationScheduleError: LocalizedError {
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Notifications are disabled. Enable them in iPhone Settings > Notifications > LifeGrid."
            }
        }
    }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            completion?(granted)
        }
    }

    func scheduleDailyReminders(
        morningHour: Int,
        morningMinute: Int = 0,
        eveningHour: Int,
        eveningMinute: Int = 0,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            guard allowed else {
                completion?(.failure(NotificationScheduleError.notAuthorized))
                return
            }

            center.removePendingNotificationRequests(withIdentifiers: ["lifegrid.morning", "lifegrid.evening"])

            let morning = UNMutableNotificationContent()
            morning.title = "Plan your day"
            morning.body = "Set your intention for today in LifeGrid."
            morning.sound = .default

            var morningDate = DateComponents()
            morningDate.hour = morningHour
            morningDate.minute = morningMinute

            let morningTrigger = UNCalendarNotificationTrigger(dateMatching: morningDate, repeats: true)
            let morningRequest = UNNotificationRequest(identifier: "lifegrid.morning", content: morning, trigger: morningTrigger)

            let evening = UNMutableNotificationContent()
            evening.title = "Time to Reflect"
            evening.body = "Log your day: quality, mood, and notes."
            evening.sound = .default

            var eveningDate = DateComponents()
            eveningDate.hour = eveningHour
            eveningDate.minute = eveningMinute

            let eveningTrigger = UNCalendarNotificationTrigger(dateMatching: eveningDate, repeats: true)
            let eveningRequest = UNNotificationRequest(identifier: "lifegrid.evening", content: evening, trigger: eveningTrigger)

            center.add(morningRequest) { error in
                if let error {
                    completion?(.failure(error))
                    return
                }

                center.add(eveningRequest) { error in
                    if let error {
                        completion?(.failure(error))
                    } else {
                        completion?(.success(()))
                    }
                }
            }
        }
    }
}

@objc(DayEntry)
public final class DayEntry: NSManagedObject, Identifiable {}

extension DayEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DayEntry> {
        NSFetchRequest<DayEntry>(entityName: "DayEntry")
    }

    @NSManaged public var activities: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var date: Date?
    @NSManaged public var diaryText: String?
    @NSManaged public var eveningReflection: String?
    @NSManaged public var mood: String?
    @NSManaged public var moodScore: Int16
    @NSManaged public var morningPlan: String?
    @NSManaged public var photoData: Data?
    @NSManaged public var progressScore: Int16
    @NSManaged public var qualityScore: Int16
    @NSManaged public var energyScore: Int16
}

@objc(UserProfile)
public final class UserProfile: NSManagedObject, Identifiable {}

extension UserProfile {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProfile> {
        NSFetchRequest<UserProfile>(entityName: "UserProfile")
    }

    @NSManaged public var birthDate: Date?
    @NSManaged public var country: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var gender: String?
    @NSManaged public var hasChronicCondition: Bool
    @NSManaged public var isSmoker: Bool
}
