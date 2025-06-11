import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation
import MapKit

// MARK: - Main Warehouse Settings View
struct WarehouseSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var inventoryManager: InventoryManager
    
    @Query(sort: [SortDescriptor<AppWarehouse>(\.name)]) private var warehouses: [AppWarehouse]
    
    @State private var showingAddWarehouse = false
    @State private var showingDeleteConfirmation = false
    @State private var warehouseToDelete: AppWarehouse?
    @State private var selectedWarehouse: AppWarehouse?
    @State private var showingWarehouseDetail = false
    @State private var warehouseStorageEnabled = true
    @State private var requireWarehouseAssignment = true
    @State private var allowMultipleWarehouses = true
    @State private var defaultTransferBehavior = "require_approval"
    
    var body: some View {
        NavigationView {
            Form {
                // Warehouse Storage Settings
                Section {
                    Toggle("Enable Warehouse Storage", isOn: $warehouseStorageEnabled)
                        .onChange(of: warehouseStorageEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "warehouse.storage_enabled")
                            
                            if !newValue {
                                // Show notification about disabling warehouses
                                showWarehouseDisabledNotification()
                            }
                        }
                    
                    if warehouseStorageEnabled {
                        Toggle("Require Warehouse Assignment", isOn: $requireWarehouseAssignment)
                            .onChange(of: requireWarehouseAssignment) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "warehouse.require_assignment")
                            }
                        
                        Toggle("Allow Multiple Warehouses", isOn: $allowMultipleWarehouses)
                            .onChange(of: allowMultipleWarehouses) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "warehouse.allow_multiple")
                            }
                        
                        Picker("Transfer Behavior", selection: $defaultTransferBehavior) {
                            Text("Require Approval").tag("require_approval")
                            Text("Auto-approve").tag("auto_approve")
                            Text("Manager Only").tag("manager_only")
                        }
                        .onChange(of: defaultTransferBehavior) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "warehouse.transfer_behavior")
                        }
                    }
                    
                } header: {
                    Text("Warehouse Storage Settings")
                } footer: {
                    Text(warehouseStorageEnabled ? 
                         "Items must be assigned to warehouses when created. You can transfer items between warehouses and vehicles." :
                         "Warehouse storage is disabled. Items can only be assigned to vehicles.")
                }
                
                if warehouseStorageEnabled {
                    // Current Warehouses
                    Section {
                        if warehouses.isEmpty {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.gray)
                                Text("No warehouses configured")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Add First Warehouse") {
                                    showingAddWarehouse = true
                                }
                                .font(.caption)
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            ForEach(warehouses) { warehouse in
                                WarehouseSettingsRow(
                                    warehouse: warehouse,
                                    onEdit: {
                                        selectedWarehouse = warehouse
                                        showingWarehouseDetail = true
                                    },
                                    onDelete: {
                                        warehouseToDelete = warehouse
                                        showingDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        
                        Button(action: { showingAddWarehouse = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add New Warehouse")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                    } header: {
                        Text("Configured Warehouses (\(warehouses.count))")
                    }
                    
                    // Warehouse Operations
                    Section {
                        if warehouses.count > 1 {
                            Button(action: consolidateWarehouses) {
                                HStack {
                                    Image(systemName: "arrow.triangle.merge")
                                        .foregroundColor(.orange)
                                    Text("Consolidate Warehouses")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        Button(action: exportWarehouseData) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                                Text("Export Warehouse Data")
                            }
                        }
                        
                        Button(action: validateWarehouseData) {
                            HStack {
                                Image(systemName: "checkmark.shield")
                                    .foregroundColor(.green)
                                Text("Validate Warehouse Data")
                            }
                        }
                        
                    } header: {
                        Text("Warehouse Operations")
                    }
                }
            }
            .navigationTitle("Warehouse Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadSettings()
            }
            .sheet(isPresented: $showingAddWarehouse) {
                EnhancedAddWarehouseView()
            }
            .sheet(isPresented: $showingWarehouseDetail) {
                if let warehouse = selectedWarehouse {
                    EnhancedWarehouseDetailView(warehouse: warehouse)
                }
            }
            .alert("Delete Warehouse", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    warehouseToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteWarehouse()
                }
            } message: {
                if let warehouse = warehouseToDelete {
                    Text("Are you sure you want to delete '\(warehouse.name)'? All inventory will be transferred to the default warehouse.")
                }
            }
        }
    }
    
    private func loadSettings() {
        warehouseStorageEnabled = UserDefaults.standard.bool(forKey: "warehouse.storage_enabled")
        requireWarehouseAssignment = UserDefaults.standard.bool(forKey: "warehouse.require_assignment")
        allowMultipleWarehouses = UserDefaults.standard.bool(forKey: "warehouse.allow_multiple")
        defaultTransferBehavior = UserDefaults.standard.string(forKey: "warehouse.transfer_behavior") ?? "require_approval"
        
        // Set defaults if first time
        if !UserDefaults.standard.bool(forKey: "warehouse.settings_initialized") {
            warehouseStorageEnabled = true
            requireWarehouseAssignment = true
            allowMultipleWarehouses = true
            UserDefaults.standard.set(true, forKey: "warehouse.settings_initialized")
            UserDefaults.standard.set(true, forKey: "warehouse.storage_enabled")
            UserDefaults.standard.set(true, forKey: "warehouse.require_assignment")
            UserDefaults.standard.set(true, forKey: "warehouse.allow_multiple")
        }
    }
    
    private func showWarehouseDisabledNotification() {
        // Create user notification about warehouse storage being disabled
        let content = UNMutableNotificationContent()
        content.title = "Warehouse Storage Disabled"
        content.body = "Warehouse storage has been disabled. New inventory items can only be assigned to vehicles. Existing warehouse inventory remains accessible."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "warehouse_disabled_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func deleteWarehouse() {
        guard let warehouse = warehouseToDelete else { return }
        
        // Transfer all inventory to default warehouse or first available
        if let defaultWarehouse = warehouses.first(where: { $0.id != warehouse.id }) {
            // Transfer stock items
            if let stockItems = warehouse.stockItems {
                for stockItem in stockItems {
                    stockItem.warehouse = defaultWarehouse
                    stockItem.updatedAt = Date()
                }
            }
        }
        
        // Delete the warehouse
        modelContext.delete(warehouse)
        try? modelContext.save()
        
        warehouseToDelete = nil
    }
    
    private func consolidateWarehouses() {
        // Implementation for consolidating warehouses
    }
    
    private func exportWarehouseData() {
        // Implementation for exporting warehouse data
    }
    
    private func validateWarehouseData() {
        // Implementation for validating warehouse data
    }
}

