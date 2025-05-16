import Foundation
import SwiftData

/// Represents a specific quantity of an inventory item at a particular location (Warehouse or Vehicle).
/// This allows tracking stock levels independently at different places.
@Model
final class StockLocationItem {
    /// Unique identifier for this stock record.
    var id: String = UUID().uuidString
    
    /// The quantity of the associated inventory item at this specific location.
    var quantity: Int = 0
    
    /// The minimum desired stock level for this item at this location.
    var minimumStockLevel: Int = 0
    
    /// The maximum desired stock level for this item at this location (optional).
    var maxStockLevel: Int?
    
    // MARK: - Relationships
    
    /// The inventory item definition this stock record refers to.
    /// Relationship is optional initially, should be set on creation.
    var inventoryItem: AppInventoryItem?
    
    /// The warehouse where this stock is located (if applicable).
    /// Null if the stock is located in a vehicle.
    var warehouse: AppWarehouse?
    
    /// The vehicle where this stock is located (if applicable).
    /// Null if the stock is located in a warehouse.
    var vehicle: AppVehicle?
    
    // MARK: - Timestamps
    
    /// The date and time when this stock record was created.
    var createdAt: Date = Date()
    
    /// The date and time when this stock record was last updated.
    var updatedAt: Date = Date()
    
    // MARK: - Initialization
    
    /// Initializes a new stock location record.
    init(
        id: String = UUID().uuidString,
        inventoryItem: AppInventoryItem? = nil,
        quantity: Int = 0,
        minimumStockLevel: Int = 0,
        maxStockLevel: Int? = nil,
        warehouse: AppWarehouse? = nil,
        vehicle: AppVehicle? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.inventoryItem = inventoryItem
        self.quantity = quantity
        self.minimumStockLevel = minimumStockLevel
        self.maxStockLevel = maxStockLevel
        self.warehouse = warehouse
        self.vehicle = vehicle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        // Ensure either warehouse or vehicle is set, but not both (validation)
        // assert((warehouse != nil && vehicle == nil) || (warehouse == nil && vehicle != nil), "StockLocationItem must belong to either a Warehouse or a Vehicle, not both or neither.")
        // assert(inventoryItem != nil, "StockLocationItem must be linked to an AppInventoryItem.")
    }
    
    // MARK: - Computed Properties
    
    /// Convenience property to get the name of the location (Warehouse or Vehicle display name).
    var locationName: String {
        if let warehouse = warehouse {
            return "Warehouse: \(warehouse.name)"
        }
        if let vehicle = vehicle {
            return "Vehicle: \(vehicle.displayName)"
        }
        return "Unassigned Location"
    }
    
    /// Indicates if the current quantity is below the minimum stock level for this location.
    var isBelowMinimumStock: Bool {
        quantity < minimumStockLevel
    }
} 