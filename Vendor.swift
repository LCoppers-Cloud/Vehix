import Foundation
import SwiftData

@Model
final class Vendor: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var isVerified: Bool
    var aliases: [String]?
    var logoData: Data?
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var cloudKitSyncStatus: Int16 = 0
    var cloudKitSyncDate: Date?
    
    // Initialize a new vendor
    init(
        id: String = UUID().uuidString,
        name: String,
        isVerified: Bool = false,
        aliases: [String]? = nil,
        logoData: Data? = nil,
        cloudKitRecordID: String? = nil,
        cloudKitSyncStatus: Int16 = 0,
        cloudKitSyncDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isVerified = isVerified
        self.aliases = aliases
        self.logoData = logoData
        self.cloudKitRecordID = cloudKitRecordID
        self.cloudKitSyncStatus = cloudKitSyncStatus
        self.cloudKitSyncDate = cloudKitSyncDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Add an alias for this vendor
    func addAlias(_ alias: String) {
        if aliases == nil {
            aliases = []
        }
        
        if !aliases!.contains(alias) {
            aliases!.append(alias)
        }
    }
} 