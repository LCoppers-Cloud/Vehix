import SwiftUI
import SwiftData

/// Displays a single pending inventory transfer request in a list row.
struct PendingTransferRowView: View {
    
    /// The pending transfer data to display.
    let transfer: PendingTransfer
    
    /// Closure to execute when the 'Accept' button is tapped.
    var onAccept: () -> Void
    
    /// Closure to execute when the 'Reject' button is tapped.
    var onReject: () -> Void
    
    var body: some View {
        HStack {
            // Content
            Text("Transfer Details")
        }
    }
}

// MARK: - Preview

#Preview {
    // Create a simple in-memory container
    let container = try! ModelContainer(
        for: PendingTransfer.self,
        AppInventoryItem.self,
        AppWarehouse.self,
        AppVehicle.self,
        AuthUser.self,
        StockLocationItem.self,
        VehicleAssignment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    // Set up preview data
    let modelContext = container.mainContext
    
    // Create mock data
    let item = AppInventoryItem(name: "Preview Bolt", partNumber: "B-123", category: "Hardware")
    let warehouse = AppWarehouse(name: "Main WH", location: "Building A")
    let vehicle = AppVehicle(make: "Ford", model: "Transit", year: 2022)
    let manager = AuthUser(id: "manager1", fullName: "Manager Bob", role: .admin)
    let tech = AuthUser(id: "tech1", fullName: "Tech Alice", role: .technician)
    
    modelContext.insert(item)
    modelContext.insert(warehouse)
    modelContext.insert(vehicle)
    modelContext.insert(manager)
    modelContext.insert(tech)
    
    let transfer = PendingTransfer(
        id: UUID().uuidString,
        requestedAt: Date().addingTimeInterval(-3600), // 1 hour ago
        status: "pending",
        quantity: 10,
        notes: "Need these ASAP for Job 123.",
        inventoryItem: item,
        fromWarehouse: warehouse,
        toVehicle: vehicle,
        requestingManager: manager,
        assignedTechnician: tech
    )
    
    modelContext.insert(transfer)
    
    // Return the view with model context
    return List {
        PendingTransferRowView(
            transfer: transfer, 
            onAccept: { print("Accept") }, 
            onReject: { print("Reject") }
        )
    }
    .modelContainer(container)
} 