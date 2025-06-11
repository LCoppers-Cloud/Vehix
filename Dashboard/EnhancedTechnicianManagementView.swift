import SwiftUI
import SwiftData
import MapKit

struct EnhancedTechnicianManagementView: View {
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var technicians: [UserAccount] = []
    @State private var vehicles: [Vehix.Vehicle] = []
    @State private var vehicleAssignments: [VehicleAssignment] = []
    @State private var isLoading = true
    @State private var selectedTechnician: UserAccount?
    @State private var showingAssignVehicle = false
    @State private var showingTechnicianDetail: UserAccount?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading technicians...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    technicianListView
                }
            }
            .navigationTitle("Technician Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAssignVehicle) {
            if let technician = selectedTechnician {
                VehicleAssignmentView(
                    technician: technician,
                    availableVehicles: availableVehicles,
                    onAssignmentComplete: loadData
                )
            }
        }
        .sheet(item: $showingTechnicianDetail) { technician in
            TechnicianDetailView(technician: technician)
                .environmentObject(authService)
        }
        .onAppear {
            loadData()
        }
    }
    
    private var technicianListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(technicians, id: \.userID) { technician in
                    TechnicianCardView(
                        technician: technician,
                        assignedVehicles: getAssignedVehicles(for: technician),
                        onAssignVehicle: {
                            selectedTechnician = technician
                            showingAssignVehicle = true
                        },
                        onViewDetails: {
                            showingTechnicianDetail = technician
                        }
                    )
                }
                
                if technicians.isEmpty {
                    EmptyTechniciansView()
                }
            }
            .padding()
        }
    }
    
    private var availableVehicles: [Vehix.Vehicle] {
        vehicles.filter { vehicle in
            !vehicleAssignments.contains(where: { assignment in
                assignment.vehicleId == vehicle.id && assignment.endDate == nil
            })
        }
    }
    
    private func getAssignedVehicles(for technician: UserAccount) -> [Vehix.Vehicle] {
        let assignedVehicleIDs = vehicleAssignments
            .filter { $0.userId == technician.userID.uuidString && $0.endDate == nil }
            .map { $0.vehicleId }
        
        return vehicles.filter { assignedVehicleIDs.contains($0.id) }
    }
    
    private func loadData() {
        isLoading = true
        
        Task {
            do {
                // Load technicians
                let userDescriptor = FetchDescriptor<UserAccount>()
                let allUsers = try modelContext.fetch(userDescriptor)
                let loadedTechnicians = allUsers.filter { $0.accountType == .technician }
                
                // Load vehicles
                let vehicleDescriptor = FetchDescriptor<Vehix.Vehicle>()
                let loadedVehicles = try modelContext.fetch(vehicleDescriptor)
                
                // Load vehicle assignments
                let assignmentDescriptor = FetchDescriptor<VehicleAssignment>()
                let loadedAssignments = try modelContext.fetch(assignmentDescriptor)
                
                await MainActor.run {
                    self.technicians = loadedTechnicians
                    self.vehicles = loadedVehicles
                    self.vehicleAssignments = loadedAssignments
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Error loading data: \(error)")
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Technician Card View

struct TechnicianCardView: View {
    let technician: UserAccount
    let assignedVehicles: [Vehix.Vehicle]
    let onAssignVehicle: () -> Void
    let onViewDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(technician.fullName)
                        .font(.headline.bold())
                        .foregroundColor(Color.vehixText)
                    
                    Text(technician.email)
                        .font(.subheadline)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(
                        text: technician.isActive ? "Active" : "Inactive",
                        color: technician.isActive ? Color.vehixGreen : Color.vehixOrange
                    )
                    
                    if let lastLogin = technician.lastLoginAt {
                        Text("Last seen \(timeAgo(lastLogin))")
                            .font(.caption)
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                }
            }
            
            // Vehicle assignments
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "car.2.fill")
                        .foregroundColor(Color.vehixBlue)
                    
                    Text("Assigned Vehicles (\(assignedVehicles.count))")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.vehixText)
                    
                    Spacer()
                    
                    Button("Assign Vehicle") {
                        onAssignVehicle()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                if assignedVehicles.isEmpty {
                    Text("No vehicles assigned")
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                        .padding(.leading, 24)
                } else {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(assignedVehicles, id: \.id) { vehicle in
                            VehicleAssignmentRow(vehicle: vehicle)
                        }
                    }
                    .padding(.leading, 24)
                }
            }
            
            // Actions
            HStack {
                Button("View Details") {
                    onViewDetails()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Track Location") {
                    // This would open GPS tracking for the technician
                }
                .buttonStyle(.borderedProminent)
                .disabled(assignedVehicles.isEmpty)
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Vehicle Assignment Row

struct VehicleAssignmentRow: View {
    let vehicle: Vehix.Vehicle
    
    var body: some View {
        HStack {
            Image(systemName: "car.fill")
                .foregroundColor(Color.vehixGreen)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                    .font(.caption.bold())
                    .foregroundColor(Color.vehixText)
                
                Text("VIN: \(String(vehicle.vin.suffix(6)))")
                    .font(.caption2)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f mi", vehicle.mileage))
                    .font(.caption)
                    .foregroundColor(Color.vehixText)
                
                Text("Active")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.vehixGreen.opacity(0.2))
                    .foregroundColor(Color.vehixGreen)
                    .cornerRadius(4)
            }
        }
    }
    
}

