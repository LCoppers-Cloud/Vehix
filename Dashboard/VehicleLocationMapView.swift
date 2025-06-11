import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct VehicleLocationMapView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var samsaraService: SamsaraService
    
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.make)]) private var vehicles: [Vehix.Vehicle]
    @Query private var trackingSessions: [VehicleTrackingSession]
    @Query private var assignments: [VehicleAssignment]
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default: San Francisco
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    )
    
    @State private var selectedVehicle: Vehix.Vehicle?
    @State private var searchText = ""
    @State private var showingVehicleDetails = false
    @State private var isRefreshingLocations = false
    @State private var showingFilters = false
    @State private var filterShowTrackedOnly = false
    @State private var filterShowActiveOnly = false
    @State private var lastLocationUpdateTime = Date()
    
    // GPS Tracking
    @StateObject private var locationManager = VehicleLocationManager()
    @State private var showingGPSSettings = false
    
    private var filteredVehicles: [Vehix.Vehicle] {
        var filtered = vehicles
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { vehicle in
                vehicle.displayName.localizedCaseInsensitiveContains(searchText) ||
                vehicle.make.localizedCaseInsensitiveContains(searchText) ||
                vehicle.model.localizedCaseInsensitiveContains(searchText) ||
                (vehicle.licensePlate?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply tracking filter
        if filterShowTrackedOnly {
            filtered = filtered.filter { $0.isTrackedBySamsara || hasActiveGPSTracking($0) }
        }
        
        // Apply active assignment filter
        if filterShowActiveOnly {
            filtered = filtered.filter { vehicle in
                assignments.contains { assignment in
                    assignment.vehicleId == vehicle.id && assignment.endDate == nil
                }
            }
        }
        
        return filtered
    }
    
    private var vehicleAnnotations: [VehicleAnnotation] {
        filteredVehicles.compactMap { vehicle in
            guard let location = getVehicleLocation(vehicle) else { return nil }
            
            let assignment = assignments.first { $0.vehicleId == vehicle.id && $0.endDate == nil }
            let trackingSession = trackingSessions.first { 
                $0.vehicleId == vehicle.id && $0.endTime == nil 
            }
            
            return VehicleAnnotation(
                id: vehicle.id,
                coordinate: location,
                vehicle: vehicle,
                isTracking: hasActiveGPSTracking(vehicle),
                assignment: assignment,
                trackingSession: trackingSession
            )
        }
    }
    
    private var locationStats: LocationStats {
        let tracked = filteredVehicles.filter { $0.lastKnownLocation != nil }.count
        let activeGPS = filteredVehicles.filter { hasActiveGPSTracking($0) }.count
        let assigned = filteredVehicles.filter { vehicle in
            assignments.contains { $0.vehicleId == vehicle.id && $0.endDate == nil }
        }.count
        
        return LocationStats(
            totalVehicles: filteredVehicles.count,
            tracked: tracked,
            activeGPS: activeGPS,
            assigned: assigned
        )
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Search and filter bar
                    searchAndFilterSection
                    
                    // Map view
                    ZStack(alignment: .topTrailing) {
                        Map(position: $position) {
                            ForEach(vehicleAnnotations) { annotation in
                                Annotation(
                                    annotation.vehicle.displayName,
                                    coordinate: annotation.coordinate
                                ) {
                                    VehicleMapPin(
                                        annotation: annotation,
                                        isSelected: selectedVehicle?.id == annotation.id
                                    )
                                    .onTapGesture {
                                        selectVehicle(annotation.vehicle)
                                    }
                                }
                            }
                        }
                        .mapStyle(.standard)
                        .onAppear {
                            centerMapOnVehicles()
                        }
                        
                        // Floating controls
                        VStack(spacing: 12) {
                            // Center on vehicles button
                            Button(action: centerMapOnVehicles) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                            }
                            
                            // Refresh locations button
                            Button(action: refreshAllLocations) {
                                Image(systemName: isRefreshingLocations ? "arrow.clockwise" : "arrow.clockwise")
                                    .foregroundColor(.blue)
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                    .rotationEffect(.degrees(isRefreshingLocations ? 360 : 0))
                                    .animation(isRefreshingLocations ? .linear(duration: 1).repeatCount(.max, autoreverses: false) : .default, value: isRefreshingLocations)
                            }
                            .disabled(isRefreshingLocations)
                            
                            // GPS settings button
                            Button(action: { showingGPSSettings = true }) {
                                Image(systemName: "gear")
                                    .foregroundColor(.blue)
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                            }
                        }
                        .padding()
                    }
                    
                    // Stats bar
                    statsBar
                    
                    // Vehicle details panel (when selected)
                    if let selectedVehicle = selectedVehicle {
                        VehicleLocationDetailsPanel(
                            vehicle: selectedVehicle,
                            assignment: assignments.first { $0.vehicleId == selectedVehicle.id && $0.endDate == nil },
                            onStartTracking: { startGPSTracking(for: selectedVehicle) },
                            onStopTracking: { stopGPSTracking(for: selectedVehicle) },
                            onNavigate: { openMapsNavigation(to: selectedVehicle) },
                            onClose: { self.selectedVehicle = nil }
                        )
                        .transition(.move(edge: .bottom))
                    }
                }
            }
            .navigationTitle("Vehicle Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            filtersSheet
        }
        .sheet(isPresented: $showingGPSSettings) {
            gpsSettingsSheet
        }
        .onAppear {
            refreshAllLocations()
        }
    }
    
    // MARK: - UI Components
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search vehicles...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Quick filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    VehicleFilterChip(
                        title: "Tracked Only",
                        isSelected: filterShowTrackedOnly,
                        action: { filterShowTrackedOnly.toggle() }
                    )
                    
                    VehicleFilterChip(
                        title: "Assigned Only",
                        isSelected: filterShowActiveOnly,
                        action: { filterShowActiveOnly.toggle() }
                    )
                    
                    VehicleFilterChip(
                        title: "Show All",
                        isSelected: !filterShowTrackedOnly && !filterShowActiveOnly,
                        action: { 
                            filterShowTrackedOnly = false
                            filterShowActiveOnly = false
                        }
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    private var statsBar: some View {
        HStack {
            StatBadge(
                icon: "car.2.fill",
                title: "Total",
                value: "\(locationStats.totalVehicles)",
                color: .blue
            )
            
            StatBadge(
                icon: "mappin.and.ellipse",
                title: "Tracked",
                value: "\(locationStats.tracked)",
                color: .green
            )
            
            StatBadge(
                icon: "location.fill",
                title: "Live GPS",
                value: "\(locationStats.activeGPS)",
                color: .orange
            )
            
            StatBadge(
                icon: "person.fill",
                title: "Assigned",
                value: "\(locationStats.assigned)",
                color: .purple
            )
            
            Spacer()
            
            Text("Updated: \(formatTime(lastLocationUpdateTime))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1)
    }
    
    private var filtersSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Display Options")
                        .font(.headline)
                    
                    Toggle("Show only tracked vehicles", isOn: $filterShowTrackedOnly)
                    Toggle("Show only assigned vehicles", isOn: $filterShowActiveOnly)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Actions")
                        .font(.headline)
                    
                    Button("Refresh All Vehicle Locations") {
                        refreshAllLocations()
                        showingFilters = false
                    }
                    
                    Button("Center Map on Fleet") {
                        centerMapOnVehicles()
                        showingFilters = false
                    }
                    
                    Button("Start Tracking All Assigned Vehicles") {
                        startTrackingAllAssigned()
                        showingFilters = false
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Map Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingFilters = false
                    }
                }
            }
        }
    }
    
    private var gpsSettingsSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("GPS Tracking Settings")
                        .font(.headline)
                    
                    Text("Configure how vehicle locations are tracked and updated.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tracking Methods")
                        .font(.headline)
                    
                    if samsaraService.isConnected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Samsara GPS")
                                    .font(.subheadline)
                                Text("Professional fleet tracking")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("Samsara GPS")
                                    .font(.subheadline)
                                Text("Not configured")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Setup") {
                                // Navigate to Samsara setup
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Device GPS")
                                .font(.subheadline)
                            Text("Use technician mobile devices")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Available")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("GPS Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingGPSSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getVehicleLocation(_ vehicle: Vehix.Vehicle) -> CLLocationCoordinate2D? {
        // Try to get location from active tracking session first
        if let session = trackingSessions.first(where: { $0.vehicleId == vehicle.id && $0.endTime == nil }),
           let lat = session.startLatitude,
           let lon = session.startLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        // If no active session, try to parse from lastKnownLocation string
        // This is a simple implementation - you might want to store coordinates directly
        if vehicle.lastKnownLocation != nil {
            // For demo purposes, generate coordinates based on vehicle ID
            // In production, you'd parse actual coordinates or use geocoding
            let hashValue = abs(vehicle.id.hashValue)
            let lat = 37.7749 + Double(hashValue % 100) / 1000.0
            let lon = -122.4194 + Double((hashValue / 100) % 100) / 1000.0
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        return nil
    }
    
    private func hasActiveGPSTracking(_ vehicle: Vehix.Vehicle) -> Bool {
        return trackingSessions.contains { session in
            session.vehicleId == vehicle.id && session.endTime == nil
        }
    }
    
    private func selectVehicle(_ vehicle: Vehix.Vehicle) {
        selectedVehicle = vehicle
        
        // Center map on selected vehicle
        if let location = getVehicleLocation(vehicle) {
            withAnimation(.easeInOut(duration: 1.0)) {
                position = .region(
                    MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }
    
    private func centerMapOnVehicles() {
        let annotations = vehicleAnnotations
        guard !annotations.isEmpty else { return }
        
        if annotations.count == 1 {
            let coordinate = annotations[0].coordinate
            position = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        } else {
            let coordinates = annotations.map { $0.coordinate }
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLon = coordinates.map { $0.longitude }.min() ?? 0
            let maxLon = coordinates.map { $0.longitude }.max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: max(0.01, (maxLat - minLat) * 1.2),
                longitudeDelta: max(0.01, (maxLon - minLon) * 1.2)
            )
            
            withAnimation(.easeInOut(duration: 1.0)) {
                position = .region(MKCoordinateRegion(center: center, span: span))
            }
        }
    }
    
    private func refreshAllLocations() {
        isRefreshingLocations = true
        
        // Update timestamp
        lastLocationUpdateTime = Date()
        
        // Refresh Samsara-tracked vehicles
        for _ in vehicles.filter({ $0.isTrackedBySamsara }) {
            // Call Samsara service to update location
            // This would be implemented based on your SamsaraService
        }
        
        // Update Apple GPS tracking for active sessions
        for _ in trackingSessions.filter({ $0.endTime == nil }) {
            // This would trigger location updates through AppleGPSTrackingManager
        }
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isRefreshingLocations = false
        }
    }
    
    private func startGPSTracking(for vehicle: Vehix.Vehicle) {
        AppleGPSTrackingManager.shared.startTracking(for: vehicle)
    }
    
    private func stopGPSTracking(for vehicle: Vehix.Vehicle) {
        AppleGPSTrackingManager.shared.stopTracking()
    }
    
    private func startTrackingAllAssigned() {
        // Start GPS tracking for all assigned vehicles
        for vehicle in vehicles {
            if assignments.contains(where: { $0.vehicleId == vehicle.id && $0.endDate == nil }) {
                if !hasActiveGPSTracking(vehicle) {
                    startGPSTracking(for: vehicle)
                }
            }
        }
    }
    
    private func openMapsNavigation(to vehicle: Vehix.Vehicle) {
        guard let location = getVehicleLocation(vehicle) else { return }
        
        let placemark = MKPlacemark(coordinate: location)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = vehicle.displayName
        
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views and Models

struct VehicleAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let vehicle: Vehix.Vehicle
    let isTracking: Bool
    let assignment: VehicleAssignment?
    let trackingSession: VehicleTrackingSession?
}

struct VehicleMapPin: View {
    let annotation: VehicleAnnotation
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : backgroundColor)
                    .frame(width: 30, height: 30)
                    .shadow(radius: isSelected ? 4 : 2)
                
                Image(systemName: "car.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }
            
            // Pin point
            Triangle()
                .fill(isSelected ? Color.blue : backgroundColor)
                .frame(width: 10, height: 6)
                .offset(y: -1)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    private var backgroundColor: Color {
        if annotation.isTracking {
            return .green
        } else if annotation.assignment != nil {
            return .orange
        } else {
            return .gray
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct VehicleFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct StatBadge: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct LocationStats {
    let totalVehicles: Int
    let tracked: Int
    let activeGPS: Int
    let assigned: Int
}

struct VehicleLocationDetailsPanel: View {
    let vehicle: Vehix.Vehicle
    let assignment: VehicleAssignment?
    let onStartTracking: () -> Void
    let onStopTracking: () -> Void
    let onNavigate: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName)
                        .font(.headline)
                    
                    if let assignment = assignment,
                       let user = assignment.user {
                        Text("Assigned to: \(user.fullName ?? user.email)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Unassigned")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
            }
            
            // Location info
            if let location = vehicle.lastKnownLocation {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                        Text("Current Location")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(location)
                        .font(.subheadline)
                    
                    if let updateDate = vehicle.lastLocationUpdateDate {
                        Text("Updated: \(updateDate, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onNavigate) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Navigate")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: onStartTracking) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start GPS")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
    }
}

// Location Manager for current device location
class VehicleLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// Helper extension for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Extension removed - handled inline

#Preview {
    VehicleLocationMapView()
        .environmentObject(AppAuthService())
        .environmentObject(SamsaraService())
        .modelContainer(for: [Vehix.Vehicle.self, VehicleTrackingSession.self, VehicleAssignment.self], inMemory: true)
} 