import Foundation
import SwiftData
import CloudKit

/*
 This file provides a consolidated collection of all model implementations.
 
 The goal is to resolve the model ambiguity issues by:
 1. Providing a single source of truth for model definitions
 2. Creating clear typealias definitions to use throughout the app

 CURRENT STATUS:
 - We've implemented the Vehix namespace in VehicleModels.swift that contains:
   - Vehix.Vehicle
   - Vehix.InventoryItem 
   - Vehix.ServiceRecord
   - Vehix.User
 
 - Type aliases have been created in ModelConfiguration.swift:
   - AppVehicle (points to Vehix.Vehicle)
   - AppInventoryItem (points to Vehix.InventoryItem)
   - AppServiceRecord (points to Vehix.ServiceRecord)
   - AppUser (points to Auth.User from ModelImports.swift)
 
 MIGRATION STRATEGY:
 1. All new code should use the App* aliases
 2. Gradually migrate existing code to use App* aliases
 3. Eventually remove the old model definitions
 
 SCHEMA DEFINITION:
 The complete schema includes all models needed for the app.
*/

// MARK: - Schema Migration Plan (Simplified for Production)

/// Current schema version for production deployment
enum VehixCurrentSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [
            // Current production models
            AuthUser.self,
            Vehix.Vehicle.self,
            VehicleAssignment.self,
            Vehix.ServiceRecord.self,
            AppTask.self,
            AppSubtask.self,
            Vehix.InventoryItem.self,
            StockLocationItem.self,
            Vehix.Warehouse.self,
            PendingTransfer.self,
            Receipt.self,
            ReceiptItem.self,
            Vehix.Vendor.self,
            PurchaseOrder.self,
            PurchaseOrderLineItem.self,
            AppSettings.self
        ]
    }
}

// MARK: - Complete Schema Definition

/// Complete schema including all models required for the SwiftData container
let completeSchema = Schema([
    // Authentication and User Management
    AuthUser.self,
    
    // Business Account Management
    BusinessAccount.self,
    UserAccount.self,
    FirstTimeSetupState.self,
    
    // Vehicle Management
    Vehix.Vehicle.self,
    VehicleAssignment.self,
    Vehix.ServiceRecord.self,
    AppTask.self,
    AppSubtask.self,
    
    // GPS Tracking with Legal Compliance
    VehicleTrackingSession.self,
    VehicleTrackingPoint.self,
    GPSConsentRecord.self,
    WorkHoursConfiguration.self,
    
    // Inventory Management
    Vehix.InventoryItem.self,
    StockLocationItem.self,
    Vehix.Warehouse.self,
    PendingTransfer.self,
    Receipt.self,
    ReceiptItem.self,
    Vehix.Vendor.self,
    
    // Purchase Order Management
    PurchaseOrder.self,
    PurchaseOrderLineItem.self,
    
    // Application Settings
    AppSettings.self
], version: VehixCurrentSchema.versionIdentifier)

// MARK: - Model Configuration

/// Creates the model configuration for the app
func createModelConfiguration() -> ModelConfiguration {
    return ModelConfiguration(
        schema: completeSchema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .private("iCloud.com.lcoppers.Vehix")
    )
}

// MARK: - Type Aliases for Consistency

// These aliases are defined in ModelImports.swift to avoid duplication
// Note: AppUser is defined in ModelImports.swift as Auth.User

// MARK: - Model Extensions for CloudKit

extension Vehix.Vehicle: CloudKitSyncable {
    var cloudKitRecordType: String { "Vehicle" }
    var cloudKitIdentifier: String { id }
}

extension Vehix.InventoryItem: CloudKitSyncable {
    var cloudKitRecordType: String { "InventoryItem" }
    var cloudKitIdentifier: String { id }
}

extension Vehix.Warehouse: CloudKitSyncable {
    var cloudKitRecordType: String { "Warehouse" }
    var cloudKitIdentifier: String { id }
}

extension StockLocationItem: CloudKitSyncable {
    var cloudKitRecordType: String { "StockLocationItem" }
    var cloudKitIdentifier: String { id }
}

extension PurchaseOrder: CloudKitSyncable {
    var cloudKitRecordType: String { "PurchaseOrder" }
    var cloudKitIdentifier: String { id }
}

// MARK: - CloudKit Syncable Protocol

protocol CloudKitSyncable {
    var cloudKitRecordType: String { get }
    var cloudKitIdentifier: String { get }
}

// MARK: - Migration Helpers

/// Helper functions for migrating between model versions
struct ModelMigrationHelper {
    
    /// Migrates old model references to new App* aliases
    static func migrateToAppAliases() {
        // Implementation for migrating existing data
        // This would be called during app updates
    }
    
