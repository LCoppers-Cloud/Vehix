import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - Warehouse Map View
struct WarehouseMapView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var authService: AppAuthService
    
    @Query(sort: [SortDescriptor<AppWarehouse>(\.name)]) private var warehouses: [AppWarehouse]
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), // Center of US
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )
    
    @State private var selectedWarehouse: AppWarehouse?
    @State private var showingWarehouseDetail = false
    @State private var showingInventoryAtWarehouse = false
    @State private var showingAddWarehouse = false
    @State private var showingRouteOptimization = false
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var filterOptions = WarehouseFilterOptions()
    
    private let locationManager = CLLocationManager()
    
    var filteredWarehouses: [AppWarehouse] {
        let filtered = warehouses.filter { warehouse in
            if !filterOptions.showInactive && !warehouse.isActive {
                return false
            }
            
            if filterOptions.warehouseType != "all" && warehouse.warehouseType != filterOptions.warehouseType {
                return false
            }
            
            if filterOptions.onlyWithInventory {
                let hasInventory = (warehouse.stockItems?.count ?? 0) > 0
                if !hasInventory { return false }
            }
            
            if filterOptions.onlyLowStock {
                let hasLowStock = warehouse.stockItems?.contains { $0.isBelowMinimumStock } ?? false
                if !hasLowStock { return false }
            }
            
            if !searchText.isEmpty {
                return warehouse.name.localizedCaseInsensitiveContains(searchText) ||
                       warehouse.address.localizedCaseInsensitiveContains(searchText)
            }
            
            return true
        }
        
        return filtered.filter { $0.isOnMap && $0.hasCoordinates }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map view
                Map {
                    ForEach(filteredWarehouses, id: \.id) { warehouse in
                        Annotation(warehouse.name, coordinate: CLLocationCoordinate2D(
                            latitude: warehouse.latitude ?? 0,
                            longitude: warehouse.longitude ?? 0
                        )) {
                            WarehouseMapAnnotation(
                                warehouse: warehouse,
                                onTap: {
                                    selectedWarehouse = warehouse
                                    showingWarehouseDetail = true
                                }
                            )
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(.all)
                
                // Top overlay with search and controls
                VStack {
                    // Search and filter bar
                    HStack {
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search warehouses...", text: $searchText)
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        
                        // Filter button
                        Button(action: { showingFilters = true }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                        }
                        
                        // Current location button
                        Button(action: centerOnCurrentLocation) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Bottom statistics panel
                    if !filteredWarehouses.isEmpty {
                        WarehouseMapStatistics(warehouses: filteredWarehouses)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("Warehouse Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingAddWarehouse = true }) {
                            Label("Add Warehouse", systemImage: "plus")
                        }
                        
                        Button(action: { showingRouteOptimization = true }) {
                            Label("Route Optimization", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        }
                        
                        Button(action: centerOnWarehouses) {
                            Label("Fit All Warehouses", systemImage: "viewfinder")
                        }
                        
                        Divider()
                        
                        Button(action: { showingFilters = true }) {
                            Label("Filter Options", systemImage: "slider.horizontal.3")
                        }
                        
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                setupLocationManager()
                centerOnWarehouses()
            }
            .sheet(isPresented: $showingWarehouseDetail) {
                if let warehouse = selectedWarehouse {
                    WarehouseMapDetailView(warehouse: warehouse)
                }
            }
            .sheet(isPresented: $showingInventoryAtWarehouse) {
                if let warehouse = selectedWarehouse {
                    WarehouseInventoryView(warehouse: warehouse)
                }
            }
            .sheet(isPresented: $showingAddWarehouse) {
                EnhancedAddWarehouseView()
            }
            .sheet(isPresented: $showingFilters) {
                WarehouseMapFiltersView(filterOptions: $filterOptions)
            }
        }
    }
    
    private func setupLocationManager() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func centerOnCurrentLocation() {
        if let location = locationManager.location {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
    
    private func centerOnWarehouses() {
        let warehousesWithCoords = filteredWarehouses.filter { $0.hasCoordinates }
        
        guard !warehousesWithCoords.isEmpty else { return }
        
        if warehousesWithCoords.count == 1, let warehouse = warehousesWithCoords.first {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: warehouse.latitude!,
                    longitude: warehouse.longitude!
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            return
        }
        
        let coordinates = warehousesWithCoords.compactMap { warehouse -> CLLocationCoordinate2D? in
            guard let lat = warehouse.latitude, let lon = warehouse.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        let minLat = coordinates.map(\.latitude).min() ?? 0
        let maxLat = coordinates.map(\.latitude).max() ?? 0
        let minLon = coordinates.map(\.longitude).min() ?? 0
        let maxLon = coordinates.map(\.longitude).max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.2, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.2, 0.01)
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Warehouse Map Annotation
struct WarehouseMapAnnotation: View {
    let warehouse: AppWarehouse
    let onTap: () -> Void
    
    private var inventoryCount: Int {
        warehouse.stockItems?.count ?? 0
    }
    
    private var inventoryValue: Double {
        warehouse.stockItems?.reduce(0.0) { total, stockItem in
            guard let item = stockItem.inventoryItem else { return total }
            return total + (Double(stockItem.quantity) * item.pricePerUnit)
        } ?? 0.0
    }
    
    private var statusColor: Color {
        switch warehouse.operationalStatus {
        case "Inactive": return .gray
        case "At Capacity": return .red
        case "Near Capacity": return .orange
        default: return .green
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Main annotation
                ZStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 30, height: 30)
                        .shadow(radius: 2)
                    
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                    
                    // Inventory count badge
                    if inventoryCount > 0 {
                        Text("\(inventoryCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 12, y: -12)
                    }
                }
                
                // Warehouse name
                Text(warehouse.name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Warehouse Map Statistics
struct WarehouseMapStatistics: View {
    let warehouses: [AppWarehouse]
    
    private var totalInventoryValue: Double {
        warehouses.reduce(0.0) { total, warehouse in
            total + (warehouse.stockItems?.reduce(0.0) { subTotal, stockItem in
                guard let item = stockItem.inventoryItem else { return subTotal }
                return subTotal + (Double(stockItem.quantity) * item.pricePerUnit)
            } ?? 0.0)
        }
    }
    
    private var totalItems: Int {
        warehouses.reduce(0) { total, warehouse in
            total + (warehouse.stockItems?.count ?? 0)
        }
    }
    
    private var lowStockCount: Int {
        warehouses.reduce(0) { total, warehouse in
            total + (warehouse.stockItems?.filter { $0.isBelowMinimumStock }.count ?? 0)
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Warehouses",
                value: "\(warehouses.count)",
                subtitle: "",
                icon: "building.2",
                color: .blue
            )
            
            StatCard(
                title: "Total Items",
                value: "\(totalItems)",
                subtitle: "",
                icon: "cube.box",
                color: .green
            )
            
            StatCard(
                title: "Total Value",
                value: String(format: "$%.0f", totalInventoryValue),
                subtitle: "",
                icon: "dollarsign.circle",
                color: .purple
            )
            
            if lowStockCount > 0 {
                StatCard(
                    title: "Low Stock",
                    value: "\(lowStockCount)",
                    subtitle: "",
                    icon: "exclamationmark.triangle",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct WarehouseStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Filter Options
struct WarehouseFilterOptions {
    var showInactive = true
    var warehouseType = "all"
    var onlyWithInventory = false
    var onlyLowStock = false
    var minValue: Double = 0
    var maxValue: Double = 1000000
}

// MARK: - Warehouse Map Filters View
struct WarehouseMapFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterOptions: WarehouseFilterOptions
    
    private let warehouseTypes = ["all", "standard", "mobile", "temporary", "distribution", "storage", "cross-dock"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Warehouse Status") {
                    Toggle("Show Inactive Warehouses", isOn: $filterOptions.showInactive)
                    Toggle("Only Warehouses with Inventory", isOn: $filterOptions.onlyWithInventory)
                    Toggle("Only Low Stock Warehouses", isOn: $filterOptions.onlyLowStock)
                }
                
                Section("Warehouse Type") {
                    Picker("Type", selection: $filterOptions.warehouseType) {
                        Text("All Types").tag("all")
                        ForEach(warehouseTypes.dropFirst(), id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                }
                
                Section("Inventory Value Range") {
                    VStack(alignment: .leading) {
                        Text("Minimum Value: \(String(format: "$%.0f", filterOptions.minValue))")
                        Slider(value: $filterOptions.minValue, in: 0...100000, step: 1000)
                        
                        Text("Maximum Value: \(String(format: "$%.0f", filterOptions.maxValue))")
                        Slider(value: $filterOptions.maxValue, in: 1000...1000000, step: 5000)
                    }
                }
                
                Section {
                    Button("Reset Filters") {
                        resetFilters()
                    }
                    .foregroundColor(.red)
                } footer: {
                    Text("Use filters to focus on specific warehouses on the map.")
                }
            }
            .navigationTitle("Map Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Apply") { dismiss() }
                }
            }
        }
    }
    
    private func resetFilters() {
        filterOptions = WarehouseFilterOptions()
    }
}

// MARK: - Warehouse Map Detail View
struct WarehouseMapDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let warehouse: AppWarehouse
    
    private var inventoryCount: Int {
        warehouse.stockItems?.count ?? 0
    }
    
    private var inventoryValue: Double {
        warehouse.stockItems?.reduce(0.0) { total, stockItem in
            guard let item = stockItem.inventoryItem else { return total }
            return total + (Double(stockItem.quantity) * item.pricePerUnit)
        } ?? 0.0
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Warehouse photo
                    if let photoData = warehouse.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    }
                    
                    // Quick stats
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(inventoryCount)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text(String(format: "$%.0f", inventoryValue))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Value")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text(warehouse.operationalStatus)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(statusColor)
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Open inventory view
                        }) {
                            HStack {
                                Image(systemName: "cube.box.fill")
                                Text("View Inventory")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            // Open in Maps app
                            openInMaps()
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Get Directions")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        if warehouse.contactPhone.isEmpty == false {
                            Button(action: {
                                // Call warehouse
                                if let url = URL(string: "tel://\(warehouse.contactPhone)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text("Call Warehouse")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    // Warehouse details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Warehouse Details")
                            .font(.headline)
                        
                        InfoRow(icon: "location", title: "Address", value: warehouse.address)
                        InfoRow(icon: "building.2", title: "Type", value: warehouse.warehouseType.capitalized)
                        
                        if !warehouse.managerName.isEmpty {
                            InfoRow(icon: "person", title: "Manager", value: warehouse.managerName)
                        }
                        
                        if !warehouse.operatingHours.isEmpty {
                            InfoRow(icon: "clock", title: "Hours", value: warehouse.operatingHours)
                        }
                        
                        if warehouse.capacity > 0 {
                            InfoRow(icon: "ruler", title: "Capacity", value: String(format: "%.0f sq ft", warehouse.capacity))
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle(warehouse.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch warehouse.operationalStatus {
        case "Inactive": return .gray
        case "At Capacity": return .red
        case "Near Capacity": return .orange
        default: return .green
        }
    }
    
    private func openInMaps() {
        if let lat = warehouse.latitude, let lon = warehouse.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = warehouse.name
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        }
    }
}

// MARK: - Warehouse Inventory View
struct WarehouseInventoryView: View {
    @Environment(\.dismiss) private var dismiss
    let warehouse: AppWarehouse
    
    private var stockItems: [StockLocationItem] {
        warehouse.stockItems ?? []
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(stockItems, id: \.id) { stockItem in
                    if let inventoryItem = stockItem.inventoryItem {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(inventoryItem.name)
                                    .font(.headline)
                                Text(inventoryItem.partNumber)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("\(stockItem.quantity)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                if stockItem.isBelowMinimumStock {
                                    Text("Low Stock")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Inventory at \(warehouse.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
} 