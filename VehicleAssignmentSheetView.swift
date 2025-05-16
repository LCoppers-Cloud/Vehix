import SwiftUI
import SwiftData

struct VehicleAssignmentSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AppAuthService // For manager info if needed
    
    let staffMember: AuthUser
    // Pass the current assignment to know if we are changing an existing one
    // or assigning for the first time. This also helps in pre-selecting.
    let currentAssignment: VehicleAssignment? 

    @State private var availableVehicles: [AppVehicle] = []
    @State private var selectedVehicleId: String? = nil
    @State private var assignmentStartDate: Date = Date() // Default to now
    
    @State private var isLoadingVehicles = false
    @State private var errorMessage: String?
    @State private var showConfirmationAlert = false
    @State private var confirmationMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Staff Member") {
                    LabeledContent("Name:", value: staffMember.fullName ?? "N/A")
                    LabeledContent("Email:", value: staffMember.email)
                }
                
                Section("Select Vehicle") {
                    if isLoadingVehicles {
                        ProgressView()
                    } else if availableVehicles.isEmpty {
                        Text("No vehicles available for assignment or all are currently assigned.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Vehicle*", selection: $selectedVehicleId) {
                            Text("Select a Vehicle").tag(String?.none) // Placeholder
                            ForEach(availableVehicles) { vehicle in
                                Text(vehicle.displayName).tag(vehicle.id as String?)
                            }
                        }
                    }
                }
                
                Section("Assignment Start Date") {
                    DatePicker("Start Date*", selection: $assignmentStartDate, displayedComponents: .date)
                }
                
                if let error = errorMessage {
                    Section {
                        Text("Error: \(error)").foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(currentAssignment?.vehicle != nil ? "Change Assignment" : "Assign Vehicle")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save Assignment") {
                        validateAndSaveAssignment()
                    }
                    .disabled(selectedVehicleId == nil || isLoadingVehicles)
                }
            }
            .onAppear(perform: loadInitialData)
            .alert("Confirm Assignment", isPresented: $showConfirmationAlert) {
                Button("OK") { dismiss() } // Dismiss after confirmation
            } message: {
                Text(confirmationMessage)
            }
        }
    }
    
    private func loadInitialData() {
        loadAvailableVehicles()
        // If changing an assignment, pre-select the current vehicle and its start date
        if let assignment = currentAssignment,
           let vehicle = assignment.vehicle {
            selectedVehicleId = vehicle.id
            assignmentStartDate = assignment.startDate
        } else {
            // Default to today if it's a new assignment
            assignmentStartDate = Date()
        }
    }

    private func loadAvailableVehicles() {
        isLoadingVehicles = true
        errorMessage = nil
        Task {
            do {
                // Fetch all vehicles initially. 
                // More complex logic might be needed to show only truly "available" ones
                // (e.g., not actively assigned or based on some other status)
                let descriptor = FetchDescriptor<AppVehicle>(sortBy: [SortDescriptor(\.make), SortDescriptor(\.model)])
                let allVehicles = try modelContext.fetch(descriptor)
                
                // For now, we list all vehicles. A vehicle can be reassigned.
                // If a vehicle is selected that is currently assigned to someone else,
                // that other assignment will be ended by the saveAssignment logic.
                await MainActor.run {
                    availableVehicles = allVehicles
                    isLoadingVehicles = false
                }
            } catch {
                print("Failed to load vehicles: \(error)")
                await MainActor.run {
                    errorMessage = "Could not load vehicle list."
                    isLoadingVehicles = false
                }
            }
        }
    }
    
    private func validateAndSaveAssignment() {
        guard let vehicleId = selectedVehicleId else {
            errorMessage = "No vehicle selected."
            return
        }
        
        // Check if staffId is empty
        guard !staffMember.id.isEmpty else {
            errorMessage = "Staff member ID is missing."
            return
        }
        
        let staffId = staffMember.id  // Already non-optional, no need to force unwrap
        
        // Check if the selected vehicle and start date are the same as the current assignment (if any)
        if let current = currentAssignment,
           let currentVehicleId = current.vehicle?.id,
           currentVehicleId == vehicleId,
           Calendar.current.isDate(current.startDate, inSameDayAs: assignmentStartDate) {
            confirmationMessage = "No changes made to the current assignment."
            showConfirmationAlert = true
            return
        }

        saveAssignment(staffId: staffId, vehicleId: vehicleId)
    }

    private func saveAssignment(staffId: String, vehicleId: String) {
        let now = Date()
        
        // --- 1. End current active assignment for THIS staff member (if any) ---
        // This handles changing a vehicle or re-assigning the same vehicle with a new start date.
        let staffAssignmentPredicate = #Predicate<VehicleAssignment> { asgn in
            asgn.userId == staffId && (asgn.endDate == nil || asgn.endDate! > now)
        }
        do {
            let currentStaffAssignments = try modelContext.fetch(FetchDescriptor(predicate: staffAssignmentPredicate))
            for assignmentToUpdate in currentStaffAssignments {
                // Don't end it if it's the exact same assignment we are trying to save 
                // (unless start date is different, handled by new assignment creation)
                if assignmentToUpdate.id != currentAssignment?.id || !Calendar.current.isDate(assignmentToUpdate.startDate, inSameDayAs: assignmentStartDate) {
                    assignmentToUpdate.endDate = now // End it now
                    print("Ended previous assignment \(assignmentToUpdate.id) for staff \(staffId)")
                }
            }
        } catch {
            errorMessage = "Failed to update staff member's previous assignments. \(error.localizedDescription)"
            return
        }

        // --- 2. End current active assignment for the SELECTED VEHICLE (if assigned to someone else) ---
        let vehicleAssignmentPredicate = #Predicate<VehicleAssignment> { asgn in
            asgn.vehicleId == vehicleId && 
            asgn.userId != staffId && // Important: only if assigned to a DIFFERENT user
            (asgn.endDate == nil || asgn.endDate! > now)
        }
        do {
            let currentVehicleAssignments = try modelContext.fetch(FetchDescriptor(predicate: vehicleAssignmentPredicate))
            for assignmentToUpdate in currentVehicleAssignments {
                assignmentToUpdate.endDate = now // End it now
                print("Ended previous assignment \(assignmentToUpdate.id) for vehicle \(vehicleId) (assigned to another tech)")
            }
        } catch {
            errorMessage = "Failed to update selected vehicle's previous assignments. \(error.localizedDescription)"
            // Continue, as the primary goal is to assign to the current staff
        }
        
        // --- 3. Create the new assignment ---
        guard let targetVehicle = availableVehicles.first(where: { $0.id == vehicleId }) else {
            errorMessage = "Selected vehicle not found."
            return
        }
        
        let newAssignment = VehicleAssignment(
            id: UUID().uuidString,
            vehicleId: vehicleId,
            userId: staffId,
            startDate: assignmentStartDate,
            endDate: nil, // Active assignment
            vehicle: targetVehicle,
            user: staffMember
        )
        modelContext.insert(newAssignment)
        print("Created new assignment for staff \(staffId) to vehicle \(vehicleId) starting \(assignmentStartDate)")
        
        // --- 4. Save context ---
        do {
            try modelContext.save()
            confirmationMessage = "Vehicle successfully assigned to \(staffMember.fullName ?? "staff") starting \(assignmentStartDate.formatted(date: .long, time: .omitted))."
            showConfirmationAlert = true
            // Parent view (StaffDetailView) should reload currentAssignment on dismiss or .onAppear
        } catch {
            errorMessage = "Failed to save new assignment: \(error.localizedDescription)"
            // TODO: More robust rollback for in-memory changes if needed, though SwiftData handles some of this.
            // For now, delete the newAssignment if save fails
            modelContext.delete(newAssignment)
            print("Error saving assignment, deleted in-memory newAssignment object.")
        }
    }
}

