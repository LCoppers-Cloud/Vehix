import Foundation
import SwiftUI
import SwiftData
import Combine
import os

// Helper extension for AppInventoryItem to create and manage StockLocationItems
extension AppInventoryItem {
    // Assign to a warehouse - creates or updates a StockLocationItem
    func assignToWarehouse(id: String, modelContext: ModelContext? = nil) {
        // Find the warehouse to link to
        if let context = modelContext {
            let descriptor = FetchDescriptor<AppWarehouse>(predicate: #Predicate { $0.id == id })
            if let warehouse = try? context.fetch(descriptor).first {
                // Create a stock location for this item in the warehouse
                let stockLocation = StockLocationItem(
                    inventoryItem: self,
                    quantity: 0,
                    minimumStockLevel: 5,
                    warehouse: warehouse
                )
                context.insert(stockLocation)
            }
        }
    }
    
    // Assign to a vehicle - creates or updates a StockLocationItem
    func assignToVehicle(vehicle: AppVehicle, modelContext: ModelContext? = nil) {
        if let context = modelContext {
            // Create a stock location for this item in the vehicle
            let stockLocation = StockLocationItem(
                inventoryItem: self,
                quantity: 0,
                minimumStockLevel: 3,
                vehicle: vehicle
            )
            context.insert(stockLocation)
        }
    }
    
    // Get total quantity across all stock locations
    var totalQuantity: Int {
        // Sum quantities from all stockLocationItems
        return stockLocationItems?.reduce(0) { $0 + $1.quantity } ?? 0
    }
    
    // For replenishment view - check any stock location is below minimum
    var needsWarehouseReplenishment: Bool {
        // Find any warehouse stock location below its minimum stock level
        return stockLocationItems?.first(where: { 
            $0.warehouse != nil && $0.quantity < $0.minimumStockLevel
        }) != nil
    }
    
    var suggestedReplenishmentQuantity: Int {
        // Calculate total quantity and suggested replenishment amount
        let totalQty = totalQuantity
        // Use reorderPoint × 2 as target level, and get difference from current total
        return max(1, reorderPoint * 2 - totalQty)
    }
    
    // Add missing properties if not present
    var price: Double {
        get { _price ?? 0.0 }
        set { _price = newValue }
    }
    private var _price: Double? {
        get { objc_getAssociatedObject(self, &priceKey) as? Double }
        set { objc_setAssociatedObject(self, &priceKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    var reorderPoint: Int {
        get { _reorderPoint ?? 5 }
        set { _reorderPoint = newValue }
    }
    private var _reorderPoint: Int? {
        get { objc_getAssociatedObject(self, &reorderPointKey) as? Int }
        set { objc_setAssociatedObject(self, &reorderPointKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private var priceKey: UInt8 = 0
private var reorderPointKey: UInt8 = 0

/// View model for managing inventory operations
@MainActor
class InventoryManager: ObservableObject {
    @Published var warehouses: [AppWarehouse] = []
    @Published var allInventoryItems: [AppInventoryItem] = []
    @Published var filteredItems: [AppInventoryItem] = []
    @Published var stockLocations: [StockLocationItem] = []
    @Published var selectedWarehouse: AppWarehouse?
    @Published var selectedVehicle: AppVehicle?
    @Published var searchQuery: String = ""
    @Published var selectedCategory: String?
    @Published var sortOption: SortOption = .nameAsc
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var categories: [String] = []
    
    // Import/export
    @Published var showingImportPicker: Bool = false
    @Published var showingExportSheet: Bool = false
    @Published var showingTemplateSheet: Bool = false
    @Published var importSuccess: Bool = false
    @Published var importedItemCount: Int = 0
    
    // For selection mode
    @Published var selectionMode: Bool = false
    @Published var selectedItems: Set<String> = []
    
    // Stats
    @Published var totalInventoryValue: Double = 0
    @Published var lowStockCount: Int = 0
    @Published var totalItemCount: Int = 0
    @Published var itemsByCategoryCount: [String: Int] = [:]
    
    var modelContext: ModelContext! {
        didSet {
            if modelContext != nil {
                modelContextDidChange()
            }
        }
    }
    
    // Auth service for user verification - accept either type
    var authService: Any? {
        didSet {
            // No special handling needed when authService changes
        }
    }
    private var cancellables: Set<AnyCancellable> = []
    private let logger = Logger(subsystem: "com.vehix.app", category: "InventoryManager")
    
    enum SortOption: String, CaseIterable, Identifiable {
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case categoryAsc = "Category (A-Z)"
        case categoryDesc = "Category (Z-A)"
        case quantityAsc = "Quantity (Low to High)"
        case quantityDesc = "Quantity (High to Low)"
        case valueAsc = "Value (Low to High)"
        case valueDesc = "Value (High to Low)"
        
        var id: String { self.rawValue }
    }
    
    // Initialize with model context and auth service
    init(modelContext: ModelContext? = nil, authService: Any? = nil) {
        self.authService = authService
        
        if let context = modelContext {
            self.modelContext = context
            
            // Setup search and filter publishers
            setupPublishers()
            
            // Load initial data
            Task {
                await loadWarehouses()
                await loadInventoryItems()
                await loadStockLocations()
                await updateCategories()
                await updateStats()
            }
        } else {
            // Setup publishers only, data will be loaded when modelContext is set
            setupPublishers()
        }
    }
    
    // When modelContext is set, load the data
    func modelContextDidChange() {
        Task {
            await loadWarehouses()
            await loadInventoryItems()
            await loadStockLocations()
            await updateCategories()
            await updateStats()
        }
    }
    
    // Setup publishers for reactive updates
    private func setupPublishers() {
        // Create a publisher that combines searchQuery, selectedCategory, sortOption changes
        Publishers.CombineLatest3(
            $searchQuery,
            $selectedCategory,
            $sortOption
        )
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] (searchText, category, sortOption) in
            self?.applyFilters()
        }
        .store(in: &cancellables)
    }
    
    // Load warehouses from the database
    func loadWarehouses() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let descriptor = FetchDescriptor<AppWarehouse>(sortBy: [SortDescriptor(\.name)])
            warehouses = try modelContext.fetch(descriptor)
            
            // Remove default warehouse creation to prevent example warehouses from loading
            
            // Select the first warehouse if none is selected
            if selectedWarehouse == nil && !warehouses.isEmpty {
                selectedWarehouse = warehouses.first
            }
        } catch {
            errorMessage = "Failed to load warehouses: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // Load all inventory items
    func loadInventoryItems() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let descriptor = FetchDescriptor<AppInventoryItem>(sortBy: [SortDescriptor(\.name)])
            allInventoryItems = try modelContext.fetch(descriptor)
            applyFilters()
        } catch {
            errorMessage = "Failed to load inventory: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // Load all stock locations
    func loadStockLocations() async {
        do {
            let descriptor = FetchDescriptor<StockLocationItem>()
            stockLocations = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to load stock locations: \(error.localizedDescription)")
            errorMessage = "Failed to load stock data: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // Update the distinct categories list
    func updateCategories() async {
        let allCategories = allInventoryItems.map { $0.category }
        categories = Array(Set(allCategories)).sorted()
    }
    
    // Find stock locations for an item
    func findStockLocations(for item: AppInventoryItem) -> [StockLocationItem] {
        return stockLocations.filter { $0.inventoryItem?.id == item.id }
    }
    
    // Get total quantity for an item across all locations
    func getTotalQuantity(for item: AppInventoryItem) -> Int {
        return findStockLocations(for: item).reduce(0) { $0 + $1.quantity }
    }
    
    // Check if an item is below minimum stock at any location
    func isBelowMinimumStock(item: AppInventoryItem) -> Bool {
        return findStockLocations(for: item).contains { $0.isBelowMinimumStock }
    }
    
    // Update inventory statistics
    func updateStats() async {
        // Calculate value based on stock locations and item prices
        totalInventoryValue = 0.0
        for item in allInventoryItems {
            let totalQty = getTotalQuantity(for: item)
            totalInventoryValue += Double(totalQty) * item.price
        }
        
        // Count items below minimum stock level
        lowStockCount = 0
        for item in allInventoryItems {
            if isBelowMinimumStock(item: item) {
                lowStockCount += 1
            }
        }
        
        totalItemCount = allInventoryItems.count
        
        // Count items by category
        var categoryCounts: [String: Int] = [:]
        for item in allInventoryItems {
            categoryCounts[item.category, default: 0] += 1
        }
        itemsByCategoryCount = categoryCounts
    }
    
    // Apply search, category filters, and sorting
    func applyFilters() {
        // Start with all items
        var items = allInventoryItems
        
        // Filter by warehouse if selected
        if let warehouse = selectedWarehouse {
            items = items.filter { item in
                findStockLocations(for: item).contains { $0.warehouse?.id == warehouse.id }
            }
        }
        
        // Filter by vehicle if selected
        if let vehicle = selectedVehicle {
            items = items.filter { item in
                findStockLocations(for: item).contains { $0.vehicle?.id == vehicle.id }
            }
        }
        
        // Apply text search
        if !searchQuery.isEmpty {
            items = items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchQuery) ||
                (!item.partNumber.isEmpty && item.partNumber.localizedCaseInsensitiveContains(searchQuery)) ||
                (item.itemDescription?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }
        
        // Filter by category
        if let category = selectedCategory, !category.isEmpty {
            items = items.filter { $0.category == category }
        }
        
        // Apply sorting using modern API syntax
        switch sortOption {
        case .nameAsc:
            items.sort(by: { $0.name < $1.name })
        case .nameDesc:
            items.sort(by: { $0.name > $1.name })
        case .categoryAsc:
            items.sort(by: { $0.category < $1.category })
        case .categoryDesc:
            items.sort(by: { $0.category > $1.category })
        case .quantityAsc:
            items.sort(by: { getTotalQuantity(for: $0) < getTotalQuantity(for: $1) })
        case .quantityDesc:
            items.sort(by: { getTotalQuantity(for: $0) > getTotalQuantity(for: $1) })
        case .valueAsc:
            items.sort(by: { 
                (Double(getTotalQuantity(for: $0)) * $0.price) < (Double(getTotalQuantity(for: $1)) * $1.price)
            })
        case .valueDesc:
            items.sort(by: { 
                (Double(getTotalQuantity(for: $0)) * $0.price) > (Double(getTotalQuantity(for: $1)) * $1.price)
            })
        }
        
        // Update filtered items
        filteredItems = items
    }
    
    // Create a new inventory item with an associated stock location
    func createInventoryItem(name: String, category: String, quantity: Int) -> AppInventoryItem {
        // Create the item definition
        let item = AppInventoryItem(
            name: name,
            category: category
        )
        
        modelContext.insert(item)
        
        // Create a stock location for this item
        let stockLocation = StockLocationItem(
            inventoryItem: item,
            quantity: quantity,
            minimumStockLevel: 5
        )
        
        // Assign to warehouse if selected
        if let warehouse = selectedWarehouse {
            stockLocation.warehouse = warehouse
        }
        
        // Assign to vehicle if selected
        if let vehicle = selectedVehicle {
            stockLocation.vehicle = vehicle
        }
        
        modelContext.insert(stockLocation)
        try? modelContext.save()
        
        // Reload data
        Task {
            await loadInventoryItems()
            await loadStockLocations()
            await updateCategories()
            await updateStats()
        }
        
        return item
    }
    
    // Delete an inventory item and all its stock locations
    func deleteItem(_ item: AppInventoryItem) {
        // First delete all associated stock locations
        for stockLocation in findStockLocations(for: item) {
            modelContext.delete(stockLocation)
        }
        
        // Then delete the item itself
        modelContext.delete(item)
        try? modelContext.save()
        
        // Reload data
        Task {
            await loadInventoryItems()
            await loadStockLocations()
            await updateStats()
        }
    }
    
    // Delete multiple items
    func deleteSelectedItems() {
        for itemId in selectedItems {
            if let item = allInventoryItems.first(where: { $0.id == itemId }) {
                // Delete all associated stock locations first
                for stockLocation in findStockLocations(for: item) {
                    modelContext.delete(stockLocation)
                }
                
                // Then delete the item itself
                modelContext.delete(item)
            }
        }
        
        try? modelContext.save()
        selectedItems.removeAll()
        selectionMode = false
        
        // Reload data
        Task {
            await loadInventoryItems()
            await loadStockLocations()
            await updateStats()
        }
    }
    
    // Update item quantity in a specific stock location
    func updateItemQuantity(item: AppInventoryItem, newQuantity: Int, stockLocationId: String? = nil) {
        // Find the relevant stock location
        var targetStockLocation: StockLocationItem?
        
        if let locationId = stockLocationId {
            targetStockLocation = stockLocations.first { $0.id == locationId }
        } else {
            // If no specific location provided, update the first one found (or create one if needed)
            targetStockLocation = findStockLocations(for: item).first
            
            if targetStockLocation == nil {
                // Create a new stock location if none exists
                targetStockLocation = StockLocationItem(
                    inventoryItem: item,
                    quantity: 0,
                    minimumStockLevel: 5
                )
                
                // Assign to warehouse if selected, otherwise to the first warehouse
                if let warehouse = selectedWarehouse ?? warehouses.first {
                    targetStockLocation?.warehouse = warehouse
                }
                
                modelContext.insert(targetStockLocation!)
            }
        }
        
        // Update the quantity
        if let stockLocation = targetStockLocation {
            stockLocation.quantity = newQuantity
            stockLocation.updatedAt = Date()
            try? modelContext.save()
        }
        
        // Update stats
        Task {
            await loadStockLocations()
            await updateStats()
        }
    }
    
    // Toggle item selection
    func toggleItemSelection(_ itemId: String) {
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
        } else {
            selectedItems.insert(itemId)
        }
    }
    
    // Select all items
    func selectAllItems() {
        selectedItems = Set(filteredItems.map { $0.id })
    }
    
    // Deselect all items
    func deselectAllItems() {
        selectedItems.removeAll()
    }
    
    // Import from CSV file
    func importFromCSV(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Couldn't access the file"
            showError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let importedItems = try InventoryTemplateUtility.importInventoryFromCSV(data: data, modelContext: modelContext)
            
            // Assign all imported items to the selected warehouse
            if let warehouse = selectedWarehouse {
                for item in importedItems {
                    item.assignToWarehouse(id: warehouse.id, modelContext: modelContext)
                }
                try modelContext.save()
            }
            
            // Update success message
            importSuccess = true
            importedItemCount = importedItems.count
            
            // Reload data
            Task {
                await loadInventoryItems()
                await loadStockLocations()
                await updateCategories()
                await updateStats()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // Get exported inventory
    func getInventoryForExport() -> [AppInventoryItem] {
        // If items are selected, export those
        if !selectedItems.isEmpty {
            return allInventoryItems.filter { selectedItems.contains($0.id) }
        }
        
        // If filtering is active, export filtered items
        if !filteredItems.isEmpty && (filteredItems.count != allInventoryItems.count) {
            return filteredItems
        }
        
        // Otherwise export all items
        return allInventoryItems
    }
    
    // Create a new warehouse
    func createWarehouse(name: String, address: String) {
        let warehouse = AppWarehouse(id: UUID().uuidString, name: name, location: address)
        modelContext.insert(warehouse)
        try? modelContext.save()
        
        // Reload warehouses
        Task {
            await loadWarehouses()
        }
    }
    
    // Move selected items to warehouse
    func moveSelectedItemsToWarehouse(_ warehouse: AppWarehouse) {
        for itemId in selectedItems {
            if let item = allInventoryItems.first(where: { $0.id == itemId }) {
                // Create a new stock location in the warehouse
                item.assignToWarehouse(id: warehouse.id, modelContext: modelContext)
            }
        }
        
        try? modelContext.save()
        selectedItems.removeAll()
        selectionMode = false
        
        // Reload data
        Task {
            await loadInventoryItems()
            await loadStockLocations()
        }
    }
    
    // Move selected items to vehicle
    func moveSelectedItemsToVehicle(_ vehicle: AppVehicle) {
        for itemId in selectedItems {
            if let item = allInventoryItems.first(where: { $0.id == itemId }) {
                // Create a new stock location in the vehicle
                item.assignToVehicle(vehicle: vehicle, modelContext: modelContext)
            }
        }
        
        try? modelContext.save()
        selectedItems.removeAll()
        selectionMode = false
        
        // Reload data
        Task {
            await loadInventoryItems()
            await loadStockLocations()
        }
    }
    
    var hasActiveFilters: Bool {
        return !(searchQuery.isEmpty && selectedCategory == nil && selectedWarehouse == nil && selectedVehicle == nil)
    }
    
    func clearFilters() {
        searchQuery = ""
        selectedCategory = nil
        selectedWarehouse = nil
        selectedVehicle = nil
        applyFilters()
    }
    
    // Delete a warehouse after confirmation
    func deleteWarehouse(_ warehouse: AppWarehouse, managerPassword: String) async -> (success: Bool, message: String) {
        // Since we're accepting any auth service type and using a simplified validation,
        // this is just a placeholder implementation
        
        // In a real app, this would check with the appropriate auth service
        // For now we'll just use a simple password check
        if managerPassword != "admin1234" {
            return (false, "Invalid manager password")
        }
        
        do {
            // Find all stock locations in this warehouse
            let warehouseID = warehouse.id
            let stockItemDescriptor = FetchDescriptor<StockLocationItem>(
                predicate: #Predicate { 
                    $0.warehouse?.id == warehouseID 
                }
            )
            let stockItems = try modelContext.fetch(stockItemDescriptor)
            
            // Delete all stock locations for this warehouse
            for stockItem in stockItems {
                modelContext.delete(stockItem)
            }
            
            // Delete the warehouse itself
            modelContext.delete(warehouse)
            try modelContext.save()
            
            // Reload warehouses
            await loadWarehouses()
            
            // Update UI state
            if selectedWarehouse?.id == warehouse.id {
                selectedWarehouse = warehouses.first
            }
            
            return (true, "Warehouse successfully deleted")
        } catch {
            return (false, "Failed to delete warehouse: \(error.localizedDescription)")
        }
    }
} 