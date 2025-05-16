import Foundation
import SwiftData
import CloudKit

/// Represents an inventory item in the system
@Model
final class InventoryItem: Identifiable {
    var id: String = UUID().uuidString
    var name: String = ""
    var partNumber: String?
    var itemDescription: String?
    var category: String = ""
    var quantity: Int = 0
    var unit: String = "each"
    var cost: Double = 0.0
    var price: Double = 0.0
    var reorderPoint: Int = 0
    var targetStockLevel: Int?
    var location: String = ""
    var notes: String = ""
    var supplier: String?
    var lastRestockDate: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Warehouse or vehicle assignment
    var warehouseId: String?
    var vehicleId: String?
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var cloudKitSyncStatus: Int16 = 0 // Default to needs upload
    var cloudKitSyncDate: Date?
    
    // Optional photo of the item
    var photoData: Data?
    
    // Optional relationships
    @Relationship(deleteRule: .nullify) var warehouse: AppWarehouse?
    @Relationship(deleteRule: .nullify) var vehicle: AppVehicle?
    
    // StockLocationItems relationship - where inventory quantities and locations are tracked
    // Add inverse relationship to fix CloudKit integration issue
    @Relationship(inverse: \StockLocationItem.inventoryItem)
    var stockLocationItems: [StockLocationItem]?
    
    // Relationship with service records
    var serviceRecords: [AppServiceRecord]?
    
    var usageRecords: [InventoryUsageRecord]?
    
    // Computed properties - disabled to avoid conflicts with Vehix.InventoryItem
    // These properties are now defined in VehicleModels.swift
    
    var totalCost: Double {
        Double(quantity) * cost
    }
    
    var totalValue: Double {
        Double(quantity) * price
    }
    
    var profit: Double {
        price - cost
    }
    
    var profitMargin: Double {
        guard price > 0 else { return 0 }
        return (price - cost) / price * 100
    }
    
    // Initialize a new inventory item
    init(
        id: String = UUID().uuidString,
        name: String = "",
        partNumber: String? = nil,
        itemDescription: String? = nil,
        category: String = "Uncategorized",
        quantity: Int = 0,
        unit: String = "each",
        cost: Double = 0.0,
        price: Double = 0.0,
        reorderPoint: Int = 5,
        targetStockLevel: Int? = nil,
        location: String = "Main Warehouse",
        notes: String = "",
        supplier: String? = nil,
        lastRestockDate: Date? = nil,
        warehouseId: String? = nil,
        vehicleId: String? = nil,
        photoData: Data? = nil,
        warehouse: AppWarehouse? = nil,
        vehicle: AppVehicle? = nil,
        stockLocationItems: [StockLocationItem]? = nil,
        serviceRecords: [AppServiceRecord]? = nil,
        usageRecords: [InventoryUsageRecord]? = nil,
        cloudKitRecordID: String? = nil,
        cloudKitSyncStatus: Int16 = 0,
        cloudKitSyncDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.partNumber = partNumber
        self.itemDescription = itemDescription
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.cost = cost
        self.price = price 
        self.reorderPoint = reorderPoint
        self.targetStockLevel = targetStockLevel
        self.location = location
        self.notes = notes
        self.supplier = supplier
        self.lastRestockDate = lastRestockDate
        self.warehouseId = warehouseId
        self.vehicleId = vehicleId
        self.photoData = photoData
        self.warehouse = warehouse
        self.vehicle = vehicle
        self.stockLocationItems = stockLocationItems
        self.serviceRecords = serviceRecords
        self.usageRecords = usageRecords
        self.cloudKitRecordID = cloudKitRecordID
        self.cloudKitSyncStatus = cloudKitSyncStatus
        self.cloudKitSyncDate = cloudKitSyncDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
    
    // Adjust inventory quantity
    func adjustQuantity(by amount: Int) {
        quantity += amount
        if amount > 0 {
            lastRestockDate = Date()
        }
        updatedAt = Date()
    }
    
    // Assign to warehouse
    func assignToWarehouse(id: String) {
        self.warehouseId = id
        self.vehicleId = nil
        self.vehicle = nil
        updatedAt = Date()
    }
    
    // Assign to vehicle
    func assignToVehicle(vehicle: AppVehicle) {
        self.vehicle = vehicle
        self.vehicleId = vehicle.id
        self.warehouseId = nil
        updatedAt = Date()
    }
} 