// MARK: - Warehouse Settings Row
struct WarehouseSettingsRow: View {
    let warehouse: AppWarehouse
    let onEdit: () -> Void
    let onDelete: () -> Void
    
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(warehouse.name)
                        .font(.headline)
                    
                    if !warehouse.address.isEmpty {
                        Text(warehouse.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(warehouse.operationalStatus)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(inventoryCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "$%.2f", inventoryValue))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if warehouse.hasCoordinates {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button("Edit", action: onEdit)
                    .font(.caption)
                    .buttonStyle(.bordered)
                
                if inventoryCount == 0 {
                    Button("Delete", action: onDelete)
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                if warehouse.isOnMap {
                    Label("On Map", systemImage: "map")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch warehouse.operationalStatus {
        case "Inactive": return .red
        case "At Capacity": return .red
        case "Near Capacity": return .orange
        default: return .green
        }
    }
}

// MARK: - Enhanced Add Warehouse View
struct EnhancedAddWarehouseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var address = ""
    @State private var description = ""
    @State private var managerName = ""
    @State private var contactPhone = ""
    @State private var contactEmail = ""
    @State private var operatingHours = ""
    @State private var warehouseType = "standard"
    @State private var securityLevel = "basic"
    @State private var capacity = ""
    @State private var monthlyOperatingCost = ""
    @State private var temperatureControlled = false
    @State private var hazardousMaterialsAllowed = false
    @State private var allowVehicleTransfers = true
    @State private var requireManagerApproval = false
    @State private var autoReorderEnabled = false
    @State private var isOnMap = true
    
    // Photo and location
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingLocationPicker = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var useCurrentLocation = false
    
    private let locationManager = CLLocationManager()
    
    private let warehouseTypes = ["standard", "mobile", "temporary", "distribution", "storage", "cross-dock"]
    private let securityLevels = ["basic", "enhanced", "high", "maximum"]
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section {
                    TextField("Warehouse Name", text: $name)
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(2...3)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                } header: {
                    Text("Basic Information")
                }
                
                // Contact Information
                Section {
                    TextField("Manager Name", text: $managerName)
                    TextField("Contact Phone", text: $contactPhone)
                        .keyboardType(.phonePad)
                    TextField("Contact Email", text: $contactEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Operating Hours", text: $operatingHours)
                        .placeholder("e.g., Mon-Fri 8AM-6PM")
                } header: {
                    Text("Contact Information")
                }
                
                // Warehouse Configuration
                Section {
                    Picker("Warehouse Type", selection: $warehouseType) {
                        ForEach(warehouseTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    
                    Picker("Security Level", selection: $securityLevel) {
                        ForEach(securityLevels, id: \.self) { level in
                            Text(level.capitalized).tag(level)
                        }
                    }
                    
                    TextField("Capacity (sq ft)", text: $capacity)
                        .keyboardType(.decimalPad)
                    
                    TextField("Monthly Operating Cost", text: $monthlyOperatingCost)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Configuration")
                }
                
                // Features
                Section {
                    Toggle("Temperature Controlled", isOn: $temperatureControlled)
                    Toggle("Hazardous Materials Allowed", isOn: $hazardousMaterialsAllowed)
                    Toggle("Allow Vehicle Transfers", isOn: $allowVehicleTransfers)
                    Toggle("Require Manager Approval", isOn: $requireManagerApproval)
                    Toggle("Auto-reorder Enabled", isOn: $autoReorderEnabled)
                    Toggle("Show on Map", isOn: $isOnMap)
                } header: {
                    Text("Features & Permissions")
                }
                
                // Location & Photo
                Section {
                    // Photo picker
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack {
                            if let photoData = photoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                    .frame(width: 60, height: 60)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Warehouse Photo")
                                    .font(.headline)
                                Text("Add a photo of the warehouse")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .onChange(of: photoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                photoData = data
                            }
                        }
                    }
                    
                    // Location picker
                    Button(action: { showingLocationPicker = true }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("GPS Location")
                                    .foregroundColor(.primary)
                                if let coordinate = selectedCoordinate {
                                    Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Tap to set location")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    
                    Button(action: useCurrentLocationAction) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.green)
                            Text("Use Current Location")
                                .foregroundColor(.green)
                        }
                    }
                    
                } header: {
                    Text("Location & Photo")
                }
                
                // Save button
                Section {
                    Button("Create Warehouse") {
                        saveWarehouse()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Warehouse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedCoordinate: $selectedCoordinate)
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !address.isEmpty
    }
    
    private func useCurrentLocationAction() {
        locationManager.requestWhenInUseAuthorization()
        
        if let location = locationManager.location {
            selectedCoordinate = location.coordinate
        }
    }
    
    private func saveWarehouse() {
        let warehouse = AppWarehouse(
            name: name,
            location: address,
            warehouseDescription: description,
            address: address,
            latitude: selectedCoordinate?.latitude,
            longitude: selectedCoordinate?.longitude
        )
        
        // Set additional properties
        warehouse.managerName = managerName
        warehouse.contactPhone = contactPhone
        warehouse.contactEmail = contactEmail
        warehouse.operatingHours = operatingHours
        warehouse.warehouseType = warehouseType
        warehouse.securityLevel = securityLevel
        warehouse.capacity = Double(capacity) ?? 0.0
        warehouse.monthlyOperatingCost = Double(monthlyOperatingCost) ?? 0.0
        warehouse.temperatureControlled = temperatureControlled
        warehouse.hazardousMaterialsAllowed = hazardousMaterialsAllowed
        warehouse.allowVehicleTransfers = allowVehicleTransfers
        warehouse.requireManagerApproval = requireManagerApproval
        warehouse.autoReorderEnabled = autoReorderEnabled
        warehouse.isOnMap = isOnMap
        warehouse.photoData = photoData
        
        modelContext.insert(warehouse)
        try? modelContext.save()
        
        dismiss()
    }
}

// MARK: - Enhanced Warehouse Detail View
struct EnhancedWarehouseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let warehouse: AppWarehouse
    
    @State private var isEditing = false
    @State private var editedWarehouse: AppWarehouse
    
    // Computed properties to simplify the body expression
    private var itemCount: Int {
        warehouse.stockItems?.count ?? 0
    }
    
    private var totalValue: Double {
        warehouse.stockItems?.reduce(0.0) { total, stockItem in
            guard let item = stockItem.inventoryItem else { return total }
            return total + (Double(stockItem.quantity) * item.pricePerUnit)
        } ?? 0.0
    }
    
    private var capacityText: String {
        String(format: "%.0f sq ft", warehouse.capacity)
    }
    
    private var utilizationText: String {
        String(format: "%.1f%%", warehouse.utilizationRate * 100)
    }
    
    init(warehouse: AppWarehouse) {
        self.warehouse = warehouse
        _editedWarehouse = State(initialValue: warehouse)
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
                    
                    // Basic info card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Warehouse Information")
                            .font(.headline)
                        
                        WarehouseInfoRow(label: "Name", value: warehouse.name)
                        WarehouseInfoRow(label: "Address", value: warehouse.address)
                        WarehouseInfoRow(label: "Type", value: warehouse.warehouseType.capitalized)
                        WarehouseInfoRow(label: "Status", value: warehouse.operationalStatus)
                        
                        if warehouse.hasCoordinates {
                            WarehouseInfoRow(label: "Coordinates", value: warehouse.coordinateDisplay)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Contact info card
                    if !warehouse.managerName.isEmpty || !warehouse.contactPhone.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contact Information")
                                .font(.headline)
                            
                            if !warehouse.managerName.isEmpty {
                                WarehouseInfoRow(label: "Manager", value: warehouse.managerName)
                            }
                            if !warehouse.contactPhone.isEmpty {
                                WarehouseInfoRow(label: "Phone", value: warehouse.contactPhone)
                            }
                            if !warehouse.contactEmail.isEmpty {
                                WarehouseInfoRow(label: "Email", value: warehouse.contactEmail)
                            }
                            if !warehouse.operatingHours.isEmpty {
                                WarehouseInfoRow(label: "Hours", value: warehouse.operatingHours)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Inventory summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Inventory Summary")
                            .font(.headline)
                        
                        WarehouseInfoRow(label: "Items", value: "\(itemCount)")
                        WarehouseInfoRow(label: "Total Value", value: String(format: "$%.2f", totalValue))
                        
                        if warehouse.capacity > 0 {
                            WarehouseInfoRow(label: "Capacity", value: capacityText)
                            WarehouseInfoRow(label: "Utilization", value: utilizationText)
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
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        isEditing = true
                    }
                }
            }
        }
    }
}

// MARK: - Warehouse Info Row Component
struct WarehouseInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco default
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    private var mapLocations: [MapLocation] {
        if let coordinate = selectedCoordinate {
            return [MapLocation(coordinate: coordinate)]
        }
        return []
    }
    