    /// Validates that all models are properly configured
    static func validateModelConfiguration() -> Bool {
        // Validate that all required models are in the schema
        let requiredModels = [
            "Vehicle", "InventoryItem", "ServiceRecord", "User",
            "AppWarehouse", "StockLocationItem", "PurchaseOrder",
            "VehicleTrackingSession", "VehicleTrackingPoint"
        ]
        
        // Check if all required models are present
        return requiredModels.allSatisfy { modelName in
            completeSchema.entities.contains { entity in
                entity.name.contains(modelName)
            }
        }
    }
}

// MARK: - Schema Validation

/// Validates the complete schema at runtime
func validateSchema() throws {
    guard ModelMigrationHelper.validateModelConfiguration() else {
        throw SchemaValidationError.missingRequiredModels
    }
}

enum SchemaValidationError: Error {
    case missingRequiredModels
    case invalidModelConfiguration
    case cloudKitSyncError
}

// MARK: - Development Helpers

#if DEBUG
/// Development helper for inspecting the schema
struct SchemaInspector {
    static func printSchemaInfo() {
        print("=== Vehix App Schema ===")
        print("Total entities: \(completeSchema.entities.count)")
        
        for entity in completeSchema.entities {
            print("- \(entity.name)")
            print("  Properties: \(entity.properties.count)")
            print("  Relationships: \(entity.relationships.count)")
        }
        
        print("========================")
    }
    
    static func validateCloudKitCompatibility() {
        // Check if all models are CloudKit compatible
        print("CloudKit Compatibility Check:")
        // Implementation would check each model's CloudKit requirements
    }
}
#endif 

// MARK: - GPS Tracking Models (Legal Compliance Built-In)

@Model
final class VehicleTrackingSession {
    var id: String = UUID().uuidString
    var vehicleId: String = ""
    var userId: String = ""
    var startTime: Date = Date()
    var endTime: Date?
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var totalDistance: Double = 0.0 // in meters
    var averageSpeed: Double = 0.0 // in m/s
    var maxSpeed: Double = 0.0 // in m/s
    var isWorkHours: Bool = true // Legal compliance: work hours only
    var userConsent: Bool = false // Legal compliance: explicit consent required
    var businessPurpose: String = "" // Legal compliance: legitimate business reason
    
    @Relationship(deleteRule: .cascade) var trackingPoints: [VehicleTrackingPoint]?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var cloudKitSyncStatus: Int16 = 0
    var cloudKitSyncDate: Date?
    
    init(
        id: String = UUID().uuidString,
        vehicleId: String = "",
        userId: String = "",
        startTime: Date = Date(),
        endTime: Date? = nil,
        startLocation: CLLocation? = nil,
        endLocation: CLLocation? = nil,
        totalDistance: Double = 0.0,
        averageSpeed: Double = 0.0,
        maxSpeed: Double = 0.0,
        trackingPoints: [VehicleTrackingPoint] = [],
        userConsent: Bool = false,
        businessPurpose: String = ""
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.userId = userId
        self.startTime = startTime
        self.endTime = endTime
        self.totalDistance = totalDistance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.trackingPoints = trackingPoints
        self.userConsent = userConsent
        self.businessPurpose = businessPurpose
        
        if let location = startLocation {
            self.startLatitude = location.coordinate.latitude
            self.startLongitude = location.coordinate.longitude
        }
        
        if let location = endLocation {
            self.endLatitude = location.coordinate.latitude
            self.endLongitude = location.coordinate.longitude
        }
        
        // Legal compliance: check if tracking is during work hours
        self.isWorkHours = isWithinWorkHours(startTime)
    }
    
    // Legal compliance helper
    private func isWithinWorkHours(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        // Default business hours: 6 AM to 8 PM (configurable)
        return hour >= 6 && hour <= 20
    }
    
    var durationMinutes: Int {
        guard let endTime = endTime else {
            return Int(Date().timeIntervalSince(startTime) / 60)
        }
        return Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    var formattedDistance: String {
        let distanceInKm = totalDistance / 1000
        return String(format: "%.1f km", distanceInKm)
    }
    
    var formattedDuration: String {
        let minutes = durationMinutes
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
    
    func setStartLocation(_ location: CLLocation) {
        startLatitude = location.coordinate.latitude
        startLongitude = location.coordinate.longitude
        updatedAt = Date()
    }
    
    func setEndLocation(_ location: CLLocation) {
        endLatitude = location.coordinate.latitude
        endLongitude = location.coordinate.longitude
        updatedAt = Date()
    }
    
    func addLocationPoint(_ location: CLLocation, distance: Double) {
        let point = VehicleTrackingPoint(
            sessionId: id,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            speed: location.speed,
            altitude: location.altitude,
            accuracy: location.horizontalAccuracy
        )
        
        // Set up the relationship properly for CloudKit
        point.session = self
        
        if trackingPoints == nil {
            trackingPoints = []
        }
        trackingPoints?.append(point)
        
        totalDistance += distance
        
        if location.speed > maxSpeed {
            maxSpeed = location.speed
        }
        
        // Update average speed
        let duration = Date().timeIntervalSince(startTime)
        if duration > 0 {
            averageSpeed = totalDistance / duration
        }
        
        updatedAt = Date()
    }
}

@Model
final class VehicleTrackingPoint {
    var id: String = UUID().uuidString
    var sessionId: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var timestamp: Date = Date()
    var speed: Double = 0.0 // in m/s
    var altitude: Double = 0.0 // in meters
    var accuracy: Double = 0.0 // in meters
    var createdAt: Date = Date()
    
    // Inverse relationship for CloudKit compatibility
    @Relationship(inverse: \VehicleTrackingSession.trackingPoints) var session: VehicleTrackingSession?
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var cloudKitSyncStatus: Int16 = 0
    var cloudKitSyncDate: Date?
    
    init(
        id: String = UUID().uuidString,
        sessionId: String = "",
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        timestamp: Date = Date(),
        speed: Double = 0.0,
        altitude: Double = 0.0,
        accuracy: Double = 0.0
    ) {
        self.id = id
        self.sessionId = sessionId
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.speed = speed
        self.altitude = altitude
        self.accuracy = accuracy
    }
    
    var location: CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy,
            timestamp: timestamp
        )
    }
    
