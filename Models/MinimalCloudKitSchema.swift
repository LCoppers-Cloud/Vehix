import Foundation
import SwiftData
import CloudKit

// MARK: - Minimal CloudKit Schema for Testing

/// Minimal schema with just essential models for CloudKit testing
/// This reduces complexity and allows step-by-step CloudKit integration
let minimalCloudKitSchema = Schema([
    // Start with just basic user and vehicle models
    AuthUser.self,
    Vehix.Vehicle.self,
    
    // Add basic inventory
    Vehix.InventoryItem.self,
    
    // Essential app settings
    AppSettings.self
], version: .init(1, 0, 0))

// MARK: - CloudKit Configuration Functions

/// Creates a minimal CloudKit configuration for testing
func createMinimalCloudKitConfiguration() -> ModelConfiguration {
    return ModelConfiguration(
        schema: minimalCloudKitSchema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .private("iCloud.com.lcoppers.Vehix")
    )
}

/// Creates a local-only configuration using minimal schema
func createMinimalLocalConfiguration() -> ModelConfiguration {
    return ModelConfiguration(
        schema: minimalCloudKitSchema,
        isStoredInMemoryOnly: false
    )
}

// MARK: - CloudKit Testing Helper

@MainActor
class CloudKitTester: ObservableObject {
    @Published var testResults: [String] = []
    @Published var isTestingCloudKit = false
    
    /// Test CloudKit connectivity with minimal schema
    func testCloudKitConnection() async {
        isTestingCloudKit = true
        testResults.removeAll()
        
        do {
            // Test 1: Create minimal container
            testResults.append("✅ Testing minimal CloudKit container...")
            let container = try ModelContainer(for: minimalCloudKitSchema, configurations: [createMinimalCloudKitConfiguration()])
            testResults.append("✅ Minimal CloudKit container created successfully")
            
            // Test 2: Create context
            let context = ModelContext(container)
            testResults.append("✅ Model context created")
            
            // Test 3: Try to save empty changes
            try context.save()
            testResults.append("✅ Empty save operation successful")
            
            // Test 4: Test CloudKit account status
            let ckContainer = CKContainer(identifier: "iCloud.com.lcoppers.Vehix")
            let accountStatus = try await ckContainer.accountStatus()
            
            switch accountStatus {
            case .available:
                testResults.append("✅ CloudKit account available")
            case .noAccount:
                testResults.append("❌ No iCloud account signed in")
            case .restricted:
                testResults.append("❌ iCloud account restricted")
            case .couldNotDetermine:
                testResults.append("⚠️ Could not determine iCloud status")
            case .temporarilyUnavailable:
                testResults.append("⚠️ iCloud temporarily unavailable")
            @unknown default:
                testResults.append("⚠️ Unknown iCloud status")
            }
            
        } catch {
            testResults.append("❌ CloudKit test failed: \(error.localizedDescription)")
        }
        
        isTestingCloudKit = false
    }
    
    /// Test creating a simple record
    func testCreateRecord() async {
        guard !isTestingCloudKit else { return }
        
        do {
            let container = try ModelContainer(for: minimalCloudKitSchema, configurations: [createMinimalCloudKitConfiguration()])
            let context = ModelContext(container)
            
            // Create a test vehicle
            let testVehicle = Vehix.Vehicle(
                make: "Test",
                model: "CloudKit Test",
                year: 2024,
                vin: "TEST123456789",
                licensePlate: "TEST001"
            )
            
            context.insert(testVehicle)
            try context.save()
            
            testResults.append("✅ Test vehicle created and saved")
            
        } catch {
            testResults.append("❌ Failed to create test record: \(error.localizedDescription)")
        }
    }
}

// MARK: - CloudKit Testing View

import SwiftUI

struct CloudKitTestingView: View {
    @StateObject private var tester = CloudKitTester()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("CloudKit Testing")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Test CloudKit integration with minimal schema")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 10) {
                    Button("Test CloudKit Connection") {
                        Task {
                            await tester.testCloudKitConnection()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tester.isTestingCloudKit)
                    
                    Button("Test Create Record") {
                        Task {
                            await tester.testCreateRecord()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(tester.isTestingCloudKit)
                    
                    if tester.isTestingCloudKit {
                        ProgressView("Testing...")
                    }
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(tester.testResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(result.hasPrefix("✅") ? .green : 
                                               result.hasPrefix("❌") ? .red : .orange)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("CloudKit Testing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
} 