    var body: some View {
        NavigationView {
            Map {
                ForEach(mapLocations) { location in
                    Marker("Selected Location", coordinate: location.coordinate)
                        .tint(.red)
                }
            }
            .mapStyle(.standard)
            .onTapGesture { location in
                // This is a simplified tap gesture - in a real implementation,
                // you'd need to convert the tap location to coordinates
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Inventory Tracking Settings View
struct InventoryTrackingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var requireWarehouseAssignment = true
    @State private var allowInventoryPhotos = true
    @State private var autoGenerateIds = true
    @State private var trackLocationHistory = true
    @State private var enableLowStockAlerts = true
    @State private var enableTransferNotifications = true
    @State private var requireReceiptPhotos = true
    @State private var autoReorderThreshold = 10.0
    @State private var defaultReorderQuantity = 50.0
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Require Warehouse Assignment", isOn: $requireWarehouseAssignment)
                    Toggle("Allow Inventory Photos", isOn: $allowInventoryPhotos)
                    Toggle("Auto-Generate Item IDs", isOn: $autoGenerateIds)
                    Toggle("Track Location History", isOn: $trackLocationHistory)
                } header: {
                    Text("Inventory Creation")
                } footer: {
                    Text("Configure how inventory items are created and tracked in the system.")
                }
                
                Section {
                    Toggle("Low Stock Alerts", isOn: $enableLowStockAlerts)
                    Toggle("Transfer Notifications", isOn: $enableTransferNotifications)
                    Toggle("Require Receipt Photos", isOn: $requireReceiptPhotos)
                } header: {
                    Text("Notifications & Requirements")
                }
                
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Auto-reorder Threshold")
                            Spacer()
                            Text(String(format: "%.0f items", autoReorderThreshold))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $autoReorderThreshold, in: 1...100, step: 1)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Default Reorder Quantity")
                            Spacer()
                            Text(String(format: "%.0f items", defaultReorderQuantity))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $defaultReorderQuantity, in: 10...500, step: 10)
                    }
                } header: {
                    Text("Auto-Reordering")
                }
                
                Section {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                } footer: {
                    Text("These settings control how inventory is tracked across warehouses and vehicles.")
                }
            }
            .navigationTitle("Inventory Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadSettings()
            }
            .onChange(of: requireWarehouseAssignment) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "inventory.require_warehouse")
            }
            .onChange(of: allowInventoryPhotos) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "inventory.allow_photos")
            }
        }
    }
    
    private func loadSettings() {
        requireWarehouseAssignment = UserDefaults.standard.bool(forKey: "inventory.require_warehouse")
        allowInventoryPhotos = UserDefaults.standard.bool(forKey: "inventory.allow_photos")
        // Load other settings...
    }
    
    private func resetToDefaults() {
        requireWarehouseAssignment = true
        allowInventoryPhotos = true
        autoGenerateIds = true
        trackLocationHistory = true
        enableLowStockAlerts = true
        enableTransferNotifications = true
        requireReceiptPhotos = true
        autoReorderThreshold = 10.0
        defaultReorderQuantity = 50.0
    }
}

