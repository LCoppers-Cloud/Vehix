import Foundation
import SwiftData

// This is a standalone user model to avoid conflicts with Vehix.User (AppUser)
// The app should preferably use AppUser in new code, but this model may be needed
// in specific contexts where the current model is required.
@Model
final class StandaloneUser: Identifiable {
    @Attribute(.unique) var id: String
    var email: String
    var firstName: String?
    var lastName: String?
    var role: String
    var companyId: String?
    var companyName: String?
    var phoneNumber: String?
    var lastLoginDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var cloudKitSyncStatus: Int16 = 0
    var cloudKitSyncDate: Date?
    
    // Convenience computed properties
    var fullName: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        } else if let lastName = lastName {
            return lastName
        } else {
            return email
        }
    }
    
    var isManager: Bool {
        role == "manager" || role == "admin"
    }
    
    var isTechnician: Bool {
        role == "technician"
    }
    
    init(
        id: String = UUID().uuidString,
        email: String,
        firstName: String? = nil,
        lastName: String? = nil,
        role: String = "technician",
        companyId: String? = nil,
        companyName: String? = nil,
        phoneNumber: String? = nil,
        lastLoginDate: Date? = nil,
        cloudKitRecordID: String? = nil,
        cloudKitSyncStatus: Int16 = 0,
        cloudKitSyncDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.role = role
        self.companyId = companyId
        self.companyName = companyName
        self.phoneNumber = phoneNumber
        self.lastLoginDate = lastLoginDate
        self.cloudKitRecordID = cloudKitRecordID
        self.cloudKitSyncStatus = cloudKitSyncStatus
        self.cloudKitSyncDate = cloudKitSyncDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 