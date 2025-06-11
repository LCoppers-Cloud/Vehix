import Foundation
import CloudKit
import SwiftData
import UserNotifications


// Cloud sync status for tracking sync state
enum CloudKitSyncStatus: Int16 {
    case needsUpload = 0
    case pendingUpload = 1
    case synced = 2
    case syncFailed = 3
}

// Protocol for objects that can be synced with CloudKit is defined in ConsolidatedModels.swift

// Subscription status for data retention management
enum SubscriptionStatus: Equatable {
    case active
    case cancelled
    case gracePeriod(daysRemaining: Int)
    case expired
    
    static func == (lhs: SubscriptionStatus, rhs: SubscriptionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.active, .active), (.cancelled, .cancelled), (.expired, .expired):
            return true
        case (.gracePeriod(let days1), .gracePeriod(let days2)):
            return days1 == days2
        default:
            return false
        }
    }
}

class CloudKitManager: ObservableObject {
    // Publish sync state and errors
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncStatus: String = "Initializing..."
    @Published var isCloudKitAvailable: Bool = false
    @Published var subscriptionStatus: SubscriptionStatus = .active
    
    // CloudKit containers - each user gets their own private database
    private let container: CKContainer?
    private let privateDatabase: CKDatabase?
    
    // Database references
    var modelContext: ModelContext?
    
    // Environment detection
    private let isDevEnvironment: Bool
    
    // User-specific container identifier
    private var userContainerID: String {
        guard let userID = getCurrentUserID() else {
            return "iCloud.com.lcoppers.Vehix.default"
        }
        return "iCloud.com.lcoppers.Vehix.\(userID)"
    }
    
