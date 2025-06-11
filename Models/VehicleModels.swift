import Foundation
import SwiftData
import CloudKit

// VehicleType enum for all vehicle-related code
public enum VehicleType: String, Codable, CaseIterable {
    case gas = "Gas"
    case diesel = "Diesel"
    case hybrid = "Hybrid"
    case electric = "Electric"
}

// All models consolidated in a single file to avoid ambiguity

// Create a namespace to avoid ambiguity with models declared in other files
public enum Vehix {
    // Vehicle model - represents a vehicle in the system
    @Model
    public final class Vehicle: Identifiable {
        public var id: String = UUID().uuidString
        public var make: String = ""
        public var model: String = ""
        public var year: Int = 0
        public var vin: String = ""
        public var licensePlate: String?
        public var color: String?
        public var vehicleType: String = VehicleType.gas.rawValue // Added vehicleType property
        public var mileage: Int = 0
        public var lastServiceDate: Date?
        public var notes: String?
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        public var ownerId: String? // Can be null for shop-owned vehicles
        
        // CloudKit sync properties
        public var cloudKitRecordID: String?
        public var cloudKitSyncStatus: Int16 = 0 // Default to needs upload
        public var cloudKitSyncDate: Date?
        
        // Oil change tracking
        public var lastOilChangeDate: Date?
        public var lastOilChangeMileage: Int?
        public var oilChangeIntervalMiles: Int = 5000 // Default 5,000 miles
        public var oilChangeIntervalMonths: Int = 6 // Default 6 months
        
        // Samsara integration
        public var samsaraDeviceId: String?
        public var samsaraVehicleId: String?
        public var isTrackedBySamsara: Bool = false
        public var lastMileageUpdateDate: Date?
        public var lastKnownLocation: String?
        public var lastLocationUpdateDate: Date?
        
        // ServiceTitan integration
        public var serviceTitanEquipmentId: String?
        public var serviceTitanCustomerId: String?
        public var isTrackedByServiceTitan: Bool = false
        
        // Photo data property
        public var photoData: Data?
        
        // Relationships - using explicit Vehix namespace to avoid ambiguity
        @Relationship(inverse: \Vehix.ServiceRecord.vehicle)
        var serviceRecords: [Vehix.ServiceRecord]? = nil
        
        // Renamed from inventoryItems to stockItems for clarity with new model
        /// Stock items currently located in this vehicle.
        @Relationship(inverse: \StockLocationItem.vehicle)
        var stockItems: [StockLocationItem]? = []
        
        // Tasks associated with this vehicle
        @Relationship(deleteRule: .cascade)
        var tasks: [AppTask]? = []
        
        /// Inverse relationship for pending transfers to this vehicle
        @Relationship(inverse: \PendingTransfer.toVehicle)
        var pendingTransfers: [PendingTransfer]? = []
        
        /// Inverse relationship for vehicle assignments
        @Relationship(inverse: \VehicleAssignment.vehicle)
        var assignments: [VehicleAssignment]? = []
        
        // Computed properties
        public var totalInventoryValue: Double {
            var sum: Double = 0.0
            if let items = stockItems {
                for item in items {
                    if let inventoryItem = item.inventoryItem {
                        sum += Double(item.quantity) * inventoryItem.pricePerUnit
                    }
                }
            }
            return sum
        }
        
        public var displayName: String {
            "\(year) \(make) \(model) - \(licensePlate ?? "No Plate")"
        }
        
        // Oil change status computed properties
        public var nextOilChangeDueDate: Date? {
            guard let lastDate = lastOilChangeDate else { return nil }
            return Calendar.current.date(byAdding: .month, value: oilChangeIntervalMonths, to: lastDate)
        }
        
        public var nextOilChangeDueMileage: Int? {
            guard let lastMileage = lastOilChangeMileage else { return nil }
            return lastMileage + oilChangeIntervalMiles
        }
        
        public var isOilChangeDue: Bool {
            if let dueDate = nextOilChangeDueDate, Date() > dueDate {
                return true
            }
            if let dueMileage = nextOilChangeDueMileage, mileage >= dueMileage {
                return true
            }
            return false
        }
        
