import SwiftUI
import SwiftData

struct PurchaseOrderListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AppAuthService
    
    @StateObject private var purchaseOrderManager = PurchaseOrderManager()
    
    @State private var selectedStatusFilter: PurchaseOrderStatus?
    @State private var searchText = ""
    @State private var sortOption = SortOption.newest
    @State private var showingFilterSheet = false
    @State private var selectedPurchaseOrder: PurchaseOrder?
    
    // Sort options
    enum SortOption: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case highestAmount = "Highest Amount"
        case lowestAmount = "Lowest Amount"
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Filter bar
                filterBar
                
                if purchaseOrderManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if purchaseOrderManager.recentPurchaseOrders.isEmpty {
                    emptyStateView
                } else {
                    purchaseOrderList
                }
            }
            .navigationTitle("Purchase Orders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: PurchaseOrderCreationView(syncManager: ServiceTitanSyncManager(service: ServiceTitanService()))) {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search POs by number, vendor...")
            .sheet(isPresented: $showingFilterSheet) {
                filterSheet
            }
            .sheet(item: $selectedPurchaseOrder) { po in
                PurchaseOrderDetailView(purchaseOrder: po, purchaseOrderManager: purchaseOrderManager)
            }
            .onAppear {
                purchaseOrderManager.setModelContext(modelContext)
            }
            .refreshable {
                purchaseOrderManager.loadRecentPurchaseOrders()
            }
            .alert(isPresented: Binding(
                get: { purchaseOrderManager.errorMessage != nil },
                set: { if !$0 { purchaseOrderManager.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(purchaseOrderManager.errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Filter bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                filterChip(title: "All", isSelected: selectedStatusFilter == nil) {
                    selectedStatusFilter = nil
                    Task {
                        purchaseOrderManager.loadRecentPurchaseOrders()
                    }
                }
                
                filterChip(title: "Pending", isSelected: selectedStatusFilter == .submitted) {
                    selectedStatusFilter = .submitted
                    Task {
                        await fetchFilteredPurchaseOrders()
                    }
                }
                
                filterChip(title: "Approved", isSelected: selectedStatusFilter == .approved) {
                    selectedStatusFilter = .approved
                    Task {
                        await fetchFilteredPurchaseOrders()
                    }
                }
                
                filterChip(title: "Rejected", isSelected: selectedStatusFilter == .rejected) {
                    selectedStatusFilter = .rejected
                    Task {
                        await fetchFilteredPurchaseOrders()
                    }
                }
                
                filterChip(title: "Received", isSelected: selectedStatusFilter == .received) {
                    selectedStatusFilter = .received
                    Task {
                        await fetchFilteredPurchaseOrders()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // Filter chip button
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color("vehix-blue") : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .animation(.easeInOut, value: isSelected)
        }
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 70))
                .foregroundColor(.blue.opacity(0.7))
            
            Text("No Purchase Orders Found")
                .font(.title2)
                .bold()
            
            if let selectedStatus = selectedStatusFilter {
                Text("No \(selectedStatus.rawValue) purchase orders to display")
                    .foregroundColor(.secondary)
            } else {
                Text("Start creating purchase orders to track your expenses")
                    .foregroundColor(.secondary)
            }
            
            NavigationLink(destination: PurchaseOrderCreationView(syncManager: ServiceTitanSyncManager(service: ServiceTitanService()))) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Create Purchase Order")
                }
                .padding()
                .background(Color("vehix-blue"))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Purchase order list
    private var purchaseOrderList: some View {
        List {
            ForEach(filteredPurchaseOrders) { po in
                PurchaseOrderRow(purchaseOrder: po)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPurchaseOrder = po
                    }
            }
        }
        .listStyle(.plain)
    }
    
    // Filter sheet
    private var filterSheet: some View {
        NavigationView {
            Form {
                // Status filter
                Section("Status") {
                    Picker("Status", selection: $selectedStatusFilter) {
                        Text("All").tag(nil as PurchaseOrderStatus?)
                        ForEach(PurchaseOrderStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status as PurchaseOrderStatus?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Sort options
                Section("Sort By") {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        showingFilterSheet = false
                        Task {
                            await fetchFilteredPurchaseOrders()
                        }
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingFilterSheet = false
                    }
                }
            }
        }
    }
    
    // Get filtered purchase orders
    private var filteredPurchaseOrders: [PurchaseOrder] {
        var result = purchaseOrderManager.recentPurchaseOrders
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { po in
                po.poNumber.localizedCaseInsensitiveContains(searchText) ||
                po.vendorName.localizedCaseInsensitiveContains(searchText) ||
                (po.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply sort
        switch sortOption {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .highestAmount:
            result.sort { $0.total > $1.total }
        case .lowestAmount:
            result.sort { $0.total < $1.total }
        }
        
        return result
    }
    
    // Fetch purchase orders with selected filter
    @MainActor
    private func fetchFilteredPurchaseOrders() async {
        if let status = selectedStatusFilter {
            purchaseOrderManager.recentPurchaseOrders = await purchaseOrderManager.fetchPurchaseOrders(status: status)
        } else {
            purchaseOrderManager.loadRecentPurchaseOrders()
        }
    }
}

// Purchase Order Row Component
struct PurchaseOrderRow: View {
    let purchaseOrder: PurchaseOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(purchaseOrder.poNumber)
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(status: purchaseOrder.poStatus)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(purchaseOrder.vendorName)
                        .font(.subheadline)
                    
                    Text(formattedDate(purchaseOrder.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("$\(String(format: "%.2f", purchaseOrder.total))")
                    .font(.headline)
            }
            
            if let notes = purchaseOrder.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Status Badge Component
struct StatusBadge: View {
    let status: PurchaseOrderStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .foregroundColor(.white)
            .cornerRadius(10)
    }
    
    private var statusColor: Color {
        switch status {
        case .draft: return Color.gray
        case .submitted: return Color("vehix-blue")
        case .approved: return Color("vehix-green")
        case .rejected: return Color.red
        case .partiallyReceived: return Color("vehix-orange")
        case .received: return Color.purple
        case .cancelled: return Color.pink
        }
    }
}

#Preview {
    PurchaseOrderListView()
} 