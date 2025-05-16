import SwiftUI
import SwiftData

/// View for technicians to see and manage their pending inventory transfer requests.
struct PendingTransfersView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    /// Query for pending transfers assigned to the current technician.
    @State private var pendingTransfers: [PendingTransfer] = [] // Use State for manual fetch
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingRejectionAlert = false
    @State private var transferToReject: PendingTransfer? = nil
    @State private var rejectionReason: String = ""

    var body: some View {
        NavigationView { // Often embedded in another view, but good for standalone preview/testing
            VStack {
                if isLoading {
                    ProgressView("Loading transfers...")
                } else if let error = errorMessage {
                    Text("Error: \(error)").foregroundColor(.red).padding()
                } else if pendingTransfers.isEmpty {
                    Text("No pending transfers.").foregroundColor(.secondary).padding()
                } else {
                    List {
                        ForEach(pendingTransfers) { transfer in
                            PendingTransferRowView(
                                transfer: transfer,
                                onAccept: { acceptTransfer(transfer) },
                                onReject: { promptForRejectionReason(transfer) }
                            )
                        }
                    }
                }
                Spacer() // Pushes list up if content is short
            }
            .navigationTitle("Pending Transfers")
            .onAppear(perform: loadPendingTransfers)
            .refreshable { loadPendingTransfers() } // Allow pull-to-refresh
            .alert("Reject Transfer?", isPresented: $showingRejectionAlert, presenting: transferToReject) { transfer in
                TextField("Reason (Optional)", text: $rejectionReason)
                Button("Cancel", role: .cancel) { 
                    rejectionReason = ""
                    transferToReject = nil
                }
                Button("Reject Transfer", role: .destructive) {
                    rejectTransfer(transfer, reason: rejectionReason)
                    rejectionReason = ""
                    transferToReject = nil
                }
            } message: { _ in 
                 Text("Please provide an optional reason for rejecting this transfer.")
            }
        }
    }

    /// Fetches pending transfers for the current user.
    private func loadPendingTransfers() {
        guard let currentUserId = authService.currentUser?.id else {
            errorMessage = "Could not identify current user."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task { // Perform fetch in background task
            let predicate = #Predicate<PendingTransfer> { 
                $0.assignedTechnician?.id == currentUserId && $0.status == "pending"
            }
            let sortDescriptor = SortDescriptor(\PendingTransfer.requestedAt, order: .reverse)
            let fetchDescriptor = FetchDescriptor<PendingTransfer>(predicate: predicate, sortBy: [sortDescriptor])
            
            do {
                let transfers = try modelContext.fetch(fetchDescriptor)
                await MainActor.run { // Update state on main thread
                    pendingTransfers = transfers
                    isLoading = false
                }
            } catch {
                print("Failed to fetch pending transfers: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load transfers."
                    isLoading = false
                }
            }
        }
    }

    /// Initiates the rejection process by showing the alert.
    private func promptForRejectionReason(_ transfer: PendingTransfer) {
        transferToReject = transfer
        showingRejectionAlert = true
    }

    /// Handles the logic for rejecting a transfer.
    private func rejectTransfer(_ transfer: PendingTransfer, reason: String?) {
        print("Rejecting transfer: \(transfer.id) with reason: \(reason ?? "None")")
        transfer.status = "rejected"
        transfer.processedAt = Date()
        transfer.rejectionReason = reason?.isEmpty ?? true ? nil : reason
        
        // Attempt to save changes
        do {
            try modelContext.save()
            // Remove from local list immediately for UI update
            pendingTransfers.removeAll { $0.id == transfer.id }
        } catch {
            print("Failed to save rejection status: \(error)")
            errorMessage = "Failed to update transfer status."
            // TODO: Consider rolling back the status change on the transfer object if save fails
        }
    }

    /// Handles the logic for accepting a transfer.
    private func acceptTransfer(_ transfer: PendingTransfer) {
        print("Accepting transfer: \(transfer.id)")
        
        guard let sourceWarehouse = transfer.fromWarehouse,
              let targetVehicle = transfer.toVehicle,
              let itemDefinition = transfer.inventoryItem
        else {
            errorMessage = "Transfer data is incomplete."
            return
        }
        
        // --- Variables for potential rollback ---
        var originalSourceStockQuantity: Int?
        var originalTargetStockQuantity: Int?
        var targetStockWasCreated = false
        var targetStockToRevert: StockLocationItem? = nil // Store the actual target stock object if found/created
        // Store original transfer status
        let originalTransferStatus = transfer.status
        let originalTransferProcessedAt = transfer.processedAt


        // --- 1. Find and Update Source Stock (Warehouse) ---
        let sourceStock: StockLocationItem
        do {
            // Get IDs for use in predicates
            let warehouseId = sourceWarehouse.id
            let itemId = itemDefinition.id
            
            // Use string-based comparison in predicate for iOS 18+ compatibility
            let sourcePredicate = #Predicate<StockLocationItem> {
                $0.warehouse?.id == warehouseId && $0.inventoryItem?.id == itemId
            }
            var sourceFetchDescriptor = FetchDescriptor<StockLocationItem>(predicate: sourcePredicate)
            sourceFetchDescriptor.fetchLimit = 1

            guard let fetchedSourceStock = try modelContext.fetch(sourceFetchDescriptor).first else {
                errorMessage = "Source stock item not found in warehouse."
                rejectTransfer(transfer, reason: "System Error: Source item missing.")
                return
            }
            sourceStock = fetchedSourceStock
            
            guard sourceStock.quantity >= transfer.quantity else {
                errorMessage = "Insufficient quantity in warehouse (\(sourceStock.quantity) available)."
                rejectTransfer(transfer, reason: "System Error: Insufficient source quantity.")
                return
            }
            
            originalSourceStockQuantity = sourceStock.quantity // Store original value
            sourceStock.quantity -= transfer.quantity
            print("Decremented warehouse (\(sourceWarehouse.name)) stock for \(itemDefinition.name) to \(sourceStock.quantity)")

        } catch {
            print("Error fetching source stock: \(error)")
            errorMessage = "Error verifying warehouse stock."
            return
        }
        
        // --- 2. Find or Create and Update Target Stock (Vehicle) ---
        do {
            // Get IDs for use in predicates
            let vehicleId = targetVehicle.id
            let itemId = itemDefinition.id
            
            // Use string-based comparison in predicate for iOS 18+ compatibility
            let targetPredicate = #Predicate<StockLocationItem> {
                $0.vehicle?.id == vehicleId && $0.inventoryItem?.id == itemId
            }
            var targetFetchDescriptor = FetchDescriptor<StockLocationItem>(predicate: targetPredicate)
            targetFetchDescriptor.fetchLimit = 1

            if let fetchedTargetStock = try modelContext.fetch(targetFetchDescriptor).first {
                targetStockToRevert = fetchedTargetStock
                originalTargetStockQuantity = fetchedTargetStock.quantity // Store original value
                fetchedTargetStock.quantity += transfer.quantity
                print("Incremented vehicle (\(targetVehicle.displayName)) stock for \(itemDefinition.name) to \(fetchedTargetStock.quantity)")
            } else {
                let newTargetStock = StockLocationItem(
                    inventoryItem: itemDefinition,
                    quantity: transfer.quantity,
                    minimumStockLevel: 2, 
                    maxStockLevel: 10, 
                    vehicle: targetVehicle
                )
                modelContext.insert(newTargetStock)
                targetStockToRevert = newTargetStock // Store for potential deletion
                targetStockWasCreated = true
                print("Created new vehicle (\(targetVehicle.displayName)) stock for \(itemDefinition.name) with qty \(newTargetStock.quantity)")
            }
        } catch {
             print("Error fetching/updating target stock: \(error)")
             errorMessage = "Error updating vehicle stock."
             // Attempt to revert source stock if target update failed
             if let originalQty = originalSourceStockQuantity {
                 sourceStock.quantity = originalQty
                 print("Reverted source stock quantity for \(itemDefinition.name) to \(originalQty) due to target stock error.")
             }
             return
        }
        
        // --- 3. Update Transfer Status ---
        transfer.status = "accepted"
        transfer.processedAt = Date()
        
        // --- 4. Save All Changes ---
        do {
            try modelContext.save() 
            print("Successfully accepted and saved transfer \(transfer.id)")
            // Remove from local list ONLY if save was successful
            pendingTransfers.removeAll { $0.id == transfer.id }
        } catch {
            print("CRITICAL: Failed to save accepted transfer status and stock changes: \(error)")
            errorMessage = "Failed to save transfer. Reverting changes. Please try again."

            // Attempt to revert all in-memory changes
            if let originalQty = originalSourceStockQuantity {
                sourceStock.quantity = originalQty
                print("Save failed: Reverted source stock quantity for \(itemDefinition.name) to \(originalQty).")
            }

            if let target = targetStockToRevert {
                if targetStockWasCreated {
                    modelContext.delete(target) // Delete if it was newly created
                    print("Save failed: Deleted newly created target stock item for \(itemDefinition.name).")
                } else if let originalQty = originalTargetStockQuantity {
                    target.quantity = originalQty // Revert quantity if it existed
                    print("Save failed: Reverted target stock quantity for \(itemDefinition.name) to \(originalQty).")
                }
            }
            
            // Revert transfer status
            transfer.status = originalTransferStatus
            transfer.processedAt = originalTransferProcessedAt
            print("Save failed: Reverted transfer \(transfer.id) status to \(originalTransferStatus).")
        }
    }
}