// MARK: - Warehouse Map Settings View
struct WarehouseMapSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var showWarehousesOnMap = true
    @State private var showInventoryLevels = true
    @State private var showDistanceToWarehouses = true
    @State private var enableRouteOptimization = false
    @State private var mapUpdateFrequency = "real_time"
    
    let updateFrequencies = ["real_time", "5_minutes", "15_minutes", "30_minutes", "hourly"]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Show Warehouses on Map", isOn: $showWarehousesOnMap)
                    Toggle("Show Inventory Levels", isOn: $showInventoryLevels)
                    Toggle("Show Distance to Warehouses", isOn: $showDistanceToWarehouses)
                    Toggle("Enable Route Optimization", isOn: $enableRouteOptimization)
                } header: {
                    Text("Map Display")
                }
                
                Section {
                    Picker("Update Frequency", selection: $mapUpdateFrequency) {
                        Text("Real Time").tag("real_time")
                        Text("Every 5 Minutes").tag("5_minutes")
                        Text("Every 15 Minutes").tag("15_minutes")
                        Text("Every 30 Minutes").tag("30_minutes")
                        Text("Hourly").tag("hourly")
                    }
                } header: {
                    Text("Update Settings")
                } footer: {
                    Text("Configure how often warehouse locations and inventory levels are updated on the map.")
                }
            }
            .navigationTitle("Map Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Warehouse Permission Settings View
struct WarehousePermissionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AppAuthService
    
    @State private var managersCanAddWarehouses = true
    @State private var managersCanDeleteWarehouses = false
    @State private var techniciansCanViewInventory = true
    @State private var techniciansCanRequestTransfers = true
    @State private var requireApprovalForTransfers = true
    @State private var allowEmergencyAccess = true
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Managers Can Add Warehouses", isOn: $managersCanAddWarehouses)
                    Toggle("Managers Can Delete Warehouses", isOn: $managersCanDeleteWarehouses)
                } header: {
                    Text("Manager Permissions")
                } footer: {
                    Text("Control what warehouse management actions managers can perform.")
                }
                
                Section {
                    Toggle("Can View Inventory", isOn: $techniciansCanViewInventory)
                    Toggle("Can Request Transfers", isOn: $techniciansCanRequestTransfers)
                } header: {
                    Text("Technician Permissions")
                }
                
                Section {
                    Toggle("Require Approval for Transfers", isOn: $requireApprovalForTransfers)
                    Toggle("Allow Emergency Access", isOn: $allowEmergencyAccess)
                } header: {
                    Text("Transfer Controls")
                } footer: {
                    Text("Emergency access allows technicians to access inventory without approval in critical situations.")
                }
                
                if authService.currentUser?.userRole == .admin {
                    Section {
                        Button("Reset All Permissions") {
                            resetPermissions()
                        }
                        .foregroundColor(.red)
                    } header: {
                        Text("Admin Controls")
                    }
                }
            }
            .navigationTitle("Permissions & Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func resetPermissions() {
        managersCanAddWarehouses = true
        managersCanDeleteWarehouses = false
        techniciansCanViewInventory = true
        techniciansCanRequestTransfers = true
        requireApprovalForTransfers = true
        allowEmergencyAccess = true
    }
}

// MARK: - Extension for TextField placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

extension TextField {
    func placeholder(_ text: String) -> some View {
        self.overlay(
            Text(text)
                .foregroundColor(.gray)
                .opacity(0.6),
            alignment: .leading
        )
    }
} 