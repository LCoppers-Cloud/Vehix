import Foundation
import SwiftData
import SwiftUI

/* 
 * IMPORTANT ARCHITECTURAL NOTES:
 *
 * This file extends the core inventory models with additional functionality related to 
 * inventory tracking, usage records, and replenishment calculations.
 *
 * TYPE ALIAS RELATIONSHIP:
 * - AppInventoryItem = Vehix.InventoryItem (defined in ModelConfiguration.swift)
 * - We're extending AppInventoryItem with additional functionality and calculated properties
 *
 * KNOWN LIMITATIONS:
 * - The base Vehix.InventoryItem model in VehicleModels.swift doesn't have a usageRecords property
 *   so we need to manage the relationship between inventory items and usage records manually
 */

// Extended inventory tracking settings
struct InventoryThreshold {
    var minimum: Int
    var maximum: Int
    var reorderPoint: Int
    var reorderQuantity: Int
}

// Usage record to track inventory consumption
@Model
final class InventoryUsageRecord {
    var id: String = UUID().uuidString
    var itemId: String              // This references the inventory item ID
    var quantity: Int
    var usageDate: Date
    var jobId: String?
    var jobNumber: String?
    var technicianId: String?
    var technicianName: String?
    var vehicleId: String?
    var comments: String?
    var imageData: Data?
    var cost: Double
    var createdAt: Date
    
    // Relationships
    // NOTE: The inverse relationship doesn't actually exist in AppInventoryItem (Vehix.InventoryItem)
    // We're defining it here for consistency but it's not bidirectional
    var inventoryItem: AppInventoryItem?
    
    @Relationship(deleteRule: .nullify)
    var vehicle: AppVehicle?
    
    @Relationship(deleteRule: .nullify)
    var serviceRecord: AppServiceRecord?
    
    init(
        id: String = UUID().uuidString,
        itemId: String,
        quantity: Int,
        usageDate: Date = Date(),
        jobId: String? = nil,
        jobNumber: String? = nil,
        technicianId: String? = nil,
        technicianName: String? = nil,
        vehicleId: String? = nil,
        comments: String? = nil,
        imageData: Data? = nil,
        cost: Double,
        inventoryItem: AppInventoryItem? = nil,
        vehicle: AppVehicle? = nil,
        serviceRecord: AppServiceRecord? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.itemId = itemId
        self.quantity = quantity
        self.usageDate = usageDate
        self.jobId = jobId
        self.jobNumber = jobNumber
        self.technicianId = technicianId
        self.technicianName = technicianName
        self.vehicleId = vehicleId
        self.comments = comments
        self.imageData = imageData
        self.cost = cost
        self.inventoryItem = inventoryItem
        self.vehicle = vehicle
        self.serviceRecord = serviceRecord
        self.createdAt = createdAt
    }
}

// MARK: - Extensions to add functionality to AppInventoryItem
extension AppInventoryItem {
    /* 
     * NOTE: Vehix.InventoryItem doesn't natively have a usageRecords property. 
     * The extension methods that reference usageRecords are designed to work with 
     * separately queried InventoryUsageRecord objects.
     *
     * In a full implementation, proper bidirectional relationships would be established.
     *
     * IMPORTANT: Properties defined here must be carefully managed to avoid duplicate
     * declarations with other extensions. Always check the base class definition in
     * VehicleModels.swift before adding new properties.
     */
    
    // Enhanced inventory tracking settings
    var warehouseThreshold: InventoryThreshold {
        get {
            let min = reorderPoint
            let max = UserDefaults.standard.integer(forKey: "warehouse_max_\(id)") 
            let reorderPoint = UserDefaults.standard.integer(forKey: "warehouse_reorder_point_\(id)")
            let reorderQty = UserDefaults.standard.integer(forKey: "warehouse_reorder_quantity_\(id)")
            
            return InventoryThreshold(
                minimum: min,
                maximum: max == 0 ? min * 3 : max,
                reorderPoint: reorderPoint == 0 ? min : reorderPoint,
                reorderQuantity: reorderQty == 0 ? min * 2 : reorderQty
            )
        }
        set {
            reorderPoint = newValue.minimum
            UserDefaults.standard.set(newValue.maximum, forKey: "warehouse_max_\(id)")
            UserDefaults.standard.set(newValue.reorderPoint, forKey: "warehouse_reorder_point_\(id)")
            UserDefaults.standard.set(newValue.reorderQuantity, forKey: "warehouse_reorder_quantity_\(id)")
        }
    }
    