    var formattedSpeed: String {
        let speedKmh = speed * 3.6 // Convert m/s to km/h
        return String(format: "%.1f km/h", speedKmh)
    }
}

// MARK: - GPS Consent Management Model

@Model
final class GPSConsentRecord {
    var id: String = UUID().uuidString
    var userId: String = ""
    var consentGiven: Bool = false
    var consentDate: Date?
    var revokedDate: Date?
    var businessPurpose: String = ""
    var workHoursOnly: Bool = true
    var consentType: String = "GPS_TRACKING" // Types: GPS_TRACKING, VEHICLE_TRACKING, etc.
    var isActive: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var cloudKitSyncStatus: Int16 = 0
    var cloudKitSyncDate: Date?
    
    init(
        userId: String,
        businessPurpose: String,
        consentType: String = "GPS_TRACKING"
    ) {
        self.userId = userId
        self.businessPurpose = businessPurpose
        self.consentType = consentType
    }
    
    func giveConsent() {
        consentGiven = true
        consentDate = Date()
        revokedDate = nil
        isActive = true
        updatedAt = Date()
    }
    
    func revokeConsent() {
        consentGiven = false
        revokedDate = Date()
        isActive = false
        updatedAt = Date()
    }
    
    var hasValidConsent: Bool {
        return consentGiven && isActive && revokedDate == nil
    }
}

// MARK: - Work Hours Configuration Model

@Model
final class WorkHoursConfiguration {
    var id: String = UUID().uuidString
    var userId: String = ""
    var startHour: Int = 6 // 6 AM
    var endHour: Int = 20 // 8 PM
    @Attribute(.transformable(by: IntArrayTransformer.self)) var workDays: [Int] = [2, 3, 4, 5, 6] // Monday-Friday (Calendar weekday values)
    var timezone: String = "America/Los_Angeles"
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var cloudKitSyncStatus: Int16 = 0
    var cloudKitSyncDate: Date?
    
    init(userId: String, startHour: Int = 6, endHour: Int = 20) {
        self.userId = userId
        self.startHour = startHour
        self.endHour = endHour
    }
    
    func isWithinWorkHours(_ date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        
        let isWorkDay = workDays.contains(weekday)
        let isWorkHour = hour >= startHour && hour <= endHour
        
        return isWorkDay && isWorkHour
    }
}

// MARK: - CloudKit Extensions for GPS Models

extension VehicleTrackingSession: CloudKitSyncable {
    var cloudKitRecordType: String { "VehicleTrackingSession" }
    var cloudKitIdentifier: String { id }
}

extension VehicleTrackingPoint: CloudKitSyncable {
    var cloudKitRecordType: String { "VehicleTrackingPoint" }
    var cloudKitIdentifier: String { id }
}

extension GPSConsentRecord: CloudKitSyncable {
    var cloudKitRecordType: String { "GPSConsentRecord" }
    var cloudKitIdentifier: String { id }
}

extension WorkHoursConfiguration: CloudKitSyncable {
    var cloudKitRecordType: String { "WorkHoursConfiguration" }
    var cloudKitIdentifier: String { id }
}

// ServiceTitan Sync Extension for PurchaseOrder
extension PurchaseOrder {
    func syncWithServiceTitan(poId: String, jobId: String, jobNumber: String) {
        self.serviceTitanPoId = poId
        self.serviceTitanJobId = jobId
        self.serviceTitanJobNumber = jobNumber
        self.syncedWithServiceTitan = true
        self.serviceTitanSyncDate = Date()
    }
    
    func markSyncFailed(error: String) {
        self.syncedWithServiceTitan = false
        // Note: lastSyncError property doesn't exist in the model yet
        // self.lastSyncError = error
        self.serviceTitanSyncDate = Date()
    }
    
    var requiresServiceTitanSync: Bool {
        return !syncedWithServiceTitan && (serviceTitanJobId != nil || serviceTitanJobNumber != nil)
    }
} 