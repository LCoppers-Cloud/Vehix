import SwiftUI
import PhotosUI
import SwiftData


struct VehicleListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @EnvironmentObject var samsaraService: SamsaraService
    
    // Explicit query specifying Vehix.Vehicle with sort parameters
    @Query(sort: \Vehix.Vehicle.createdAt, order: .reverse) private var vehicles: [Vehix.Vehicle]
    
    @State private var showingAddVehicle = false
    @State private var showSamsaraPrompt = false
    @State private var showNotificationPrompt = false
    @State private var newVehicle: AppVehicle?
    @State private var showUpgradePrompt = false
    @State private var selectedVehicle: AppVehicle?
    @State private var showVehicleDetails = false
    @State private var showFixDuplicatesPrompt = false
    @State private var duplicateIds = Set<String>()
    @State private var vehicleToDelete: AppVehicle? = nil
    @State private var isEditing = false
    @State private var debugMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Debug banner to show vehicle count (hidden in production)
                #if DEBUG
                Text("Vehicle count in database: \(vehicles.count)")
                    .font(.footnote)
                    .padding(5)
                    .background(Color.yellow.opacity(0.5))
                    .cornerRadius(4)
                
                if debugMessage.isEmpty == false {
                    Text(debugMessage)
                        .font(.footnote)
                        .padding(5)
                        .background(Color.orange.opacity(0.5))
                        .cornerRadius(4)
                }
                #endif
                
                if vehicles.isEmpty {
                    emptyStateView
                } else {
                    // Banner at the top
                    if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                        addVehicleBanner
                    }
                    
                    // Full screen list with spacing and padding
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(vehicles) { vehicle in
                                if isEditing {
                                    HStack {
                                        VehicleListRow(vehicle: vehicle)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            vehicleToDelete = vehicle
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .padding(8)
                                                .background(Color.gray.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                        .padding(.trailing, 8)
                                    }
                                    .padding(.vertical, 4)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                                    .padding(.horizontal, 8)
                                } else {
                                    Button(action: {
                                        selectedVehicle = vehicle
                                        showVehicleDetails = true
                                    }) {
                                        VehicleListRow(vehicle: vehicle)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemBackground))
                                            .cornerRadius(8)
                                            .shadow(color: .black.opacity(0.1), radius: 2)
                                            .padding(.horizontal, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Vehicles")
            .toolbar {
                // Add button for admins and dealers
                if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            if storeKitManager.vehicleRemaining > 0 {
                                showingAddVehicle = true
                            } else {
                                showUpgradePrompt = true
                            }
                        }) {
                            Label("Add Vehicle", systemImage: "plus")
                        }
                        .disabled(storeKitManager.vehicleRemaining == 0)
                    }
                    
                    // Add Edit button when vehicles exist
                    if !vehicles.isEmpty {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(isEditing ? "Done" : "Edit") {
                                isEditing.toggle()
                            }
                        }
                    }
                    
                    #if DEBUG
                    // Add debug button
                    ToolbarItem(placement: .bottomBar) {
                        Button("Debug DB") {
                            debugDatabase()
                        }
                    }
                    #endif
                }
            }
            .navigationDestination(isPresented: $showVehicleDetails) {
                if let vehicle = selectedVehicle {
                    VehicleDetailView(vehicle: vehicle)
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleForm(onVehicleCreated: { vehicle in
                    newVehicle = vehicle
                    showingAddVehicle = false
                    showSamsaraPrompt = true
                })
            }
            .alert("Connect to Samsara?", isPresented: $showSamsaraPrompt) {
                Button("Connect", action: { showNotificationPrompt = true })
                Button("Skip", role: .cancel, action: { showNotificationPrompt = true })
            } message: {
                Text("Would you like to connect this vehicle to Samsara for automatic mileage tracking?")
            }
            .alert("Enable Notifications?", isPresented: $showNotificationPrompt) {
                Button("Enable", action: requestNotificationPermission)
                Button("Not Now", role: .cancel, action: {})
            } message: {
                Text("Enable notifications to get oil change reminders for this vehicle.")
            }
            .alert(isPresented: $showUpgradePrompt) {
                Alert(
                    title: Text("Upgrade Required"),
                    message: Text("You've reached your plan's vehicle limit (\(storeKitManager.vehicleLimit)). Upgrade your subscription to add more vehicles."),
                    primaryButton: .default(Text("Upgrade Now"), action: {
                        // Open subscription management
                    }),
                    secondaryButton: .cancel(Text("Cancel"))
                )
            }
            .alert("Fix Duplicate Vehicle IDs", isPresented: $showFixDuplicatesPrompt) {
                Button("Fix Now", action: fixDuplicateVehicleIds)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Found \(duplicateIds.count) duplicate vehicle IDs. This can cause display issues. Would you like to fix them now?")
            }
            .sheet(isPresented: $showFixDuplicatesPrompt) {
                DuplicateVehiclesView(duplicateIds: duplicateIds)
            }
            .sheet(item: $vehicleToDelete) { vehicle in
                DeleteVehicleView(vehicle: vehicle, onDelete: {
                    // Nothing special needed here, the view handles deletion
                })
            }
            .onAppear {
                checkForDuplicateIds()
                debugVehicles()
                // Force fetch vehicles directly
                directFetchVehicles()
            }
            .refreshable {
                debugVehicles()
                directFetchVehicles()
            }
        }
    }
    
    // Directly fetch vehicles to ensure we're seeing current data
    private func directFetchVehicles() {
        do {
            let descriptor = FetchDescriptor<Vehix.Vehicle>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            let fetchedVehicles = try modelContext.fetch(descriptor)
            debugMessage = "Direct fetch found \(fetchedVehicles.count) vehicles"
            
            if vehicles.count != fetchedVehicles.count {
                // There's a mismatch between our query and direct fetch
                debugMessage += " - MISMATCH with @Query: \(vehicles.count)"
            }
            
            if fetchedVehicles.isEmpty {
                debugMessage = "No vehicles found in direct fetch - database may be empty"
            }
        } catch {
            debugMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    // Top banner with add vehicle button for better visibility
    private var addVehicleBanner: some View {
        HStack {
            Text("Manage your vehicle fleet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                if storeKitManager.vehicleRemaining > 0 {
                    showingAddVehicle = true
                } else {
                    showUpgradePrompt = true
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Vehicle")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            .disabled(storeKitManager.vehicleRemaining == 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // Check for duplicate IDs
    private func checkForDuplicateIds() {
        var seenIds = Set<String>()
        duplicateIds.removeAll()
        
        for vehicle in vehicles {
            if seenIds.contains(vehicle.id) {
                duplicateIds.insert(vehicle.id)
            } else {
                seenIds.insert(vehicle.id)
            }
        }
        
        if !duplicateIds.isEmpty {
            print("WARNING: Found duplicate vehicle IDs: \(duplicateIds)")
            showFixDuplicatesPrompt = true
        }
    }
    
    // Empty state view when no vehicles are available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "car.fill")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.7))
            
            Text("No Vehicles")
                .font(.title2)
                .bold()
            
            Text("Add vehicles to track maintenance, assign inventory, and monitor location.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                Button(action: {
                    if storeKitManager.vehicleRemaining > 0 {
                        showingAddVehicle = true
                    } else {
                        showUpgradePrompt = true
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Vehicle")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .disabled(storeKitManager.vehicleRemaining == 0)
            }
            
            Spacer()
        }
    }
    
    // Debug functions for troubleshooting
    private func debugVehicles() {
        var vehicleInfo = "Vehicles in database: \(vehicles.count)\n"
        
        for (index, vehicle) in vehicles.enumerated() {
            vehicleInfo += "[\(index)] \(vehicle.make) \(vehicle.model) (\(vehicle.id))\n"
        }
        
        print(vehicleInfo)
        debugMessage = "Found \(vehicles.count) vehicles in database"
    }
    
    private func debugDatabase() {
        do {
            // Directly fetch vehicles to verify database content
            let descriptor = FetchDescriptor<Vehix.Vehicle>()
            let actualVehicles = try modelContext.fetch(descriptor)
            
            if actualVehicles.count > 0 {
                var vehicleInfo = "DEBUG FETCH: Found \(actualVehicles.count) vehicles\n"
                for vehicle in actualVehicles {
                    vehicleInfo += "- \(vehicle.make) \(vehicle.model) (\(vehicle.id))\n"
                }
                print(vehicleInfo)
                debugMessage = "Direct fetch found \(actualVehicles.count) vehicles"
            } else {
                debugMessage = "No vehicles found in direct database fetch"
            }
        } catch {
            debugMessage = "Error fetching vehicles: \(error.localizedDescription)"
            print("Error fetching vehicles: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    func requestNotificationPermission() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Notification permissions granted")
            } else if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
    }
    
    func fixDuplicateVehicleIds() {
        for vehicle in vehicles {
            if duplicateIds.contains(vehicle.id) {
                // Generate a new unique ID
                vehicle.id = UUID().uuidString
                print("Fixed duplicate ID, new ID: \(vehicle.id)")
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("Successfully saved changes after fixing duplicate IDs")
            duplicateIds.removeAll()
        } catch {
            print("Error saving context after fixing duplicate IDs: \(error)")
        }
    }
    
    // Date formatting helper (needed for formatDate references)
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Vehicle List Row

struct VehicleListRow: View {
    var vehicle: Vehix.Vehicle
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var samsaraService: SamsaraService
    
    @State private var showTrackingOptions = false
    @State private var isUpdatingSamsara = false
    @State private var showingSamsaraSuccess = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 15) {
                // Vehicle image or fallback icon
                if let photoData = vehicle.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 1)
                } else {
                    Image(systemName: "car.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 60)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Vehicle details
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                        .font(.headline)
                    
                    if let plate = vehicle.licensePlate, !plate.isEmpty {
                        Text(plate)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Inventory count
                    if let items = vehicle.stockItems, !items.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(items.count) items · $\(String(format: "%.2f", vehicle.totalInventoryValue))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Tracking status indicator
                VStack(alignment: .trailing, spacing: 2) {
                    if vehicle.isTrackedBySamsara {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.green)
                            Text("Tracked")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    } else {
                        Button {
                            showTrackingOptions = true
                        } label: {
                            HStack {
                                Image(systemName: "location.slash")
                                Text("Set up")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Mileage info
                    HStack(spacing: 4) {
                        Image(systemName: "gauge")
                            .font(.caption)
                        Text("\(vehicle.mileage) mi")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Location data (shown if available)
            if vehicle.isTrackedBySamsara, let location = vehicle.lastKnownLocation {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location)
                                .font(.footnote)
                            
                            if let updateDate = vehicle.lastLocationUpdateDate {
                                Text("Updated: \(formatDate(updateDate))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if vehicle.isTrackedBySamsara {
                            Button {
                                refreshSamsaraData()
                            } label: {
                                HStack {
                                    if isUpdatingSamsara {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption)
                                    }
                                    Text("Refresh")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .disabled(isUpdatingSamsara)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            
            // Oil change status indicator
            if vehicle.isOilChangeDue {
                VStack(alignment: .leading, spacing: 4) {
                    if !vehicle.isTrackedBySamsara {
                        Divider()
                    }
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Oil Change Due")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        if let nextMileage = vehicle.nextOilChangeDueMileage {
                            Text("Current: \(vehicle.mileage) mi / Due: \(nextMileage) mi")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
        .actionSheet(isPresented: $showTrackingOptions) {
            ActionSheet(
                title: Text("Vehicle Tracking Options"),
                message: Text("Select a tracking option for this vehicle"),
                buttons: [
                    .default(Text("Set up Samsara Tracking")) {
                        setupSamsaraTracking()
                    },
                    .default(Text("Use AirTag")) {
                        // Show AirTag instructions in a sheet
                    },
                    .default(Text("Learn More About Tracking")) {
                        // Show tracking info sheet
                    },
                    .cancel()
                ]
            )
        }
        .alert("Samsara Tracking Enabled", isPresented: $showingSamsaraSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This vehicle will now be tracked through Samsara. Location and mileage data will be synchronized automatically.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func setupSamsaraTracking() {
        // Enable Samsara tracking for this vehicle
        vehicle.isTrackedBySamsara = true
        
        // Generate a mock Samsara ID if none exists
        if vehicle.samsaraVehicleId == nil {
            vehicle.samsaraVehicleId = UUID().uuidString
        }
        
        // Set initial location data
        vehicle.lastKnownLocation = "Connecting to Samsara..."
        vehicle.lastLocationUpdateDate = Date()
        
        // Save changes
        do {
            try modelContext.save()
            
            // Refresh data immediately
            refreshSamsaraData()
        } catch {
            print("Error setting up Samsara tracking: \(error)")
        }
    }
    
    private func refreshSamsaraData() {
        guard vehicle.isTrackedBySamsara else { return }
        
        isUpdatingSamsara = true
        
        // Need to create a temporary AppVehicle to work with the SamsaraService
        let appVehicle = AppVehicle(
            id: vehicle.id,
            make: vehicle.make,
            model: vehicle.model,
            year: vehicle.year,
            vin: vehicle.vin,
            licensePlate: vehicle.licensePlate,
            mileage: vehicle.mileage,
            samsaraVehicleId: vehicle.samsaraVehicleId,
            isTrackedBySamsara: vehicle.isTrackedBySamsara
        )
        
        // Call the SamsaraService to update this vehicle's data
        samsaraService.syncVehicle(appVehicle) { success, error in
            isUpdatingSamsara = false
            
            if success {
                // Update the actual Vehix.Vehicle with the data from appVehicle
                if let newMileage = appVehicle.lastMileageUpdateDate != nil ? appVehicle.mileage : nil,
                   let newLocation = appVehicle.lastKnownLocation {
                    
                    vehicle.mileage = newMileage
                    vehicle.lastKnownLocation = newLocation
                    vehicle.lastLocationUpdateDate = Date()
                    vehicle.lastMileageUpdateDate = Date()
                    
                    // Try to save the changes
                    do {
                        try modelContext.save()
                        showingSamsaraSuccess = true
                    } catch {
                        print("Error saving updated vehicle data: \(error)")
                    }
                }
            } else if let errorMsg = error {
                print("Error syncing with Samsara: \(errorMsg)")
            }
        }
    }
}

// MARK: - Duplicate Vehicles View

struct DuplicateVehiclesView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var duplicateIds: Set<String>
    @Query private var vehicles: [AppVehicle]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Found \(duplicateIds.count) vehicle IDs with duplicates. This may cause synchronization issues. The Fix button will update all affected vehicles with new unique IDs.")
                        .font(.footnote)
                }
                
                Section("Duplicate Vehicles") {
                    ForEach(Array(duplicateIds), id: \.self) { id in
                        let vehiclesWithId = vehicles.filter { $0.id == id }
                        
                        VStack(alignment: .leading) {
                            Text("ID: \(id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(vehiclesWithId) { vehicle in
                                Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                                    .padding(.leading)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Duplicate Vehicle IDs")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fix All") {
                        fixDuplicates()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func fixDuplicates() {
        var processed = Set<String>()
        
        for vehicle in vehicles {
            if duplicateIds.contains(vehicle.id) && !processed.contains(vehicle.id) {
                // Keep the ID for the first occurrence of each duplicate
                processed.insert(vehicle.id)
            } else if duplicateIds.contains(vehicle.id) {
                // Generate a new ID for subsequent duplicates
                vehicle.id = UUID().uuidString
            }
        }
        
        try? modelContext.save()
    }
}

// Vehicle Detail View
struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    let vehicle: AppVehicle
    
    @State private var showingEditSheet = false
    @State private var showingSamsaraDetails = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Vehicle Image
                ZStack(alignment: .bottomTrailing) {
                    if let data = vehicle.photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    } else {
                        HStack {
                            Spacer()
                            Image(systemName: "car.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 120)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                            Spacer()
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                    }
                    
                    // Location indicator (if Samsara connected)
                    if vehicle.isTrackedBySamsara, let location = vehicle.lastKnownLocation {
                        Button(action: {
                            showingSamsaraDetails = true
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text(location)
                                    .lineLimit(1)
                            }
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .padding(12)
                        }
                    }
                }
                
                // Vehicle Info
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(vehicle.displayName)
                            .font(.title2)
                            .bold()
                        
                        if let plate = vehicle.licensePlate, !plate.isEmpty {
                            Text("License: \(plate)")
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Type: \(vehicle.vehicleType)")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Maintenance Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Maintenance")
                            .font(.headline)
                        
                        // Mileage
                        HStack {
                            Image(systemName: "gauge")
                                .frame(width: 24)
                            Text("Mileage: \(vehicle.mileage) miles")
                            
                            if vehicle.isTrackedBySamsara {
                                Text("(Automatic)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Oil Change Info
                        if vehicle.vehicleType != "Electric" {
                            HStack(alignment: .top) {
                                Image(systemName: "drop.fill")
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading) {
                                    if let lastOilDate = vehicle.lastOilChangeDate, let lastOilMileage = vehicle.lastOilChangeMileage {
                                        Text("Last Oil Change: \(VehicleListView.formatDate(lastOilDate)) at \(lastOilMileage) miles")
                                    } else {
                                        Text("No oil change records")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if vehicle.isOilChangeDue {
                                        Text("Status: DUE NOW")
                                            .foregroundColor(.red)
                                            .bold()
                                    } else {
                                        Text("Status: \(vehicle.oilChangeDueStatus)")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Inventory Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Inventory")
                            .font(.headline)
                        
                        if let stockItems = vehicle.stockItems, !stockItems.isEmpty {
                            ForEach(stockItems) { item in
                                HStack {
                                    Text(item.inventoryItem?.name ?? "Unknown Item")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("Qty: \(item.quantity)")
                                        .foregroundColor(item.isBelowMinimumStock ? .red : .secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
                            Text("No inventory assigned to this vehicle")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        
                        if let stockItems = vehicle.stockItems, !stockItems.isEmpty {
                            Divider()
                            
                            HStack {
                                Text("Total Value:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("$\(String(format: "%.2f", vehicle.totalInventoryValue))")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Additional Information
                    if vehicle.isTrackedBySamsara {
                        samsaraSection
                    }
                }
                
                Spacer()
            }
        }
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditVehicleForm(vehicle: vehicle) { updatedVehicle in
                // Refresh view with updated vehicle data if needed
            }
        }
        .sheet(isPresented: $showingSamsaraDetails) {
            // TODO: Implement Samsara details view with map
            Text("Samsara Location Map Placeholder")
        }
    }
    
    // Samsara section
    private var samsaraSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GPS Tracking")
                .font(.headline)
            
            HStack(alignment: .top) {
                Image(systemName: "location.fill")
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let location = vehicle.lastKnownLocation {
                        Text(location)
                    } else {
                        Text("Location unavailable")
                            .foregroundColor(.secondary)
                    }
                    
                    if let date = vehicle.lastLocationUpdateDate {
                        Text("Updated: \(VehicleListView.formatDate(date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button(action: {
                showingSamsaraDetails = true
            }) {
                Text("View on Map")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct DeleteVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var vehicle: AppVehicle
    var onDelete: () -> Void
    
    @State private var confirmation = ""
    @State private var showError = false
    
    var inventoryItemCount: Int {
        vehicle.stockItems?.count ?? 0
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.red)
                    .padding(.top, 20)
                
                Text("Confirm Vehicle Deletion")
                    .font(.title2)
                    .bold()
                
                Text("You are about to permanently delete \(vehicle.year) \(vehicle.make) \(vehicle.model).")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if inventoryItemCount > 0 {
                    Text("⚠️ WARNING: This vehicle has \(inventoryItemCount) inventory items attached that will also be deleted.")
                        .font(.callout)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Text("This action cannot be undone.")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding(.top, 5)
                
                VStack(alignment: .leading) {
                    Text("To confirm, please type 'DELETE'")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    TextField("Type DELETE", text: $confirmation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Button(action: {
                    if confirmation == "DELETE" {
                        // Delete the vehicle and its associated inventory items
                        modelContext.delete(vehicle)
                        try? modelContext.save()
                        onDelete()
                        dismiss()
                    } else {
                        showError = true
                    }
                }) {
                    Text("Delete Vehicle\(inventoryItemCount > 0 ? " + Inventory" : "")")
                        .frame(minWidth: 200)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(confirmation != "DELETE")
                
                Button("Cancel") {
                    dismiss()
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Delete Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Incorrect Confirmation", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text("Please type 'DELETE' exactly as shown to confirm.")
            }
        }
    }
}

// MARK: - Previews
struct VehicleListView_Previews: PreviewProvider {
    static var previews: some View {
        VehicleListView()
    }
} 