// MARK: - Empty Technicians View

struct EmptyTechniciansView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(Color.vehixSecondaryText)
            
            Text("No Technicians Found")
                .font(.title2.bold())
                .foregroundColor(Color.vehixText)
            
            Text("Invite technicians through User Management to get started with vehicle assignments and GPS tracking.")
                .font(.body)
                .foregroundColor(Color.vehixSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Vehicle Assignment View

struct VehicleAssignmentView: View {
    let technician: UserAccount
    let availableVehicles: [Vehix.Vehicle]
    let onAssignmentComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedVehicle: Vehix.Vehicle?
    @State private var assignmentNotes: String = ""
    @State private var isAssigning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assign Vehicle")
                        .font(.title2.bold())
                        .foregroundColor(Color.vehixText)
                    
                    Text("Assign a vehicle to \(technician.fullName)")
                        .font(.subheadline)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Vehicle selection
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availableVehicles, id: \.id) { vehicle in
                            TechnicianVehicleSelectionRow(
                                vehicle: vehicle,
                                isSelected: selectedVehicle?.id == vehicle.id
                            ) {
                                selectedVehicle = vehicle
                            }
                        }
                        
                        if availableVehicles.isEmpty {
                            Text("No vehicles available for assignment")
                                .font(.body)
                                .foregroundColor(Color.vehixSecondaryText)
                                .padding()
                        }
                    }
                    .padding()
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assignment Notes (Optional)")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.vehixText)
                    
                    TextField("Add notes about this assignment...", text: $assignmentNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                .padding()
                
                Spacer()
                
                // Action buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Assign Vehicle") {
                        assignVehicle()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedVehicle == nil || isAssigning)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func assignVehicle() {
        guard let vehicle = selectedVehicle else { return }
        
        isAssigning = true
        
        let assignment = VehicleAssignment(
            vehicleId: vehicle.id,
            userId: technician.userID.uuidString,
            startDate: Date()
        )
        
        modelContext.insert(assignment)
        
        do {
            try modelContext.save()
            onAssignmentComplete()
            dismiss()
        } catch {
            print("Error saving assignment: \(error)")
        }
        
        isAssigning = false
    }
}

// MARK: - Technician Vehicle Selection Row

struct TechnicianVehicleSelectionRow: View {
    let vehicle: Vehix.Vehicle
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                        .font(.headline)
                        .foregroundColor(Color.vehixText)
                    
                    Text("VIN: \(vehicle.vin)")
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                    
                    Text(String(format: "%.0f miles", vehicle.mileage))
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color.vehixGreen : Color.vehixSecondaryText)
                    .font(.title2)
            }
            .padding()
            .background(isSelected ? Color.vehixGreen.opacity(0.1) : Color.vehixSecondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.vehixGreen : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Technician Detail View

struct TechnicianDetailView: View {
    let technician: UserAccount
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Profile section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profile Information")
                            .font(.headline.bold())
                            .foregroundColor(Color.vehixBlue)
                        
                        VStack(spacing: 8) {
                            TechnicianDetailRow(title: "Full Name", value: technician.fullName)
                            TechnicianDetailRow(title: "Email", value: technician.email)
                            TechnicianDetailRow(title: "Account Type", value: technician.accountType.rawValue)
                            TechnicianDetailRow(title: "Status", value: technician.isActive ? "Active" : "Inactive")
                            
                            if let lastLogin = technician.lastLoginAt {
                                TechnicianDetailRow(title: "Last Login", value: formatDate(lastLogin))
                            }
                            
                            TechnicianDetailRow(title: "Created", value: formatDate(technician.createdAt))
                        }
                    }
                    .padding()
                    .background(Color.vehixSecondaryBackground)
                    .cornerRadius(16)
                    
                    // Permissions section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permissions")
                            .font(.headline.bold())
                            .foregroundColor(Color.vehixBlue)
                        
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(technician.permissions, id: \.self) { permission in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.vehixGreen)
                                        .font(.caption)
                                    
                                    Text(permission.displayName)
                                        .font(.body)
                                        .foregroundColor(Color.vehixText)
                                }
                            }
                            
                            if technician.permissions.isEmpty {
                                Text("Default technician permissions")
                                    .font(.body)
                                    .foregroundColor(Color.vehixSecondaryText)
                            }
                        }
                    }
                    .padding()
                    .background(Color.vehixSecondaryBackground)
                    .cornerRadius(16)
                }
                .padding()
            }
            .navigationTitle("Technician Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Technician Detail Row

struct TechnicianDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(Color.vehixSecondaryText)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(Color.vehixText)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EnhancedTechnicianManagementView()
        .environmentObject(AppAuthService())
} 