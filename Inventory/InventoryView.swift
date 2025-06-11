import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    // Using unified inventory system with @Query - no need for InventoryManager
    
    // UI State
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showLowStockOnly = false
    @State private var sortBy: SortOption = .name
    @State private var showingAddItem = false
    @State private var showingAddWarehouse = false
    @State private var selectedItem: AppInventoryItem?
    @State private var showingDetail = false
    
    // Data queries - these will be the source of truth
    @Query(sort: [SortDescriptor(\Vehix.InventoryItem.name)]) private var allInventoryItems: [AppInventoryItem]
    @Query(sort: [SortDescriptor(\StockLocationItem.createdAt, order: .reverse)]) private var stockLocations: [StockLocationItem]
    @Query(sort: [SortDescriptor(\AppWarehouse.name)]) private var warehouses: [AppWarehouse]
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.licensePlate)]) private var vehicles: [AppVehicle]
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case category = "Category"
        case stock = "Stock Level"
        case value = "Value"
    }
    
    // Computed properties for inventory status
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
        
        // Apply sorting
        switch sortBy {
        case .name:
            filtered.sort { $0.item.name < $1.item.name }
        case .category:
            filtered.sort { $0.item.category < $1.item.category }
        case .stock:
            filtered.sort { $0.totalQuantity > $1.totalQuantity }
        case .value:
            filtered.sort { $0.totalValue > $1.totalValue }
        }
        
        return filtered
    }
    
    private var categories: [String] {
        Array(Set(allInventoryItems.map(\.category))).sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter bar
                searchAndFilterBar
                
                // Main content
                if allInventoryItems.isEmpty {
                    emptyStateView
                } else {
                    inventoryListView
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddItem = true }) {
                            Label("Add Item", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showingAddWarehouse = true }) {
                            Label("Add Warehouse", systemImage: "building.2")
                        }
                        
                        Divider()
                        
                        Button(action: { /* TODO: Import */ }) {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                        }
                        
                        Button(action: { /* TODO: Export */ }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // No need for onAppear setup with unified system
            .sheet(isPresented: $showingAddItem) {
                AddInventoryItemForm()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showingAddWarehouse) {
                VehixAddWarehouseForm(onSave: { _ in })
                    .environment(\.modelContext, modelContext)
            }
            .sheet(item: $selectedItem) { item in
                InventoryItemDetailView(item: item, inventoryManager: InventoryManager())
                    .environmentObject(authService)
            }
        }
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
                
                Picker("Sort", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Toggle("Low Stock", isOn: $showLowStockOnly)
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Inventory List View
    private var inventoryListView: some View {
        List {
            ForEach(filteredAndSortedItems, id: \.item.id) { itemStatus in
                InventoryRowView(itemStatus: itemStatus) {
                    selectedItem = itemStatus.item
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Inventory Items")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start by adding your first inventory item")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddItem = true }) {
                Label("Add First Item", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

 // MARK: - Supporting Views
 
 // Inventory types are now imported from InventoryTypes.swift

#Preview {
    InventoryView()
        .environmentObject(AppAuthService())
        .modelContainer(for: [Vehix.InventoryItem.self, StockLocationItem.self, AppWarehouse.self, Vehix.Vehicle.self], inMemory: true)
}

// With UTType extension for xlsx
extension UTType {
    static var xlsx: UTType {
        UTType(importedAs: "com.microsoft.excel.xlsx")
    }
}

 