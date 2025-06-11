import SwiftUI
import SwiftData
import MessageUI

public struct VehicleManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    
    // Data queries - using the correct model types
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.licensePlate)]) private var vehicles: [Vehix.Vehicle]
    @Query(sort: [SortDescriptor(\AuthUser.fullName)]) private var allUsers: [AuthUser]
    @Query(sort: [SortDescriptor(\VehicleAssignment.startDate, order: .reverse)]) private var assignments: [VehicleAssignment]
    
    // UI State
    @State private var selectedTab: ManagementTab = .vehicles
    @State private var searchText = ""
    @State private var showingAddVehicle = false
    @State private var showingInviteTechnician = false
    @State private var showingAssignmentSheet = false
    @State private var selectedVehicle: Vehix.Vehicle?
    @State private var selectedTechnician: AuthUser?
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: DeletableItem?
    @State private var showingReassignSheet = false
    @State private var vehicleToReassign: Vehix.Vehicle?
    
    enum ManagementTab: String, CaseIterable {
        case vehicles = "Vehicles"
        case technicians = "Technicians"
        case assignments = "Assignments"
        
        var icon: String {
            switch self {
            case .vehicles: return "car.fill"
            case .technicians: return "person.2.fill"
            case .assignments: return "arrow.triangle.swap"
            }
        }
    }
    
    enum DeletableItem {
        case vehicle(Vehix.Vehicle)
        case technician(AuthUser)
        case assignment(VehicleAssignment)
    }
    
    // Computed properties
    private var technicians: [AuthUser] {
        allUsers.filter { user in
            user.userRole == .technician || user.userRole == .dealer
        }
    }
    
    private var filteredVehicles: [Vehix.Vehicle] {
        if searchText.isEmpty {
            return vehicles
        }
        return vehicles.filter { vehicle in
            vehicle.displayName.localizedCaseInsensitiveContains(searchText) ||
            vehicle.vin.localizedCaseInsensitiveContains(searchText) ||
            (vehicle.licensePlate?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var filteredTechnicians: [AuthUser] {
        if searchText.isEmpty {
            return technicians
        }
        return technicians.filter { technician in
            (technician.fullName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            technician.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var activeAssignments: [VehicleAssignment] {
        assignments.filter { $0.endDate == nil }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                
                // Search bar
                searchBar
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    vehiclesTab
                        .tag(ManagementTab.vehicles)
                    
                    techniciansTab
                        .tag(ManagementTab.technicians)
                    
                    assignmentsTab
                        .tag(ManagementTab.assignments)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Vehicle Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingAddVehicle = true }) {
                            Label("Add Vehicle", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showingInviteTechnician = true }) {
                            Label("Invite Technician", systemImage: "person.badge.plus")
                        }
                        
                        if !vehicles.isEmpty && !technicians.isEmpty {
                            Button(action: { showingAssignmentSheet = true }) {
                                Label("Create Assignment", systemImage: "arrow.triangle.swap")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddVehicle) {
            AddVehicleForm()
                .environmentObject(authService)
                .environmentObject(storeKitManager)
        }
        .sheet(isPresented: $showingInviteTechnician) {
            InviteTechnicianView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingAssignmentSheet) {
            VehicleAssignmentCreationView(vehicles: vehicles, technicians: technicians)
                .environment(\.modelContext, modelContext)
        }
        .sheet(item: $vehicleToReassign) { vehicle in
            ReassignVehicleView(
                vehicle: vehicle, 
                currentAssignment: getCurrentAssignment(for: vehicle),
                technicians: technicians
            )
            .environment(\.modelContext, modelContext)
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteAlert, presenting: itemToDelete) { item in
            Button("Delete", role: .destructive) {
                deleteItem(item)
            }
            Button("Cancel", role: .cancel) { }
        } message: { item in
            Text(deletionMessage(for: item))
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ManagementTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? Color.vehixBlue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(.systemGray6))
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 2)
                .foregroundColor(Color.vehixBlue)
                .offset(x: tabIndicatorOffset, y: 0)
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
    }
    
    private var tabIndicatorOffset: CGFloat {
        let tabWidth = UIScreen.main.bounds.width / CGFloat(ManagementTab.allCases.count)
        let index = ManagementTab.allCases.firstIndex(of: selectedTab) ?? 0
        return (CGFloat(index) * tabWidth) - (UIScreen.main.bounds.width / 2) + (tabWidth / 2)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search \(selectedTab.rawValue.lowercased())", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Vehicles Tab
    private var vehiclesTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredVehicles.isEmpty {
                    emptyVehiclesView
                } else {
                    ForEach(filteredVehicles, id: \.id) { vehicle in
                        VehicleManagementCard(
                            vehicle: vehicle,
                            assignment: getCurrentAssignment(for: vehicle),
                            onReassign: { vehicleToReassign = vehicle },
                            onDelete: { itemToDelete = .vehicle(vehicle); showingDeleteAlert = true }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Technicians Tab
    private var techniciansTab: some View {
        technicianManagementContent()
    }
    
    // MARK: - Assignments Tab
    private var assignmentsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if activeAssignments.isEmpty {
                    emptyAssignmentsView
                } else {
                    ForEach(activeAssignments, id: \.id) { assignment in
                        AssignmentManagementCard(
                            assignment: assignment,
                            onEnd: { endAssignment(assignment) },
                            onDelete: { itemToDelete = .assignment(assignment); showingDeleteAlert = true }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State Views
    private var emptyVehiclesView: some View {
        VStack(spacing: 20) {
                                Image(systemName: "car.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.7))
            
            Text("No Vehicles")
                .font(.title2)
                .bold()
            
            Text("Add your first vehicle to get started with fleet management")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Add Vehicle") {
                showingAddVehicle = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var emptyTechniciansView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.7))
            
            Text("No Technicians")
                .font(.title2)
                .bold()
            
            Text("Invite technicians to your team to assign them to vehicles")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Invite Technician") {
                showingInviteTechnician = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var emptyAssignmentsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.7))
            
            Text("No Active Assignments")
                .font(.title2)
                .bold()
            
            Text("Create assignments to connect vehicles with technicians")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if !vehicles.isEmpty && !technicians.isEmpty {
                Button("Create Assignment") {
                    showingAssignmentSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Technician Management Tab
    
    private func technicianManagementContent() -> some View {
        VStack(spacing: 16) {
            // Header with add button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Team Members")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Manage technicians and vehicle assignments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingInviteTechnician = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Invite")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.vehixBlue)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal)
            
            if filteredTechnicians.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Technicians Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Invite your first technician to get started with vehicle assignments and inventory management.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showingInviteTechnician = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Send Invitation")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.vehixBlue)
                        .cornerRadius(25)
                    }
                    
                    // Clear existing sample data button (for cleanup)
                    Button(action: clearSampleTechnicians) {
                        Text("Clear Old Demo Data")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(filteredTechnicians, id: \.id) { technician in
                        TechnicianManagementCard(
                            technician: technician,
                            assignedVehicles: getAssignedVehicles(for: technician),
                            onDelete: {
                                itemToDelete = .technician(technician)
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showingInviteTechnician) {
            EnhancedTechnicianInviteView()
                .environmentObject(authService)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentAssignment(for vehicle: Vehix.Vehicle) -> VehicleAssignment? {
        assignments.first { $0.vehicleId == vehicle.id && $0.endDate == nil }
    }
    
    private func getAssignedVehicles(for technician: AuthUser) -> [Vehix.Vehicle] {
        let technicianAssignments = assignments.filter { 
            $0.userId == technician.id && $0.endDate == nil 
        }
        return vehicles.filter { vehicle in
            technicianAssignments.contains { $0.vehicleId == vehicle.id }
        }
    }
    
    private func endAssignment(_ assignment: VehicleAssignment) {
        assignment.endDate = Date()
        assignment.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Error ending assignment: \(error)")
        }
    }
    
    private func deleteItem(_ item: DeletableItem) {
        do {
            switch item {
            case .vehicle(let vehicle):
                // End any active assignments first
                let vehicleAssignments = assignments.filter { 
                    $0.vehicleId == vehicle.id && $0.endDate == nil 
                }
                for assignment in vehicleAssignments {
                    assignment.endDate = Date()
                }
                
                // Save assignment changes first
                try modelContext.save()
                
                // Then delete the vehicle
                modelContext.delete(vehicle)
                
            case .technician(let technician):
                // End any active assignments first
                let technicianAssignments = assignments.filter { 
                    $0.userId == technician.id && $0.endDate == nil 
                }
                for assignment in technicianAssignments {
                    assignment.endDate = Date()
                }
                
                // Save assignment changes first
                try modelContext.save()
                
                // Then delete the technician
                modelContext.delete(technician)
                
            case .assignment(let assignment):
                modelContext.delete(assignment)
            }
            
            // Final save
            try modelContext.save()
        } catch {
            print("Error deleting item: \(error)")
            // Rollback on error
            modelContext.rollback()
        }
    }
    
    private func deletionMessage(for item: DeletableItem) -> String {
        switch item {
        case .vehicle(let vehicle):
            return "Are you sure you want to delete \(vehicle.displayName)? This will also end any active assignments."
        case .technician(let technician):
            return "Are you sure you want to remove \(technician.fullName ?? technician.email)? This will end any active vehicle assignments."
        case .assignment(_):
            return "Are you sure you want to delete this assignment? This cannot be undone."
        }
    }
    
    private func clearSampleTechnicians() {
        // Remove any existing technicians that might be left over from development
        for technician in technicians {
            // End any active assignments first
            let technicianAssignments = assignments.filter { 
                $0.userId == technician.id && $0.endDate == nil 
            }
            for assignment in technicianAssignments {
                assignment.endDate = Date()
            }
            
            modelContext.delete(technician)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error clearing sample technicians: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct VehicleManagementCard: View {
    let vehicle: Vehix.Vehicle
    let assignment: VehicleAssignment?
    let onReassign: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Vehicle header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName)
                        .font(.headline)
                    Text("VIN: \(vehicle.vin)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button("Reassign", action: onReassign)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            // Assignment status
            HStack {
                Image(systemName: assignment != nil ? "person.fill" : "person.slash")
                    .foregroundColor(assignment != nil ? .green : .orange)
                
                if let assignment = assignment,
                   let technician = assignment.user {
                    Text("Assigned to \(technician.fullName ?? technician.email)")
                        .font(.subheadline)
                } else {
                    Text("Unassigned")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if assignment != nil {
                    Button("Reassign") {
                        onReassign()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
            
            // Vehicle details
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mileage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(vehicle.mileage)")
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(vehicle.vehicleType)
                        .font(.subheadline)
                        .bold()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
}

struct TechnicianManagementCard: View {
    let technician: AuthUser
    let assignedVehicles: [Vehix.Vehicle]
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Technician header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(technician.fullName ?? "Unknown")
                        .font(.headline)
                    Text(technician.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button("Send Message", action: { /* TODO: Implement messaging */ })
                    Button("Reset Password", action: { /* TODO: Implement password reset */ })
                    Button("Remove", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            // Assignment status
            HStack {
                Image(systemName: assignedVehicles.isEmpty ? "car.circle" : "car.fill")
                    .foregroundColor(assignedVehicles.isEmpty ? .orange : .green)
                
                if assignedVehicles.isEmpty {
                    Text("No vehicles assigned")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                } else {
                    Text("\(assignedVehicles.count) vehicle\(assignedVehicles.count == 1 ? "" : "s") assigned")
                        .font(.subheadline)
                }
                
                Spacer()
            }
            
            // Assigned vehicles list
            if !assignedVehicles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assigned Vehicles:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(assignedVehicles.prefix(3), id: \.id) { vehicle in
                        Text("• \(vehicle.displayName)")
                            .font(.caption)
                    }
                    
                    if assignedVehicles.count > 3 {
                        Text("• +\(assignedVehicles.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
}

struct AssignmentManagementCard: View {
    let assignment: VehicleAssignment
    let onEnd: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Assignment header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let vehicle = assignment.vehicle {
                        Text(vehicle.displayName)
                            .font(.headline)
                    } else {
                        Text("Unknown Vehicle")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let technician = assignment.user {
                        Text("Assigned to \(technician.fullName ?? technician.email)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Unknown Technician")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("End Assignment", action: onEnd)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            // Assignment details
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(assignment.startDate, style: .date)
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(durationText)
                        .font(.subheadline)
                        .bold()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var durationText: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: assignment.startDate, to: Date())
        let days = components.day ?? 0
        return "\(days) day\(days == 1 ? "" : "s")"
    }
}

#Preview {
    VehicleManagementView()
        .environmentObject(AppAuthService())
        .environmentObject(StoreKitManager())
        .modelContainer(for: [Vehix.Vehicle.self, AuthUser.self, VehicleAssignment.self], inMemory: true)
} 