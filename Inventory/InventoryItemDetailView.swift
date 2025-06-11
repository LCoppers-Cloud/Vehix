import SwiftUI
import SwiftData
import Charts

struct InventoryItemDetailView: View {
    let item: AppInventoryItem
    let inventoryManager: InventoryManager
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab = 0
    @State private var showingEditSheet = false
    @State private var showingTransferSheet = false
    @State private var selectedStockLocation: StockLocationItem?
    
    // Edit states for managers
    @State private var editingMinimumLevels = false
    @State private var editingMaximumLevels = false
    @State private var tempMinimumLevels: [String: Int] = [:]
    @State private var tempMaximumLevels: [String: Int] = [:]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Item header
                itemHeaderView
                
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Locations").tag(1)
                    Text("Analytics").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Main content
                TabView(selection: $selectedTab) {
                    overviewTab.tag(0)
                    locationsTab.tag(1)
                    analyticsTab.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isManager {
                        Menu {
                            Button(action: { showingEditSheet = true }) {
                                Label("Edit Item", systemImage: "pencil")
                            }
                            
                            Button(action: { toggleEditingMinimumLevels() }) {
                                Label(editingMinimumLevels ? "Save Min Levels" : "Edit Min Levels", 
                                      systemImage: "slider.horizontal.below.rectangle")
                            }
                            
                            Button(action: { toggleEditingMaximumLevels() }) {
                                Label(editingMaximumLevels ? "Save Max Levels" : "Edit Max Levels", 
                                      systemImage: "slider.horizontal.above.rectangle")
                            }
                            
                            Divider()
                            
                            Button(action: { showingTransferSheet = true }) {
                                Label("Transfer Stock", systemImage: "arrow.right.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditInventoryItemView(item: item)
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showingTransferSheet) {
                if let stockLocation = selectedStockLocation,
                   let warehouse = stockLocation.warehouse {
                    InventoryTransferView(
                        sourceWarehouse: warehouse,
                        stockItem: stockLocation
                    )
                        .environmentObject(inventoryManager)
                        .environmentObject(authService)
                }
            }
        }
    }
    
    // MARK: - Header View
    private var itemHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Part #: \(item.partNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Category: \(item.category)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(String(format: "%.2f", item.pricePerUnit))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("per unit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick stats
            HStack(spacing: 20) {
                QuickStatView(
                    title: "Total Qty",
                    value: "\(item.stockTotalQuantity)",
                    color: .blue
                )
                
                QuickStatView(
                    title: "Total Value",
                    value: "$\(String(format: "%.2f", calculateItemTotalValue(item)))",
                    color: .green
                )
                
                QuickStatView(
                    title: "Locations",
                    value: "\(stockLocations.count)",
                    color: .purple
                )
                
                if hasLowStock {
                    QuickStatView(
                        title: "Status",
                        value: "LOW",
                        color: .red
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Overview Tab
    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Distribution chart
                distributionChartView
                
                // Stock summary
                stockSummaryView
                
                // Item details
                itemDetailsView
            }
            .padding()
        }
    }
    
    private var distributionChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stock Distribution")
                .font(.headline)
            
            Chart {
                ForEach(stockLocations, id: \.id) { stockLocation in
                    BarMark(
                        x: .value("Location", stockLocation.locationName),
                        y: .value("Quantity", stockLocation.quantity)
                    )
                    .foregroundStyle(stockLocation.isBelowMinimumStock ? Color.red : Color.blue)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(orientation: .vertical)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var stockSummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stock Summary")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SummaryCard(
                    title: "In Warehouses",
                    value: "\(warehouseQuantity)",
                    subtitle: "$\(String(format: "%.2f", warehouseValue))",
                    icon: "building.2.fill",
                    color: .purple
                )
                
                SummaryCard(
                    title: "On Vehicles",
                    value: "\(vehicleQuantity)",
                    subtitle: "$\(String(format: "%.2f", vehicleValue))",
                    icon: "car.fill",
                    color: .blue
                )
                
                SummaryCard(
                    title: "Low Stock Locations",
                    value: "\(lowStockLocations.count)",
                    subtitle: "out of \(stockLocations.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
                
                SummaryCard(
                    title: "Average Cost",
                    value: "$\(String(format: "%.2f", averageUnitCost))",
                    subtitle: "per unit",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var itemDetailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Item Details")
                .font(.headline)
            
            VStack(spacing: 8) {
                DetailRow(label: "Name", value: item.name)
                DetailRow(label: "Part Number", value: item.partNumber)
                DetailRow(label: "Category", value: item.category)
                DetailRow(label: "Price per Unit", value: "$\(String(format: "%.2f", item.pricePerUnit))")
                
                if let description = item.itemDescription, !description.isEmpty {
                    DetailRow(label: "Description", value: description)
                }
                
                if let supplier = item.supplier, !supplier.isEmpty {
                    DetailRow(label: "Supplier", value: supplier)
                }
                
                DetailRow(label: "Active", value: item.isActive ? "Yes" : "No")
                DetailRow(label: "Created", value: DateFormatter.short.string(from: item.createdAt))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Locations Tab
    private var locationsTab: some View {
        List {
            Section("Warehouses") {
                ForEach(warehouseStockLocations, id: \.id) { stockLocation in
                    LocationRowView(
                        stockLocation: stockLocation,
                        isManager: isManager,
                        editingMinimum: editingMinimumLevels,
                        editingMaximum: editingMaximumLevels,
                        tempMinimumLevels: $tempMinimumLevels,
                        tempMaximumLevels: $tempMaximumLevels
                    ) {
                        selectedStockLocation = stockLocation
                        showingTransferSheet = true
                    }
                }
            }
            
            Section("Vehicles") {
                ForEach(vehicleStockLocations, id: \.id) { stockLocation in
                    LocationRowView(
                        stockLocation: stockLocation,
                        isManager: isManager,
                        editingMinimum: editingMinimumLevels,
                        editingMaximum: editingMaximumLevels,
                        tempMinimumLevels: $tempMinimumLevels,
                        tempMaximumLevels: $tempMaximumLevels
                    ) {
                        selectedStockLocation = stockLocation
                        showingTransferSheet = true
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Analytics Tab
    private var analyticsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Usage trends (placeholder for future implementation)
                usageTrendsView
                
                // Cost analysis
                costAnalysisView
                
                // Reorder recommendations
                reorderRecommendationsView
            }
            .padding()
        }
    }
    
    private var usageTrendsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage Trends")
                .font(.headline)
            
            Text("Usage tracking will be available once inventory consumption data is collected.")
                .foregroundColor(.secondary)
                .italic()
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var costAnalysisView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Analysis")
                .font(.headline)
            
            VStack(spacing: 8) {
                CostAnalysisRow(label: "Total Inventory Value", value: calculateItemTotalValue(item))
                CostAnalysisRow(label: "Average Unit Cost", value: averageUnitCost)
                CostAnalysisRow(label: "Warehouse Value", value: warehouseValue)
                CostAnalysisRow(label: "Vehicle Value", value: vehicleValue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var reorderRecommendationsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reorder Recommendations")
                .font(.headline)
            
            if lowStockLocations.isEmpty {
                Text("All locations have adequate stock levels")
                    .foregroundColor(.green)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(lowStockLocations, id: \.id) { stockLocation in
                        ReorderRecommendationCard(stockLocation: stockLocation)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var stockLocations: [StockLocationItem] {
        inventoryManager.stockLocations.filter { $0.inventoryItem?.id == item.id }
    }
    
    private var warehouseStockLocations: [StockLocationItem] {
        stockLocations.filter { $0.warehouse != nil }
    }
    
    private var vehicleStockLocations: [StockLocationItem] {
        stockLocations.filter { $0.vehicle != nil }
    }
    
    private var lowStockLocations: [StockLocationItem] {
        stockLocations.filter { $0.isBelowMinimumStock }
    }
    
    private var warehouseQuantity: Int {
        warehouseStockLocations.reduce(0) { $0 + $1.quantity }
    }
    
    private var vehicleQuantity: Int {
        vehicleStockLocations.reduce(0) { $0 + $1.quantity }
    }
    
    private var warehouseValue: Double {
        Double(warehouseQuantity) * item.pricePerUnit
    }
    
    private var vehicleValue: Double {
        Double(vehicleQuantity) * item.pricePerUnit
    }
    
    private var averageUnitCost: Double {
        item.pricePerUnit
    }
    
    private var hasLowStock: Bool {
        !lowStockLocations.isEmpty
    }
    
    private var isManager: Bool {
        authService.currentUser?.userRole == .admin || 
        authService.currentUser?.userRole == .dealer
    }
    
    // MARK: - Helper Methods
    private func toggleEditingMinimumLevels() {
        if editingMinimumLevels {
            saveMinimumLevels()
        } else {
            startEditingMinimumLevels()
        }
        editingMinimumLevels.toggle()
    }
    
    private func toggleEditingMaximumLevels() {
        if editingMaximumLevels {
            saveMaximumLevels()
        } else {
            startEditingMaximumLevels()
        }
        editingMaximumLevels.toggle()
    }
    
    private func startEditingMinimumLevels() {
        tempMinimumLevels = Dictionary(uniqueKeysWithValues: 
            stockLocations.map { ($0.id, $0.minimumStockLevel) }
        )
    }
    
    private func startEditingMaximumLevels() {
        tempMaximumLevels = Dictionary(uniqueKeysWithValues: 
            stockLocations.compactMap { stockLocation in
                guard let maxLevel = stockLocation.maxStockLevel else { return nil }
                return (stockLocation.id, maxLevel)
            }
        )
    }
    
    private func saveMinimumLevels() {
        for stockLocation in stockLocations {
            if let newLevel = tempMinimumLevels[stockLocation.id] {
                stockLocation.minimumStockLevel = newLevel
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving minimum levels: \(error)")
        }
    }
    
    private func saveMaximumLevels() {
        for stockLocation in stockLocations {
            if let newLevel = tempMaximumLevels[stockLocation.id] {
                stockLocation.maxStockLevel = newLevel
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving maximum levels: \(error)")
        }
    }
    
    private func calculateItemTotalValue(_ item: AppInventoryItem) -> Double {
        let stockItems = inventoryManager.stockLocations.filter { $0.inventoryItem?.id == item.id }
        return stockItems.reduce(0.0) { sum, stockItem in
            sum + (Double(stockItem.quantity) * item.pricePerUnit)
        }
    }
}

// MARK: - Supporting Views

struct QuickStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct LocationRowView: View {
    let stockLocation: StockLocationItem
    let isManager: Bool
    let editingMinimum: Bool
    let editingMaximum: Bool
    @Binding var tempMinimumLevels: [String: Int]
    @Binding var tempMaximumLevels: [String: Int]
    let onTransfer: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stockLocation.locationName)
                        .font(.headline)
                    
                    Text("Current: \(stockLocation.quantity)")
                        .font(.subheadline)
                        .foregroundColor(stockLocation.isBelowMinimumStock ? .red : .primary)
                }
                
                Spacer()
                
                if isManager {
                    Button("Transfer", action: onTransfer)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            
            // Minimum level editing
            HStack {
                Text("Minimum:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if editingMinimum && isManager {
                    TextField("Min", value: Binding(
                        get: { tempMinimumLevels[stockLocation.id] ?? stockLocation.minimumStockLevel },
                        set: { tempMinimumLevels[stockLocation.id] = $0 }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                } else {
                    Text("\(stockLocation.minimumStockLevel)")
                        .font(.caption)
                }
                
                Spacer()
                
                Text("Maximum:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if editingMaximum && isManager {
                    TextField("Max", value: Binding(
                        get: { tempMaximumLevels[stockLocation.id] ?? stockLocation.maxStockLevel ?? 0 },
                        set: { tempMaximumLevels[stockLocation.id] = $0 }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                } else {
                    Text("\(stockLocation.maxStockLevel ?? 0)")
                        .font(.caption)
                }
            }
            
            if stockLocation.isBelowMinimumStock {
                Text("Below minimum stock level")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CostAnalysisRow: View {
    let label: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("$\(String(format: "%.2f", value))")
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.vertical, 2)
    }
}

struct ReorderRecommendationCard: View {
    let stockLocation: StockLocationItem
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stockLocation.locationName)
                    .font(.headline)
                
                Text("Current: \(stockLocation.quantity) | Min: \(stockLocation.minimumStockLevel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Suggested reorder: \((stockLocation.maxStockLevel ?? stockLocation.minimumStockLevel * 2) - stockLocation.quantity) units")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
} 