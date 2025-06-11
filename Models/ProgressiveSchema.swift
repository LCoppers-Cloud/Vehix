import Foundation
import SwiftData

// MARK: - Progressive Schema Expansion

/// Step-by-step schema expansion to safely add back full functionality
/// This allows us to identify which specific models cause issues

// Step 0: Minimal schema (same as minimalCloudKitSchema from other file)
let minimalSchema = Schema([
    AuthUser.self,
    Vehix.Vehicle.self,
    Vehix.InventoryItem.self,
    AppSettings.self
], version: .init(1, 0, 0))

// Step 1: Core models only (WORKING)
let coreSchema = Schema([
    AuthUser.self,
    Vehix.Vehicle.self,
    Vehix.InventoryItem.self,
    AppSettings.self
], version: .init(1, 0, 0))

// Step 2: Add business and user management
let businessSchema = Schema([
    AuthUser.self,
    Vehix.Vehicle.self,
    Vehix.InventoryItem.self,
    AppSettings.self,
    // Add business models
    BusinessAccount.self,
    UserAccount.self,
    FirstTimeSetupState.self,
    // Add AI shared data models for machine learning (CloudKit-compatible with default values)
    SharedVendorData.self,
    SharedInventoryPattern.self,
    SharedReceiptPattern.self
], version: .init(1, 1, 2))

// Step 3: Add inventory management
let inventorySchema = Schema([
    AuthUser.self,
    Vehix.Vehicle.self,
    Vehix.InventoryItem.self,
    AppSettings.self,
    BusinessAccount.self,
    UserAccount.self,
    FirstTimeSetupState.self,
    SharedVendorData.self,
    SharedInventoryPattern.self,
    SharedReceiptPattern.self,
    // Add inventory models
    StockLocationItem.self,
    Vehix.Warehouse.self,
    PendingTransfer.self,
    Receipt.self,
    ReceiptItem.self,
    Vehix.Vendor.self
], version: .init(1, 2, 2))

// Step 4: Add vehicle relationships and tracking
let vehicleTrackingSchema = Schema([
    AuthUser.self,
    Vehix.Vehicle.self,
    Vehix.InventoryItem.self,
    AppSettings.self,
    BusinessAccount.self,
    UserAccount.self,
    FirstTimeSetupState.self,
    SharedVendorData.self,
    SharedInventoryPattern.self,
    SharedReceiptPattern.self,
    StockLocationItem.self,
    Vehix.Warehouse.self,
    PendingTransfer.self,
    Receipt.self,
    ReceiptItem.self,
    Vehix.Vendor.self,
    // Add vehicle relationships
    VehicleAssignment.self,
    Vehix.ServiceRecord.self,
    AppTask.self,
    AppSubtask.self
], version: .init(1, 3, 2))

// Step 5: Add GPS tracking (this might be the problematic one)
let gpsTrackingSchema = Schema([
    AuthUser.self,
    Vehix.Vehicle.self,
    Vehix.InventoryItem.self,
    AppSettings.self,
    BusinessAccount.self,
    UserAccount.self,
    FirstTimeSetupState.self,
    SharedVendorData.self,
    SharedInventoryPattern.self,
    SharedReceiptPattern.self,
    StockLocationItem.self,
    Vehix.Warehouse.self,
    PendingTransfer.self,
    Receipt.self,
    ReceiptItem.self,
    Vehix.Vendor.self,
    VehicleAssignment.self,
    Vehix.ServiceRecord.self,
    AppTask.self,
    AppSubtask.self,
    // Add GPS tracking models (potential crash source)
    VehicleTrackingSession.self,
    VehicleTrackingPoint.self,
    GPSConsentRecord.self,
    WorkHoursConfiguration.self
], version: .init(1, 4, 2))

