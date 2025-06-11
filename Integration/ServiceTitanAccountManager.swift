import Foundation
import SwiftUI
import SwiftData

// MARK: - ServiceTitan Account Management

@MainActor
class ServiceTitanAccountManager: ObservableObject {
    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncStatus: SyncStatus = .notStarted
    
    private let serviceTitanAPI: ServiceTitanAPIService
    private let modelContext: ModelContext?
    private let userDefaults = UserDefaults.standard
    
    enum SyncStatus: Equatable {
        case notStarted
        case syncing
        case completed
        case failed(String)
        case requiresReview
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted), (.syncing, .syncing), (.completed, .completed), (.requiresReview, .requiresReview):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    init(serviceTitanAPI: ServiceTitanAPIService, modelContext: ModelContext?) {
        self.serviceTitanAPI = serviceTitanAPI
        self.modelContext = modelContext
        loadStoredConfiguration()
    }
    
    // MARK: - Configuration Management
    
    func configureServiceTitan(
        clientId: String,
        clientSecret: String,
        tenantId: String,
        appKey: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // For now, we'll simulate successful configuration
        // In a real implementation, you'd test the credentials with ServiceTitan API
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        let success = !clientId.isEmpty && !clientSecret.isEmpty && !tenantId.isEmpty && !appKey.isEmpty
        
        if success {
            isConfigured = true
            saveConfiguration()
        } else {
            errorMessage = "Invalid configuration parameters"
        }
        
        isLoading = false
        return success
    }
    
    func performInitialSync() async {
        syncStatus = .syncing
        
        // Simulate sync process
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
        
        // For now, assume sync completes successfully
        syncStatus = .completed
    }
    
    // MARK: - Private Helper Methods
    
    private func loadStoredConfiguration() {
        isConfigured = userDefaults.bool(forKey: "servicetitan_configured")
    }
    
    private func saveConfiguration() {
        userDefaults.set(isConfigured, forKey: "servicetitan_configured")
    }
}

// MARK: - ServiceTitan Configuration View

struct ServiceTitanConfigurationView: View {
    @ObservedObject var accountManager: ServiceTitanAccountManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var tenantId = ""
    @State private var appKey = ""
    @State private var showingResult = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("ServiceTitan Credentials") {
                    TextField("Client ID", text: $clientId)
                        .textContentType(.username)
                    
                    SecureField("Client Secret", text: $clientSecret)
                        .textContentType(.password)
                    
                    TextField("Tenant ID", text: $tenantId)
                    
                    TextField("App Key", text: $appKey)
                        .textContentType(.password)
                }
                
                Section("Status") {
                    if accountManager.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing configuration...")
                        }
                    } else if accountManager.isConfigured {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Not configured", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
                
                if let errorMessage = accountManager.errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("ServiceTitan Setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        configureServiceTitan()
                    }
                    .disabled(clientId.isEmpty || clientSecret.isEmpty || tenantId.isEmpty || appKey.isEmpty || accountManager.isLoading)
                }
            }
            .alert("Configuration Result", isPresented: $showingResult) {
                Button("OK") {
                    if accountManager.isConfigured {
                        dismiss()
                    }
                }
            } message: {
                if accountManager.isConfigured {
                    Text("ServiceTitan configured successfully!")
                } else {
                    Text(accountManager.errorMessage ?? "Configuration failed")
                }
            }
        }
    }
    
    private func configureServiceTitan() {
        Task {
            _ = await accountManager.configureServiceTitan(
                clientId: clientId,
                clientSecret: clientSecret,
                tenantId: tenantId,
                appKey: appKey
            )
            showingResult = true
        }
    }
}

// MARK: - Account Synchronization View

struct ServiceTitanSyncView: View {
    @ObservedObject var accountManager: ServiceTitanAccountManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch accountManager.syncStatus {
                case .notStarted:
                    notStartedView
                case .syncing:
                    syncingView
                case .completed:
                    completedView
                case .failed(let error):
                    failedView(error: error)
                case .requiresReview:
                    requiresReviewView
                }
            }
            .navigationTitle("Account Sync")
            .onAppear {
                if accountManager.syncStatus == .notStarted {
                    Task {
                        await accountManager.performInitialSync()
                    }
                }
            }
        }
    }
    
    private var notStartedView: some View {
        VStack(spacing: 20) {
            Text("Ready to sync with ServiceTitan")
                .font(.headline)
            
            Button("Start Sync") {
                Task {
                    await accountManager.performInitialSync()
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    private var syncingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Syncing with ServiceTitan...")
                .font(.headline)
            
            Text("This may take a few moments")
                .foregroundColor(.secondary)
        }
    }
    
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Sync Complete!")
                .font(.headline)
            
            Text("ServiceTitan integration is ready")
                .foregroundColor(.secondary)
        }
    }
    
    private func failedView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Sync Failed")
                .font(.headline)
            
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await accountManager.performInitialSync()
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    private var requiresReviewView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Review Required")
                .font(.headline)
            
            Text("Some account mappings need manual review")
                .foregroundColor(.secondary)
            
            Button("Review Mappings") {
                // Navigate to review view
            }
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
} 