#Preview {
    VehicleAssignmentSheetPreview()
}

// Separate preview struct to fix the opaque return type issues
struct VehicleAssignmentSheetPreview: View {
    var body: some View {
        let container = try? ModelContainer(
            for: AuthUser.self, AppVehicle.self, VehicleAssignment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        Group {
            if let container = container {
                let previewContent = PreparePreviewContent(container: container)
                
                VehicleAssignmentSheetView(staffMember: previewContent.staff1, currentAssignment: previewContent.currentAsgn)
                    .modelContainer(container)
                    .environmentObject(previewContent.auth)
            } else {
                Text("Failed to create preview container")
            }
        }
    }
    
    // Helper struct to prepare data for preview
    private struct PreparePreviewContent {
        let staff1: AuthUser
        let currentAsgn: VehicleAssignment
        let auth = AppAuthService()
        
        @MainActor
        init(container: ModelContainer) {
            let modelContext = container.mainContext
            
            // Create test users
            staff1 = AuthUser(
                id: "tech-assign", 
                email: "assign@example.com",
                fullName: "Tech Assignee", 
                role: .technician
            )
            let staff2 = AuthUser(
                id: "other-tech", 
                email: "other@example.com",
                fullName: "Other Tech", 
                role: .technician
            )
            
            // Create test vehicles
            let vehicle1 = AppVehicle(id: "v1", make: "Ford", model: "Transit", year: 2023, licensePlate: "ASSIGN1")
            let vehicle2 = AppVehicle(id: "v2", make: "Chevy", model: "Express", year: 2022, licensePlate: "ASSIGN2")
            let vehicle3 = AppVehicle(id: "v3", make: "Dodge", model: "ProMaster", year: 2023, licensePlate: "ASSIGN3")
            
            // Create assignments
            currentAsgn = VehicleAssignment(
                id: "asgn1",
                vehicleId: vehicle1.id,
                userId: staff1.id,
                startDate: Date().addingTimeInterval(-86400 * 10),
                endDate: nil,
                vehicle: vehicle1,
                user: staff1
            )
            let otherAsgn = VehicleAssignment(
                id: "asgn2",
                vehicleId: vehicle2.id,
                userId: staff2.id,
                startDate: Date().addingTimeInterval(-86400 * 5),
                endDate: nil,
                vehicle: vehicle2,
                user: staff2
            )
            
            // Insert data into model context
            modelContext.insert(staff1)
            modelContext.insert(staff2)
            modelContext.insert(vehicle1)
            modelContext.insert(vehicle2)
            modelContext.insert(vehicle3)
            modelContext.insert(currentAsgn)
            modelContext.insert(otherAsgn)
        }
    }
} 