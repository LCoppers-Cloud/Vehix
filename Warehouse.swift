import Foundation
import SwiftData

/// Represents a warehouse or storage location
@Model
final class Warehouse: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var address: String
    var warehouseDescription: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationship with StockLocationItems
    var stockItems: [StockLocationItem]? = []
    
    // Computed property to get all inventory items in this warehouse
    var inventoryItems: [AppInventoryItem]? {
        get {
            guard let modelContext = ModelContext.current() else { return [] }
            
            // With the new model structure, we need to go through stockItems
            // and collect their associated inventory items
            let itemIds = stockItems?.compactMap { $0.inventoryItem?.id } ?? []
            if itemIds.isEmpty { return [] }
            
            do {
                // iOS 18+ compatible approach
                let descriptor = FetchDescriptor<AppInventoryItem>()
                let allItems = try modelContext.fetch(descriptor)
                return allItems.filter { item in 
                    itemIds.contains(item.id)
                }
            } catch {
                print("Failed to fetch inventory items for warehouse: \(error)")
                return []
            }
        }
    }
    
    // Initialize a new warehouse
    init(
        id: String = UUID().uuidString,
        name: String,
        address: String = "",
        warehouseDescription: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.warehouseDescription = warehouseDescription
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Computed property for total inventory value
    var totalInventoryValue: Double {
        // Use stockItems instead of inventoryItems to get quantity and price
        return stockItems?.reduce(into: 0.0) { result, stockItem in
            let price = stockItem.inventoryItem?.pricePerUnit ?? 0.0
            result += Double(stockItem.quantity) * price
        } ?? 0.0
    }
    
    // Computed property for total item count
    var totalItemCount: Int {
        stockItems?.reduce(0) { $0 + $1.quantity } ?? 0
    }
}

extension ModelContext {
    /// Helper to get the current model context from environment
    static func current() -> ModelContext? {
        // iOS 18+ compatible approach - the shared container should be accessed from the environment
        // in a real app, but this is a placeholder to avoid errors
        return nil
    }
} 