import SwiftUI
import SwiftData
import CoreLocation

/// Manager class for Purchase Order operations
class PurchaseOrderManager: ObservableObject {
    private var modelContext: ModelContext?
    
    // Published properties for UI updates
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var recentPurchaseOrders: [PurchaseOrder] = []
    @Published var pendingApprovalCount: Int = 0
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        loadRecentPurchaseOrders()
    }
    
    /// Set the model context
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadRecentPurchaseOrders()
    }
    
    /// Load recent purchase orders
    func loadRecentPurchaseOrders() {
        guard let modelContext = modelContext else { return }
        
        isLoading = true
        
        do {
            // Create a fetch descriptor for PurchaseOrder
            let sortDescriptor = SortDescriptor<PurchaseOrder>(\.createdAt, order: .reverse)
            var descriptor = FetchDescriptor<PurchaseOrder>(sortBy: [sortDescriptor])
            descriptor.fetchLimit = 10
            
            // Fetch the records
            recentPurchaseOrders = try modelContext.fetch(descriptor)
            
            // Update pending approval count
            countPendingApprovals()
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load purchase orders: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Count purchase orders pending approval
    func countPendingApprovals() {
        guard let modelContext = modelContext else { return }
        
        do {
            // Create a predicate for submitted purchase orders
            let predicate = #Predicate<PurchaseOrder> { po in
                po.status == "Submitted"
            }
            
            // Create fetch descriptor with the predicate
            let descriptor = FetchDescriptor<PurchaseOrder>(predicate: predicate)
            
            // Fetch the count
            pendingApprovalCount = try modelContext.fetchCount(descriptor)
        } catch {
            errorMessage = "Failed to count pending approvals: \(error.localizedDescription)"
        }
    }
    
    /// Fetch purchase orders by status
    @MainActor
    func fetchPurchaseOrders(status: PurchaseOrderStatus? = nil, limit: Int? = nil) async -> [PurchaseOrder] {
        guard let modelContext = modelContext else { return [] }
        
        do {
            // Create sort descriptor
            let sortDescriptor = SortDescriptor<PurchaseOrder>(\.createdAt, order: .reverse)
            
            // Create fetch descriptor
            var descriptor = FetchDescriptor<PurchaseOrder>(sortBy: [sortDescriptor])
            
            // Add predicate if status is specified
            if let status = status {
                let predicate = #Predicate<PurchaseOrder> { po in
                    po.status == status.rawValue
                }
                descriptor.predicate = predicate
            }
            
            // Set limit if specified
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            // Fetch the records
            return try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch purchase orders: \(error.localizedDescription)"
            return []
        }
    }
    
    /// Approve a purchase order
    func approvePurchaseOrder(_ purchaseOrder: PurchaseOrder) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        // Update status
        purchaseOrder.poStatus = .approved
        purchaseOrder.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Refresh data
            await MainActor.run {
                loadRecentPurchaseOrders()
            }
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to approve purchase order: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Reject a purchase order
    func rejectPurchaseOrder(_ purchaseOrder: PurchaseOrder, reason: String) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        // Update status
        purchaseOrder.poStatus = .rejected
        purchaseOrder.notes = reason
        purchaseOrder.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Refresh data
            await MainActor.run {
                loadRecentPurchaseOrders()
            }
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to reject purchase order: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Mark a purchase order as received
    func markPurchaseOrderAsReceived(_ purchaseOrder: PurchaseOrder, isPartial: Bool = false) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        // Update status
        purchaseOrder.poStatus = isPartial ? .partiallyReceived : .received
        purchaseOrder.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Refresh data
            await MainActor.run {
                loadRecentPurchaseOrders()
            }
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update purchase order: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Attach a receipt to a purchase order
    func attachReceipt(to purchaseOrder: PurchaseOrder, image: UIImage, captureLocation: CLLocationCoordinate2D? = nil) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        // Create a new receipt
        let receipt = Receipt(
            date: Date(),
            total: purchaseOrder.total,
            imageData: image.jpegData(compressionQuality: 0.8),
            vendorId: purchaseOrder.vendorId
        )
        
        // Location data is not supported in the current Receipt model
        
        do {
            // Add the receipt to the database
            modelContext.insert(receipt)
            
            // Connect receipt to purchase order
            purchaseOrder.receipt = receipt
            purchaseOrder.updatedAt = Date()
            
            try modelContext.save()
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to attach receipt: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Create a purchase order from receipt data
    func createPurchaseOrderFromReceipt(receipt: Receipt, jobId: String, jobNumber: String, userId: String, userName: String) async -> PurchaseOrder? {
        guard let modelContext = modelContext else { return nil }
        
        // Generate PO number
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        let poNumber = "\(jobNumber)-\(dateString)-\(Int.random(in: 100...999))"
        
        // Since the Receipt model might not have the expected properties,
        // we'll create the PO with default values
        let purchaseOrder = PurchaseOrder(
            poNumber: poNumber,
            date: receipt.date,  // receipt.date is non-optional
            vendorId: receipt.vendorId ?? "",
            vendorName: "Unknown Vendor", // Default value since vendorName may not exist
            status: .submitted,
            subtotal: 0, // Default value since totalAmount may not exist
            tax: 0,
            total: 0, // Default value since totalAmount may not exist
            notes: "Created from receipt",
            createdByUserId: userId,
            createdByName: userName,
            serviceTitanJobId: jobId,
            serviceTitanJobNumber: jobNumber
        )
        
        // Link receipt to purchase order
        purchaseOrder.receipt = receipt
        
        // Add line items if available
        if let parsedItems = receipt.parsedItems {
            var lineItems: [PurchaseOrderLineItem] = []
            
            for item in parsedItems {
                let lineItem = PurchaseOrderLineItem(
                    purchaseOrderId: purchaseOrder.id,
                    inventoryItemId: item.inventoryItemId,
                    itemDescription: item.name,
                    quantity: Int(item.quantity),
                    unitPrice: item.unitPrice,
                    lineTotal: item.totalPrice
                )
                lineItems.append(lineItem)
                modelContext.insert(lineItem)
            }
            
            purchaseOrder.lineItems = lineItems
        }
        
        do {
            modelContext.insert(purchaseOrder)
            try modelContext.save()
            return purchaseOrder
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create purchase order: \(error.localizedDescription)"
            }
            return nil
        }
    }
} 