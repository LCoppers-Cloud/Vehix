import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    // State for tab selection
    @State private var selectedTab = 0
    
    // Sheet states
    @State private var showingAddItemSheet = false
    @State private var showingAddWarehouseSheet = false
    @State private var showingTransferSheet = false
    @State private var itemToTransfer: StockLocationItem? = nil
    @State private var showingFirstTimeHelp = false
    @State private var showingDeleteWarehouseSheet = false
    @State private var warehouseToDelete: AppWarehouse? = nil
    @State private var showingExcelSheet = false
    @State private var isExporting = false
    
    // Alert and message states
    @State private var showingExcelExportOptions = false
    @State private var showImportSuccessAlert = false
    @State private var importSuccessMessage = ""
    @State private var showingErrorAlert = false
    @State private var errorAlertMessage = ""
    
    // Manager for inventory operations
    @StateObject private var inventoryManager: InventoryManager
    
    // Document picker states
    @State private var isImporting = false
    @State private var importedFileURL: URL?
    
    // Create the manager with the model context
    init() {
        // Use the _StateObject property wrapper to initialize the StateObject
        _inventoryManager = StateObject(wrappedValue: InventoryManager())
    }
    
    // Fetch StockLocationItems, prefetch related item definition for efficiency
    @Query(sort: [SortDescriptor(\StockLocationItem.inventoryItem?.name)])
    private var stockItems: [StockLocationItem]
    
    // Fetch inventory items for definitions
    @Query(sort: [SortDescriptor(\AppInventoryItem.name)])
    private var inventoryItems: [AppInventoryItem]
    
    // Fetch warehouses
    @Query(sort: [SortDescriptor(\AppWarehouse.name)])
    private var warehouses: [AppWarehouse]
    
    /// Group stock items by their underlying inventory item definition
    private var groupedStockItems: [AppInventoryItem: [StockLocationItem]] {
        Dictionary(grouping: stockItems.filter { $0.inventoryItem != nil }) { $0.inventoryItem! }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Dashboard").tag(0)
                    Text("Inventory List").tag(1)
                    Text("Warehouses").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Main content area
                mainContent
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Make Add Item button visible to all users
                    Menu {
                        Button(action: { showingAddItemSheet = true }) {
                            Label("Add Item", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showingAddWarehouseSheet = true }) {
                            Label("Add Warehouse", systemImage: "building.2")
                        }
                        
                        Divider()
                        
                        Button(action: { showingExcelSheet = true }) {
                            Label("Import from Excel", systemImage: "square.and.arrow.down")
                        }
                        
                        Button(action: { showingExcelExportOptions = true }) {
                            Label("Export to Excel", systemImage: "square.and.arrow.up")
                        }
                        
                        if !warehouses.isEmpty && !inventoryItems.isEmpty {
                            Divider()
                            
                            Button(action: { showingFirstTimeHelp = true }) {
                                Label("Help & Introduction", systemImage: "questionmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Sheet for adding a new item definition
            .sheet(isPresented: $showingAddItemSheet) {
                AddInventoryItemForm()
                    .environment(\.modelContext, modelContext)
            }
            // Sheet for adding a new warehouse
            .sheet(isPresented: $showingAddWarehouseSheet) {
                VehixAddWarehouseForm(onSave: { _ in 
                    // Do nothing with the new warehouse - just adding it to the database is enough
                })
                .environment(\.modelContext, modelContext)
            }
            // Sheet for transferring stock
            .sheet(item: $itemToTransfer) { stockItem in
                // Pass the specific warehouse stock item to the transfer view
                TransferStockView(sourceStockItem: stockItem)
                    .environmentObject(authService)
            }
            // Sheet for deleting a warehouse
            .sheet(item: $warehouseToDelete) { warehouse in
                DeleteWarehouseView(warehouse: warehouse) { managerPassword in
                    Task {
                        inventoryManager.modelContext = modelContext
                        let result = await inventoryManager.deleteWarehouse(warehouse, managerPassword: managerPassword)
                        if !result.success {
                            errorAlertMessage = result.message
                            showingErrorAlert = true
                        }
                    }
                }
                .environmentObject(authService)
            }
            .sheet(isPresented: $showingFirstTimeHelp) {
                InventoryHelpView()
            }
            .alert("Import Successful", isPresented: $showImportSuccessAlert) {
                Button("OK") { }
            } message: {
                Text(importSuccessMessage)
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorAlertMessage)
            }
            .onAppear {
                inventoryManager.modelContext = modelContext
                // authService property now accepts Any type
                inventoryManager.authService = authService
            }
        }
    }
    
    // MARK: - Subviews
    
    // Main content view based on selected tab and data availability
    private var mainContent: some View {
        Group {
            switch selectedTab {
            case 0: // Dashboard
                if inventoryItems.isEmpty {
                    emptyDashboardView
                } else {
                    inventoryDashboardView
                }
            case 1: // Inventory List
                if inventoryItems.isEmpty {
                    emptyInventoryView
                } else {
                    inventoryListView
                }
            case 2: // Warehouses
                if warehouses.isEmpty {
                    emptyWarehouseView
                } else {
                    // Use a NavigationView with list of warehouses
                    List {
                        ForEach(warehouses) { warehouse in
                            NavigationLink(destination: warehouseDetailView(for: warehouse)) {
                                VStack(alignment: .leading) {
                                    Text(warehouse.name)
                                        .font(.headline)
                                    Text(warehouse.location)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    warehouseToDelete = warehouse
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            default:
                Text("Invalid tab selected")
            }
        }
    }
    
    // Empty state view when no inventory exists
    private var emptyInventoryView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "cube.box.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue.opacity(0.7))
            
            Text("No Inventory Items")
                .font(.title2)
                .bold()
            
            Text("Start tracking your inventory by adding items individually or importing from Excel.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            VStack(spacing: 16) {
                Button(action: {
                    showingAddItemSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Inventory Item")
                    }
                    .frame(minWidth: 240)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // New Excel Import Button
                Button(action: {
                    // This would show an Excel import sheet in the future
                    // For now it will show a coming soon alert
                    showExcelImportComingSoon()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Import from Excel")
                    }
                    .frame(minWidth: 240)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                if warehouses.isEmpty {
                    Button(action: {
                        showingAddWarehouseSheet = true
                    }) {
                        HStack {
                            Image(systemName: "building.2")
                            Text("Add Warehouse")
                        }
                        .frame(minWidth: 240)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                    }
                }
                
                Button(action: {
                    showingFirstTimeHelp = true
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("Learn About Inventory")
                    }
                    .frame(minWidth: 240)
                    .padding()
                    .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("With Inventory Management You Can:")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                FeatureRow(icon: "cube.box.fill", text: "Track parts and supplies across warehouses")
                FeatureRow(icon: "arrow.left.arrow.right", text: "Transfer inventory between locations")
                FeatureRow(icon: "car.fill", text: "Assign inventory to service vehicles")
                FeatureRow(icon: "bell.fill", text: "Get low stock alerts automatically")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Monitor inventory usage and costs")
                FeatureRow(icon: "power", text: "Deactivate items without deleting them")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    // Empty state view when no warehouses exist
    private var emptyWarehouseView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "building.2.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue.opacity(0.7))
            
            Text("No Warehouses Added")
                .font(.title2)
                .bold()
            
            Text("Add a warehouse to organize and track your inventory. Most businesses only need one warehouse, but you can add multiple locations if needed.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingAddWarehouseSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add First Warehouse")
                }
                .frame(minWidth: 240)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("About Warehouses")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Warehouses represent physical storage locations")
                    Text("• You can have one or multiple warehouses")
                    Text("• Each warehouse can store different inventory items")
                    Text("• Track stock quantities separately for each location")
                    Text("• Transfer inventory between warehouses as needed")
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    // Dashboard view showing summary information
    private var inventoryDashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Inventory Summary")
                    .font(.headline)
                    .padding(.horizontal)
                
                // Extract low stock warning section to separate method
                lowStockWarningSection
                
                // Extract warehouse summary to separate method
                warehouseSummarySection
                
                // Add import/export buttons
                HStack(spacing: 12) {
                    Button(action: {
                        showingExcelSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Excel")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color("vehix-blue"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        showingExcelExportOptions = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Excel")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color("vehix-green"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingExcelSheet) {
            ExcelImportView(onImport: { importedCount in
                importSuccessMessage = "Successfully imported \(importedCount) inventory items."
                showImportSuccessAlert = true
            })
        }
        .sheet(isPresented: $showingExcelExportOptions) {
            ExcelExportView(inventoryItems: inventoryItems)
        }
    }
    
    // Low stock warning section extracted to reduce complexity
    private var lowStockWarningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Low Stock Items")
                .font(.subheadline)
                .foregroundColor(.orange)
            
            let lowStockItems = stockItems.filter({ $0.isBelowMinimumStock }).prefix(5)
            
            if !lowStockItems.isEmpty {
                ForEach(Array(lowStockItems), id: \.id) { item in
                    lowStockItemRow(for: item)
                }
            } else {
                Text("No low stock items")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Individual low stock item row
    private func lowStockItemRow(for item: StockLocationItem) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(item.inventoryItem?.name ?? "Unknown Item")
            Spacer()
            Text("\(item.quantity)/\(item.minimumStockLevel)")
                .foregroundColor(.orange)
        }
        .padding(.horizontal)
    }
    
    // Warehouse summary section extracted to reduce complexity
    private var warehouseSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Warehouses")
                .font(.subheadline)
            
            ForEach(warehouses.prefix(3)) { warehouse in
                warehouseRow(for: warehouse)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Individual warehouse row
    private func warehouseRow(for warehouse: AppWarehouse) -> some View {
        let warehouseItems = stockItems.filter { $0.warehouse?.id == warehouse.id }
        let totalItems = warehouseItems.count
        // Removed unused variable calculation
        
        return HStack {
            Image(systemName: "building.2")
                .foregroundColor(.blue)
            Text(warehouse.name)
            Spacer()
            Text("\(totalItems) items")
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    // Warehouse detail view function
    private func warehouseDetailView(for warehouse: AppWarehouse) -> some View {
        let warehouseStockItems = stockItems.filter { $0.warehouse?.id == warehouse.id }
        
        return List {
            Section("Warehouse Info") {
                LabeledContent("Name", value: warehouse.name)
                LabeledContent("Location", value: warehouse.location)
                LabeledContent("Total Items", value: "\(warehouseStockItems.count)")
            }
            
            Section("Inventory") {
                if warehouseStockItems.isEmpty {
                    Text("No items in this warehouse")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(warehouseStockItems) { stockItem in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(stockItem.inventoryItem?.name ?? "Unknown Item")
                                    .font(.body)
                                if let partNumber = stockItem.inventoryItem?.partNumber {
                                    Text("Part #: \(partNumber)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text("Qty: \(stockItem.quantity)")
                                .bold()
                                .foregroundColor(stockItem.isBelowMinimumStock ? .red : .primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(warehouse.name)
    }
    
    // Inventory list view showing all items
    private var inventoryListView: some View {
        VStack {
            // Add an import/export toolbar above the list
            HStack {
                Button(action: {
                    showingAddItemSheet = true
                }) {
                    Label("Add Item", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    showingExcelSheet = true 
                }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    showingExcelExportOptions = true
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Existing list content
            inventoryListContent
                .listStyle(.insetGrouped)
        }
        .sheet(isPresented: $showingExcelSheet) {
            ExcelImportView(onImport: { importedCount in
                importSuccessMessage = "Successfully imported \(importedCount) inventory items."
                showImportSuccessAlert = true
            })
        }
        .sheet(isPresented: $showingExcelExportOptions) {
            ExcelExportView(inventoryItems: inventoryItems)
        }
    }
    
    // Extract complex content to improve compiler performance
    private var inventoryListContent: some View {
        List {
            // Iterate through grouped items
            let sortedKeys = groupedStockItems.keys.sorted(by: { $0.name < $1.name })
            
            ForEach(sortedKeys, id: \.id) { itemDefinition in
                inventorySection(for: itemDefinition)
            }
        }
        .onAppear {
            print("INVENTORY COUNT: \(inventoryItems.count)")
            print("STOCK ITEMS COUNT: \(stockItems.count)")
            for item in inventoryItems {
                print("Inventory ID: \(item.id), Name: \(item.name)")
            }
        }
    }
    
    // Extract section creation to a method
    private func inventorySection(for itemDefinition: AppInventoryItem) -> some View {
        Section(header: InventoryItemGroupHeader(item: itemDefinition)) {
            // List each location for this item
            let locations = groupedStockItems[itemDefinition] ?? []
            ForEach(locations, id: \.id) { stockLocation in
                inventoryRow(for: stockLocation)
            }
        }
    }
    
    // Extract row creation to a method
    private func inventoryRow(for stockLocation: StockLocationItem) -> some View {
        let isWarehouse = stockLocation.warehouse != nil
        let isAdmin = authService.currentUser?.userRole == .admin
        let isDealer = authService.currentUser?.userRole == .dealer
        let canTransfer = (isAdmin || isDealer) && isWarehouse
        
        return InventoryStockLocationRow(
            stockItem: stockLocation,
            canTransfer: canTransfer,
            onTransfer: { item in
                itemToTransfer = item
                showingTransferSheet = true
            }
        )
    }
    
    // Function to show Excel import coming soon alert
    private func showExcelImportComingSoon() {
        let alert = UIAlertController(title: "Coming Soon", message: "Excel import functionality will be available in the next update. Stay tuned!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Find the active window scene and present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    // Dashboard view - Empty state
    private var emptyDashboardView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue.opacity(0.7))
            
            Text("Inventory Dashboard")
                .font(.title2)
                .bold()
            
            Text("Add inventory items to see your dashboard with stock levels, alerts, and analytics.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Dashboard Features")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "exclamationmark.triangle", text: "Low stock alerts for items below minimum levels")
                    FeatureRow(icon: "chart.pie", text: "Inventory value breakdown by category")
                    FeatureRow(icon: "arrow.up.arrow.down", text: "Recent inventory transactions and transfers")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Usage trends and consumption patterns")
                    FeatureRow(icon: "eye", text: "Quick view of total items across all locations")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            
            Button(action: {
                showingAddItemSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add First Item")
                }
                .frame(minWidth: 240)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Spacer()
        }
    }
}

/// Simple component for feature list
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundColor(.blue)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Help and introduction view for inventory management
struct InventoryHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Introduction
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Welcome to Inventory Management")
                            .font(.title2)
                            .bold()
                        
                        Text("This guide will help you understand how to use the inventory management system to track parts, supplies, and equipment across your warehouses and vehicles.")
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Tab Explanations
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Understanding the Tabs")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dashboard Tab")
                                .fontWeight(.semibold)
                            
                            Text("The Dashboard provides a quick overview of your inventory status, including low stock alerts, recent activity, and usage trends. Monitor your inventory health at a glance.")
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Inventory List Tab")
                                .fontWeight(.semibold)
                            
                            Text("View and manage all your inventory items in a detailed list. See quantities across locations, transfer stock, update item details, and track usage history.")
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Warehouses Tab")
                                .fontWeight(.semibold)
                            
                            Text("Manage your physical storage locations. Most businesses need only one warehouse, but you can add multiple warehouses if your operations span different locations.")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Key Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Key Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "list.bullet", text: "Track inventory items with details such as name, part number, and price")
                        
                        FeatureRow(icon: "building.2", text: "Organize inventory across multiple warehouses or locations")
                        
                        FeatureRow(icon: "car", text: "Assign inventory to service vehicles for field technicians")
                        
                        FeatureRow(icon: "arrow.left.arrow.right", text: "Transfer items between locations with full history tracking")
                        
                        FeatureRow(icon: "bell", text: "Get notified when stock levels fall below minimums")
                        
                        FeatureRow(icon: "power", text: "Deactivate items temporarily without deleting them")
                        
                        FeatureRow(icon: "arrow.down.doc", text: "Import inventory data from Excel spreadsheets (coming soon)")
                    }
                    
                    Divider()
                    
                    // Getting Started
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Getting Started")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Add Warehouses")
                                .fontWeight(.semibold)
                            
                            Text("Start by adding at least one warehouse where your inventory will be stored. Each warehouse represents a physical location with a name and address.")
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("2. Add Inventory Items")
                                .fontWeight(.semibold)
                            
                            Text("Create inventory items with details like name, part number, category, and price. You'll set initial quantities, minimum stock levels, and assign to warehouses.")
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("3. Manage Stock")
                                .fontWeight(.semibold)
                            
                            Text("Adjust quantities, transfer between locations, or assign to vehicles as needed. The system will track all changes automatically.")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Warehouse Management
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Warehouse Management")
                            .font(.headline)
                        
                        Text("Most businesses only need to set up one warehouse to track their inventory. However, the system supports multiple warehouses if you have different physical locations.")
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Each warehouse has its own inventory quantities")
                            Text("• Set location-specific minimum stock levels")
                            Text("• Easily transfer inventory between warehouses")
                            Text("• View warehouse-specific stock reports")
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pro Tips")
                            .font(.headline)
                            
                        Text("• Set realistic minimum stock levels based on usage patterns")
                        Text("• Use categories consistently to make filtering easier")
                        Text("• Check the dashboard regularly for low stock warnings")
                        Text("• Deactivate seasonal items instead of deleting them")
                        Text("• Track transfers carefully to maintain accurate counts")
                    }
                    .foregroundColor(.secondary)
                    
                    Button("Close Guide") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top, 16)
                }
                .padding()
            }
            .navigationTitle("Inventory Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Header view for each inventory item group
struct InventoryItemGroupHeader: View {
    let item: AppInventoryItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(item.name).font(.headline)
                    if !item.isActive {
                        Text("INACTIVE")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray)
                            .cornerRadius(4)
                    }
                }
                Text("Part #: \(item.partNumber)").font(.subheadline).foregroundColor(.secondary)
                if let callout = item.calloutNumber, !callout.isEmpty {
                    Text("Callout: \(callout)").font(.caption).foregroundColor(.orange)
                }
            }
            Spacer()
            // Display total quantity across all locations
            Text("Total: \(item.stockTotalQuantity)").font(.callout).bold()
        }
        .padding(.vertical, 5)
        .opacity(item.isActive ? 1.0 : 0.7)
    }
}

/// Row view for a specific stock location
struct InventoryStockLocationRow: View {
    let stockItem: StockLocationItem
    let canTransfer: Bool
    let onTransfer: (StockLocationItem) -> Void
    
    @State private var showingChangeStatus = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            Image(systemName: stockItem.warehouse != nil ? "building.2" : "car")
                .foregroundColor(.secondary)
                .frame(width: 25)
            VStack(alignment: .leading) {
                // Use warehouse or vehicle properties directly instead of locationName
                if let warehouse = stockItem.warehouse {
                    Text("Warehouse: \(warehouse.name)").font(.body)
                } else if let vehicle = stockItem.vehicle {
                    Text("Vehicle: \(vehicle.make) \(vehicle.model)").font(.body)
                } else {
                    Text("Unassigned Location").font(.body)
                }
                
                Text("Min: \(stockItem.minimumStockLevel) | Max: \(stockItem.maxStockLevel != nil ? String(stockItem.maxStockLevel!) : "N/A")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("Qty: \(stockItem.quantity)")
                .font(.body).bold()
                .foregroundColor(stockItem.isBelowMinimumStock ? .red : .primary)

            // Action Menu
            if canTransfer {
                Menu {
                    if stockItem.warehouse != nil {
                        Button {
                            onTransfer(stockItem)
                        } label: {
                            Label("Transfer", systemImage: "arrow.right.circle.fill")
                        }
                    }
                    
                    // Toggle active state
                    if let inventoryItem = stockItem.inventoryItem {
                        Button {
                            showingChangeStatus = true
                        } label: {
                            Label(inventoryItem.isActive ? "Deactivate Item" : "Activate Item", 
                                  systemImage: inventoryItem.isActive ? "power" : "power.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
                .confirmationDialog(
                    "Change Item Status",
                    isPresented: $showingChangeStatus,
                    titleVisibility: .visible
                ) {
                    if let inventoryItem = stockItem.inventoryItem {
                        Button(inventoryItem.isActive ? "Deactivate Item" : "Activate Item") {
                            inventoryItem.isActive.toggle()
                            try? modelContext.save()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                } message: {
                    if let inventoryItem = stockItem.inventoryItem, 
                       inventoryItem.isActive {
                        Text("Deactivating will hide this item from regular inventory views but preserve its data. You can reactivate it later.")
                    } else {
                        Text("This will make the item visible and usable in the inventory system again.")
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(stockItem.inventoryItem?.isActive ?? true ? 1.0 : 0.7)
    }
}

// Excel Import View
struct ExcelImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var onImport: (Int) -> Void
    @State private var showingDocumentPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Template info section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Import Inventory from Excel")
                        .font(.headline)
                    
                    Text("Use our Excel template for a smooth import. The template includes columns for item name, category, part number, and quantities.")
                        .font(.body)
                    
                    Divider()
                    
                    Text("Required columns:")
                        .font(.subheadline)
                        .bold()
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("• Name (required)")
                        Text("• Category (required)")
                        Text("• Quantity (required)")
                        Text("• PartNumber")
                        Text("• Cost/Price")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Download template button
                Button(action: {
                    downloadTemplate()
                }) {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("Download Excel Template")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                }
                
                // Import button
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Select Excel File to Import")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("vehix-blue"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            .navigationTitle("Import Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [UTType.spreadsheet, UTType.xlsx, UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let selectedFile = try result.get().first else {
                        return
                    }
                    
                    if selectedFile.startAccessingSecurityScopedResource() {
                        defer { selectedFile.stopAccessingSecurityScopedResource() }
                        
                        // In the real implementation, this would use the InventoryManager to import
                        // For now, simulate a successful import
                        
                        // Simulate import delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            // Call success callback with random number of imported items
                            onImport(Int.random(in: 5...20))
                            dismiss()
                        }
                    } else {
                        errorMessage = "Could not access the selected file"
                        showingError = true
                    }
                } catch {
                    errorMessage = "Error selecting file: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func downloadTemplate() {
        // In a real implementation, this would save the template to Files
        // For now, show an informational message
        errorMessage = "Template is available in the app resources. For this demo, no template will be downloaded."
        showingError = true
    }
}

// Excel Export View
struct ExcelExportView: View {
    @Environment(\.dismiss) private var dismiss
    let inventoryItems: [AppInventoryItem]
    
    @State private var filename = "Inventory_\(dateFormatter.string(from: Date()))"
    @State private var exportFormat = "Excel (.xlsx)"
    @State private var includeStockLevels = true
    @State private var includeInactiveItems = false
    @State private var showingSuccessMessage = false
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Export Settings") {
                    TextField("Filename", text: $filename)
                    
                    Picker("Format", selection: $exportFormat) {
                        Text("Excel (.xlsx)").tag("Excel (.xlsx)")
                        Text("CSV (.csv)").tag("CSV (.csv)")
                    }
                    
                    Toggle("Include Stock Levels", isOn: $includeStockLevels)
                    Toggle("Include Inactive Items", isOn: $includeInactiveItems)
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Items to export: \(itemCount)")
                        Text("Export format: \(exportFormat)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section {
                    Button("Export Inventory") {
                        // Simulate export success
                        showingSuccessMessage = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Export Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Export Successful", isPresented: $showingSuccessMessage) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Inventory data has been exported to \(filename).\(exportFormat == "Excel (.xlsx)" ? "xlsx" : "csv")")
            }
        }
    }
    
    var itemCount: Int {
        inventoryItems.filter { includeInactiveItems || $0.isActive }.count
    }
}

// Create a helper function for previews
struct InventoryViewPreview: View {
    var body: some View {
        let previewData = createPreviewData()
        
        if let container = previewData.container, let auth = previewData.auth {
            InventoryView()
                .modelContainer(container)
                .environmentObject(auth)
        } else {
            Text("Failed to create preview")
        }
    }
    
    private struct PreviewData {
        let container: ModelContainer?
        let auth: AuthService?
    }
    
    private func createPreviewData() -> PreviewData {
        do {
            // Create an explicit configuration
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            
            // Specify the exact schema types for the container
            let schema = Schema([
                AppInventoryItem.self,
                StockLocationItem.self,
                AppWarehouse.self
            ])
            
            // Create the container with explicit schema
            let container = try ModelContainer(for: schema, configurations: config)
            
            // Set up preview data
            let context = container.mainContext
            
            // Create some inventory items
            let item1 = AppInventoryItem(name: "Oil Filter", partNumber: "OF-123")
            let item2 = AppInventoryItem(name: "Air Filter", partNumber: "AF-456")
            let item3 = AppInventoryItem(name: "Wiper Blades", partNumber: "WB-789")
            
            // Create warehouses
            let warehouse1 = AppWarehouse(name: "Main Warehouse", location: "Building A")
            let warehouse2 = AppWarehouse(name: "Secondary Storage", location: "Building B")
            
            // Create stock locations
            let stock1 = StockLocationItem(
                inventoryItem: item1,
                quantity: 10,
                minimumStockLevel: 15,
                warehouse: warehouse1
            )
            
            let stock2 = StockLocationItem(
                inventoryItem: item2, 
                quantity: 25, 
                minimumStockLevel: 10,
                warehouse: warehouse1
            )
            
            let stock3 = StockLocationItem(
                inventoryItem: item1,
                quantity: 5, 
                minimumStockLevel: 10,
                warehouse: warehouse2
            )
            
            let stock4 = StockLocationItem(
                inventoryItem: item3,
                quantity: 15,
                minimumStockLevel: 5,
                warehouse: warehouse2
            )
            
            // Insert all objects
            context.insert(item1)
            context.insert(item2)
            context.insert(item3)
            context.insert(warehouse1)
            context.insert(warehouse2)
            context.insert(stock1)
            context.insert(stock2)
            context.insert(stock3)
            context.insert(stock4)
            
            // Create and configure auth service
            let auth = AuthService()
            auth.currentUser = AuthUser(email: "admin@example.com", fullName: "Admin User", role: .admin)
            
            return PreviewData(container: container, auth: auth)
        } catch {
            print("Preview error: \(error.localizedDescription)")
            // Use explicit nil types to avoid ambiguity
            let nilContainer: ModelContainer? = nil
            let nilAuth: AuthService? = nil
            return PreviewData(container: nilContainer, auth: nilAuth)
        }
    }
}

#Preview {
    InventoryViewPreview()
}

// With UTType extension for xlsx
extension UTType {
    static var xlsx: UTType {
        UTType(importedAs: "com.microsoft.excel.xlsx")
    }
}

 