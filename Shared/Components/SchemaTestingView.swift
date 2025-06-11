import SwiftUI

struct SchemaTestingView: View {
    @State private var currentSchemaLevel = getCurrentSchemaLevel()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var testResults: [SchemaLevel: (success: Bool, error: String?)] = [:]
    @State private var isTestingInProgress = false
    @State private var cloudKitEnabled = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Schema Testing")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Current Schema: \(currentSchemaLevel.displayName)")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                VStack(spacing: 10) {
                    Text("⚠️ Developer Tool")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Use this to test different schema configurations and find issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // CloudKit Toggle
                Toggle("Enable CloudKit Testing", isOn: $cloudKitEnabled)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                // Current Schema Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Schema Details:")
                        .font(.headline)
                    
                    Text("• Models: \(currentSchemaLevel.schema.entities.count)")
                    Text("• CloudKit: \(cloudKitEnabled ? "Enabled" : "Disabled")")
                    Text("• Version: \(currentSchemaLevel.schema.version)")
                    
                    if let result = testResults[currentSchemaLevel] {
                        Text("• Status: \(result.success ? "✅ Working" : "❌ Failed")")
                            .foregroundColor(result.success ? .green : .red)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Test Buttons
                VStack(spacing: 12) {
                    Button("Test Current Schema") {
                        testCurrentSchema()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTestingInProgress)
                    
                    Button("Test All Schema Levels") {
                        testAllSchemaLevels()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingInProgress)
                    
                    Button("Advance to Next Level") {
                        advanceSchema()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingInProgress || currentSchemaLevel == .full)
                    
                    Button("Reset to Minimal") {
                        resetToMinimal()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingInProgress)
                    
                    // Ultra minimal testing buttons
                    Divider()
                    
                    Button("🧪 Run Ultra Minimal Tests") {
                        runUltraMinimalTests()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingInProgress)
                    
                    Button("🔬 Comprehensive Schema Test") {
                        runComprehensiveTests()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingInProgress)
                }
                
                // Test Results
                if !testResults.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Test Results:")
                                .font(.headline)
                            
                            ForEach(SchemaLevel.allCases, id: \.self) { level in
                                if let result = testResults[level] {
                                    HStack {
                                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(result.success ? .green : .red)
                                        
                                        Text(level.displayName)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        if !result.success, let error = result.error {
                                            Button("Details") {
                                                alertMessage = "Error in \(level.displayName):\n\n\(error)"
                                                showingAlert = true
                                            }
                                            .font(.caption)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                if isTestingInProgress {
                    ProgressView("Testing schemas...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Schema Testing")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Schema Test Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func testCurrentSchema() {
        isTestingInProgress = true
        
        Task {
            let result = testSchemaLevel(currentSchemaLevel)
            
            await MainActor.run {
                testResults[currentSchemaLevel] = result
                
                if result.success {
                    alertMessage = "✅ \(currentSchemaLevel.displayName) schema works perfectly!"
                } else {
                    alertMessage = "❌ \(currentSchemaLevel.displayName) schema failed:\n\n\(result.error ?? "Unknown error")"
                }
                
                showingAlert = true
                isTestingInProgress = false
            }
        }
    }
    
    private func testAllSchemaLevels() {
        isTestingInProgress = true
        testResults.removeAll()
        
        Task {
            for level in SchemaLevel.allCases {
                let result = testSchemaLevel(level)
                
                await MainActor.run {
                    testResults[level] = result
                }
                
                // Add small delay between tests
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                // Stop at first failure to identify the breaking point
                if !result.success {
                    await MainActor.run {
                        alertMessage = "❌ Schema testing stopped at \(level.displayName)\n\nFirst failure point identified. This helps narrow down the problematic models."
                        showingAlert = true
                    }
                    break
                }
            }
            
            await MainActor.run {
                isTestingInProgress = false
            }
        }
    }
    
    private func advanceSchema() {
        if let nextLevel = advanceToNextSchemaLevel() {
            currentSchemaLevel = nextLevel
            alertMessage = "🆙 Advanced to \(nextLevel.displayName)\n\n⚠️ App restart required to use new schema"
            showingAlert = true
        }
    }
    
    private func resetToMinimal() {
        setCurrentSchemaLevel(.minimal)
        currentSchemaLevel = .minimal
        testResults.removeAll()
        alertMessage = "🔄 Reset to minimal schema\n\n⚠️ App restart required"
        showingAlert = true
    }
    
    private func runUltraMinimalTests() {
        isTestingInProgress = true
        
        Task {
            await MainActor.run {
                // Run the ultra minimal schema tests
                testSchemaCreation()
                
                alertMessage = "🧪 Ultra minimal schema tests completed!\n\nCheck console for detailed results."
                showingAlert = true
                isTestingInProgress = false
            }
        }
    }
    
    private func runComprehensiveTests() {
        isTestingInProgress = true
        
        Task {
            await MainActor.run {
                // Run comprehensive schema tests
                comprehensiveSchemaTest()
                
                let diagnostics = getSchemaDiagnostics()
                alertMessage = "🔬 Comprehensive schema tests completed!\n\n\(diagnostics)\n\nCheck console for detailed results."
                showingAlert = true
                isTestingInProgress = false
            }
        }
    }
}

#Preview {
    SchemaTestingView()
} 