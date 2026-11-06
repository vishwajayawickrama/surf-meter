import Foundation
import CoreData

/// Local Core Data/SQLite aggregate store. Programmatic schema avoids a model compiler dependency.
/// All reads and writes belong to the main app; browser adapters never open this store.
@MainActor
public final class UsageStore {
    private let context: NSManagedObjectContext
    private let coordinator: NSPersistentStoreCoordinator

    public init(directory: URL? = nil, inMemory: Bool = false) throws {
        func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
            let field = NSAttributeDescription(); field.name = name; field.attributeType = type; field.isOptional = false
            return field
        }
        let bucket = NSEntityDescription(); bucket.name = "Bucket"; bucket.managedObjectClassName = "NSManagedObject"
        bucket.properties = [attribute("key", .stringAttributeType), attribute("day", .stringAttributeType), attribute("hour", .integer64AttributeType), attribute("platform", .stringAttributeType), attribute("seconds", .doubleAttributeType)]
        bucket.uniquenessConstraints = [["key"]]
        let coverage = NSEntityDescription(); coverage.name = "Coverage"; coverage.managedObjectClassName = "NSManagedObject"
        coverage.properties = [attribute("day", .stringAttributeType), attribute("reasons", .stringAttributeType)]
        coverage.uniquenessConstraints = [["day"]]
        let model = NSManagedObjectModel(); model.entities = [bucket, coverage]; model.versionIdentifiers = ["SurfMeterAggregateV1"]
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let location: URL?
        if inMemory { location = nil }
        else {
            let directory = directory ?? LocalBridge.defaultDirectory.appendingPathComponent("Data")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            location = directory.appendingPathComponent("activity.sqlite")
        }
        try coordinator.addPersistentStore(ofType: inMemory ? NSInMemoryStoreType : NSSQLiteStoreType, configurationName: nil, at: location, options: [NSSQLitePragmasOption: ["journal_mode": "WAL", "synchronous": "FULL"]])
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.undoManager = nil
    }

    public func load() throws -> UsageLedger {
        var ledger = UsageLedger()
        for object in try fetch("Bucket") {
            guard let day = object.value(forKey: "day") as? String,
                  let platform = object.value(forKey: "platform") as? String,
                  let hour = object.value(forKey: "hour") as? Int,
                  let seconds = object.value(forKey: "seconds") as? Double,
                  seconds.isFinite, seconds > 0, (0..<24).contains(hour) else { continue }
            ledger.buckets[.init(day: day, hour: hour, platform: platform)] = seconds
        }
        for object in try fetch("Coverage") {
            guard let day = object.value(forKey: "day") as? String, let reasons = object.value(forKey: "reasons") as? String else { continue }
            ledger.coverage[day] = Set(reasons.split(separator: ",").map(String.init))
        }
        return ledger
    }

    private func fetch(_ entity: String) throws -> [NSManagedObject] {
        try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entity))
    }

    public func save(_ ledger: UsageLedger) throws {
        do {
            var remaining = Dictionary(uniqueKeysWithValues: ledger.buckets.map { ($0.key.id, ($0.key, $0.value)) })
            for object in try fetch("Bucket") {
                if let id = object.value(forKey: "key") as? String, let (_, seconds) = remaining.removeValue(forKey: id) { object.setValue(seconds, forKey: "seconds") }
                else { context.delete(object) }
            }
            for (_, entry) in remaining {
                let (key, seconds) = entry
                let object = NSEntityDescription.insertNewObject(forEntityName: "Bucket", into: context)
                for (field, value) in ["key": key.id, "day": key.day, "hour": key.hour, "platform": key.platform, "seconds": seconds] as [String: Any] { object.setValue(value, forKey: field) }
            }
            var remainingCoverage = ledger.coverage
            for object in try fetch("Coverage") {
                if let day = object.value(forKey: "day") as? String, let reasons = remainingCoverage.removeValue(forKey: day) { object.setValue(reasons.sorted().joined(separator: ","), forKey: "reasons") }
                else { context.delete(object) }
            }
            for (day, reasons) in remainingCoverage {
                let object = NSEntityDescription.insertNewObject(forEntityName: "Coverage", into: context)
                object.setValue(day, forKey: "day"); object.setValue(reasons.sorted().joined(separator: ","), forKey: "reasons")
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
