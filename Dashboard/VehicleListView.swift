import SwiftUI
import PhotosUI
import SwiftData

struct VehicleListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @EnvironmentObject var samsaraService: SamsaraService
    
    // Explicit query specifying Vehix.Vehicle with sort parameters
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.createdAt, order: .reverse)]) private var allVehicles: [Vehix.Vehicle]
    @Query(sort: [SortDescriptor(\VehicleAssignment.startDate, order: .reverse)]) private var assignments: [VehicleAssignment]
    
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
    @State private var debugMessage = ""
    @State private var showingVehicleManagement = false
    
    // Computed property to filter vehicles based on user role
    private var vehicles: [Vehix.Vehicle] {
        guard let userRole = authService.currentUser?.userRole,
              let userId = authService.currentUser?.id else { 
            return allVehicles 
        }
        
        // For technicians, only show assigned vehicles
        if userRole == .technician {
            let activeAssignments = assignments.filter { assignment in
                assignment.userId == userId && assignment.endDate == nil
            }
            
            return allVehicles.filter { vehicle in
                activeAssignments.contains { $0.vehicleId == vehicle.id }
            }
        }
        
        // For managers and admins, show all vehicles
        return allVehicles
    }
    
    var body: some View {
        NavigationStack {
            mainContent
        }
        .navigationDestination(isPresented: $showVehicleDetails) {
            if let vehicle = selectedVehicle {
                VehicleDetailView(vehicle: vehicle)
            }
        }
        .sheet(isPresented: $showingAddVehicle) {
            AddVehicleForm()
        }
        .sheet(isPresented: $showingVehicleManagement) {
            VehicleManagementView()
                .environmentObject(authService)
                .environmentObject(storeKitManager)
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
        .alert("Delete Vehicle", isPresented: .constant(vehicleToDelete != nil)) {
            Button("Cancel", role: .cancel) {
                vehicleToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let vehicle = vehicleToDelete {
                    deleteVehicle(vehicle)
                    vehicleToDelete = nil
                }
            }
        } message: {
            if let vehicle = vehicleToDelete {
                Text("Are you sure you want to delete \(vehicle.year) \(vehicle.make) \(vehicle.model)? This action cannot be undone.")
            }
        }
        .onAppear {
            checkForDuplicateIds()
            debugVehicles()
            directFetchVehicles()
        }
        .refreshable {
            debugVehicles()
            directFetchVehicles()
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            debugBanner
            
            if vehicles.isEmpty {
                technicianAwareEmptyStateView
            } else {
                vehicleListContent
            }
        }
        .navigationTitle("Vehicles")
        .toolbar {
            toolbarContent
        }
    }
    
    @ViewBuilder
    private var debugBanner: some View {
        #if DEBUG
        VStack {
            Text("Total vehicles: \(allVehicles.count) | Visible: \(vehicles.count)")
                .font(.footnote)
                .padding(5)
                .background(Color.yellow.opacity(0.5))
                .cornerRadius(4)
            
            if authService.currentUser?.userRole == .technician {
                Text("Showing assigned vehicles only")
                    .font(.caption)
                    .padding(3)
                    .background(Color.blue.opacity(0.5))
                    .cornerRadius(4)
            }
            
            if !debugMessage.isEmpty {
                Text(debugMessage)
                    .font(.footnote)
                    .padding(5)
                    .background(Color.orange.opacity(0.5))
                    .cornerRadius(4)
            }
        }
        #endif
    }
    
    private var vehicleListContent: some View {
        VStack(spacing: 0) {
            if canManageVehicles {
                addVehicleBanner
            }
            
            vehicleList
        }
    }
    
    private var vehicleList: some View {
        List {
            ForEach(vehicles) { vehicle in
                Button(action: {
                    selectedVehicle = vehicle
                    showVehicleDetails = true
                }) {
                    VehicleListRow(vehicle: vehicle)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    swipeActions(for: vehicle)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func swipeActions(for vehicle: Vehix.Vehicle) -> some View {
        Button(role: .destructive) {
            vehicleToDelete = vehicle
        } label: {
            Label("Delete", systemImage: "trash")
        }
        
        Button {
            // TODO: Add edit functionality
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.blue)
    }
    
    // Computed property to check if user can manage vehicles
    private var canManageVehicles: Bool {
        guard let userRole = authService.currentUser?.userRole else { return false }
        return userRole == .admin || userRole == .dealer || userRole == .premium
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            NavigationLink(destination: VehicleLocationMapView().environmentObject(authService).environmentObject(samsaraService)) {
                Image(systemName: "map.fill")
                    .foregroundColor(.blue)
            }
        }
        
        if canManageVehicles {
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
            
            #if DEBUG
            ToolbarItem(placement: .bottomBar) {
                Button("Debug DB") {
                    debugDatabase()
                }
            }
            #endif
        }
    }
    
    // MARK: - Helper Functions
    
    private func deleteVehicle(_ vehicle: Vehix.Vehicle) {
        // Delete associated stock items first
        if let stockItems = vehicle.stockItems {
            for stockItem in stockItems {
                modelContext.delete(stockItem)
            }
        }
        
        // Delete the vehicle
        modelContext.delete(vehicle)
        
        // Save changes
        do {
            try modelContext.save()
        } catch {
            print("Error deleting vehicle: \(error)")
        }
    }
    
    // Directly fetch vehicles to ensure we're seeing current data
    private func directFetchVehicles() {
        do {
            let descriptor = FetchDescriptor<Vehix.Vehicle>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            let fetchedVehicles = try modelContext.fetch(descriptor)
            debugMessage = "Direct fetch found \(fetchedVehicles.count) total vehicles"
            
            if authService.currentUser?.userRole == .technician {
                debugMessage += " | Showing \(vehicles.count) assigned"
            } else {
                debugMessage += " | Showing \(vehicles.count) (all)"
            }
            
            if allVehicles.count != fetchedVehicles.count {
                // There's a mismatch between our query and direct fetch
                debugMessage += " - MISMATCH"
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
        VStack(spacing: 12) {
            HStack {
                Text("Manage your vehicle fleet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Vehicle Management Button (Primary)
                Button(action: {
                    showingVehicleManagement = true
                }) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                        Text("Vehicle Management")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                
                // Add Vehicle Button (Secondary)
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
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                .disabled(storeKitManager.vehicleRemaining == 0)
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
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
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "car.2.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Vehicles in Fleet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Your vehicle fleet is empty. Add vehicles to start managing inventory assignments, tracking maintenance schedules, and monitoring performance metrics.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }
            
            // Show different buttons based on permissions
            if canManageVehicles {
                VStack(spacing: 16) {
                    // Primary Add Vehicle Button - More Prominent
                    Button(action: {
                        if storeKitManager.vehicleRemaining > 0 {
                            showingAddVehicle = true
                        } else {
                            showUpgradePrompt = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Add Your First Vehicle")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(storeKitManager.vehicleRemaining == 0)
                    
                    // Secondary Vehicle Management Button
                    Button(action: {
                        showingVehicleManagement = true
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.title3)
                            Text("Vehicle Management")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 1)
                        )
                    }
                    
                    // Information Text
                    VStack(spacing: 8) {
                        Text("You can add \(storeKitManager.vehicleRemaining) more vehicles")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        
                        Text("Use Vehicle Management to assign technicians, send invitations, and manage your fleet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 40)
            } else {
                // For users without management permissions
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    Text("Vehicle Management Access Required")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Contact your administrator to get permission to add vehicles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // Technician-aware empty state that considers both scenarios
    private var technicianAwareEmptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if authService.currentUser?.userRole == .technician {
                // No assigned vehicles for technician
                Image(systemName: "car.slash")
                    .font(.system(size: 80))
                    .foregroundColor(.orange.opacity(0.6))
                
                VStack(spacing: 12) {
                    Text("No Assigned Vehicles")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("You don't have any vehicles assigned to you yet. Contact your manager to get vehicles assigned so you can start managing inventory and completing service tasks.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        // Open profile to see assignment status
                        // TODO: Add navigation to profile or assignment request
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .font(.title3)
                            Text("View My Profile")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 60)
                }
            } else {
                // No vehicles in system (for managers/admins)
                emptyStateView
            }
            
            Spacer()
        }
    }
    
    // Debug functions for troubleshooting
    private func debugVehicles() {
        var vehicleInfo = "Total vehicles: \(allVehicles.count), Visible: \(vehicles.count)\n"
        
        if authService.currentUser?.userRole == .technician {
            vehicleInfo += "(Showing assigned vehicles only)\n"
        }
        
        for (index, vehicle) in vehicles.enumerated() {
            vehicleInfo += "[\(index)] \(vehicle.make) \(vehicle.model) (\(vehicle.id))\n"
        }
        
        print(vehicleInfo)
        debugMessage = "Total: \(allVehicles.count), Visible: \(vehicles.count)"
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
                    
                    // Inventory count and value
                    if let items = vehicle.stockItems, !items.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(items.count) items")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("$\(String(format: "%.0f", vehicle.totalInventoryValue))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("No inventory assigned")
                                .font(.caption)
                                .foregroundColor(.gray)
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

