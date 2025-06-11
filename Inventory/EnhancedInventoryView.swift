import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct EnhancedInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    // Unified data queries - same as InventoryView.swift
    @Query(sort: [SortDescriptor(\Vehix.InventoryItem.name)]) private var allInventoryItems: [AppInventoryItem]
    @Query(sort: [SortDescriptor(\StockLocationItem.createdAt, order: .reverse)]) private var stockLocations: [StockLocationItem]
    @Query(sort: [SortDescriptor(\AppWarehouse.name)]) private var warehouses: [AppWarehouse]
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.licensePlate)]) private var vehicles: [AppVehicle]
    
    // State for navigation and UI
    @State private var selectedTab = 0
    @State private var selectedItem: AppInventoryItem?
    @State private var showingItemDetail = false
    @State private var showingAddItemSheet = false
    @State private var showingAddWarehouseSheet = false
    @State private var showingReportsView = false
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showLowStockOnly = false
    @State private var isRefreshing = false
    
    // Error handling
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Reports and export
    @State private var showingExportOptions = false
    @State private var showingImportSheet = false
    
    // Inventory Manager for warehouse operations
    @StateObject private var inventoryManager = InventoryManager()
    
    // Computed properties using unified types
    private var inventoryItems: [InventoryItemStatus] {
        return allInventoryItems.toInventoryStatuses(with: stockLocations)
    }
    
    private var filteredAndSortedItems: [InventoryItemStatus] {
        var filtered = inventoryItems
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.item.name.localizedCaseInsensitiveContains(searchText) ||
                item.item.partNumber.localizedCaseInsensitiveContains(searchText) ||
                item.item.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply category filter
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.item.category == selectedCategory }
        }
        
        // Apply low stock filter
        if showLowStockOnly {
            filtered = filtered.filter { $0.status == .lowStock || $0.status == .outOfStock }
        }
        
        return filtered
    }
    
    private var categories: [String] {
        Array(Set(allInventoryItems.map(\.category))).sorted()
    }
    
    private var totalInventoryValue: Double {
        inventoryItems.reduce(0) { $0 + $1.totalValue }
    }
    
    private var lowStockItemsCount: Int {
        inventoryItems.filter { $0.status == .lowStock || $0.status == .outOfStock }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced search and filter bar
                searchAndFilterBar
                
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Inventory").tag(1)
                    Text("Warehouses").tag(2)
                    Text("Reports").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Main content
                mainContentView
            }
            .navigationTitle("Inventory Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddItemSheet = true }) {
                            Label("Add Item", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showingAddWarehouseSheet = true }) {
                            Label("Add Warehouse", systemImage: "building.2")
                        }
                        
                        Divider()
                        
                        Button(action: { showingImportSheet = true }) {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                        }
                        
                        Button(action: { showingExportOptions = true }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(action: { showingReportsView = true }) {
                            Label("Advanced Reports", systemImage: "chart.bar.doc.horizontal")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddItemSheet) {
                AddInventoryItemForm()
            }
            .sheet(isPresented: $showingAddWarehouseSheet) {
                VehixAddWarehouseForm { _ in }
            }
            .sheet(isPresented: $showingReportsView) {
                AdvancedReportsView(inventoryItems: inventoryItems)
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportView()
            }
            .sheet(isPresented: $showingImportSheet) {
                Text("Import functionality coming soon")
            }
            .sheet(isPresented: $showingItemDetail) {
                if let item = selectedItem {
                    InventoryItemDetailView(item: item, inventoryManager: inventoryManager)
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                setupInventoryManager()
            }
        }
        .environmentObject(inventoryManager)
    }
    
    // MARK: - Search and Filter Bar
    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search inventory...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            HStack {
                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag("All")
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
                
                Toggle("Low Stock Only", isOn: $showLowStockOnly)
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Main Content Views
    private var mainContentView: some View {
        Group {
            switch selectedTab {
            case 0:
                inventoryOverviewView
            case 1:
                inventoryListView
            case 2:
                warehouseManagementView
            case 3:
                reportsPreviewView
            default:
                Text("Invalid tab")
            }
        }
    }
    
    // MARK: - Overview Tab
    private var inventoryOverviewView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Summary cards
                summaryCardsSection
                
                // Quick stats
                quickStatsSection
                
                // Low stock alerts
                if lowStockItemsCount > 0 {
                    lowStockAlertsSection
                }
                
                // Recent activity
                recentActivitySection
                
                // Warehouse summary
                warehouseSummarySection
            }
            .padding()
        }
    }
    
    private var summaryCardsSection: some View {
        HStack(spacing: 16) {
            InventorySummaryCard(
                title: "Total Items",
                value: "\(allInventoryItems.count)",
                icon: "shippingbox.fill",
                color: .blue
            )
            
            InventorySummaryCard(
                title: "Total Value",
                value: totalInventoryValue.formatted(.currency(code: "USD")),
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            InventorySummaryCard(
                title: "Low Stock",
                value: "\(lowStockItemsCount)",
                icon: "exclamationmark.triangle.fill",
                color: lowStockItemsCount > 0 ? .orange : .gray
            )
        }
    }
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Stats")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Categories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(categories.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading) {
                    Text("Warehouses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(warehouses.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading) {
                    Text("Vehicles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(vehicles.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var lowStockAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Low Stock Alerts")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    showLowStockOnly = true
                    selectedTab = 1
                }
                .foregroundColor(.orange)
            }
            
            ForEach(inventoryItems.filter { $0.status == .lowStock || $0.status == .outOfStock }.prefix(3), id: \.item.id) { itemStatus in
                LowStockAlertRow(itemStatus: itemStatus)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            // Placeholder for recent activity
            Text("Recent inventory changes will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var warehouseSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Warehouse Summary")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    selectedTab = 2
                }
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(warehouses.prefix(3)) { warehouse in
                    WarehouseSummaryCard(
                        title: warehouse.name,
                        value: "\(warehouse.stockItems?.count ?? 0) items",
                        icon: "building.2",
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Inventory List Tab
    private var inventoryListView: some View {
        List {
            ForEach(filteredAndSortedItems, id: \.item.id) { itemStatus in
                InventoryRowView(itemStatus: itemStatus) {
                    selectedItem = itemStatus.item
                    showingItemDetail = true
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Warehouse Management Tab
    private var warehouseManagementView: some View {
        WarehouseManagementDashboard()
            .environmentObject(inventoryManager)
            .environmentObject(authService)
    }
    
    // MARK: - Reports Preview Tab
    private var reportsPreviewView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Reports & Analytics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Quick report cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ReportCard(
                        title: "Inventory Valuation",
                        description: "Current inventory value by location",
                        icon: "dollarsign.circle",
                        color: .green
                    ) {
                        // Action for inventory valuation report
                    }
                    
                    ReportCard(
                        title: "Stock Levels",
                        description: "Current stock levels and alerts",
                        icon: "chart.bar",
                        color: .blue
                    ) {
                        // Action for stock levels report
                    }
                    
                    ReportCard(
                        title: "Usage Analytics",
                        description: "Inventory usage patterns",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .orange
                    ) {
                        // Action for usage analytics report
                    }
                    
                    ReportCard(
                        title: "Reorder Report",
                        description: "Items that need reordering",
                        icon: "arrow.clockwise.circle",
                        color: .purple
                    ) {
                        // Action for reorder report
                    }
                }
                
                Button("View Advanced Reports") {
                    showingReportsView = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    private func setupInventoryManager() {
        inventoryManager.modelContext = modelContext
        Task {
            await inventoryManager.loadInventoryItems()
            await inventoryManager.loadWarehouses()
            await inventoryManager.loadVehicles()
            await inventoryManager.loadStockLocations()
        }
    }
}

// MARK: - Supporting Views

struct LowStockAlertRow: View {
    let itemStatus: InventoryItemStatus
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(itemStatus.item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Only \(itemStatus.totalQuantity) remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(itemStatus.status.text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(itemStatus.status.color)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EnhancedInventoryView()
        .environmentObject(AppAuthService())
        .modelContainer(for: [Vehix.InventoryItem.self, StockLocationItem.self, AppWarehouse.self, Vehix.Vehicle.self], inMemory: true)
} 