import Foundation
import SwiftData

// MARK: - Ultra Minimal Schema for Crash Debugging

/// Ultra minimal schema with just one simple model
/// This is to isolate the exact cause of the ModelContainer crash
let ultraMinimalSchema = Schema([
    // Just one simple model to test
    AppSettings.self
], version: .init(1, 0, 0))

// MARK: - Simple Test Model

@Model
final class TestModel {
    var id: String = UUID().uuidString
    var name: String = ""
    var createdAt: Date = Date()
    
    init(id: String = UUID().uuidString, name: String = "", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

/// Even simpler schema with just a test model
let simpleTestSchema = Schema([
    TestModel.self
], version: .init(1, 0, 0))

// MARK: - Schema Testing Functions

/// Test different schemas to identify the problematic one
func testSchemaCreation() {
    print("🧪 Testing schema creation...")
    
    let testCases: [(String, Schema)] = [
        ("Ultra minimal schema (AppSettings)", ultraMinimalSchema),
        ("Simple test schema (TestModel)", simpleTestSchema),
        ("Minimal CloudKit schema", minimalCloudKitSchema)
    ]
    
    var successCount = 0
    var failureCount = 0
    
    for (name, schema) in testCases {
        do {
            _ = try ModelContainer(for: schema)
            print("✅ \(name) works")
            successCount += 1
        } catch {
            print("❌ \(name) failed: \(error)")
            failureCount += 1
        }
    }
    
    print("📊 Schema Test Results: \(successCount) passed, \(failureCount) failed")
}

/// Test a specific schema with CloudKit configuration
func testSchemaWithCloudKit(_ schema: Schema, name: String) {
    print("☁️ Testing \(name) with CloudKit...")
    
    do {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.lcoppers.Vehix")
        )
        _ = try ModelContainer(for: schema, configurations: config)
        print("✅ \(name) works with CloudKit")
    } catch {
        print("❌ \(name) failed with CloudKit: \(error)")
    }
}

/// Comprehensive schema testing including CloudKit
func comprehensiveSchemaTest() {
    print("🔬 Running comprehensive schema tests...")
    print(String(repeating: "=", count: 50))
    
    // Test basic schema creation
    testSchemaCreation()
    
    print("\n" + String(repeating: "=", count: 50))
    print("Testing with CloudKit...")
    
    // Test with CloudKit
    testSchemaWithCloudKit(ultraMinimalSchema, name: "Ultra minimal schema")
    testSchemaWithCloudKit(simpleTestSchema, name: "Simple test schema")
    testSchemaWithCloudKit(minimalCloudKitSchema, name: "Minimal CloudKit schema")
    
    print(String(repeating: "=", count: 50))
}

// MARK: - Debug Utilities

/// Create test data in the ultra minimal schema
func createTestData(in container: ModelContainer) {
    let context = ModelContext(container)
    
    do {
        // Create test model instance
        let testModel = TestModel(name: "Test Entry \(Date())")
        context.insert(testModel)
        
        // Try to save
        try context.save()
        print("✅ Test data created successfully")
    } catch {
        print("❌ Failed to create test data: \(error)")
    }
}

/// Get diagnostic information about the current schema state
func getSchemaDiagnostics() -> String {
    var diagnostics = "📋 Schema Diagnostics:\n"
    diagnostics += "- Ultra Minimal Schema Models: \(ultraMinimalSchema.entities.map { $0.name }.joined(separator: ", "))\n"
    diagnostics += "- Simple Test Schema Models: \(simpleTestSchema.entities.map { $0.name }.joined(separator: ", "))\n"
    diagnostics += "- Current App Schema: Using minimal CloudKit schema\n"
    diagnostics += "- CloudKit Container: iCloud.com.lcoppers.Vehix\n"
    return diagnostics
} 