    var vehicleThreshold: InventoryThreshold {
        get {
            let min = UserDefaults.standard.integer(forKey: "vehicle_min_\(id)")
            let max = UserDefaults.standard.integer(forKey: "vehicle_max_\(id)")
            let reorderPoint = UserDefaults.standard.integer(forKey: "vehicle_reorder_point_\(id)")
            let reorderQty = UserDefaults.standard.integer(forKey: "vehicle_reorder_quantity_\(id)")
            
            return InventoryThreshold(
                minimum: min == 0 ? 1 : min,
                maximum: max == 0 ? 5 : max,
                reorderPoint: reorderPoint == 0 ? 2 : reorderPoint,
                reorderQuantity: reorderQty == 0 ? 3 : reorderQty
            )
        }
        set {
            UserDefaults.standard.set(newValue.minimum, forKey: "vehicle_min_\(id)")
            UserDefaults.standard.set(newValue.maximum, forKey: "vehicle_max_\(id)")
            UserDefaults.standard.set(newValue.reorderPoint, forKey: "vehicle_reorder_point_\(id)")
            UserDefaults.standard.set(newValue.reorderQuantity, forKey: "vehicle_reorder_quantity_\(id)")
        }
    }
    
    // Creates a new usage record for this inventory item
    // NOTE: The original code assumed there was a usageRecords property, but that's not 
    // present in Vehix.InventoryItem. This method is adjusted to just create and return a record.
    func recordUsage(
        quantity: Int,
        jobId: String?,
        jobNumber: String?,
        technicianId: String?,
        technicianName: String?,
        vehicle: AppVehicle?,
        serviceRecord: AppServiceRecord?,
        imageData: Data?,
        comments: String?
    ) -> InventoryUsageRecord {
        // Create usage record with proper initialization parameters matching InventoryUsageRecord init
        let usageRecord = InventoryUsageRecord(
            itemId: id,
            quantity: quantity,
            usageDate: Date(),
            jobId: jobId,
            jobNumber: jobNumber,
            technicianId: technicianId,
            technicianName: technicianName,
            vehicleId: vehicle?.id,
            comments: comments,
            imageData: imageData,
            cost: pricePerUnit * Double(quantity),
            inventoryItem: self,
            vehicle: vehicle,
            serviceRecord: serviceRecord
        )
        
        // Update quantity on the first available stock location instead
        if let firstStockLocation = stockLocationItems?.first {
            firstStockLocation.quantity -= quantity
        }
        
        return usageRecord
    }
    
    // MARK: - Replenishment management
    
    /* This method is defined elsewhere as an optional, so we're not defining it here
    // Check if warehouse item needs replenishment based on thresholds
    var needsWarehouseReplenishment: Bool {
        return quantity <= warehouseThreshold.reorderPoint
    }
    */
    
    // Check if vehicle item needs replenishment
    var needsVehicleReplenishment: Bool {
        // Only applies if this has a stock location with a vehicle
        let vehicleStockLocation = stockLocationItems?.first(where: { $0.vehicle != nil })
        guard vehicleStockLocation != nil else { return false }
        return vehicleStockLocation!.quantity <= vehicleStockLocation!.minimumStockLevel
    }
    
    // Get suggested quantity to replenish - this is already defined elsewhere
    /* This method is defined elsewhere as an optional, so we're not defining it here
    var suggestedReplenishmentQuantity: Int {
        if needsWarehouseReplenishment {
            return warehouseThreshold.reorderQuantity
        } else if needsVehicleReplenishment {
            return vehicleThreshold.reorderQuantity
        }
        return 0
    }
    */
    
