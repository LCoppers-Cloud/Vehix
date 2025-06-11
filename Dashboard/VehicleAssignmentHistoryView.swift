import SwiftUI
import SwiftData

struct VehicleAssignmentHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    let vehicle: AppVehicle
    let assignments: [VehicleAssignment]
    
    @State private var showingReassignSheet = false
    @State private var showingEndAssignmentAlert = false
    @State private var assignmentToEnd: VehicleAssignment?
    
    // Query for all users to show assignment options
    @Query private var allUsers: [AuthUser]
    
    private var currentAssignment: VehicleAssignment? {
        assignments.first { $0.endDate == nil }
    }
    
    private var pastAssignments: [VehicleAssignment] {
        assignments.filter { $0.endDate != nil }.sorted { $0.startDate > $1.startDate }
    }
    
    private var assignmentStats: (total: Int, avgDuration: Int, currentDuration: Int?) {
        let total = assignments.count
        
        let completedAssignments = pastAssignments
        let avgDuration = completedAssignments.isEmpty ? 0 : 
            completedAssignments.reduce(0) { sum, assignment in
                let duration = Calendar.current.dateComponents([.day], 
                    from: assignment.startDate, 
                    to: assignment.endDate ?? Date()).day ?? 0
                return sum + duration
            } / completedAssignments.count
        
        let currentDuration = currentAssignment.map { assignment in
            Calendar.current.dateComponents([.day], 
                from: assignment.startDate, 
                to: Date()).day ?? 0
        }
        
        return (total, avgDuration, currentDuration)
    }
    
    var body: some View {
        NavigationView {
            SwiftUI.ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // Vehicle Header
                    vehicleHeaderSection
                    
                    // Assignment Stats
                    assignmentStatsSection
                    
                    // Current Assignment
                    if let current = currentAssignment {
                        currentAssignmentSection(current)
                    }
                    
                    // Assignment History
                    if !pastAssignments.isEmpty {
                        assignmentHistorySection
                    }
                    
                    // Empty state
                    if assignments.isEmpty {
                        emptyStateSection
                    }
                }
                .padding()
            }
            .navigationTitle("Assignment History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                customNavigationHeader
            }
        }
        .sheet(isPresented: $showingReassignSheet) {
            ReassignVehicleView(
                vehicle: vehicle,
                currentAssignment: currentAssignment,
                technicians: allUsers.filter { $0.userRole == .technician }
            )
        }
        .alert("End Assignment", isPresented: $showingEndAssignmentAlert) {
            Button("Cancel", role: .cancel) {
                assignmentToEnd = nil
            }
            Button("End Assignment") {
                endAssignment()
            }
        } message: {
            if assignmentToEnd != nil {
                Text("Are you sure you want to end this vehicle assignment?")
            }
        }
    }
    
    // MARK: - Vehicle Header Section
    private var vehicleHeaderSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vehicle.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("VIN: \(vehicle.vin)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let plate = vehicle.licensePlate {
                        Text("License: \(plate)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "car.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("\(vehicle.mileage) mi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Assignment Stats Section
    private var assignmentStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assignment Overview")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Total Assignments",
                    value: "\(assignmentStats.total)",
                    subtitle: "All time",
                    icon: "person.2.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Avg Duration",
                    value: "\(assignmentStats.avgDuration)",
                    subtitle: "Days",
                    icon: "clock.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Current Duration",
                    value: assignmentStats.currentDuration.map { "\($0)" } ?? "N/A",
                    subtitle: "Days",
                    icon: "timer.circle.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Current Assignment Section
    private func currentAssignmentSection(_ assignment: VehicleAssignment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Assignment")
                    .font(.headline)
                
                Spacer()
                
                if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .premium {
                    Button("End Assignment") {
                        assignmentToEnd = assignment
                        showingEndAssignmentAlert = true
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            AssignmentCard(
                assignment: assignment,
                user: allUsers.first { $0.id == assignment.userId },
                isActive: true
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Assignment History Section
    private var assignmentHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assignment History")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(pastAssignments, id: \.id) { assignment in
                    AssignmentCard(
                        assignment: assignment,
                        user: allUsers.first { $0.id == assignment.userId },
                        isActive: false
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Empty State Section
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Assignment History")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This vehicle hasn't been assigned to any technicians yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .premium {
                Button("Assign Vehicle") {
                    showingReassignSheet = true
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Custom Navigation Header
    private var customNavigationHeader: some View {
        HStack {
            Button("Close") {
                dismiss()
            }
            .foregroundColor(.blue)
            
            Spacer()
            
            Text("Assignment History")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .premium {
                Button("Reassign") {
                    showingReassignSheet = true
                }
                .disabled(currentAssignment == nil)
                .foregroundColor(currentAssignment != nil ? .blue : .gray)
            } else {
                // Empty space to maintain layout balance
                Button("") { }
                    .disabled(true)
                    .opacity(0)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - Helper Functions
    private func endAssignment() {
        guard let assignment = assignmentToEnd else { return }
        
        assignment.endDate = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Error ending assignment: \(error)")
        }
        
        assignmentToEnd = nil
    }
}

// MARK: - Supporting Views

#Preview {
    VehicleAssignmentHistoryView(
        vehicle: AppVehicle(
            make: "Ford",
            model: "Transit",
            year: 2022,
            vin: "1234567890",
            licensePlate: "ABC123",
            mileage: 50000
        ),
        assignments: []
    )
    .environmentObject(AppAuthService())
    .modelContainer(for: [VehicleAssignment.self, AuthUser.self], inMemory: true)
} 
