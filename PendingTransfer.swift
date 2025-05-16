import Foundation
import SwiftData

/// Represents a request to transfer a specific quantity of an inventory item 
/// from a warehouse to a vehicle, awaiting technician acceptance.
@Model
final class PendingTransfer {
    /// Unique identifier for the transfer request.
    @Attribute(.unique) var id: String
    
    /// Timestamp when the transfer was requested.
    var requestedAt: Date
    
    /// Current status of the transfer request.
    /// Possible values: "pending", "accepted", "rejected".
    var status: String
    
    /// The quantity of the item requested for transfer.
    var quantity: Int
    
    /// Optional notes from the manager initiating the transfer.
    var notes: String?
    
    // MARK: - Links
    
    /// The inventory item definition being transferred.
    var inventoryItem: AppInventoryItem?
    
    /// The source warehouse for the transfer.
    var fromWarehouse: AppWarehouse?
    
    /// The target vehicle for the transfer.
    var toVehicle: AppVehicle?
    
    /// The manager user who initiated the transfer request.
    var requestingManager: AuthUser?
    
    /// The technician user assigned to the target vehicle at the time of request.
    var assignedTechnician: AuthUser?
    
    // MARK: - Processing Info
    
    /// Timestamp when the transfer was accepted or rejected.
    var processedAt: Date?
    
    /// Optional reason provided if the technician rejected the transfer.
    var rejectionReason: String?
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        requestedAt: Date = Date(),
        status: String = "pending",
        quantity: Int,
        notes: String? = nil,
        inventoryItem: AppInventoryItem? = nil,
        fromWarehouse: AppWarehouse? = nil,
        toVehicle: AppVehicle? = nil,
        requestingManager: AuthUser? = nil,
        assignedTechnician: AuthUser? = nil,
        processedAt: Date? = nil,
        rejectionReason: String? = nil
    ) {
        self.id = id
        self.requestedAt = requestedAt
        self.status = status
        self.quantity = quantity
        self.notes = notes
        self.inventoryItem = inventoryItem
        self.fromWarehouse = fromWarehouse
        self.toVehicle = toVehicle
        self.requestingManager = requestingManager
        self.assignedTechnician = assignedTechnician
        self.processedAt = processedAt
        self.rejectionReason = rejectionReason
        
        // Basic validation
        // assert(quantity > 0, "Transfer quantity must be positive.")
        // assert(inventoryItem != nil, "PendingTransfer must link to an AppInventoryItem.")
        // assert(fromWarehouse != nil, "PendingTransfer must have a source warehouse.")
        // assert(toVehicle != nil, "PendingTransfer must have a target vehicle.")
        // assert(requestingManager != nil, "PendingTransfer must have a requesting manager.")
        // assert(assignedTechnician != nil, "PendingTransfer must have an assigned technician.")
    }
} 