import SwiftUI
import SwiftData

/// A view to display a log of processed (accepted or rejected) inventory transfers.
struct TransferLogView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService // For role-based filtering
    
    // Configuration
    var targetUser: AuthUser? = nil // If provided, filters by this technician
    var title: String = "Transfer Log"
    var itemLimit: Int? = nil // Optional limit for number of items to show

    @State private var processedTransfers: [PendingTransfer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            if isLoading {
                ProgressView("Loading log...")
                    .padding()
            } else if let error = errorMessage {
                Text("Error: \(error)").foregroundColor(.red).padding()
            } else if processedTransfers.isEmpty {
                Text("No transfer records found.").foregroundColor(.secondary).padding()
            } else {
                List {
                    ForEach(processedTransfers) { transfer in
                        TransferLogDetailRow(transfer: transfer)
                    }
                }
                .frame(height: calculateListHeight()) // Dynamic height or fixed
                .listStyle(.plain)
            }
        }
        .onAppear(perform: loadProcessedTransfers)
        // Add .refreshable if this view might appear in a context where it's the primary scroll view
    }
    
    private func calculateListHeight() -> CGFloat {
        // Basic calculation, adjust as needed for your row height and desired max height
        let rowHeight: CGFloat = 90 // Approximate height of TransferLogDetailRow
        let maxHeight: CGFloat = 500 // Max height for the list
        let calculatedHeight = CGFloat(processedTransfers.count) * rowHeight
        return min(calculatedHeight, maxHeight)
    }

    private func loadProcessedTransfers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            var predicates: [Predicate<PendingTransfer>] = [
                #Predicate<PendingTransfer> { $0.status == "accepted" || $0.status == "rejected" }
            ]
            
            // If a targetUser (technician) is specified, filter by their ID
            if let user = targetUser {
                guard let userId = user.id as String? else { // Ensure targetUser has an ID
                     await MainActor.run {
                        errorMessage = "Target user ID is missing."
                        isLoading = false
                    }
                    return
                }
                predicates.append(#Predicate<PendingTransfer> { $0.assignedTechnician?.id == userId })
            }
            
            // Fixed approach: Use specific predicate or combine manually
            var finalPredicate: Predicate<PendingTransfer>
            if predicates.count > 1 {
                finalPredicate = #Predicate<PendingTransfer> { transfer in
                    predicates[0].evaluate(transfer) && predicates[1].evaluate(transfer)
                }
            } else {
                finalPredicate = predicates[0]
            }
                
            let sortDescriptor = SortDescriptor<PendingTransfer>(\.processedAt, order: .reverse) // Show most recent first
            
            var fetchDescriptor = FetchDescriptor<PendingTransfer>(predicate: finalPredicate, sortBy: [sortDescriptor])
            
            if let limit = itemLimit {
                fetchDescriptor.fetchLimit = limit
            }
            
            do {
                let transfers = try modelContext.fetch(fetchDescriptor)
                await MainActor.run {
                    processedTransfers = transfers
                    isLoading = false
                }
            } catch {
                print("Failed to fetch processed transfers: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load transfer log."
                    isLoading = false
                }
            }
        }
    }
}

