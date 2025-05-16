import Foundation
import SwiftData
import Combine

class ServiceTitanService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    
    var modelContext: ModelContext?
    private var config: ServiceTitanConfig?
    private var cancellables = Set<AnyCancellable>()
    
    // Base URL for ServiceTitan API
    private let baseURL = "https://api.servicetitan.io"
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        loadConfiguration()
    }
    
    // Load configuration from SwiftData
    func loadConfiguration() {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            return
        }
        
        do {
            let configs = try modelContext.fetch(FetchDescriptor<ServiceTitanConfig>())
            if let config = configs.first {
                self.config = config
                self.isConnected = config.isValid
                self.lastSyncDate = config.lastSyncDate
            } else {
                // Create a default config if none exists
                let newConfig = ServiceTitanConfig()
                modelContext.insert(newConfig)
                try modelContext.save()
                self.config = newConfig
                self.isConnected = false
            }
        } catch {
            errorMessage = "Failed to load configuration: \(error.localizedDescription)"
        }
    }
    
    // Save configuration to SwiftData
    func saveConfiguration(_ config: ServiceTitanConfig) {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            return
        }
        
        do {
            try modelContext.save()
            self.config = config
            self.isConnected = config.isValid
        } catch {
            errorMessage = "Failed to save configuration: \(error.localizedDescription)"
        }
    }
    
    // Test connection to ServiceTitan API
    func testConnection(completion: @escaping (Bool, String?) -> Void) {
        guard let config = config, config.isValid else {
            completion(false, "Invalid configuration")
            return
        }
        
        isLoading = true
        
        // In a real implementation, this would make an actual API call to ServiceTitan
        // For demonstration, we'll simulate a successful connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            self.isConnected = true
            completion(true, nil)
        }
    }
    
    // Sync inventory with ServiceTitan
    func syncInventory(completion: @escaping (Bool, String?) -> Void) {
        guard let config = config, config.isValid, config.syncInventory else {
            completion(false, "Inventory sync not enabled or invalid configuration")
            return
        }
        
        isLoading = true
        
        // In a real implementation, this would:
        // 1. Fetch inventory from ServiceTitan API
        // 2. Update local inventory items
        // 3. Handle conflicts and merges
        
        // For demonstration, we'll simulate a successful sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            
            // Update last sync date
            self.config?.lastSyncDate = Date()
            self.lastSyncDate = self.config?.lastSyncDate
            
            if let modelContext = self.modelContext {
                do {
                    try modelContext.save()
                } catch {
                    completion(false, "Failed to save sync date: \(error.localizedDescription)")
                    return
                }
            }
            
            completion(true, nil)
        }
    }
    
    // Sync purchase orders with ServiceTitan
    func syncPurchaseOrders(completion: @escaping (Bool, String?) -> Void) {
        guard let config = config, config.isValid, config.syncPurchaseOrders else {
            completion(false, "Purchase order sync not enabled or invalid configuration")
            return
        }
        
        isLoading = true
        
        // In a real implementation, this would:
        // 1. Fetch purchase orders from ServiceTitan API
        // 2. Update local purchase orders
        // 3. Push local purchase orders to ServiceTitan
        
        // For demonstration, we'll simulate a successful sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            
            // Update last sync date
            self.config?.lastSyncDate = Date()
            self.lastSyncDate = self.config?.lastSyncDate
            
            if let modelContext = self.modelContext {
                do {
                    try modelContext.save()
                } catch {
                    completion(false, "Failed to save sync date: \(error.localizedDescription)")
                    return
                }
            }
            
            completion(true, nil)
        }
    }
    
    // Create a purchase order in ServiceTitan
    func createPurchaseOrder(_ purchaseOrder: PurchaseOrder, completion: @escaping (Bool, String?) -> Void) {
        guard let config = config, config.isValid else {
            completion(false, "Invalid configuration")
            return
        }
        
        isLoading = true
        
        // In a real implementation, this would:
        // 1. Format the purchase order for ServiceTitan API
        // 2. Send a POST request to create the purchase order
        // 3. Update the local purchase order with the ServiceTitan ID
        
        // For demonstration, we'll simulate a successful creation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            
            // Generate a fake ServiceTitan PO ID
            let fakePoId = "ST-\(Int.random(in: 10000...99999))"
            
            // Update the purchase order with the ServiceTitan ID
            purchaseOrder.syncWithServiceTitan(poId: fakePoId)
            
            if let modelContext = self.modelContext {
                do {
                    try modelContext.save()
                } catch {
                    completion(false, "Failed to save purchase order: \(error.localizedDescription)")
                    return
                }
            }
            
            completion(true, nil)
        }
    }
} 