// Step 6: Full schema (complete)
let fullSchema = Schema([
    AuthUser.self,
    Vehix.Vehicle.self,
    Vehix.InventoryItem.self,
    AppSettings.self,
    BusinessAccount.self,
    UserAccount.self,
    FirstTimeSetupState.self,
    SharedVendorData.self,
    SharedInventoryPattern.self,
    SharedReceiptPattern.self,
    StockLocationItem.self,
    Vehix.Warehouse.self,
    PendingTransfer.self,
    Receipt.self,
    ReceiptItem.self,
    Vehix.Vendor.self,
    VehicleAssignment.self,
    Vehix.ServiceRecord.self,
    AppTask.self,
    AppSubtask.self,
    VehicleTrackingSession.self,
    VehicleTrackingPoint.self,
    GPSConsentRecord.self,
    WorkHoursConfiguration.self,
    // Add purchase order models
    PurchaseOrder.self,
    PurchaseOrderLineItem.self
], version: .init(1, 5, 2))

// MARK: - Schema Testing Functions

/// Test progressive schema expansion to find the breaking point
func testProgressiveSchemas() {
    print("🔬 Testing progressive schema expansion...")
    
    let schemas = [
        ("Core", coreSchema),
        ("Business", businessSchema),
        ("Inventory", inventorySchema),
        ("Vehicle Tracking", vehicleTrackingSchema),
        ("GPS Tracking", gpsTrackingSchema),
        ("Full", fullSchema)
    ]
    
    for (name, schema) in schemas {
        do {
            _ = try ModelContainer(for: schema)
            print("✅ \(name) schema works (\(schema.entities.count) models)")
        } catch {
            print("❌ \(name) schema failed: \(error)")
            break // Stop at first failure
        }
    }
}

// MARK: - Schema Selection Helper

enum SchemaLevel: String, CaseIterable {
    case minimal = "minimal"
    case core = "core"
    case business = "business"
    case inventory = "inventory"
    case vehicleTracking = "vehicleTracking"
    case gpsTracking = "gpsTracking"
    case full = "full"
    
    var schema: Schema {
        switch self {
        case .minimal:
            return minimalSchema
        case .core:
            return coreSchema
        case .business:
            return businessSchema
        case .inventory:
            return inventorySchema
        case .vehicleTracking:
            return vehicleTrackingSchema
        case .gpsTracking:
            return gpsTrackingSchema
        case .full:
            return fullSchema
        }
    }
    
    var displayName: String {
        switch self {
        case .minimal:
            return "Minimal (4 models)"
        case .core:
            return "Core (4 models)"
        case .business:
            return "Business (10 models)"
        case .inventory:
            return "Inventory (16 models)"
        case .vehicleTracking:
            return "Vehicle Tracking (20 models)"
        case .gpsTracking:
            return "GPS Tracking (24 models)"
        case .full:
            return "Full (26 models)"
        }
    }
}

/// Get current schema level from UserDefaults
func getCurrentSchemaLevel() -> SchemaLevel {
    let stored = UserDefaults.standard.string(forKey: "SchemaLevel") ?? "minimal"
    return SchemaLevel(rawValue: stored) ?? .minimal
}

/// Set current schema level
func setCurrentSchemaLevel(_ level: SchemaLevel) {
    UserDefaults.standard.set(level.rawValue, forKey: "SchemaLevel")
    print("📊 Schema level set to: \(level.displayName)")
}

/// Advance to next schema level for testing
func advanceToNextSchemaLevel() -> SchemaLevel? {
    let current = getCurrentSchemaLevel()
    let allLevels = SchemaLevel.allCases
    
    if let currentIndex = allLevels.firstIndex(of: current),
       currentIndex + 1 < allLevels.count {
        let nextLevel = allLevels[currentIndex + 1]
        setCurrentSchemaLevel(nextLevel)
        return nextLevel
    }
    return nil
}

/// Test if a schema level works with CloudKit
func testSchemaLevel(_ level: SchemaLevel) -> (success: Bool, error: String?) {
    do {
        _ = try ModelContainer(for: level.schema)
        return (true, nil)
    } catch {
        return (false, error.localizedDescription)
    }
} 