import Foundation
import SwiftData
import Combine

// Samsara configuration for API access
@Model
final class SamsaraConfig {
    var id: String = UUID().uuidString
    var apiKey: String? // Kept for backward compatibility, but won't store actual API key
    var organizationId: String?
    var isEnabled: Bool = false
    var lastSyncDate: Date?
    var syncIntervalMinutes: Int = 30
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    var isValid: Bool {
        !getApiKey().isEmpty && !(organizationId?.isEmpty ?? true)
    }
    
    init(
        id: String = UUID().uuidString,
        apiKey: String? = nil,
        organizationId: String? = nil,
        isEnabled: Bool = false,
        lastSyncDate: Date? = nil,
        syncIntervalMinutes: Int = 30,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        
        // Don't store the API key directly, use KeychainServices
        if let key = apiKey {
            setApiKey(key)
        }
        
        self.organizationId = organizationId
        self.isEnabled = isEnabled
        self.lastSyncDate = lastSyncDate
        self.syncIntervalMinutes = syncIntervalMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Securely store API key
    func setApiKey(_ key: String) {
        let keychainKey = "samsara.apiKey.\(id)"
        KeychainServices.save(key: keychainKey, value: key)
        
        // Set a placeholder value to indicate a key has been stored
        self.apiKey = "SECURE_STORAGE" // This is just a placeholder
    }
    
    // Securely retrieve API key
    func getApiKey() -> String {
        let keychainKey = "samsara.apiKey.\(id)"
        return KeychainServices.get(key: keychainKey) ?? ""
    }
}

// Samsara integration service
class SamsaraService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    
    var modelContext: ModelContext?
    private var config: SamsaraConfig?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    
    // Base URL for Samsara API
    private let baseURL = "https://api.samsara.com/v1"
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        loadConfiguration()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // Load configuration from SwiftData
    func loadConfiguration() {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            return
        }
        
        do {
            let configs = try modelContext.fetch(FetchDescriptor<SamsaraConfig>())
            if let config = configs.first {
                self.config = config
                self.isConnected = config.isValid && config.isEnabled
                self.lastSyncDate = config.lastSyncDate
                
                if config.isValid && config.isEnabled {
                    startAutoSync(interval: config.syncIntervalMinutes)
                }
            } else {
                // Create a default config if none exists
                let newConfig = SamsaraConfig()
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
    func saveConfiguration(_ config: SamsaraConfig) {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            return
        }
        
        do {
            try modelContext.save()
            self.config = config
            self.isConnected = config.isValid && config.isEnabled
            
            // Update auto-sync if needed
            if config.isValid && config.isEnabled {
                startAutoSync(interval: config.syncIntervalMinutes)
            } else {
                stopAutoSync()
            }
        } catch {
            errorMessage = "Failed to save configuration: \(error.localizedDescription)"
        }
    }
    
    // Start auto-sync timer
    private func startAutoSync(interval: Int) {
        stopAutoSync() // Stop any existing timer
        
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval * 60), repeats: true) { [weak self] _ in
            self?.syncAllVehicles { _, _ in }
        }
    }
    
    // Stop auto-sync timer
    private func stopAutoSync() {
        timer?.invalidate()
        timer = nil
    }
    
    // Test connection to Samsara API
    func testConnection(completion: @escaping (Bool, String?) -> Void) {
        guard let config = config, config.isValid else {
            completion(false, "Invalid configuration")
            return
        }
        
        isLoading = true
        
        // In a real implementation, this would make an actual API call to Samsara
        // For demonstration, we'll simulate a successful connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            self.isConnected = true
            completion(true, nil)
        }
    }
    
    // Sync all vehicles from Samsara
    func syncAllVehicles(completion: @escaping (Bool, String?) -> Void) {
        guard let config = config, config.isValid, config.isEnabled else {
            completion(false, "Samsara integration not enabled or invalid configuration")
            return
        }
        
        isLoading = true
        
        // In a real implementation, this would:
        // 1. Fetch all vehicles from Samsara API
        // 2. Update local vehicles with mileage and location data
        
        // For demonstration, we'll simulate a successful sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            
            // Update vehicles with simulated data
            self.updateVehiclesWithSimulatedData()
            
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
    
    // Sync a specific vehicle from Samsara
    func syncVehicle(_ vehicle: AppVehicle, completion: @escaping (Bool, String?) -> Void) {
        guard let config = config, config.isValid, config.isEnabled else {
            completion(false, "Samsara integration not enabled or invalid configuration")
            return
        }
        
        guard vehicle.isTrackedBySamsara, vehicle.samsaraVehicleId != nil else {
            completion(false, "Vehicle is not tracked by Samsara")
            return
        }
        
        isLoading = true
        
        // In a real implementation, this would:
        // 1. Fetch the specific vehicle data from Samsara API
        // 2. Update local vehicle with mileage and location data
        
        // For demonstration, we'll simulate a successful sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            
            // Update vehicle with simulated data
            let newMileage = vehicle.mileage + Int.random(in: 10...100)
            let locations = ["San Francisco, CA", "Los Angeles, CA", "New York, NY", "Chicago, IL", "Houston, TX"]
            let randomLocation = locations[Int.random(in: 0..<locations.count)]
            
            vehicle.updateMileageFromSamsara(newMileage: newMileage, location: randomLocation)
            
            if let modelContext = self.modelContext {
                do {
                    try modelContext.save()
                } catch {
                    completion(false, "Failed to save vehicle data: \(error.localizedDescription)")
                    return
                }
            }
            
            completion(true, nil)
        }
    }
    
    // Update all vehicles with simulated data
    private func updateVehiclesWithSimulatedData() {
        guard let modelContext = modelContext else {
            return
        }
        
        do {
            // Get all vehicles that are tracked by Samsara
            let predicate = #Predicate<AppVehicle> { $0.isTrackedBySamsara }
            let vehicles = try modelContext.fetch(FetchDescriptor<AppVehicle>(predicate: predicate))
            
            for vehicle in vehicles {
                // Generate random mileage increase
                let newMileage = vehicle.mileage + Int.random(in: 10...100)
                
                // Generate random location
                let locations = ["San Francisco, CA", "Los Angeles, CA", "New York, NY", "Chicago, IL", "Houston, TX"]
                let randomLocation = locations[Int.random(in: 0..<locations.count)]
                
                vehicle.updateMileageFromSamsara(newMileage: newMileage, location: randomLocation)
            }
            
            try modelContext.save()
        } catch {
            print("Failed to update vehicles with simulated data: \(error.localizedDescription)")
        }
    }
    
    private func trackVehiclesInModelContext() {
        guard let modelContext = modelContext else { return }
        
        do {
            // Get vehicles that are configured for Samsara tracking
            let descriptor = FetchDescriptor<AppVehicle>(
                predicate: #Predicate<AppVehicle> { vehicle in
                    vehicle.isTrackedBySamsara == true
                }
            )
            let vehicles = try modelContext.fetch(descriptor)
            
            // Start tracking each vehicle
            for vehicle in vehicles {
                startTracking(vehicle: vehicle)
            }
        } catch {
            print("Failed to fetch vehicles for Samsara tracking: \(error)")
        }
    }
    
    // Add method to start tracking a vehicle
    private func startTracking(vehicle: AppVehicle) {
        print("Started tracking vehicle: \(vehicle.make) \(vehicle.model)")
        // In a real app, this would set up real-time tracking for the vehicle
    }
} 