import Foundation
import SwiftData

// Purchase Order Status
enum PurchaseOrderStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case submitted = "Submitted"
    case approved = "Approved"
    case rejected = "Rejected"
    case partiallyReceived = "Partially Received"
    case received = "Received"
    case cancelled = "Cancelled"
}

// Purchase Order Model
@Model
final class PurchaseOrder {
    var id: String = UUID().uuidString
    var poNumber: String = ""
    var date: Date = Date()
    var vendorId: String?
    var vendorName: String = ""
    var status: String = PurchaseOrderStatus.draft.rawValue
    var subtotal: Double = 0.0
    var tax: Double = 0.0
    var total: Double = 0.0
    var notes: String?
    var createdByUserId: String = ""
    var createdByName: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // ServiceTitan integration
    var serviceTitanPoId: String?
    var syncedWithServiceTitan: Bool = false
    var serviceTitanSyncDate: Date?
    var serviceTitanJobId: String?
    var serviceTitanJobNumber: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade)
    var lineItems: [PurchaseOrderLineItem]?
    
    // Receipt relationship
    @Relationship(deleteRule: .nullify)
    var receipt: Receipt?
    
    // Computed properties for status
    var poStatus: PurchaseOrderStatus {
        get { PurchaseOrderStatus(rawValue: status) ?? .draft }
        set { status = newValue.rawValue }
    }
    
    var statusColor: String {
        switch poStatus {
        case .draft: return "gray"
        case .submitted: return "vehix-blue"
        case .approved: return "vehix-green"
        case .rejected: return "red"
        case .partiallyReceived: return "vehix-orange"
        case .received: return "purple"
        case .cancelled: return "pink"
        }
    }
    
    // Initialize a new purchase order
    init(
        id: String = UUID().uuidString,
        poNumber: String = "",
        date: Date = Date(),
        vendorId: String? = nil,
        vendorName: String = "",
        status: PurchaseOrderStatus = .draft,
        subtotal: Double = 0.0,
        tax: Double = 0.0,
        total: Double = 0.0,
        notes: String? = nil,
        createdByUserId: String = "",
        createdByName: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        serviceTitanPoId: String? = nil,
        syncedWithServiceTitan: Bool = false,
        serviceTitanSyncDate: Date? = nil,
        serviceTitanJobId: String? = nil,
        serviceTitanJobNumber: String? = nil,
        lineItems: [PurchaseOrderLineItem]? = nil,
        receipt: Receipt? = nil
    ) {
        self.id = id
        self.poNumber = poNumber
        self.date = date
        self.vendorId = vendorId
        self.vendorName = vendorName
        self.status = status.rawValue
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
        self.notes = notes
        self.createdByUserId = createdByUserId
        self.createdByName = createdByName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serviceTitanPoId = serviceTitanPoId
        self.syncedWithServiceTitan = syncedWithServiceTitan
        self.serviceTitanSyncDate = serviceTitanSyncDate
        self.serviceTitanJobId = serviceTitanJobId
        self.serviceTitanJobNumber = serviceTitanJobNumber
        self.lineItems = lineItems
        self.receipt = receipt
    }
    
    // Calculate totals based on line items
    func recalculateTotals() {
        let calculatedSubtotal = lineItems?.reduce(0.0) { $0 + $1.lineTotal } ?? 0.0
        self.subtotal = calculatedSubtotal
        self.total = subtotal + tax
    }
    
    // Sync with ServiceTitan
    func syncWithServiceTitan(poId: String, jobId: String? = nil, jobNumber: String? = nil) {
        self.serviceTitanPoId = poId
        self.syncedWithServiceTitan = true
        self.serviceTitanSyncDate = Date()
        self.serviceTitanJobId = jobId
        self.serviceTitanJobNumber = jobNumber
        self.updatedAt = Date()
    }
}

// Purchase Order Line Item Model
@Model
final class PurchaseOrderLineItem {
    var id: String = UUID().uuidString
    var purchaseOrderId: String = ""
    var inventoryItemId: String?
    var itemDescription: String = ""
    var quantity: Int = 0
    var unitPrice: Double = 0.0
    var lineTotal: Double = 0.0
    
    // ServiceTitan integration
    var serviceTitanLineItemId: String?
    
    // Add inverse relationship to PurchaseOrder
    @Relationship(deleteRule: .cascade)
    var purchaseOrder: PurchaseOrder?
    
    init(
        id: String = UUID().uuidString,
        purchaseOrderId: String = "",
        inventoryItemId: String? = nil,
        itemDescription: String = "",
        quantity: Int = 0,
        unitPrice: Double = 0.0,
        lineTotal: Double? = nil,
        serviceTitanLineItemId: String? = nil
    ) {
        self.id = id
        self.purchaseOrderId = purchaseOrderId
        self.inventoryItemId = inventoryItemId
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal ?? Double(quantity) * unitPrice
        self.serviceTitanLineItemId = serviceTitanLineItemId
    }
} 