// MARK: - Preview

#Preview {
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
    
    // Setup preview data
    let modelContext = container.mainContext
    
    // Create sample users for demo
    let technician1 = AuthUser(id: "tech1", fullName: "Technician Smith", role: .technician)
    let dealer = AuthUser(id: "dealer-bob", fullName: "Dealer Bob", role: .dealer)
    
    // Create sample warehouse and vehicle
    let mainWarehouse = AppWarehouse(name: "Main Warehouse", location: "123 Supply St")
    let vehicle1 = AppVehicle(make: "Ford", model: "Transit", year: 2022)
    
    // Create sample inventory items
    let pipe = AppInventoryItem(
        name: "Copper Pipe",
        partNumber: "CP-123",
        category: "Plumbing"
    )
    
    // Insert all into context
    modelContext.insert(technician1)
    modelContext.insert(dealer)
    modelContext.insert(mainWarehouse)
    modelContext.insert(vehicle1)
    modelContext.insert(pipe)
    
    // Create stock location for item
    let pipeStock = StockLocationItem(
        inventoryItem: pipe, 
        quantity: 50, 
        minimumStockLevel: 10, 
        maxStockLevel: 100,
        warehouse: mainWarehouse
    )
    modelContext.insert(pipeStock)
    
    // Create pending transfer
    let transfer1 = PendingTransfer(
        id: UUID().uuidString,
        requestedAt: Date().addingTimeInterval(-86400),
        status: "pending",
        quantity: 5,
        notes: "Vehicle restock",
        inventoryItem: pipe,
        fromWarehouse: mainWarehouse,
        toVehicle: vehicle1,
        requestingManager: dealer,
        assignedTechnician: technician1
    )
    modelContext.insert(transfer1)
    
    // Setup auth service
    let auth = AppAuthService()
    auth.currentUser = technician1
    
    // Return the actual view
    return PendingTransfersView()
        .modelContainer(container)
        .environmentObject(auth)
} 