    // Helper method to determine if replenishment is needed, safely unwrapping optional
    func isReplenishmentNeeded() -> Bool {
        // Safely unwrap the optional property defined in InventoryManager.swift
        if let needsReplenishment = (self as? any ExtendedInventoryItem)?.needsWarehouseReplenishment {
            return needsReplenishment
        }
        // Fallback logic if the optional is not available
        let stockTotal = calculateTotalQuantity()
        return stockTotal <= reorderPoint
    }
    
    // Helper method to get suggested quantity for replenishment
    func getReplenishmentQuantity() -> Int {
        // Safely unwrap the optional property defined in InventoryManager.swift
        if let suggestedQty = (self as? any ExtendedInventoryItem)?.suggestedReplenishmentQuantity {
            return suggestedQty
        }
        // Fallback logic if the optional is not available
        let stockTotal = calculateTotalQuantity()
        return max(1, reorderPoint * 2 - stockTotal)
    }
    
    // Helper to calculate total quantity across all stock locations
    private func calculateTotalQuantity() -> Int {
        // Sum quantities from all stock locations
        return stockLocationItems?.reduce(0) { $0 + $1.quantity } ?? 0
    }
    
    // MARK: - Usage statistics
    
    /*
     * NOTE: The following methods assume that we fetch usageRecords separately and pass them in.
     * This is a workaround since the base Vehix.InventoryItem doesn't have a usageRecords property.
     */
    
    // Computed property for estimated days until depletion
    // This provides a default implementation to make InventoryReplenishmentView happy
    var estimatedDaysUntilDepletion: Int {
        // Use a default monthly usage value of 1.0 if we don't have access to actual usage records
        // In a full implementation, this would query for related usage records first
        return estimateDaysUntilDepletion(monthlyUsage: 1.0)
    }
    
    // Calculate monthly usage given a list of usage records
    func calculateMonthlyUsage(with usageRecords: [InventoryUsageRecord]) -> Double {
        guard !usageRecords.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let now = Date()
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        
        let recentUsages = usageRecords.filter { 
            $0.itemId == self.id && $0.usageDate >= oneMonthAgo 
        }
        let totalQuantity = recentUsages.reduce(0) { $0 + $1.quantity }
        
        return Double(totalQuantity)
    }
    
    // Calculate days until depletion given monthly usage
    func estimateDaysUntilDepletion(monthlyUsage: Double) -> Int {
        if monthlyUsage <= 0 { return 999 } // Practically infinite if no usage
        
        // Daily usage rate
        let dailyUsage = monthlyUsage / 30.0
        
        // Days until depletion at current rate
        let stockTotal = calculateTotalQuantity()
        return Int(Double(stockTotal) / dailyUsage)
    }
    
    // MARK: - Warehouse Relationship Properties
    
    // Add warehouse relationship properties that don't exist in the base class
    @objc var warehouseId: String? {
        get {
            // Look for a warehouse in stock locations
            return stockLocationItems?.first(where: { $0.warehouse != nil })?.warehouse?.id
        }
        set {
            // This would need to create or update stock locations appropriately
            // Not implementing for compatibility reasons
        }
    }
    
    // Warehouse relationship (computed property that loads the warehouse on-demand)
    var warehouse: AppWarehouse? {
        get {
            // Look for a warehouse in stock locations
            return stockLocationItems?.first(where: { $0.warehouse != nil })?.warehouse
        }
        set {
            // This would need proper implementation if allowed to set
        }
    }
}

// Protocol to help bridge optional and non-optional property versions
protocol ExtendedInventoryItem {
    var needsWarehouseReplenishment: Bool? { get }
    var suggestedReplenishmentQuantity: Int? { get }
}

// Helper functions for working with InventoryUsageRecords
extension InventoryUsageRecord {
    // Find all usage records for a specific inventory item
    static func findAllForItem(itemId: String, in modelContext: ModelContext) -> [InventoryUsageRecord] {
        do {
            let descriptor = FetchDescriptor<InventoryUsageRecord>(
                predicate: #Predicate<InventoryUsageRecord> { record in
                    record.itemId == itemId
                }
            )
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching usage records: \(error.localizedDescription)")
            return []
        }
    }
} 