/// A row view to display details of a single processed transfer in the log.
struct TransferLogDetailRow: View {
    let transfer: PendingTransfer
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transfer.inventoryItem?.name ?? "Unknown Item")
                    .fontWeight(.semibold)
                Text("Qty: \(transfer.quantity) | From: \(transfer.fromWarehouse?.name ?? "N/A") | To: \(transfer.toVehicle?.displayName ?? "N/A")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Manager: \(transfer.requestingManager?.fullName ?? "N/A") | Tech: \(transfer.assignedTechnician?.fullName ?? "N/A")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let processedDate = transfer.processedAt {
                    Text("Processed: \(processedDate.formatted(date: .numeric, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else {
                    Text("Requested: \(transfer.requestedAt.formatted(date: .numeric, time: .shortened))") // Fallback for safety
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                if let reason = transfer.rejectionReason, !reason.isEmpty, transfer.status == "rejected" {
                    Text("Reason: \(reason)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            Spacer() // Pushes content to the left
        }
        .padding(.vertical, 6)
    }
    
    private var statusIcon: String {
        switch transfer.status {
        case "accepted":
            return "checkmark.circle.fill"
        case "rejected":
            return "xmark.octagon.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch transfer.status {
        case "accepted":
            return .green
        case "rejected":
            return .red
        default:
            return .gray
        }
    }
}


// MARK: - Preview

#Preview { 
    // Create a consistent model container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: PendingTransfer.self, AppInventoryItem.self, AppWarehouse.self, 
        AppVehicle.self, AuthUser.self, StockLocationItem.self, VehicleAssignment.self,
        configurations: config
    )
    
    // Set up the preview data
    let modelContext = container.mainContext
    
    // Mock Data
    let item1 = AppInventoryItem(name: "Preview Bolt", partNumber: "B-123")
    let item2 = AppInventoryItem(name: "Preview Nut", partNumber: "N-456")
    let warehouse = AppWarehouse(name: "Central WH", location: "Preview Location")
    let vehicle1 = AppVehicle(make: "Ford", model: "Transit", licensePlate: "V1")
    let vehicle2 = AppVehicle(make: "Chevy", model: "Express", licensePlate: "V2")
    let manager = AuthUser(id: "manager-log", email: "manager@example.com", fullName: "Log Manager", role: .admin)
    let tech1 = AuthUser(id: "tech-log1", email: "tech1@example.com", fullName: "Log Tech One", role: .technician)
    let tech2 = AuthUser(id: "tech-log2", email: "tech2@example.com", fullName: "Log Tech Two", role: .technician)

    modelContext.insert(item1)
    modelContext.insert(item2)
    modelContext.insert(warehouse)
    modelContext.insert(vehicle1)
    modelContext.insert(vehicle2)
    modelContext.insert(manager)
    modelContext.insert(tech1)
    modelContext.insert(tech2)

    let acceptedTransfer = PendingTransfer(
        requestedAt: Date().addingTimeInterval(-3600*24*2), // 2 days ago
        status: "accepted", 
        quantity: 10, 
        inventoryItem: item1, 
        fromWarehouse: warehouse, 
        toVehicle: vehicle1, 
        requestingManager: manager, 
        assignedTechnician: tech1,
        processedAt: Date().addingTimeInterval(-3600*24*2 + 600) // processed 10 mins later
    )
    let rejectedTransfer = PendingTransfer(
        requestedAt: Date().addingTimeInterval(-3600*24), // 1 day ago
        status: "rejected", 
        quantity: 5, 
        notes: "Urgent",
        inventoryItem: item2, 
        fromWarehouse: warehouse, 
        toVehicle: vehicle2, 
        requestingManager: manager, 
        assignedTechnician: tech2,
        processedAt: Date().addingTimeInterval(-3600*24 + 300),
        rejectionReason: "No longer needed for the job."
    )
    let acceptedTransferTech2 = PendingTransfer(
        requestedAt: Date().addingTimeInterval(-3600*12), // 12 hours ago
        status: "accepted", 
        quantity: 8, 
        inventoryItem: item1, 
        fromWarehouse: warehouse, 
        toVehicle: vehicle2, // Tech Two's vehicle
        requestingManager: manager, 
        assignedTechnician: tech2,
        processedAt: Date().addingTimeInterval(-3600*12 + 200)
    )

    modelContext.insert(acceptedTransfer)
    modelContext.insert(rejectedTransfer)
    modelContext.insert(acceptedTransferTech2)
    
    let auth = AppAuthService()
    auth.currentUser = manager // Preview as manager by default

    // Return a single ScrollView to ensure consistent view type
    return ScrollView { 
        VStack(spacing: 20) {
            TransferLogView(itemLimit: 5) // Manager sees all, limited to 5 for preview
                .environmentObject(auth)
            
            Divider().padding()
            
            Text("Tech One's Log").font(.title2).padding(.leading)
            TransferLogView(targetUser: tech1, title: "My Recent Transfers", itemLimit: 3)
                .environmentObject(auth) // Auth still needed for context
        }
        .modelContainer(container)
    }
} 