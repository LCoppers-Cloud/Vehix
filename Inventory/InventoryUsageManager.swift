import Foundation
import SwiftData
import SwiftUI
import UserNotifications

/// Manages inventory usage, tracking, and replenishment
@MainActor
class InventoryUsageManager: ObservableObject {
    // Published properties for UI
    @Published var isLoading = false
    @Published var needsReplenishment: [AppInventoryItem] = []
    @Published var vehicleReplenishmentItems: [String: [AppInventoryItem]] = [:]
    @Published var errorMessage: String?
    
    private var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        requestNotificationPermission()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Inventory Usage Tracking
    
    /// Record usage of an inventory item
    func recordItemUsage(
        item: AppInventoryItem,
        quantity: Int,
        jobId: String?,
        jobNumber: String?,
        technician: AppUser?,
        vehicle: AppVehicle?,
        serviceRecord: AppServiceRecord?,
        imageData: Data?,
        comments: String?,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let modelContext = modelContext else {
            completion(false, "Database not available")
            return
        }
        
        guard quantity > 0 else {
            completion(false, "Quantity must be greater than zero")
            return
        }
        
        // Get or create a stock location for this item
        let stockLocations = fetchStockLocationsForItem(item)
        guard let stockLocation = stockLocations.first, stockLocation.quantity >= quantity else {
            completion(false, "Not enough inventory available")
            return
        }
        
        // Create usage record using the AppInventoryUsageRecord type alias
        let usageRecord = AppInventoryUsageRecord(
            id: UUID().uuidString,
            inventoryItemId: item.id,
            quantity: quantity,
            timestamp: Date(),
            technicianId: technician?.id,
            vehicleId: vehicle?.id,
            jobId: jobId,
            notes: comments
        )
        
        // Adjust the stock location's quantity
        stockLocation.quantity -= quantity
        stockLocation.updatedAt = Date()
        
        // Save to database
        do {
            modelContext.insert(usageRecord)
            try modelContext.save()
            
            // Check if replenishment is needed
            checkReplenishmentNeeds(for: item, stockLocation: stockLocation)
            
            completion(true, nil)
        } catch {
            completion(false, "Failed to save usage record: \(error.localizedDescription)")
        }
    }
    
    // Helper function to fetch stock locations for an item
    private func fetchStockLocationsForItem(_ item: AppInventoryItem) -> [StockLocationItem] {
        guard let modelContext = modelContext else {
            return []
        }
        
        // Safely get the item ID
        guard let itemId = item.id as String? else {
            return []
        }
        
        let predicate = #Predicate<StockLocationItem> { stockItem in
            stockItem.inventoryItem?.id == itemId
        }
        
