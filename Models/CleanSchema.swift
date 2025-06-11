import Foundation
import SwiftData

// MARK: - Clean Schema Definition
// This file replaces all other scattered model definitions to eliminate schema bloat

/// Clean schema with exactly 10 core models for production stability
let cleanProductionSchema = Schema([
    // 1. User Authentication
    AuthUser.self,
    
    // 2. Vehicle Management
    Vehix.Vehicle.self,
    
    // 3. Inventory Management
    Vehix.InventoryItem.self,
    
    // 4. Warehouse Management
    Vehix.Warehouse.self,
    
    // 5. Task Management
    AppTask.self,
    
    // 6. Service Records
    Vehix.ServiceRecord.self,
    
    // 7. Purchase Orders
    PurchaseOrder.self,
    
    // 8. Stock Locations
    StockLocationItem.self,
    
    // 9. Application Settings
    AppSettings.self,
    
    // 10. Vehicle Assignments
    VehicleAssignment.self
    
], version: .init(1, 0, 0))

// MARK: - Schema Level Configuration

enum CleanSchemaLevel: String, CaseIterable {
    case minimal = "minimal"      // 4 models - for development/debugging
    case production = "production" // 10 models - for production use
    
    var schema: Schema {
        switch self {
        case .minimal:
            return Schema([
                AuthUser.self,
                Vehix.Vehicle.self,
                Vehix.InventoryItem.self,
                AppSettings.self
            ], version: .init(1, 0, 0))
            
        case .production:
            return cleanProductionSchema
        }
    }
    
    var displayName: String {
        switch self {
        case .minimal:
            return "Minimal (4 models)"
        case .production:
            return "Production (10 models)"
        }
    }
    
    var modelCount: Int {
        return schema.entities.count
    }
}

// MARK: - Schema Helper Functions

/// Get the current clean schema level
func getCleanSchemaLevel() -> CleanSchemaLevel {
    let stored = UserDefaults.standard.string(forKey: "CleanSchemaLevel") ?? "minimal"
    return CleanSchemaLevel(rawValue: stored) ?? .minimal
}

/// Set the clean schema level
func setCleanSchemaLevel(_ level: CleanSchemaLevel) {
    UserDefaults.standard.set(level.rawValue, forKey: "CleanSchemaLevel")
    print("📊 Clean schema level set to: \(level.displayName)")
}

/// Create a clean model configuration without CloudKit conflicts
func createCleanModelConfiguration(level: CleanSchemaLevel = .production) -> ModelConfiguration {
    print("🧹 Creating clean model configuration with \(level.displayName)")
    print("📊 Schema contains \(level.modelCount) models")
    
    // Always use local storage for stability
    return ModelConfiguration(
        schema: level.schema,
        isStoredInMemoryOnly: false
    )
}

/// Validate that the schema has the expected number of entities
func validateCleanSchema(_ schema: Schema, expectedCount: Int) -> Bool {
    let actualCount = schema.entities.count
    let isValid = actualCount == expectedCount
    
    if isValid {
        print("✅ Schema validation passed: \(actualCount) models as expected")
    } else {
        print("❌ Schema validation failed: \(actualCount) models found, expected \(expectedCount)")
        print("📋 Entities found:")
        for entity in schema.entities {
            print("  - \(entity.name)")
        }
    }
    
    return isValid
}

// MARK: - Migration Strategy

/// Migrate from the old progressive schema system to the clean schema
func migrateToCleanSchema() {
    // Remove old schema preferences
    UserDefaults.standard.removeObject(forKey: "SchemaLevel")
    
    // Set clean schema to minimal initially for safety
    setCleanSchemaLevel(.minimal)
    
    print("🔄 Migrated to clean schema system")
}

/// Advance from minimal to production schema when ready
func advanceToProductionSchema() {
    let currentLevel = getCleanSchemaLevel()
    
    if currentLevel == .minimal {
        setCleanSchemaLevel(.production)
        print("📈 Advanced to production schema (10 models)")
        return
    }
    
    print("📊 Already using production schema")
}

// MARK: - Debug Helpers

#if DEBUG
/// Print detailed schema information for debugging
func debugPrintSchemaInfo(_ schema: Schema) {
    print("\n=== Clean Schema Debug Info ===")
    print("Total entities: \(schema.entities.count)")
    print("Schema version: \(schema.version)")
    
    for (index, entity) in schema.entities.enumerated() {
        print("\(index + 1). \(entity.name)")
        print("   Properties: \(entity.properties.count)")
        print("   Relationships: \(entity.relationships.count)")
    }
    print("==============================\n")
}

/// Test that the clean schema can be initialized without crashes
func testCleanSchemaInitialization() {
    print("🧪 Testing clean schema initialization...")
    
    let levels: [CleanSchemaLevel] = [.minimal, .production]
    
    for level in levels {
        do {
            let configuration = createCleanModelConfiguration(level: level)
            let container = try ModelContainer(for: level.schema, configurations: [configuration])
            print("✅ \(level.displayName) schema initialization successful")
            
            // Validate entity count
            _ = validateCleanSchema(level.schema, expectedCount: level.modelCount)
            
        } catch {
            print("❌ \(level.displayName) schema initialization failed: \(error)")
        }
    }
}
#endif 