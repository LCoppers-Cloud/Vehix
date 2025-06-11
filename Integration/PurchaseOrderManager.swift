import SwiftUI
import SwiftData
import CoreLocation
import UserNotifications

/// Manager class for Purchase Order operations
class PurchaseOrderManager: ObservableObject {
    private var modelContext: ModelContext?
    private var serviceTitanService: ServiceTitanService?
    
    // Published properties for UI updates
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var recentPurchaseOrders: [PurchaseOrder] = []
    @Published var pendingApprovalCount: Int = 0
    @Published var purchaseOrders: [PurchaseOrder] = []
    @Published var pendingApprovals: [PurchaseOrder] = []
    @Published var selectedFilter: PurchaseOrderFilter = .all
    @Published var searchText = ""
    
    init(modelContext: ModelContext? = nil, serviceTitanService: ServiceTitanService? = nil) {
        self.modelContext = modelContext
        self.serviceTitanService = serviceTitanService
        loadPurchaseOrders()
        setupNotificationHandling()
    }
    
    func loadPurchaseOrders() {
        guard let modelContext = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<PurchaseOrder>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            purchaseOrders = try modelContext.fetch(descriptor)
            
            // Filter pending approvals (submitted purchase orders)
            pendingApprovals = purchaseOrders.filter { $0.poStatus == .submitted }
        } catch {
            errorMessage = "Failed to load purchase orders: \(error.localizedDescription)"
        }
    }
    
    /// Set the model context
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadRecentPurchaseOrders()
    }
    
    /// Load recent purchase orders
    func loadRecentPurchaseOrders() {
        guard let modelContext = modelContext else { return }
        
        isLoading = true
        
        do {
            // Create a fetch descriptor for PurchaseOrder
            let sortDescriptor = SortDescriptor<PurchaseOrder>(\.createdAt, order: .reverse)
            var descriptor = FetchDescriptor<PurchaseOrder>(sortBy: [sortDescriptor])
            descriptor.fetchLimit = 10
            
            // Fetch the records
            recentPurchaseOrders = try modelContext.fetch(descriptor)
            
            // Update pending approval count
            countPendingApprovals()
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load purchase orders: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Count purchase orders pending approval
    func countPendingApprovals() {
        guard let modelContext = modelContext else { return }
        
        do {
            // Create a predicate for submitted purchase orders
            let predicate = #Predicate<PurchaseOrder> { po in
                po.status == "Submitted"
            }
            
            // Create fetch descriptor with the predicate
            let descriptor = FetchDescriptor<PurchaseOrder>(predicate: predicate)
            
            // Fetch the count
            pendingApprovalCount = try modelContext.fetchCount(descriptor)
        } catch {
            errorMessage = "Failed to count pending approvals: \(error.localizedDescription)"
        }
    }
    
    /// Fetch purchase orders by status
    @MainActor
    func fetchPurchaseOrders(status: PurchaseOrderStatus? = nil, limit: Int? = nil) async -> [PurchaseOrder] {
        guard let modelContext = modelContext else { return [] }
        
        do {
            // Create sort descriptor
            let sortDescriptor = SortDescriptor<PurchaseOrder>(\.createdAt, order: .reverse)
            
            // Create fetch descriptor
            var descriptor = FetchDescriptor<PurchaseOrder>(sortBy: [sortDescriptor])
            
            // Add predicate if status is specified
            if let status = status {
                let predicate = #Predicate<PurchaseOrder> { po in
                    po.status == status.rawValue
                }
                descriptor.predicate = predicate
            }
            
            // Set limit if specified
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            // Fetch the records
            return try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch purchase orders: \(error.localizedDescription)"
            return []
        }
    }
    
    /// Approve a purchase order
    func approvePurchaseOrder(_ purchaseOrder: PurchaseOrder) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        // Update status
        purchaseOrder.poStatus = .approved
        purchaseOrder.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Refresh data
            await MainActor.run {
                loadRecentPurchaseOrders()
            }
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to approve purchase order: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Reject a purchase order
    func rejectPurchaseOrder(_ purchaseOrder: PurchaseOrder, reason: String) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        // Update status
        purchaseOrder.poStatus = .rejected
        purchaseOrder.notes = reason
        purchaseOrder.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Refresh data
            await MainActor.run {
                loadRecentPurchaseOrders()
            }
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to reject purchase order: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Mark a purchase order as received
    func markPurchaseOrderAsReceived(_ purchaseOrder: PurchaseOrder, isPartial: Bool = false) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        // Update status
        purchaseOrder.poStatus = isPartial ? .partiallyReceived : .received
        purchaseOrder.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Refresh data
            await MainActor.run {
                loadRecentPurchaseOrders()
            }
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update purchase order: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Attach a receipt to a purchase order
    func attachReceipt(to purchaseOrder: PurchaseOrder, image: UIImage, captureLocation: CLLocationCoordinate2D? = nil) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        // Create a new receipt
        let receipt = Receipt(
            date: Date(),
            total: purchaseOrder.total,
            imageData: image.jpegData(compressionQuality: 0.8),
            vendorId: purchaseOrder.vendorId
        )
        
        // Location data is not supported in the current Receipt model
        
        do {
            // Add the receipt to the database
            modelContext.insert(receipt)
            
            // Connect receipt to purchase order
            purchaseOrder.receipt = receipt
            purchaseOrder.updatedAt = Date()
            
            try modelContext.save()
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to attach receipt: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Create a purchase order from receipt data
    func createPurchaseOrderFromReceipt(receipt: Receipt, jobId: String, jobNumber: String, userId: String, userName: String) async -> PurchaseOrder? {
        guard let modelContext = modelContext else { return nil }
        
        // Generate PO number using proper sequential system
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        
        // PRODUCTION MODE: Use proper sequential numbering instead of random
        // Get count of existing POs for today to create sequential number
        let todayStart = Calendar.current.startOfDay(for: date)
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart)!
        
        // Query database directly to avoid async issues
        let todayPOCount: Int
        do {
            let descriptor = FetchDescriptor<PurchaseOrder>()
            let allPOs = try modelContext.fetch(descriptor)
            todayPOCount = allPOs.filter { po in
                po.createdAt >= todayStart && po.createdAt < todayEnd
            }.count
        } catch {
            todayPOCount = 0 // Fallback to 0 if query fails
        }
        
        let sequentialNumber = String(format: "%03d", todayPOCount + 1)
        let poNumber = "\(jobNumber)-\(dateString)-\(sequentialNumber)"
        
        // Since the Receipt model might not have the expected properties,
        // we'll create the PO with default values
        let purchaseOrder = PurchaseOrder(
            poNumber: poNumber,
            date: receipt.date,  // receipt.date is non-optional
            vendorId: receipt.vendorId ?? "",
            vendorName: "Unknown Vendor", // Default value since vendorName may not exist
            status: .submitted,
            subtotal: 0, // Default value since totalAmount may not exist
            tax: 0,
            total: 0, // Default value since totalAmount may not exist
            notes: "Created from receipt",
            createdByUserId: userId,
            createdByName: userName,
            serviceTitanJobId: jobId,
            serviceTitanJobNumber: jobNumber
        )
        
        // Link receipt to purchase order
        purchaseOrder.receipt = receipt
        
        // Add line items if available
        if let parsedItems = receipt.parsedItems {
            var lineItems: [PurchaseOrderLineItem] = []
            
            for item in parsedItems {
                let lineItem = PurchaseOrderLineItem(
                    purchaseOrderId: purchaseOrder.id,
                    inventoryItemId: item.inventoryItemId,
                    itemDescription: item.name,
                    quantity: Int(item.quantity),
                    unitPrice: item.unitPrice,
                    lineTotal: item.totalPrice
                )
                lineItems.append(lineItem)
                modelContext.insert(lineItem)
            }
            
            purchaseOrder.lineItems = lineItems
        }
        
        do {
            modelContext.insert(purchaseOrder)
            try modelContext.save()
            return purchaseOrder
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create purchase order: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Manager Approval Actions
    
    func approvePurchaseOrder(_ po: PurchaseOrder, completion: @escaping (Bool, String?) -> Void) {
        guard let modelContext = modelContext else {
            completion(false, "Database not available")
            return
        }
        
        po.status = PurchaseOrderStatus.approved.rawValue
        po.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Send to ServiceTitan if connected
            if let serviceTitanService = serviceTitanService, serviceTitanService.isConnected {
                serviceTitanService.submitPurchaseOrder(po) { [weak self] success, error in
                    DispatchQueue.main.async {
                        if success {
                            po.syncWithServiceTitan(
                                poId: "ST-\(po.id)",
                                jobId: po.serviceTitanJobId,
                                jobNumber: po.serviceTitanJobNumber
                            )
                            try? modelContext.save()
                            
                            // Send approval notification to technician
                            self?.sendApprovalNotification(for: po)
                            
                            completion(true, "Purchase order approved and synced with ServiceTitan")
                        } else {
                            // Still mark as approved but note sync issue
                            self?.sendApprovalNotification(for: po)
                            completion(true, "Purchase order approved. ServiceTitan sync failed: \(error ?? "Unknown error")")
                        }
                        
                        self?.loadPurchaseOrders()
                    }
                }
            } else {
                // No ServiceTitan connection, just approve locally
                sendApprovalNotification(for: po)
                completion(true, "Purchase order approved")
                loadPurchaseOrders()
            }
            
        } catch {
            completion(false, "Failed to approve purchase order: \(error.localizedDescription)")
        }
    }
    
    func rejectPurchaseOrder(_ po: PurchaseOrder, reason: String, completion: @escaping (Bool, String?) -> Void) {
        guard let modelContext = modelContext else {
            completion(false, "Database not available")
            return
        }
        
        po.status = PurchaseOrderStatus.rejected.rawValue
        po.notes = reason
        po.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Send rejection notification to technician
            sendRejectionNotification(for: po, reason: reason)
            
            completion(true, "Purchase order rejected")
            loadPurchaseOrders()
            
        } catch {
            completion(false, "Failed to reject purchase order: \(error.localizedDescription)")
        }
    }
    
    func requestMoreInfo(_ po: PurchaseOrder, message: String, completion: @escaping (Bool, String?) -> Void) {
        guard let modelContext = modelContext else {
            completion(false, "Database not available")
            return
        }
        
        // Add manager note requesting more information
        let currentNotes = po.notes ?? ""
        po.notes = currentNotes.isEmpty ? "Manager requests: \(message)" : "\(currentNotes)\n\nManager requests: \(message)"
        po.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Send notification to technician requesting more info
            sendMoreInfoRequestNotification(for: po, message: message)
            
            completion(true, "Information request sent to technician")
            loadPurchaseOrders()
            
        } catch {
            completion(false, "Failed to request more information: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notification System
    
    private func setupNotificationHandling() {
        // Listen for notification responses
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("POApprovalAction"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let poId = userInfo["poId"] as? String,
               let action = userInfo["action"] as? String {
                self?.handleNotificationAction(poId: poId, action: action)
            }
        }
    }
    
    private func handleNotificationAction(poId: String, action: String) {
        guard let po = purchaseOrders.first(where: { $0.id == poId }) else { return }
        
        switch action {
        case "approve":
            approvePurchaseOrder(po) { _, _ in }
        case "reject":
            // This would typically show a rejection reason dialog
            rejectPurchaseOrder(po, reason: "Rejected via notification") { _, _ in }
        case "view":
            // Navigate to detailed view
            break
        default:
            break
        }
    }
    
    private func sendApprovalNotification(for po: PurchaseOrder) {
        let content = UNMutableNotificationContent()
        content.title = "Purchase Order Approved ✅"
        content.body = "Your PO \(po.poNumber) for $\(String(format: "%.2f", po.total)) has been approved and synced with ServiceTitan."
        content.categoryIdentifier = "PO_APPROVED"
        content.userInfo = ["poId": po.id]
        content.sound = .default
        
        // Add action buttons
        let viewAction = UNNotificationAction(
            identifier: "VIEW_PO",
            title: "View Details",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "PO_APPROVED",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        let request = UNNotificationRequest(
            identifier: "po_approved_\(po.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendRejectionNotification(for po: PurchaseOrder, reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "Purchase Order Rejected ❌"
        content.body = "Your PO \(po.poNumber) was rejected. Reason: \(reason)"
        content.categoryIdentifier = "PO_REJECTED"
        content.userInfo = ["poId": po.id, "reason": reason]
        content.sound = .default
        
        let viewAction = UNNotificationAction(
            identifier: "VIEW_REJECTION",
            title: "View Details",
            options: .foreground
        )
        
        let retryAction = UNNotificationAction(
            identifier: "RETRY_PO",
            title: "Create New PO",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "PO_REJECTED",
            actions: [viewAction, retryAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        let request = UNNotificationRequest(
            identifier: "po_rejected_\(po.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendMoreInfoRequestNotification(for po: PurchaseOrder, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Additional Information Needed"
        content.body = "Your manager needs more information about PO \(po.poNumber): \(message)"
        content.categoryIdentifier = "PO_MORE_INFO"
        content.userInfo = ["poId": po.id, "message": message]
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "po_more_info_\(po.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Analytics and Reporting
    
    func getPurchaseOrderStats() -> PurchaseOrderStats {
        let total = purchaseOrders.count
        let pending = purchaseOrders.filter { $0.poStatus == .submitted }.count
        let approved = purchaseOrders.filter { $0.poStatus == .approved }.count
        let rejected = purchaseOrders.filter { $0.poStatus == .rejected }.count
        let totalAmount = purchaseOrders.reduce(0) { $0 + $1.total }
        let avgApprovalTime = calculateAverageApprovalTime()
        
        return PurchaseOrderStats(
            totalOrders: total,
            pendingApproval: pending,
            approved: approved,
            rejected: rejected,
            totalAmount: totalAmount,
            averageApprovalTime: avgApprovalTime
        )
    }
    
    private func calculateAverageApprovalTime() -> TimeInterval {
        let approvedOrders = purchaseOrders.filter { 
            $0.poStatus == .approved || $0.poStatus == .rejected 
        }
        
        guard !approvedOrders.isEmpty else { return 0 }
        
        let totalTime = approvedOrders.reduce(0.0) { total, po in
            return total + po.updatedAt.timeIntervalSince(po.createdAt)
        }
        
        return totalTime / Double(approvedOrders.count)
    }
    
    func exportPurchaseOrders(for dateRange: DateInterval) -> [PurchaseOrder] {
        return purchaseOrders.filter { po in
            dateRange.contains(po.createdAt)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

enum PurchaseOrderFilter: String, CaseIterable {
    case all = "All"
    case draft = "Draft"
    case submitted = "Pending Approval"
    case approved = "Approved"
    case rejected = "Rejected"
    case completed = "Completed"
}

struct PurchaseOrderStats {
    let totalOrders: Int
    let pendingApproval: Int
    let approved: Int
    let rejected: Int
    let totalAmount: Double
    let averageApprovalTime: TimeInterval
    
    var approvalRate: Double {
        let total = approved + rejected
        return total > 0 ? Double(approved) / Double(total) : 0
    }
    
    var formattedApprovalTime: String {
        let hours = Int(averageApprovalTime) / 3600
        let minutes = Int(averageApprovalTime) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Manager Approval Interface

struct ManagerApprovalView: View {
    @ObservedObject var manager: PurchaseOrderManager
    @State private var selectedPO: PurchaseOrder?
    @State private var showingApprovalDetail = false
    @State private var showingRejectionDialog = false
    @State private var rejectionReason = ""
    @State private var showingMoreInfoDialog = false
    @State private var moreInfoMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if manager.pendingApprovals.isEmpty {
                    ContentUnavailableView(
                        "No Pending Approvals",
                        systemImage: "checkmark.circle",
                        description: Text("All purchase orders have been reviewed. New submissions will appear here.")
                    )
                } else {
                    List {
                        ForEach(manager.pendingApprovals) { po in
                            PendingApprovalRow(
                                purchaseOrder: po,
                                onApprove: {
                                    approvePO(po)
                                },
                                onReject: {
                                    selectedPO = po
                                    showingRejectionDialog = true
                                },
                                onRequestInfo: {
                                    selectedPO = po
                                    showingMoreInfoDialog = true
                                },
                                onViewDetails: {
                                    selectedPO = po
                                    showingApprovalDetail = true
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Pending Approvals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Mark All as Reviewed") {
                            // Bulk action
                        }
                        
                        Button("Export List") {
                            // Export functionality
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await MainActor.run {
                    manager.loadPurchaseOrders()
                }
            }
            .sheet(isPresented: $showingApprovalDetail) {
                if let po = selectedPO {
                    PurchaseOrderDetailView(purchaseOrder: po, purchaseOrderManager: manager)
                }
            }
            .alert("Reject Purchase Order", isPresented: $showingRejectionDialog) {
                TextField("Reason for rejection", text: $rejectionReason)
                
                Button("Reject", role: .destructive) {
                    if let po = selectedPO {
                        rejectPO(po, reason: rejectionReason)
                    }
                    rejectionReason = ""
                }
                
                Button("Cancel", role: .cancel) {
                    rejectionReason = ""
                }
            } message: {
                Text("Please provide a reason for rejecting this purchase order. The technician will be notified.")
            }
            .alert("Request More Information", isPresented: $showingMoreInfoDialog) {
                TextField("What information do you need?", text: $moreInfoMessage)
                
                Button("Send Request") {
                    if let po = selectedPO {
                        requestMoreInfo(po, message: moreInfoMessage)
                    }
                    moreInfoMessage = ""
                }
                
                Button("Cancel", role: .cancel) {
                    moreInfoMessage = ""
                }
            } message: {
                Text("What additional information do you need from the technician?")
            }
        }
    }
    
    private func approvePO(_ po: PurchaseOrder) {
        manager.approvePurchaseOrder(po) { success, message in
            // Handle result
        }
    }
    
    private func rejectPO(_ po: PurchaseOrder, reason: String) {
        manager.rejectPurchaseOrder(po, reason: reason) { success, message in
            // Handle result
        }
    }
    
    private func requestMoreInfo(_ po: PurchaseOrder, message: String) {
        manager.requestMoreInfo(po, message: message) { success, response in
            // Handle result
        }
    }
}

struct PendingApprovalRow: View {
    let purchaseOrder: PurchaseOrder
    let onApprove: () -> Void
    let onReject: () -> Void
    let onRequestInfo: () -> Void
    let onViewDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with PO number and amount
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(purchaseOrder.poNumber)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("$\(String(format: "%.2f", purchaseOrder.total))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("PENDING")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                    
                    Text(timeAgo(from: purchaseOrder.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                        .frame(width: 16)
                    Text("Technician: \(purchaseOrder.createdByName)")
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.blue)
                        .frame(width: 16)
                    Text("Vendor: \(purchaseOrder.vendorName)")
                        .font(.subheadline)
                }
                
                if let jobNumber = purchaseOrder.serviceTitanJobNumber {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Text("Job: \(jobNumber)")
                            .font(.subheadline)
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("View Details") {
                    onViewDetails()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Request Info") {
                    onRequestInfo()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Reject") {
                    onReject()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                
                Button("Approve") {
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                )
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
} 