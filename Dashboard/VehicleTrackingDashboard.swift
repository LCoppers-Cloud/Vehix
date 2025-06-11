import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct VehicleTrackingDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var samsaraService: SamsaraService
    @StateObject private var appleGPSManager = AppleGPSTrackingManager.shared
    
    @Query private var vehicles: [Vehix.Vehicle]
    @Query private var trackingSessions: [VehicleTrackingSession]
    @Query private var assignments: [VehicleAssignment]
    @Query private var allUsers: [AuthUser]
    
    @State private var selectedVehicle: Vehix.Vehicle?
    @State private var showingTrackingOptions = false
    @State private var showingSessionDetails = false
    @State private var selectedSession: VehicleTrackingSession?
    @State private var showingLocationPermissionAlert = false
    @State private var searchText = ""
    @State private var selectedFilter: VehicleFilter = .all
    @State private var showingGPSSetup = false
    @State private var selectedUser: AuthUser?
    
    enum VehicleFilter: String, CaseIterable {
        case all = "All"
        case assigned = "Assigned"
        case available = "Available"
        case maintenance = "Maintenance"
    }
    
    private var filteredVehicles: [Vehix.Vehicle] {
        let searchFiltered = vehicles.filter { vehicle in
            searchText.isEmpty || 
            vehicle.displayName.localizedCaseInsensitiveContains(searchText) ||
            vehicle.vin.localizedCaseInsensitiveContains(searchText) ||
            (vehicle.licensePlate?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        switch selectedFilter {
        case .all:
            return searchFiltered
        case .assigned:
            return searchFiltered.filter { vehicle in
                assignments.contains { $0.vehicleId == vehicle.id && $0.endDate == nil }
            }
        case .available:
            return searchFiltered.filter { vehicle in
                !assignments.contains { $0.vehicleId == vehicle.id && $0.endDate == nil }
            }
        case .maintenance:
            // For now, just return empty - this would be based on maintenance status
            return []
        }
    }
    
    private var totalVehicles: Int { vehicles.count }
    private var assignedVehicles: Int {
        vehicles.filter { vehicle in
            assignments.contains { $0.vehicleId == vehicle.id && $0.endDate == nil }
        }.count
    }
    private var availableVehicles: Int { totalVehicles - assignedVehicles }
    
    private var activeTrackingSessions: [VehicleTrackingSession] {
        trackingSessions.filter { $0.endTime == nil }
    }
    
    private var recentSessions: [VehicleTrackingSession] {
        trackingSessions
            .filter { $0.endTime != nil }
            .sorted { $0.startTime > $1.startTime }
            .prefix(10)
            .map { $0 }
    }
    
    private var samsaraConnectedCount: Int {
        vehicles.filter { $0.isTrackedBySamsara }.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with tracking status
                trackingStatusHeader
                
                // Search and Filter
                searchAndFilterSection
                
                // Main content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Active tracking section
                        if !activeTrackingSessions.isEmpty {
                            activeTrackingSection
                        }
                        
                        // Vehicle list
                        vehicleListSection
                        
                        // Recent sessions
                        recentSessionsSection
                        
                        // GPS Setup Section for Users
                        GPSSetupSection(
                            users: allUsers,
                            onUserSelect: { user in
                                selectedUser = user
                                showingGPSSetup = true
                            }
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Vehicle Tracking")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingTrackingOptions = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingTrackingOptions) {
                TrackingOptionsView()
                    .environmentObject(samsaraService)
            }
            .sheet(isPresented: $showingSessionDetails) {
                if let session = selectedSession {
                    TrackingSessionDetailView(session: session)
                }
            }
            .sheet(isPresented: $showingGPSSetup) {
                if let user = selectedUser {
                    GPSConsentView(userId: user.id, userName: user.fullName ?? "Unknown User")
                } else {
                    Text("Please select a user")
                }
            }
            .alert("Location Permission Required", isPresented: $showingLocationPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Location access is required for vehicle tracking. Please enable location permissions in Settings.")
            }
            .onAppear {
                appleGPSManager.setModelContext(modelContext)
            }
        }
    }
    
    // MARK: - View Components
    
    private var trackingStatusHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracking Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if appleGPSManager.isTracking {
                        Text(appleGPSManager.getTrackingStatusString())
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else {
                        Text("Not tracking")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Location permission status
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: locationPermissionIcon)
                        .font(.title2)
                        .foregroundColor(locationPermissionColor)
                    
                    Text(locationPermissionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick stats
            HStack(spacing: 20) {
                StatCard(
                    title: "Active Sessions",
                    value: "\(activeTrackingSessions.count)",
                    subtitle: "currently tracking",
                    icon: "location.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Total Vehicles",
                    value: "\(totalVehicles)",
                    subtitle: "in fleet",
                    icon: "car.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Samsara Connected",
                    value: "\(samsaraConnectedCount)",
                    subtitle: "vehicles tracked",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var activeTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Tracking Sessions")
                .font(.headline)
                .fontWeight(.semibold)
            
            if activeTrackingSessions.isEmpty {
                Text("No active tracking sessions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(activeTrackingSessions, id: \.id) { session in
                    ActiveTrackingCard(session: session) {
                        selectedSession = session
                        showingSessionDetails = true
                    }
                }
            }
        }
    }
    
    private var vehicleListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredVehicles, id: \.id) { vehicle in
                    VehicleTrackingCard(
                        vehicle: vehicle,
                        assignment: assignments.first { $0.vehicleId == vehicle.id && $0.endDate == nil },
                        users: allUsers,
                        onTap: {
                            selectedVehicle = vehicle
                            showingSessionDetails = true
                        }
                    )
                }
                
                if filteredVehicles.isEmpty {
                    EmptyStateView(
                        icon: "car",
                        title: "No Vehicles Found",
                        message: searchText.isEmpty ? 
                            "No vehicles match the selected filter" : 
                            "No vehicles match your search criteria"
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
                .fontWeight(.semibold)
            
            if recentSessions.isEmpty {
                Text("No recent sessions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(recentSessions), id: \.id) { session in
                    RecentSessionCard(session: session) {
                        selectedSession = session
                        showingSessionDetails = true
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var locationPermissionIcon: String {
        switch appleGPSManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    private var locationPermissionColor: Color {
        switch appleGPSManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var locationPermissionText: String {
        switch appleGPSManager.authorizationStatus {
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        case .denied, .restricted:
            return "Denied"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search vehicles...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filter Buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(VehicleFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            Text(filter.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedFilter == filter ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    // MARK: - Actions
    
    private func startTracking(for vehicle: Vehix.Vehicle) {
        guard authService.currentUser != nil else { return }
        
        // Check location permission
        guard appleGPSManager.authorizationStatus == .authorizedWhenInUse || 
              appleGPSManager.authorizationStatus == .authorizedAlways else {
            showingLocationPermissionAlert = true
            return
        }
        
        appleGPSManager.startTracking(for: vehicle)
    }
    
    private func stopTracking() {
        appleGPSManager.stopTracking()
    }
}

// MARK: - Supporting Views

struct VehicleStatusCard: View {
    let vehicle: Vehix.Vehicle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(vehicle.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Circle()
                    .fill(vehicle.isTrackedBySamsara ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mileage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(vehicle.mileage)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(vehicle.isTrackedBySamsara ? "Tracked" : "Manual")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(vehicle.isTrackedBySamsara ? .green : .orange)
                }
            }
            
            if let location = vehicle.lastKnownLocation {
                Text(location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct VehicleTrackingCard: View {
    let vehicle: Vehix.Vehicle
    let assignment: VehicleAssignment?
    let users: [AuthUser]
    let onTap: () -> Void
    
    private var assignedUser: AuthUser? {
        guard let assignment = assignment else { return nil }
        return users.first { $0.id == assignment.userId }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Vehicle Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("VIN: \(vehicle.vin)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusBadge(
                            text: assignment != nil ? "Assigned" : "Available",
                            color: assignment != nil ? .green : .orange
                        )
                        
                        if let plate = vehicle.licensePlate {
                            Text(plate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Assignment Info
                if let assignment = assignment, let user = assignedUser {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.fullName ?? "Unknown User")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Since \(assignment.startDate, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        let days = Calendar.current.dateComponents([.day], from: assignment.startDate, to: Date()).day ?? 0
                        Text("\(days) days")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Vehicle Details
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mileage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(vehicle.mileage)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(vehicle.vehicleType)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ActiveTrackingCard: View {
    let session: VehicleTrackingSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vehicle ID: \(session.vehicleId)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Started: \(formatTime(session.startTime))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Duration: \(session.durationMinutes) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !session.businessPurpose.isEmpty {
                        Text("Purpose: \(session.businessPurpose)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Text("ACTIVE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Text(session.formattedDistance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RecentSessionCard: View {
    let session: VehicleTrackingSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vehicle ID: \(session.vehicleId)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(formatDateRange(session.startTime, session.endTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !session.businessPurpose.isEmpty {
                        Text("Purpose: \(session.businessPurpose)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(session.formattedDistance)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(session.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if session.userConsent {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct TrackingOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var samsaraService: SamsaraService
    
    var body: some View {
        NavigationView {
            Form {
                Section("GPS Tracking Options") {
                    NavigationLink("Apple GPS Settings") {
                        AppleGPSSettingsView()
                    }
                    
                    NavigationLink("Samsara Integration") {
                        SamsaraSettingsView(service: samsaraService)
                    }
                }
                
                Section("Permissions") {
                    Button("Open Location Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                }
            }
            .navigationTitle("Tracking Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AppleGPSSettingsView: View {
    var body: some View {
        Form {
            Section("Apple GPS Tracking") {
                Text("Configure Apple GPS tracking settings here")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Apple GPS")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TrackingSessionDetailView: View {
    let session: VehicleTrackingSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Session overview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Overview")
                            .font(.headline)
                        
                        HStack {
                            Text("Vehicle:")
                            Spacer()
                            Text(session.vehicleId)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Duration:")
                            Spacer()
                            Text(session.formattedDuration)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Distance:")
                            Spacer()
                            Text(session.formattedDistance)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Average Speed:")
                            Spacer()
                            Text(String(format: "%.1f km/h", session.averageSpeed * 3.6))
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Max Speed:")
                            Spacer()
                            Text(String(format: "%.1f km/h", session.maxSpeed * 3.6))
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Legal Compliance Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Legal Compliance")
                            .font(.headline)
                        
                        HStack {
                            Text("User Consent:")
                            Spacer()
                            Image(systemName: session.userConsent ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(session.userConsent ? .green : .red)
                        }
                        
                        HStack {
                            Text("Work Hours:")
                            Spacer()
                            Image(systemName: session.isWorkHours ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(session.isWorkHours ? .green : .red)
                        }
                        
                        if !session.businessPurpose.isEmpty {
                            HStack {
                                Text("Business Purpose:")
                                Spacer()
                                Text(session.businessPurpose)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Tracking points summary
                    if let points = session.trackingPoints, !points.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tracking Points")
                                .font(.headline)
                            
                            Text("\(points.count) location points recorded")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // You can add a map view here in the future
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GPSSetupSection: View {
    let users: [AuthUser]
    let onUserSelect: (AuthUser) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GPS Setup for Users")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150))
            ], spacing: 12) {
                ForEach(users, id: \.id) { user in
                    UserGPSCard(user: user) {
                        onUserSelect(user)
                    }
                }
            }
        }
    }
}

struct UserGPSCard: View {
    let user: AuthUser
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text(user.fullName ?? "Unknown User")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                Text("Setup GPS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// Helper functions
private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func formatDateRange(_ start: Date, _ end: Date?) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    
    let startString = formatter.string(from: start)
    
    if let end = end {
        let endString = formatter.string(from: end)
        return "\(startString) - \(endString)"
    } else {
        return "Started: \(startString)"
    }
}

#Preview {
    VehicleTrackingDashboard()
        .environmentObject(AppAuthService())
        .environmentObject(SamsaraService())
        .modelContainer(for: [Vehix.Vehicle.self, VehicleAssignment.self], inMemory: true)
} 