        public var oilChangeDueStatus: String {
            if isOilChangeDue {
                return "Due Now"
            } else if let nextDate = nextOilChangeDueDate, let nextMileage = nextOilChangeDueMileage {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.day], from: Date(), to: nextDate)
                let daysUntilDue = components.day ?? 0
                
                if daysUntilDue <= 14 {
                    return "Due Soon: \(daysUntilDue) days or \(nextMileage - mileage) miles"
                } else {
                    return "OK: Due in \(daysUntilDue) days or \(nextMileage - mileage) miles"
                }
            }
            return "Unknown"
        }
        
        // Initialize a new vehicle
        init(
            id: String = UUID().uuidString,
            make: String = "",
            model: String = "",
            year: Int = 0,
            vin: String = "",
            licensePlate: String? = nil,
            color: String? = nil,
            mileage: Int = 0,
            lastServiceDate: Date? = nil,
            notes: String? = nil,
            ownerId: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            lastOilChangeDate: Date? = nil,
            lastOilChangeMileage: Int? = nil,
            oilChangeIntervalMiles: Int = 5000,
            oilChangeIntervalMonths: Int = 6,
            samsaraDeviceId: String? = nil,
            samsaraVehicleId: String? = nil,
            isTrackedBySamsara: Bool = false,
            serviceTitanEquipmentId: String? = nil,
            serviceTitanCustomerId: String? = nil,
            isTrackedByServiceTitan: Bool = false,
            photoData: Data? = nil,
            serviceRecords: [Vehix.ServiceRecord]? = nil,
            stockItems: [StockLocationItem]? = nil
        ) {
            self.id = id
            self.make = make
            self.model = model
            self.year = year
            self.vin = vin
            self.licensePlate = licensePlate
            self.color = color
            self.mileage = mileage
            self.lastServiceDate = lastServiceDate
            self.notes = notes
            self.ownerId = ownerId
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.lastOilChangeDate = lastOilChangeDate
            self.lastOilChangeMileage = lastOilChangeMileage
            self.oilChangeIntervalMiles = oilChangeIntervalMiles
            self.oilChangeIntervalMonths = oilChangeIntervalMonths
            self.samsaraDeviceId = samsaraDeviceId
            self.samsaraVehicleId = samsaraVehicleId
            self.isTrackedBySamsara = isTrackedBySamsara
            self.serviceTitanEquipmentId = serviceTitanEquipmentId
            self.serviceTitanCustomerId = serviceTitanCustomerId
            self.isTrackedByServiceTitan = isTrackedByServiceTitan
            self.photoData = photoData
            self.serviceRecords = serviceRecords
            self.stockItems = stockItems
        }
        
        // Update mileage from Samsara
        public func updateMileageFromSamsara(newMileage: Int, location: String? = nil) {
            self.mileage = newMileage
            self.lastMileageUpdateDate = Date()
            
            if let location = location {
                self.lastKnownLocation = location
                self.lastLocationUpdateDate = Date()
            }
            
            self.updatedAt = Date()
        }
        
        // Record an oil change
        public func recordOilChange(mileage: Int, date: Date = Date()) {
            self.lastOilChangeDate = date
            self.lastOilChangeMileage = mileage
            self.lastServiceDate = date
            self.updatedAt = Date()
        }
        
        // CloudKit sync methods
        public func markPendingUpload() {
            self.cloudKitSyncStatus = 1 // pending upload
        }
        
        public func markSynced() {
            self.cloudKitSyncStatus = 2 // synced
            self.cloudKitSyncDate = Date()
        }
        
        public func markSyncFailed() {
            self.cloudKitSyncStatus = 3 // sync failed
        }
    }

    // Inventory Item model - represents the *definition* of parts or supplies
    @Model
    public final class InventoryItem {
        public var id: String = UUID().uuidString // Keep unique ID for the item definition
        public var name: String = "" // Item name (e.g., "Oil Filter")
        public var partNumber: String = "" // Manufacturer or internal part number
        public var calloutNumber: String? // Specific callout/reference number
        public var itemDescription: String? // Detailed description
        public var category: String = "" // Category (e.g., "Filters", "Brakes")
        public var pricePerUnit: Double = 0.0 // Standard price per unit
        public var supplier: String? // Default or preferred supplier
        public var barcodeData: String? // Stored barcode/QR code data
        public var photoData: Data? // Photo of the item
        public var isActive: Bool = true // Whether the item is active or deactivated
        
        // Removed: quantity, minimumStockLevel, maxStockLevel, location, warehouseId, vehicleId
        // These are now managed per location in StockLocationItem

        // Unit of measure (e.g., "each", "box", "liter")
        public var unit: String = "each"
        
        // Timestamps for the item definition itself
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        
        // CloudKit sync properties (for the item definition)
        public var cloudKitRecordID: String?
        public var cloudKitSyncStatus: Int16 = 0
        public var cloudKitSyncDate: Date?
        
        // MARK: - Relationships
        
        /// Link to all the locations where this item exists.
        @Relationship(inverse: \StockLocationItem.inventoryItem)
        var stockLocationItems: [StockLocationItem]? = []
        
        /// Links to the join model for service records
        @Relationship(deleteRule: .cascade)
        var serviceLinks: [Vehix.InventoryServiceLink]? = []
        
        /// Inverse relationship for pending transfers
        @Relationship(inverse: \PendingTransfer.inventoryItem)
        var pendingTransfers: [PendingTransfer]? = []
        
        /// Convenience computed property to access service records through the join model
        var serviceRecords: [Vehix.ServiceRecord]? {
            get {
                return serviceLinks?.compactMap { $0.serviceRecord }
            }
        }
        

        
        // MARK: - Computed Properties
        
        /// Calculates the total quantity of this item across all stock locations.
        public var stockTotalQuantity: Int {
            (stockLocationItems ?? []).reduce(0) { $0 + $1.quantity }
        }
        
        // Removed: isLowStock (now checked per StockLocationItem)
        // Removed: totalValue (now calculated based on StockLocationItems if needed)
        
        // MARK: - Initialization
        
        /// Initializes a new inventory item definition.
        init(
            id: String = UUID().uuidString,
            name: String = "",
            partNumber: String = "",
            calloutNumber: String? = nil,
            itemDescription: String? = nil,
            category: String = "",
            pricePerUnit: Double = 0.0,
            supplier: String? = nil,
            barcodeData: String? = nil,
            photoData: Data? = nil,
            isActive: Bool = true,
            unit: String = "each",
            // Removed quantity, min/max stock, location parameters
            cloudKitRecordID: String? = nil,
            cloudKitSyncStatus: Int16 = 0,
            cloudKitSyncDate: Date? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            serviceLinks: [Vehix.InventoryServiceLink]? = nil
        ) {
            self.id = id
            self.name = name
            self.partNumber = partNumber
            self.calloutNumber = calloutNumber
            self.itemDescription = itemDescription
            self.category = category
            self.pricePerUnit = pricePerUnit
            self.supplier = supplier
            self.barcodeData = barcodeData
            self.photoData = photoData
            self.isActive = isActive
            self.unit = unit
            self.cloudKitRecordID = cloudKitRecordID
            self.cloudKitSyncStatus = cloudKitSyncStatus
            self.cloudKitSyncDate = cloudKitSyncDate
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.serviceLinks = serviceLinks
            // Note: stockLocations relationship is managed separately
        }
        
        // CloudKit sync methods (remain the same for the item definition)
        public func markPendingUpload() {
            self.cloudKitSyncStatus = 1 // pending upload
        }
        
        public func markSynced() {
            self.cloudKitSyncStatus = 2 // synced
            self.cloudKitSyncDate = Date()
        }
        
        public func markSyncFailed() {
            self.cloudKitSyncStatus = 3 // sync failed
        }
    }

    // Service Record model - represents a completed service on a vehicle
    @Model
    final class ServiceRecord {
        var id: String = UUID().uuidString
        var title: String = ""
        var serviceDescription: String = ""
        var startTime: Date = Date()
        var endTime: Date?
        var mileageAtService: Int?
        var partsCost: Double = 0.0
        var laborCost: Double = 0.0
        var totalCost: Double = 0.0
        var status: String = "Scheduled"
        var technicianId: String = ""
        var technicianName: String?
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        
        // CloudKit sync properties
        var cloudKitRecordID: String?
        var cloudKitSyncStatus: Int16 = 0 // Default to needs upload
        var cloudKitSyncDate: Date?
        
        // Relationships - using explicit Vehix namespace
        var vehicle: Vehix.Vehicle? = nil
        
        /// Links to the join model for inventory items
        @Relationship(deleteRule: .cascade)
        var inventoryLinks: [Vehix.InventoryServiceLink]? = []
        
        /// Convenience computed property to access inventory items through the join model
        var inventoryItems: [Vehix.InventoryItem]? {
            get {
                return inventoryLinks?.compactMap { $0.inventoryItem }
            }
        }
        
        // Old relationships - commented out to avoid circular references
        // var usedInventoryItems: [Vehix.InventoryItem]? = nil
        // var inventoryItemsUsed: [Vehix.InventoryItem]? = nil
        
        // Computed property for duration in minutes
        var durationMinutes: Int {
            guard let end = endTime else { return 0 }
            return Int(end.timeIntervalSince(startTime) / 60)
        }
        
        // Format duration as "Xh Ym"
        var formattedDuration: String {
            let minutes = durationMinutes
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            
            if hours > 0 {
                return "\(hours)h \(remainingMinutes)m"
            } else {
                return "\(remainingMinutes)m"
            }
        }
        
        // Initialize a new service record
        init(
            id: String = UUID().uuidString,
            title: String = "",
            serviceDescription: String = "",
            startTime: Date = Date(),
            endTime: Date? = nil,
            mileageAtService: Int? = nil,
            partsCost: Double = 0.0,
            laborCost: Double = 0.0,
            totalCost: Double = 0.0,
            status: String = "Scheduled",
            technicianId: String = "",
            technicianName: String? = nil,
            notes: String? = nil,
            vehicle: Vehix.Vehicle? = nil,
            inventoryLinks: [Vehix.InventoryServiceLink]? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.title = title
            self.serviceDescription = serviceDescription
            self.startTime = startTime
            self.endTime = endTime
            self.mileageAtService = mileageAtService
            self.partsCost = partsCost
            self.laborCost = laborCost
            self.totalCost = totalCost
            self.status = status
            self.technicianId = technicianId
            self.technicianName = technicianName
            self.notes = notes
            self.vehicle = vehicle
            self.inventoryLinks = inventoryLinks
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
        
        // CloudKit sync methods
        func markPendingUpload() {
            self.cloudKitSyncStatus = 1 // pending upload
        }
        
        func markSynced() {
            self.cloudKitSyncStatus = 2 // synced
            self.cloudKitSyncDate = Date()
        }
        
        func markSyncFailed() {
            self.cloudKitSyncStatus = 3 // sync failed
        }
    }
    
    // Vendor model - represents parts and supplies vendors
    @Model
    final class Vendor {
        var id: String = UUID().uuidString
        var name: String = ""
        var email: String = ""
        var phone: String?
        var address: String?
        var isActive: Bool = true
        var serviceTitanId: String?
        var syncedWithServiceTitan: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        
        /// Inverse relationship for receipts from this vendor
        @Relationship(inverse: \Receipt.vendor)
        var receipts: [Receipt]? = []
        
        init(
            id: String = UUID().uuidString,
            name: String,
            email: String,
            phone: String? = nil,
            address: String? = nil,
            isActive: Bool = true,
            serviceTitanId: String? = nil,
            syncedWithServiceTitan: Bool = false
        ) {
            self.id = id
            self.name = name
            self.email = email
            self.phone = phone
            self.address = address
            self.isActive = isActive
            self.serviceTitanId = serviceTitanId
            self.syncedWithServiceTitan = syncedWithServiceTitan
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
    
    // Warehouse model for warehouse locations
    @Model
    public final class Warehouse {
        public var id: String = UUID().uuidString
        public var name: String = ""
        public var location: String = ""
        public var warehouseDescription: String = ""
        public var isActive: Bool = true
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        
        // Enhanced warehouse properties
        public var address: String = ""
        public var latitude: Double?
        public var longitude: Double?
        public var photoData: Data?
        public var contactPhone: String = ""
        public var contactEmail: String = ""
        public var managerName: String = ""
        public var operatingHours: String = ""
        public var warehouseType: String = "standard" // standard, mobile, temporary
        public var securityLevel: String = "basic" // basic, enhanced, high
        public var capacity: Double = 0.0 // square footage or cubic meters
        public var utilizationRate: Double = 0.0 // percentage of capacity used
        public var monthlyOperatingCost: Double = 0.0
        public var isOnMap: Bool = true // show on map view
        public var allowVehicleTransfers: Bool = true
        public var requireManagerApproval: Bool = false
        public var autoReorderEnabled: Bool = false
        public var temperatureControlled: Bool = false
        public var hazardousMaterialsAllowed: Bool = false
        public var lastInspectionDate: Date?
        public var nextInspectionDue: Date?
        public var notes: String = ""
        
        /// Stock items currently located in this warehouse.
        @Relationship(inverse: \StockLocationItem.warehouse)
        var stockItems: [StockLocationItem]? = []
        
        /// Inverse relationship for pending transfers from this warehouse
        @Relationship(inverse: \PendingTransfer.fromWarehouse)
        var pendingTransfers: [PendingTransfer]? = []
        
        init(id: String = UUID().uuidString, name: String, location: String, warehouseDescription: String = "", address: String = "", latitude: Double? = nil, longitude: Double? = nil, isActive: Bool = true, createdAt: Date = Date()) {
            self.id = id
            self.name = name
            self.location = location
            self.warehouseDescription = warehouseDescription
            self.address = address
            self.latitude = latitude
            self.longitude = longitude
            self.isActive = isActive
            self.createdAt = createdAt
            self.updatedAt = Date()
        }
        
        // Computed property for display purposes
        public var displayInfo: String {
            var info = name
            if !address.isEmpty {
                info += " - \(address)"
            } else if !location.isEmpty {
                info += " - \(location)"
            }
            return info
        }
        
        // Computed property to check if warehouse has description
        public var hasDescription: Bool {
            !warehouseDescription.isEmpty
        }
        
        // Computed property for GPS coordinates
        public var hasCoordinates: Bool {
            latitude != nil && longitude != nil
        }
        
        // Computed property for coordinate display
        public var coordinateDisplay: String {
            guard let lat = latitude, let lon = longitude else { return "No GPS coordinates" }
            return String(format: "%.6f, %.6f", lat, lon)
        }
        
        // Computed property for address validation
        public var isAddressComplete: Bool {
            !address.isEmpty && hasCoordinates
        }
        
        // Computed property for warehouse status
        public var operationalStatus: String {
            if !isActive { return "Inactive" }
            if utilizationRate >= 0.9 { return "At Capacity" }
            if utilizationRate >= 0.7 { return "Near Capacity" }
            return "Operational"
        }
        
        // Method to update coordinates
        public func updateCoordinates(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
            self.updatedAt = Date()
        }
        
        // Method to update photo
        public func updatePhoto(data: Data?) {
            self.photoData = data
            self.updatedAt = Date()
        }
        
        // Method to calculate distance from another coordinate
        public func distanceFrom(latitude: Double, longitude: Double) -> Double? {
            guard let myLat = self.latitude, let myLon = self.longitude else { return nil }
            
            let lat1Radians = myLat * .pi / 180
            let lon1Radians = myLon * .pi / 180
            let lat2Radians = latitude * .pi / 180
            let lon2Radians = longitude * .pi / 180
            
            let deltaLat = lat2Radians - lat1Radians
            let deltaLon = lon2Radians - lon1Radians
            
            let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                    cos(lat1Radians) * cos(lat2Radians) *
                    sin(deltaLon / 2) * sin(deltaLon / 2)
            let c = 2 * atan2(sqrt(a), sqrt(1 - a))
            
            return 6371000 * c // Earth's radius in meters
        }
        
        // Method to validate warehouse data
        public func validate() -> [String] {
            var errors: [String] = []
            
            if name.isEmpty {
                errors.append("Warehouse name is required")
            }
            
            if address.isEmpty && location.isEmpty {
                errors.append("Address or location is required")
            }
            
            if hasCoordinates {
                guard let lat = latitude, let lon = longitude else {
                    errors.append("Invalid GPS coordinates")
                    return errors
                }
                
                if lat < -90 || lat > 90 {
                    errors.append("Latitude must be between -90 and 90 degrees")
                }
                
                if lon < -180 || lon > 180 {
                    errors.append("Longitude must be between -180 and 180 degrees")
                }
            }
            
            if capacity < 0 {
                errors.append("Capacity cannot be negative")
            }
            
            if utilizationRate < 0 || utilizationRate > 1 {
                errors.append("Utilization rate must be between 0 and 100%")
            }
            
            if monthlyOperatingCost < 0 {
                errors.append("Operating cost cannot be negative")
            }
            
            return errors
        }
    }
    
    // InventoryUsageRecord for tracking inventory consumption
    @Model
    final class InventoryUsageRecord {
        var id: String = UUID().uuidString
        // Make non-optional attributes either optional or provide defaults
        var inventoryItemId: String = "" // Default empty string
        var quantity: Int = 0 // Default to zero
        var timestamp: Date = Date()
        var technicianId: String?
        var vehicleId: String?
        var jobId: String?
        var notes: String?
        var photoEvidence: Data?
        
        init(id: String = UUID().uuidString, 
             inventoryItemId: String = "", 
             quantity: Int = 0,
             timestamp: Date = Date(),
             technicianId: String? = nil,
             vehicleId: String? = nil,
             jobId: String? = nil,
             notes: String? = nil) {
            self.id = id
            self.inventoryItemId = inventoryItemId
            self.quantity = quantity
            self.timestamp = timestamp
            self.technicianId = technicianId
            self.vehicleId = vehicleId
            self.jobId = jobId
            self.notes = notes
        }
    }

    // MARK: - Special Models for CloudKit compatibility
    
    // Add an intermediary model to handle many-to-many relationship between 
    // InventoryItem and ServiceRecord without circular references
    @Model
    final class InventoryServiceLink {
        var id: String = UUID().uuidString
        var createdAt: Date = Date()
        
        // Reference to the inventory item
        @Relationship(inverse: \Vehix.InventoryItem.serviceLinks)
        var inventoryItem: Vehix.InventoryItem? = nil
        
        // Reference to the service record
        @Relationship(inverse: \Vehix.ServiceRecord.inventoryLinks)
        var serviceRecord: Vehix.ServiceRecord? = nil
        
        // Additional metadata about the relationship
        var quantity: Int = 0
        var notes: String = ""
        
        init(id: String = UUID().uuidString,
             inventoryItem: Vehix.InventoryItem? = nil,
             serviceRecord: Vehix.ServiceRecord? = nil,
             quantity: Int = 0,
             notes: String = "",
             createdAt: Date = Date()) {
            self.id = id
            self.inventoryItem = inventoryItem
            self.serviceRecord = serviceRecord
            self.quantity = quantity
            self.notes = notes
            self.createdAt = createdAt
        }
    }
}

// Enum for vehicle search/filter options
enum VehicleSort: String, CaseIterable {
    case makeModelAsc = "Make/Model (A-Z)"
    case makeModelDesc = "Make/Model (Z-A)"
    case yearAsc = "Year (Oldest First)"
    case yearDesc = "Year (Newest First)"
    case mileageAsc = "Mileage (Low to High)"
    case mileageDesc = "Mileage (High to Low)"
    case lastServiceAsc = "Service Date (Oldest First)"
    case lastServiceDesc = "Service Date (Recent First)"
}

// Enum for inventory search/filter options
enum InventorySort: String, CaseIterable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case priceAsc = "Price (Low to High)"
    case priceDesc = "Price (High to Low)"
    case dateAddedAsc = "Date Added (Oldest First)"
    case dateAddedDesc = "Date Added (Newest First)"
    case categoryAsc = "Category (A-Z)"
    case categoryDesc = "Category (Z-A)"
}

// Helper class for implementing month-based reporting
class MonthlyReport {
    let month: Int
    let year: Int
    var totalInventoryValue: Double = 0
    var totalInventoryItems: Int = 0
    var vehiclesServiced: Int = 0
    var laborHours: Double = 0
    var laborRevenue: Double = 0
    var partsRevenue: Double = 0
    
    var totalRevenue: Double {
        laborRevenue + partsRevenue
    }
    
    var monthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = month
        components.year = year
        if let date = calendar.date(from: components) {
            return dateFormatter.string(from: date)
        }
        return "Unknown"
    }
    
    init(month: Int, year: Int) {
        self.month = month
        self.year = year
    }
}


