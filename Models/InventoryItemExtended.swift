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

// Protocol to extend inventory item functionality
public protocol ExtendedInventoryItem {
    var price: Double { get set }
    var reorderPoint: Int { get set }
    var suggestedReplenishmentQuantity: Int { get }
}

// MARK: - Extensions to add functionality to AppInventoryItem
extension AppInventoryItem {
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
    
    // Check if vehicle item needs replenishment
    var needsVehicleReplenishment: Bool {
        let vehicleStockLocation = stockLocationItems?.first(where: { $0.vehicle != nil })
        guard vehicleStockLocation != nil else { return false }
        return vehicleStockLocation!.quantity <= vehicleStockLocation!.minimumStockLevel
    }
    
    // Helper method to calculate total quantity across all stock locations
    private func calculateTotalQuantity() -> Int {
        return stockLocationItems?.reduce(0) { $0 + $1.quantity } ?? 0
    }
    
    // Computed property for estimated days until depletion
    var estimatedDaysUntilDepletion: Int {
        return estimateDaysUntilDepletion(monthlyUsage: 1.0)
    }
    
    // Calculate days until depletion given monthly usage
    func estimateDaysUntilDepletion(monthlyUsage: Double) -> Int {
        if monthlyUsage <= 0 { return 999 }
        let dailyUsage = monthlyUsage / 30.0
        let stockTotal = calculateTotalQuantity()
        return Int(Double(stockTotal) / dailyUsage)
    }
    
    // Warehouse relationship properties
    @objc var warehouseId: String? {
        get {
            return stockLocationItems?.first(where: { $0.warehouse != nil })?.warehouse?.id
        }
        set {
            // Not implementing for compatibility reasons
        }
    }
    
    var warehouse: AppWarehouse? {
        get {
            return stockLocationItems?.first(where: { $0.warehouse != nil })?.warehouse
        }
        set {
            // Not implementing for compatibility reasons
        }
    }
} 