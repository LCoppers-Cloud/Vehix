import Foundation
import SwiftData

@Model
final class ServiceRecord: Identifiable {
    @Attribute(.unique) var id: String
    var serviceDate: Date
    var serviceType: String
    var serviceDescription: String
    var technicianId: String?
    var technicianName: String?
    var vehicleId: String?
    var customerId: String?
    var customerName: String?
    var status: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \AppVehicle.serviceRecords)
    var vehicle: AppVehicle?
    
    @Relationship(deleteRule: .nullify)
    var inventoryItemsUsed: [AppInventoryItem]?
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var cloudKitSyncStatus: Int16 = 0
    var cloudKitSyncDate: Date?
    
    // Initialize
    init(
        id: String = UUID().uuidString,
        serviceDate: Date = Date(),
        serviceType: String,
        serviceDescription: String,
        technicianId: String? = nil,
        technicianName: String? = nil,
        vehicleId: String? = nil,
        customerId: String? = nil,
        customerName: String? = nil,
        status: String = "Scheduled",
        notes: String = "",
        vehicle: AppVehicle? = nil,
        inventoryItemsUsed: [AppInventoryItem]? = nil,
        cloudKitRecordID: String? = nil,
        cloudKitSyncStatus: Int16 = 0,
        cloudKitSyncDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.serviceDate = serviceDate
        self.serviceType = serviceType
        self.serviceDescription = serviceDescription
        self.technicianId = technicianId
        self.technicianName = technicianName
        self.vehicleId = vehicleId
        self.customerId = customerId
        self.customerName = customerName
        self.status = status
        self.notes = notes
        self.vehicle = vehicle
        self.inventoryItemsUsed = inventoryItemsUsed
        self.cloudKitRecordID = cloudKitRecordID
        self.cloudKitSyncStatus = cloudKitSyncStatus
        self.cloudKitSyncDate = cloudKitSyncDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Computed property to calculate the total cost of used inventory
    var totalInventoryCost: Double {
        return inventoryItemsUsed?.reduce(0) { $0 + $1.pricePerUnit } ?? 0
    }
    
    // CloudKit sync methods
    func markPendingUpload() {
        self.cloudKitSyncStatus = 1 // pending upload
    }
    
    func markSynced() {
        self.cloudKitSyncStatus = 2 // synced
        self.cloudKitSyncDate = Date()
    }
    
    func markSyncFailed() {
        self.cloudKitSyncStatus = 3 // sync failed
    }
    
    // Helper method to add inventory item used in service
    func addInventoryItem(_ item: AppInventoryItem) {
        if inventoryItemsUsed == nil {
            inventoryItemsUsed = []
        }
        
        if !inventoryItemsUsed!.contains(where: { $0.id == item.id }) {
            inventoryItemsUsed!.append(item)
        }
    }
    
    // Helper method to remove inventory item
    func removeInventoryItem(_ item: AppInventoryItem) {
        if let items = inventoryItemsUsed, let index = items.firstIndex(where: { $0.id == item.id }) {
            inventoryItemsUsed!.remove(at: index)
        }
    }
} 