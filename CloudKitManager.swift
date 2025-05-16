import Foundation
import SwiftData
import CloudKit

// Cloud sync status for tracking sync state
enum CloudKitSyncStatus: Int16 {
    case needsUpload = 0
    case pendingUpload = 1
    case synced = 2
    case syncFailed = 3
}

// Protocol for objects that can be synced with CloudKit
protocol CloudKitSyncable {
    var cloudKitRecordID: String? { get set }
    var cloudKitSyncStatus: Int16 { get set }
    var cloudKitSyncDate: Date? { get set }
    
    func markPendingUpload()
    func markSynced()
    func markSyncFailed()
}

class CloudKitManager: ObservableObject {
    // Publish sync state and errors
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncStatus: String = "Not Synced"
    @Published var isSharingEnabled: Bool = false
    
    // CloudKit containers
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    // Database references
    var modelContext: ModelContext?
    
    // Settings
    private var shouldShareInventory: Bool = false
    private var sharePrices: Bool = false
    private var shareUsageData: Bool = false
    
    init() {
        // Use the specific CloudKit container
        self.container = CKContainer(identifier: "iCloud.com.lcoppers.Vehix")
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        
        // Check iCloud account status
        checkiCloudAccountStatus()
    }
    
    // Check if the user is signed into iCloud
    private func checkiCloudAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.syncStatus = "iCloud Available"
                case .noAccount:
                    self?.syncError = "No iCloud account. Please sign in to use cloud features."
                case .restricted:
                    self?.syncError = "iCloud access is restricted."
                case .couldNotDetermine:
                    self?.syncError = "Could not determine iCloud status: \(error?.localizedDescription ?? "Unknown error")"
                case .temporarilyUnavailable:
                    self?.syncError = "iCloud is temporarily unavailable."
                @unknown default:
                    self?.syncError = "Unknown iCloud account status."
                }
            }
        }
    }
    
    // Configure sharing settings
    func configureSharing(shareInventory: Bool, sharePrices: Bool, shareUsageData: Bool) {
        // Update privacy consent with the user's preferences
        CloudKitPrivacyManager.shared.setUserConsent(
            consent: shareInventory,
            shareInventory: shareInventory,
            sharePrices: sharePrices,
            shareUsageData: shareUsageData
        )
        
        // Keep these for backward compatibility
        self.shouldShareInventory = shareInventory
        self.sharePrices = sharePrices
        self.shareUsageData = shareUsageData
        self.isSharingEnabled = shareInventory
    }
    
    // MARK: - Inventory Sync Methods
    
    // Sync inventory items to CloudKit
    func syncInventoryItems() {
        guard let modelContext = modelContext else {
            syncError = "No model context available"
            return
        }
        
        // Only proceed if sharing is enabled and user has consented
        guard CloudKitPrivacyManager.shared.shouldShareInventory else {
            syncStatus = "Inventory sharing disabled or no consent given"
            return
        }
        
        isSyncing = true
        syncStatus = "Syncing inventory..."
        
        do {
            // Get all inventory items that need syncing
            let pendingItems = try getPendingInventoryItems()
            
            if pendingItems.isEmpty {
                syncStatus = "No items to sync"
                isSyncing = false
                return
            }
            
            // Create a dispatch group to track when all operations complete
            let group = DispatchGroup()
            
            // Process each item one at a time
            for item in pendingItems {
                group.enter()
                
                // Create a record from the inventory item
                let record = createInventoryRecord(from: item)
                
                // Sanitize the record to remove any PII
                let sanitizedRecord = CloudKitPrivacyManager.shared.sanitizeRecord(record)
                
                // Save the sanitized record to CloudKit
                publicDatabase.save(sanitizedRecord) { [weak self] (savedRecord, error) in
                    defer { group.leave() }
                    
                    if let error = error {
                        // Handle error
                        item.cloudKitSyncStatus = CloudKitSyncStatus.syncFailed.rawValue
                        self?.syncError = "Failed to sync item: \(error.localizedDescription)"
                    } else if let savedRecord = savedRecord {
                        // Update the item with the saved record ID
                        item.cloudKitRecordID = savedRecord.recordID.recordName
                        item.cloudKitSyncStatus = CloudKitSyncStatus.synced.rawValue
                        item.cloudKitSyncDate = Date()
                    }
                }
            }
            
            // Wait for all operations to complete
            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                
                do {
                    // Save changes to the model context
                    try modelContext.save()
                    
                    // Update last sync date
                    self.lastSyncDate = Date()
                    self.syncStatus = "Sync completed"
                } catch {
                    self.syncError = "Failed to save changes: \(error.localizedDescription)"
                }
                
                self.isSyncing = false
            }
            
        } catch {
            syncError = "Failed to sync inventory: \(error.localizedDescription)"
            isSyncing = false
        }
    }
    
    // Get inventory items that need to be synced
    private func getPendingInventoryItems() throws -> [AppInventoryItem] {
        guard let modelContext = modelContext else {
            throw NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model context not available"])
        }
        
        // Create a descriptor to fetch all items
        let descriptor = FetchDescriptor<AppInventoryItem>()
        let allItems = try modelContext.fetch(descriptor)
        
        // Filter items that need to be synced
        let pendingStatusValues: [Int16] = [
            CloudKitSyncStatus.needsUpload.rawValue,
            CloudKitSyncStatus.pendingUpload.rawValue,
            CloudKitSyncStatus.syncFailed.rawValue
        ]
        
        return allItems.filter { pendingStatusValues.contains($0.cloudKitSyncStatus) }
    }
    
    // Create a CloudKit record from an inventory item
    private func createInventoryRecord(from item: AppInventoryItem) -> CKRecord {
        // If the item already has a record ID, use it
        let recordID: CKRecord.ID
        if let existingID = item.cloudKitRecordID {
            recordID = CKRecord.ID(recordName: existingID)
        } else {
            recordID = CKRecord.ID(recordName: UUID().uuidString)
        }
        
        let record = CKRecord(recordType: "InventoryItem", recordID: recordID)
        
        // Set record fields - using explicit NSString and NSNumber casts
        record["name"] = item.name as NSString
        record["partNumber"] = item.partNumber as NSString
        record["category"] = item.category as NSString
        
        // Only include description if it's not nil
        if let description = item.itemDescription {
            record["description"] = description as NSString
        }
        
        // Only include price if sharing prices is enabled
        if CloudKitPrivacyManager.shared.shouldSharePrices {
            record["pricePerUnit"] = NSNumber(value: item.pricePerUnit)
        }
        
        // Include other non-sensitive fields
        // Note: The following fields were moved to StockLocationItem and are no longer on AppInventoryItem
        // We could optionally include average/recommended minimumStockLevel from all stockLocations if needed
        // record["minimumStockLevel"] = NSNumber(value: item.minimumStockLevel)
        // record["location"] = item.location as NSString
        
        if let supplier = item.supplier {
            record["supplier"] = supplier as NSString
        }
        
        // Usage data is now in StockLocationItem, not directly on AppInventoryItem
        // record["quantity"] = NSNumber(value: item.quantity)
        // record["lastRestockDate"] = item.lastRestockDate as NSDate
        
        // Add a timestamp for when this record was created
        record["sharedAt"] = Date() as NSDate
        
        // Add app version information
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            record["appVersion"] = version as NSString
        }
        
        return record
    }
    
    // MARK: - Inventory Search Methods
    
    // Search for inventory items in the public database
    func searchSharedInventory(query: String, completion: @escaping ([AppInventoryItem]?, Error?) -> Void) {
        // Create a predicate for the search
        let predicate = NSPredicate(format: "name CONTAINS[cd] %@ OR partNumber CONTAINS[cd] %@ OR category CONTAINS[cd] %@", query, query, query)
        
        // Create a query operation
        let operation = CKQueryOperation(query: CKQuery(recordType: "InventoryItem", predicate: predicate))
        operation.resultsLimit = 50
        
        var foundRecords: [CKRecord] = []
        
        // Set the record matching block
        operation.recordMatchedBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                foundRecords.append(record)
            case .failure(let error):
                print("Error fetching record: \(error.localizedDescription)")
            }
        }
        
        // Set the completion block
        operation.queryResultBlock = { [weak self] result in
            switch result {
            case .success(_):
                // Convert records to inventory items
                let items = foundRecords.compactMap { self?.inventoryItemFrom(record: $0) }
                completion(items, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
        
        // Add the operation to the public database
        publicDatabase.add(operation)
    }
    
    // Convert a CloudKit record to an inventory item
    private func inventoryItemFrom(record: CKRecord) -> AppInventoryItem? {
        // Extract fields from the record
        guard let name = record["name"] as? String,
              let category = record["category"] as? String else {
            return nil
        }
        
        let partNumber = record["partNumber"] as? String ?? ""
        
        // Create a new inventory item
        let item = AppInventoryItem(
            name: name,
            partNumber: partNumber,
            itemDescription: record["description"] as? String,
            category: category,
            pricePerUnit: (record["pricePerUnit"] as? Double) ?? 0.0,
            supplier: record["supplier"] as? String
        )
        
        // Set CloudKit fields
        item.cloudKitRecordID = record.recordID.recordName
        item.cloudKitSyncStatus = CloudKitSyncStatus.synced.rawValue
        item.cloudKitSyncDate = Date()
        
        return item
    }
    
    // Import an item from the shared catalog
    func importInventoryItem(_ item: AppInventoryItem, completion: @escaping (Bool, String?) -> Void) {
        guard let modelContext = modelContext else {
            completion(false, "Model context not available")
            return
        }
        
        // Check if the item already exists
        do {
            // Create a descriptor to fetch all items
            let descriptor = FetchDescriptor<AppInventoryItem>()
            let allItems = try modelContext.fetch(descriptor)
            
            // Find matching items
            let existingItems = allItems.filter { 
                $0.partNumber == item.partNumber || 
                ($0.cloudKitRecordID != nil && $0.cloudKitRecordID == item.cloudKitRecordID) 
            }
            
            if let existingItem = existingItems.first {
                // Item already exists, update with latest info
                existingItem.name = item.name
                existingItem.itemDescription = item.itemDescription
                existingItem.category = item.category
                // No longer has minimumStockLevel or location
                // existingItem.minimumStockLevel = item.minimumStockLevel
                // existingItem.location = item.location
                existingItem.supplier = item.supplier
                
                // Only update price if it's available and non-zero
                if item.pricePerUnit > 0 {
                    existingItem.pricePerUnit = item.pricePerUnit
                }
                
                try modelContext.save()
                completion(true, "Item updated in your inventory")
            } else {
                // Create a new item with only the needed parameters
                let newItem = AppInventoryItem(
                    name: item.name,
                    partNumber: item.partNumber,
                    itemDescription: item.itemDescription,
                    category: item.category,
                    pricePerUnit: item.pricePerUnit,
                    supplier: item.supplier
                )
                
                // Set CloudKit fields
                newItem.cloudKitRecordID = item.cloudKitRecordID
                newItem.cloudKitSyncStatus = CloudKitSyncStatus.synced.rawValue
                newItem.cloudKitSyncDate = Date()
                
                modelContext.insert(newItem)
                try modelContext.save()
                completion(true, "Item added to your inventory")
            }
        } catch {
            completion(false, "Failed to import item: \(error.localizedDescription)")
        }
    }
    
    // Verify CloudKit container connection
    func verifyContainerConnection(completion: @escaping (Bool, String?) -> Void) {
        container.accountStatus { [weak self] status, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "CloudKit error: \(error.localizedDescription)")
                }
                return
            }
            
            guard status == .available else {
                let statusMessage: String
                switch status {
                case .couldNotDetermine:
                    statusMessage = "Could not determine iCloud account status"
                case .restricted:
                    statusMessage = "iCloud account is restricted"
                case .noAccount:
                    statusMessage = "No iCloud account found. Please sign in to iCloud"
                case .temporarilyUnavailable:
                    statusMessage = "iCloud is temporarily unavailable"
                default:
                    statusMessage = "Unknown iCloud account status"
                }
                
                DispatchQueue.main.async {
                    completion(false, statusMessage)
                }
                return
            }
            
            // Test container access by fetching container info
            self?.container.fetchUserRecordID { recordID, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, "Failed to access container: \(error.localizedDescription)")
                    } else if recordID != nil {
                        // Successfully connected to container
                        completion(true, "Successfully connected to CloudKit container: iCloud.com.lcoppers.Vehix")
                    } else {
                        completion(false, "Unknown error accessing CloudKit container")
                    }
                }
            }
        }
    }
} 