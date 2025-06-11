import SwiftUI
import Combine

// MARK: - Sheet Type Enum
enum SheetType: String, CaseIterable {
    case purchaseOrder = "purchaseOrder"
    case inventoryManagement = "inventoryManagement"
    case vehicleManagement = "vehicleManagement"
    case warehouseManagement = "warehouseManagement"
    case staffManagement = "staffManagement"
    case reports = "reports"
    case profile = "profile"
    case settings = "settings"
    case notification = "notification"
    case receiptProcessing = "receiptProcessing"
    
    var title: String {
        switch self {
        case .purchaseOrder: return "Purchase Orders"
        case .inventoryManagement: return "Inventory Management"
        case .vehicleManagement: return "Vehicle Management"
        case .warehouseManagement: return "Warehouse Management"
        case .staffManagement: return "Staff Management"
        case .reports: return "Reports"
        case .profile: return "Profile"
        case .settings: return "Settings"
        case .notification: return "Notifications"
        case .receiptProcessing: return "AI Receipt Processing"
        }
    }
}

// MARK: - Sheet Presentation Manager
@MainActor
class SheetPresentationManager: ObservableObject {
    @Published var currentSheet: SheetType?
    @Published var isSheetPresented: Bool = false
    
    private var presentationQueue: [SheetType] = []
    private let presentationDelay: TimeInterval = 0.1
    
    func requestPresentation(_ sheetType: SheetType) {
        // If no sheet is currently presented, present immediately
        if !isSheetPresented {
            presentSheet(sheetType)
        } else {
            // Queue the presentation for later
            if !presentationQueue.contains(sheetType) {
                presentationQueue.append(sheetType)
            }
        }
    }
    
    private func presentSheet(_ sheetType: SheetType) {
        currentSheet = sheetType
        isSheetPresented = true
    }
    
    func dismissSheet() {
        isSheetPresented = false
        currentSheet = nil
        
        // Process queue after a delay to allow current sheet to fully dismiss
        Task {
            try await Task.sleep(nanoseconds: UInt64(presentationDelay * 1_000_000_000))
            processQueue()
        }
    }
    
    private func processQueue() {
        guard !presentationQueue.isEmpty else { return }
        
        let nextSheet = presentationQueue.removeFirst()
        presentSheet(nextSheet)
    }
    
    func clearQueue() {
        presentationQueue.removeAll()
    }
    
    var hasQueuedPresentations: Bool {
        !presentationQueue.isEmpty
    }
}

// MARK: - Sheet Content View
struct CoordinatedSheetView: View {
    let sheetType: SheetType
    @EnvironmentObject var sheetManager: SheetPresentationManager
    
    var body: some View {
        // Use NavigationStack instead of NavigationView to prevent conflicts
        NavigationStack {
            Group {
                switch sheetType {
                case .purchaseOrder:
                    PurchaseOrderCreation()
                case .inventoryManagement:
                    InventoryView()
                case .vehicleManagement:
                    VehicleManagementView()
                case .warehouseManagement:
                    WarehouseManagementDashboard()
                case .staffManagement:
                    StaffListView()
                case .reports:
                    DataAnalyticsView()
                case .profile:
                    VehixUserProfileView()
                case .settings:
                    // Present settings without wrapper navigation to prevent conflicts
                    SettingsView()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                case .notification:
                    Text("Notifications")
                case .receiptProcessing:
                    ReceiptProcessingWorkflow()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        sheetManager.dismissSheet()
                    }
                }
            }
        }
        // Add a small delay to prevent rapid presentation conflicts
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
            }
        }
    }
}

// MARK: - Dashboard Button with Coordinated Presentation
struct CoordinatedDashboardButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let sheetType: SheetType
    
    @EnvironmentObject var sheetManager: SheetPresentationManager
    
    var body: some View {
        Button(action: {
            sheetManager.requestPresentation(sheetType)
        }) {
            VStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 80, height: 80)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 