        let descriptor = FetchDescriptor<StockLocationItem>(predicate: predicate)
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching stock locations: \(error)")
            return []
        }
    }
    
    // MARK: - Replenishment Management
    
    /// Check if item needs replenishment and send notifications
    private func checkReplenishmentNeeds(for item: AppInventoryItem, stockLocation: StockLocationItem) {
        // We need to check the stock location for quantity and minimumStockLevel
        if isReplenishmentNeeded(for: item, stockLocation: stockLocation) {
            // Send notification for warehouse replenishment
            let reorderPoint = item.reorderPoint
            sendReplenishmentNotification(
                for: item, 
                isWarehouse: stockLocation.warehouse != nil,
                quantity: max(1, reorderPoint * 2 - stockLocation.quantity)
            )
        } else if stockLocation.vehicle != nil && stockLocation.quantity <= stockLocation.minimumStockLevel {
            // Send notification for vehicle replenishment
            guard let vehicle = stockLocation.vehicle else { return }
            sendReplenishmentNotification(
                for: item, 
                isWarehouse: false,
                vehicleId: vehicle.id,
                vehicleName: "\(vehicle.year) \(vehicle.make) \(vehicle.model)",
                quantity: max(1, stockLocation.minimumStockLevel * 2 - stockLocation.quantity)
            )
        }
    }
    
    private func isReplenishmentNeeded(for item: AppInventoryItem, stockLocation: StockLocationItem) -> Bool {
        let reorderPoint = item.reorderPoint
        return stockLocation.quantity <= reorderPoint && stockLocation.warehouse != nil
    }
    
    /// Load all items that need replenishment
    func loadReplenishmentNeeds() async {
        guard let modelContext = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        isLoading = true
        
        do {
            // Get all StockLocationItem objects instead
            let descriptor = FetchDescriptor<StockLocationItem>()
            let stockLocations = try modelContext.fetch(descriptor)
            
            // Check each stock location
            var warehouseItems: [AppInventoryItem] = []
            var vehicleItems: [String: [AppInventoryItem]] = [:]
            
            for stockLocation in stockLocations {
                guard let item = stockLocation.inventoryItem else { continue }
                
                // For warehouse replenishment
                let reorderPoint = item.reorderPoint
                if stockLocation.warehouse != nil && stockLocation.quantity <= reorderPoint {
                    warehouseItems.append(item)
                }
                // For vehicle replenishment
                else if let vehicle = stockLocation.vehicle, stockLocation.quantity <= stockLocation.minimumStockLevel {
                    if vehicleItems[vehicle.id] == nil {
                        vehicleItems[vehicle.id] = []
                    }
                    vehicleItems[vehicle.id]?.append(item)
                }
            }
            
            // Update published properties
            DispatchQueue.main.async {
                self.needsReplenishment = warehouseItems
                self.vehicleReplenishmentItems = vehicleItems
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load replenishment needs: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Generate purchase order for warehouse replenishment
    func generateWarehouseReplenishmentOrder() async -> PurchaseOrder? {
        guard let modelContext = modelContext else {
            errorMessage = "Database not available"
            return nil
        }
        
        // Group items by supplier
        let itemsBySupplier = Dictionary(grouping: needsReplenishment) { item -> String in
            return item.supplier ?? "Unknown Supplier"
        }
        
        // For each supplier, create a purchase order
        var createdOrders: [PurchaseOrder] = []
        
        for (supplierName, items) in itemsBySupplier {
            // Skip if no items need replenishment
            if items.isEmpty { continue }
            
            // Get the first item's supplier ID or create a placeholder
            let vendorId = items.first?.supplier ?? "unknown-vendor"
            
            // Create new purchase order
            let po = PurchaseOrder(
                poNumber: "AUTO-\(UUID().uuidString.prefix(8))",
                vendorId: vendorId,
                vendorName: supplierName,
                status: .draft,
                subtotal: 0.0, // Will calculate based on line items
                notes: "Auto-generated replenishment order"
            )
            
            // Add line items
            var total = 0.0
            for item in items {
                // Find the stock location for this item
                let stockLocations = fetchStockLocationsForItem(item)
                guard let stockLocation = stockLocations.first(where: { $0.warehouse != nil }) else { continue }
                
                // Calculate reorder quantity based on reorderPoint
                let reorderPoint = item.reorderPoint
                
                // StockLocation.quantity is non-optional so no need for nil coalescing
                let quantity = max(1, (reorderPoint * 2) - stockLocation.quantity)
                
                // Use price as unit cost
                let lineTotal = Double(quantity) * (item.pricePerUnit)
                
                let lineItem = PurchaseOrderLineItem(
                    purchaseOrderId: po.id,
                    inventoryItemId: item.id,
                    itemDescription: item.name,
                    quantity: quantity,
                    unitPrice: item.pricePerUnit,
                    lineTotal: lineTotal
                )
                
                if po.lineItems == nil {
                    po.lineItems = []
                }
                po.lineItems?.append(lineItem)
                total += lineTotal
            }
            
            // Update order totals
            po.subtotal = total
            po.total = total // No tax for simplicity, could be added later
            
            // Save to database
            modelContext.insert(po)
            createdOrders.append(po)
        }
        
        do {
            try modelContext.save()
            return createdOrders.first // Return the first order created
        } catch {
            errorMessage = "Failed to create purchase order: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Generate vehicle replenishment task
    func createVehicleReplenishmentTask(for vehicleId: String) async -> String? {
        guard let items = vehicleReplenishmentItems[vehicleId], !items.isEmpty else {
            return nil
        }
        
        // In a real implementation, this would create a task in the system
        // For now, we'll just return a task ID
        return "TASK-\(UUID().uuidString.prefix(8))"
    }
    
    /// Load vehicle data for a specific vehicle
    func loadVehicleData(for vehicleId: String) async {
        // This method should load specific vehicle data
        // For now, the vehicle data is already loaded in the vehicle UI components
        // This is a placeholder to satisfy the interface
    }
    
    /// Fetch all vehicle replenishment data
    func fetchVehicleReplenishmentData() async {
        // Re-fetch all vehicle replenishment data
        await loadReplenishmentNeeds()
    }
    
    // MARK: - Notifications
    
    /// Request permission for notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Send notification for item replenishment
    private func sendReplenishmentNotification(
        for item: AppInventoryItem,
        isWarehouse: Bool,
        vehicleId: String? = nil,
        vehicleName: String? = nil,
        quantity: Int
    ) {
        let content = UNMutableNotificationContent()
        
        // Find stock location for this item
        let stockLocations = fetchStockLocationsForItem(item)
        let stockLocation = stockLocations.first
        let currentQuantity = stockLocation?.quantity ?? 0
        
        if isWarehouse {
            content.title = "Warehouse Inventory Alert"
            content.body = "\(item.name) is low in stock (Qty: \(currentQuantity)). Suggested reorder: \(quantity)"
            content.sound = .default
            content.userInfo = [
                "type": "warehouse_replenishment",
                "itemId": item.id,
                "quantity": quantity
            ]
        } else {
            content.title = "Vehicle Inventory Alert"
            content.body = "\(item.name) is low in \(vehicleName ?? "vehicle"). Replenishment needed: \(quantity)"
            content.sound = .default
            content.userInfo = [
                "type": "vehicle_replenishment",
                "itemId": item.id,
                "vehicleId": vehicleId ?? "",
                "quantity": quantity
            ]
        }
        
        // Create a unique identifier
        let identifier = "\(isWarehouse ? "warehouse" : "vehicle")_\(item.id)_\(Date().timeIntervalSince1970)"
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        // Add the request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Usage Reports
    
    /// Generate usage report for a date range
    func generateUsageReport(
        startDate: Date,
        endDate: Date,
        vehicleId: String? = nil,
        technicianId: String? = nil
    ) async -> [UsageReportItem] {
        guard let modelContext = modelContext else {
            errorMessage = "Database not available"
            return []
        }
        
        do {
            // Break up the complex type-check expressions into simpler steps
            // Use AppInventoryUsageRecord type alias
            let baseDescriptor = FetchDescriptor<AppInventoryUsageRecord>()
            let allRecords = try modelContext.fetch(baseDescriptor)
            
            // Filter the records in memory instead of complex predicates
            let filteredRecords = allRecords.filter { record in
                // First filter by date
                let dateMatches = record.timestamp >= startDate && record.timestamp <= endDate
                
                // Then check other filters
                if let vehicleId = vehicleId, let technicianId = technicianId {
                    return dateMatches && record.vehicleId == vehicleId && record.technicianId == technicianId
                } else if let vehicleId = vehicleId {
                    return dateMatches && record.vehicleId == vehicleId
                } else if let technicianId = technicianId {
                    return dateMatches && record.technicianId == technicianId
                } else {
                    return dateMatches
                }
            }
            
            // Process the filtered records
            let reportItems = processUsageRecords(filteredRecords)
            
            return reportItems
        } catch {
            errorMessage = "Failed to generate usage report: \(error.localizedDescription)"
            return []
        }
    }
    
    /// Process usage records into report items
    private func processUsageRecords(_ records: [AppInventoryUsageRecord]) -> [UsageReportItem] {
        // Group records by item using the inventoryItemId from AppInventoryUsageRecord
        let groupedByItem = Dictionary(grouping: records) { record in record.inventoryItemId }
        
        // Process into report items
        return groupedByItem.map { itemId, records in
            let totalQuantity = records.reduce(0) { $0 + $1.quantity }
            let totalCost = 0.0 // Cost calculation simplified since it's not in the basic model
            let itemName = "Item-\(itemId)" // Simplified since we don't have direct relationship
            
            return UsageReportItem(
                itemId: itemId,
                itemName: itemName,
                totalQuantity: totalQuantity,
                totalCost: totalCost,
                records: records
            )
        }.sorted { $0.totalCost > $1.totalCost } // Sort by cost (highest first)
    }
    
    /// Send replenishment email to vendor (simulated)
    func sendVendorReplenishmentEmail(vendorId: String, items: [AppInventoryItem]) -> Bool {
        // In a real app, this would connect to an email service
        // For now, we'll simulate success
        
        // Log the email content
        print("Email would be sent to vendor \(vendorId) for replenishment of \(items.count) items:")
        for item in items {
            // Check if the getReplenishmentQuantity method exists and use a fallback if not
            let quantity = (item as? any ExtendedInventoryItem)?.suggestedReplenishmentQuantity ?? 
                max(1, item.reorderPoint * 2 - calculateTotalQuantity(for: item))
            print("  - \(item.name): \(quantity) units")
        }
        
        return true
    }
    
    // Helper method to calculate total quantity for an item
    private func calculateTotalQuantity(for item: AppInventoryItem) -> Int {
        // Find all stock locations for this item and sum the quantities
        let stockLocations = fetchStockLocationsForItem(item)
        return stockLocations.reduce(0) { $0 + $1.quantity }
    }
}

// Model for usage report items
struct UsageReportItem: Identifiable {
    var id: String { itemId }
    var itemId: String
    var itemName: String
    var totalQuantity: Int
    var totalCost: Double
    var records: [AppInventoryUsageRecord]
} 