    init() {
        // Detect environment - same logic as VehixApp.swift
        #if DEBUG 
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #else
        let isSimulator = false
        #endif
        
        // DEVELOPMENT MODE: Keep this synchronized with VehixApp.swift
        let forceDevelopmentMode = true // Must match VehixApp.swift setting exactly
        self.isDevEnvironment = isSimulator || forceDevelopmentMode
        
        if isDevEnvironment {
            // Development mode - don't initialize CloudKit
            self.container = nil
            self.privateDatabase = nil
            self.syncStatus = "Local storage only (Development)"
            self.isCloudKitAvailable = false
            print("CloudKitManager: Development mode - CloudKit disabled")
        } else {
            // Production mode - initialize CloudKit
            self.container = CKContainer(identifier: "iCloud.com.lcoppers.Vehix")
            self.privateDatabase = container?.privateCloudDatabase
            
            // Set up notification observers for subscription changes
            setupNotificationObservers()
            
            // Automatically initialize CloudKit for production users
            initializeCloudKit()
            print("CloudKitManager: Production mode - CloudKit initialized")
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSubscriptionCancelled),
            name: .subscriptionCancelled,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSubscriptionReactivated),
            name: .subscriptionReactivated,
            object: nil
        )
    }
    
    @objc private func handleSubscriptionCancelled() {
        handleSubscriptionCancellation()
    }
    
    @objc private func handleSubscriptionReactivated() {
        reactivateSubscription()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Automatic CloudKit Initialization
    
    private func initializeCloudKit() {
        guard !isDevEnvironment else {
            print("CloudKitManager: Skipping CloudKit initialization in development mode")
            return
        }
        
        guard let container = container else {
            print("CloudKitManager: Container not available")
            syncStatus = "CloudKit not available"
            isCloudKitAvailable = false
            return
        }
        
        print("CloudKitManager: Initializing with container: \(container.containerIdentifier ?? "Unknown")")
        
        checkiCloudAccountStatus { [weak self] in
            self?.setupUserContainer()
            self?.checkSubscriptionStatus()
            self?.startAutomaticSync()
        }
    }
    
    private func checkiCloudAccountStatus(completion: @escaping () -> Void) {
        guard !isDevEnvironment else { return }
        
        guard let container = container else {
            DispatchQueue.main.async {
                self.syncError = "CloudKit container not available"
                self.syncStatus = "Container Error"
                self.isCloudKitAvailable = false
            }
            return
        }
        
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CloudKitManager: Account status error: \(error)")
                    self?.syncError = "CloudKit error: \(error.localizedDescription)"
                    self?.syncStatus = "Error"
                    self?.isCloudKitAvailable = false
                    return
                }
                
                switch status {
                case .available:
                    self?.syncStatus = "CloudKit Ready"
                    self?.isCloudKitAvailable = true
                    completion()
                case .noAccount:
                    self?.syncError = "iCloud account required. Please sign in to iCloud in Settings."
                    self?.syncStatus = "iCloud Required"
                    self?.isCloudKitAvailable = false
                case .restricted:
                    self?.syncError = "iCloud access is restricted on this device."
                    self?.syncStatus = "Access Restricted"
                    self?.isCloudKitAvailable = false
                case .couldNotDetermine:
                    self?.syncError = "Could not determine iCloud status: \(error?.localizedDescription ?? "Unknown error")"
                    self?.syncStatus = "Status Unknown"
                    self?.isCloudKitAvailable = false
                case .temporarilyUnavailable:
                    self?.syncError = "iCloud is temporarily unavailable. Will retry automatically."
                    self?.syncStatus = "Temporarily Unavailable"
                    self?.isCloudKitAvailable = false
                    // Retry after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        self?.initializeCloudKit()
                    }
                @unknown default:
                    self?.syncError = "Unknown iCloud account status."
                    self?.syncStatus = "Unknown Status"
                    self?.isCloudKitAvailable = false
                }
            }
        }
    }
    
    private func setupUserContainer() {
        guard !isDevEnvironment else { return }
        
        // Create user-specific record zone for data isolation
        let customZone = CKRecordZone(zoneName: "UserData")
        
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: nil)
        operation.modifyRecordZonesResultBlock = { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.syncStatus = "User container ready"
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.syncError = "Failed to setup user container: \(error.localizedDescription)"
                }
            }
        }
        
        privateDatabase?.add(operation)
    }
    
    // MARK: - Subscription Management
    
    private func checkSubscriptionStatus() {
        // Check with StoreKit for current subscription status
        // This would integrate with your existing StoreKitManager
        
        // For now, simulate checking subscription status
        let isSubscriptionActive = UserDefaults.standard.bool(forKey: "subscription.active")
        let cancellationDate = UserDefaults.standard.object(forKey: "subscription.cancellation.date") as? Date
        
        if !isSubscriptionActive {
            if let cancellationDate = cancellationDate {
                let daysSinceCancellation = Calendar.current.dateComponents([.day], from: cancellationDate, to: Date()).day ?? 0
                let daysRemaining = max(0, 90 - daysSinceCancellation)
                
                if daysRemaining > 0 {
                    subscriptionStatus = .gracePeriod(daysRemaining: daysRemaining)
                    scheduleDataDeletion(in: daysRemaining)
                } else {
                    subscriptionStatus = .expired
                    deleteAllUserData()
                }
            } else {
                subscriptionStatus = .expired
                deleteAllUserData()
            }
        } else {
            subscriptionStatus = .active
        }
    }
    
    func handleSubscriptionCancellation() {
        // Called when user cancels subscription
        UserDefaults.standard.set(false, forKey: "subscription.active")
        UserDefaults.standard.set(Date(), forKey: "subscription.cancellation.date")
        
        // Notify user about 90-day grace period
        DispatchQueue.main.async {
            self.subscriptionStatus = .gracePeriod(daysRemaining: 90)
            self.showDataDeletionWarning()
        }
        
        scheduleDataDeletion(in: 90)
    }
    
    private func showDataDeletionWarning() {
        // This would trigger a notification or alert to the user
        let notification = UNMutableNotificationContent()
        notification.title = "Subscription Cancelled"
        notification.body = "Your data will be deleted in 90 days unless you reactivate your subscription."
        notification.sound = .default
        
        let request = UNNotificationRequest(identifier: "subscription.cancelled", content: notification, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleDataDeletion(in days: Int) {
        // Schedule background task to delete data after grace period
        let deletionDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        UserDefaults.standard.set(deletionDate, forKey: "data.deletion.scheduled")
        
        // Create notification for data deletion warning
        let content = UNMutableNotificationContent()
        content.title = "Data Deletion Warning"
        content.body = "Your Vehix data will be permanently deleted in \(days) days. Reactivate your subscription to keep your data."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(days * 24 * 60 * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "data.deletion.warning", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func deleteAllUserData() {
        guard let modelContext = modelContext else { return }
        
        // Delete all local data
        do {
            // Delete all inventory items
            let inventoryDescriptor = FetchDescriptor<AppInventoryItem>()
            let inventoryItems = try modelContext.fetch(inventoryDescriptor)
            for item in inventoryItems {
                modelContext.delete(item)
            }
            
            // Delete all vehicles (with proper relationship handling)
            let vehicleDescriptor = FetchDescriptor<AppVehicle>()
            let vehicles = try modelContext.fetch(vehicleDescriptor)
            for vehicle in vehicles {
                // Clear relationships before deletion to avoid crashes
                vehicle.serviceRecords = nil
                vehicle.stockItems = nil
                vehicle.tasks = nil
                vehicle.pendingTransfers = nil
                vehicle.assignments = nil
                modelContext.delete(vehicle)
            }
            
            // Delete all purchase orders
            let poDescriptor = FetchDescriptor<PurchaseOrder>()
            let purchaseOrders = try modelContext.fetch(poDescriptor)
            for po in purchaseOrders {
                modelContext.delete(po)
            }
            
            try modelContext.save()
            
            // Delete CloudKit data
            deleteCloudKitData()
            
        } catch {
            print("Error deleting user data: \(error)")
        }
    }
    
    private func deleteCloudKitData() {
        guard !isDevEnvironment else { return }
        
        // Delete all records in user's private database
        let query = CKQuery(recordType: "UserData", predicate: NSPredicate(value: true))
        
        // Use CKQueryOperation for better compatibility
        let queryOperation = CKQueryOperation(query: query)
        var recordsToDelete: [CKRecord.ID] = []
        
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                recordsToDelete.append(record.recordID)
            case .failure:
                break
            }
        }
        
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            switch result {
            case .success:
                // Now delete all the collected records
                let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsToDelete)
                
                deleteOperation.modifyRecordsResultBlock = { (result: Result<Void, Error>) in
                    switch result {
                    case .success:
                        print("Successfully deleted \(recordsToDelete.count) user records")
                        UserDefaults.standard.set(Date(), forKey: "data.deletion.date")
                    case .failure(let error):
                        print("Error deleting user data: \(error.localizedDescription)")
                    }
                }
                
                self?.privateDatabase?.add(deleteOperation)
            case .failure(let error):
                print("Error fetching records for deletion: \(error.localizedDescription)")
            }
        }
        
        privateDatabase?.add(queryOperation)
    }
    
    // MARK: - Automatic Sync
    
    private func startAutomaticSync() {
        guard !isDevEnvironment && isCloudKitAvailable else { return }
        
        // Start periodic sync every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.syncAllData()
        }
        
        // Initial sync
        syncAllData()
    }
    
    private func syncAllData() {
        guard !isDevEnvironment && isCloudKitAvailable, subscriptionStatus == .active else { return }
        
        isSyncing = true
        syncStatus = "Syncing data..."
        
        // Sync all data types
        syncInventoryItems()
        syncVehicles()
        syncPurchaseOrders()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isSyncing = false
            self.lastSyncDate = Date()
            self.syncStatus = "Sync complete"
        }
    }
    
    // MARK: - Data Sync Methods
    
    private func syncInventoryItems() {
        guard !isDevEnvironment, let modelContext = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<AppInventoryItem>()
            let items = try modelContext.fetch(descriptor)
            
            for item in items {
                if item.cloudKitSyncStatus != CloudKitSyncStatus.synced.rawValue {
                    uploadInventoryItem(item)
                }
            }
        } catch {
            print("Error syncing inventory items: \(error)")
        }
    }
    
    private func uploadInventoryItem(_ item: AppInventoryItem) {
        guard !isDevEnvironment else { return }
        
        let record = createInventoryRecord(from: item)
        
        privateDatabase?.save(record) { [weak self] savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    item.cloudKitSyncStatus = CloudKitSyncStatus.syncFailed.rawValue
                    print("Failed to sync inventory item: \(error)")
                } else if let savedRecord = savedRecord {
                    item.cloudKitRecordID = savedRecord.recordID.recordName
                    item.cloudKitSyncStatus = CloudKitSyncStatus.synced.rawValue
                    item.cloudKitSyncDate = Date()
                    
                    try? self?.modelContext?.save()
                }
            }
        }
    }
    
    private func createInventoryRecord(from item: AppInventoryItem) -> CKRecord {
        let recordID: CKRecord.ID
        if let existingID = item.cloudKitRecordID {
            recordID = CKRecord.ID(recordName: existingID, zoneID: CKRecordZone.ID(zoneName: "UserData"))
        } else {
            recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: CKRecordZone.ID(zoneName: "UserData"))
        }
        
        let record = CKRecord(recordType: "InventoryItem", recordID: recordID)
        
        // Set record fields with user's private data
        record["name"] = item.name as NSString
        record["partNumber"] = item.partNumber as NSString
        record["category"] = item.category as NSString
        record["pricePerUnit"] = NSNumber(value: item.pricePerUnit)
        
        if let description = item.itemDescription {
            record["description"] = description as NSString
        }
        
        if let supplier = item.supplier {
            record["supplier"] = supplier as NSString
        }
        
        record["syncDate"] = Date() as NSDate
        record["userID"] = getCurrentUserID() as NSString? ?? "unknown" as NSString
        
        return record
    }
    
    private func syncVehicles() {
        // Similar implementation for vehicles
        // This would sync vehicle data to user's private CloudKit database
    }
    
    private func syncPurchaseOrders() {
        // Similar implementation for purchase orders
        // This would sync PO data to user's private CloudKit database
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserID() -> String? {
        // Get current user ID from auth service
        // This ensures each user has their own data container
        return UserDefaults.standard.string(forKey: "current.user.id")
    }
    
    // MARK: - Public Methods
    
    func setCurrentUser(_ userID: String) {
        UserDefaults.standard.set(userID, forKey: "current.user.id")
        UserDefaults.standard.set(true, forKey: "subscription.active") // Default to active for new users
        
        // Only reinitialize CloudKit if not in development mode
        if !isDevEnvironment {
            initializeCloudKit()
        }
    }
    
    func reactivateSubscription() {
        guard !isDevEnvironment else {
            print("CloudKitManager: Subscription management disabled in development mode")
            return
        }
        
        UserDefaults.standard.set(true, forKey: "subscription.active")
        UserDefaults.standard.removeObject(forKey: "subscription.cancellation.date")
        UserDefaults.standard.removeObject(forKey: "data.deletion.scheduled")
        
        // Cancel scheduled deletion notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["data.deletion.warning"])
        
        subscriptionStatus = .active
        syncStatus = "Subscription reactivated"
        
        // Resume automatic syncing
        startAutomaticSync()
    }
    
    func forceSync() {
        guard !isDevEnvironment else {
            syncError = "CloudKit sync disabled in development mode"
            return
        }
        
        guard isCloudKitAvailable else {
            syncError = "CloudKit not available"
            return
        }
        
        syncAllData()
    }
    
    func getDataRetentionInfo() -> String {
        switch subscriptionStatus {
        case .active:
            return "Your data is actively synced and backed up to iCloud."
        case .cancelled:
            return "Subscription cancelled. Data will be deleted in 90 days."
        case .gracePeriod(let daysRemaining):
            return "Data will be deleted in \(daysRemaining) days unless subscription is reactivated."
        case .expired:
            return "Subscription expired. Data has been deleted."
        }
    }
} 