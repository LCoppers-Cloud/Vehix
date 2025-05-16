import Foundation
import SwiftData

@Model
final class Receipt: Identifiable {
    @Attribute(.unique) var id: String
    var date: Date
    var total: Double
    var taxAmount: Double?
    var receiptNumber: String?
    var notes: String?
    var imageData: Data?
    var parsedItems: [ReceiptItem]?
    var createdAt: Date
    var updatedAt: Date
    
    // References
    var vendorId: String?
    var rawVendorName: String?
    
    // Relationships
    @Relationship(deleteRule: .nullify) var vendor: AppVendor?
    
    // Purchase order relationship
    @Relationship(inverse: \PurchaseOrder.receipt) var purchaseOrder: PurchaseOrder?
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var cloudKitSyncStatus: Int16 = 0
    var cloudKitSyncDate: Date?
    
    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        total: Double = 0.0,
        taxAmount: Double? = nil,
        receiptNumber: String? = nil,
        notes: String? = nil,
        imageData: Data? = nil,
        vendorId: String? = nil,
        rawVendorName: String? = nil,
        vendor: AppVendor? = nil,
        parsedItems: [ReceiptItem]? = nil,
        cloudKitRecordID: String? = nil,
        cloudKitSyncStatus: Int16 = 0,
        cloudKitSyncDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.total = total
        self.taxAmount = taxAmount
        self.receiptNumber = receiptNumber
        self.notes = notes
        self.imageData = imageData
        self.vendorId = vendorId
        self.rawVendorName = rawVendorName
        self.vendor = vendor
        self.parsedItems = parsedItems
        self.cloudKitRecordID = cloudKitRecordID
        self.cloudKitSyncStatus = cloudKitSyncStatus
        self.cloudKitSyncDate = cloudKitSyncDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Assign a vendor to this receipt
    func assignVendor(_ vendor: AppVendor) {
        self.vendor = vendor
        self.vendorId = vendor.id
        self.updatedAt = Date()
    }
    
    // Add a parsed item to this receipt
    func addItem(_ item: ReceiptItem) {
        if parsedItems == nil {
            parsedItems = []
        }
        
        parsedItems?.append(item)
        updatedAt = Date()
    }
}

// Model for individual line items in a receipt
@Model
final class ReceiptItem: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var quantity: Double
    var unitPrice: Double
    var totalPrice: Double
    var inventoryItemId: String?
    var createdAt: Date
    
    // Receipt this item belongs to
    @Relationship(deleteRule: .cascade, inverse: \Receipt.parsedItems) var receipt: Receipt?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        quantity: Double = 1.0,
        unitPrice: Double = 0.0,
        totalPrice: Double = 0.0,
        inventoryItemId: String? = nil,
        receipt: Receipt? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.inventoryItemId = inventoryItemId
        self.receipt = receipt
        self.createdAt = createdAt
    }
} 