import SwiftUI
import SwiftData

struct PurchaseOrderSummaryComponent: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var purchaseOrderManager: PurchaseOrderManager
    @State private var showPOList = false
    @State private var showPOCreation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header section
            HStack {
                Text("Purchase Orders")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Update to use modern NavigationLink API
                Button {
                    showPOList = true
                } label: {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .navigationDestination(isPresented: $showPOList) {
                PurchaseOrderListView()
                    .environmentObject(purchaseOrderManager)
            }
            .navigationDestination(isPresented: $showPOCreation) {
                PurchaseOrderCreationView(syncManager: ServiceTitanSyncManager(service: ServiceTitanService()))
            }
            
            if purchaseOrderManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if purchaseOrderManager.recentPurchaseOrders.isEmpty {
                emptyStateView
            } else {
                // Abbreviated list showing only recent POs
                ForEach(purchaseOrderManager.recentPurchaseOrders.prefix(3)) { po in
                    purchaseOrderRow(po)
                }
                
                // "Create" button at the bottom
                Button(action: {
                    showPOCreation = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Purchase Order")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .padding(.top, 6)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
        .onAppear {
            purchaseOrderManager.setModelContext(modelContext)
            purchaseOrderManager.loadRecentPurchaseOrders()
        }
    }
    
    // Empty state
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            
            Text("No purchase orders yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                // Navigate to purchase order creation
                showPOCreation = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create First Purchase Order")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color("vehix-blue"))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // Helper for status color
    private func statusColor(for status: PurchaseOrderStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .submitted: return Color("vehix-blue")
        case .approved: return Color("vehix-green")
        case .rejected: return .red
        case .partiallyReceived: return Color("vehix-orange")
        case .received: return .purple
        case .cancelled: return .pink
        }
    }
    
    // Row for displaying a purchase order
    private func purchaseOrderRow(_ po: PurchaseOrder) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PO #\(po.poNumber)")
                    .font(.subheadline)
                    .bold()
                
                Text(po.vendorName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let jobNumber = po.serviceTitanJobNumber, !jobNumber.isEmpty {
                    Text("Job: \(jobNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", po.total))")
                    .font(.subheadline)
                    .bold()
                
                Text(formatDate(po.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(po.poStatus.rawValue)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(for: po.poStatus))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 6)
    }
    
    // Helper to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
} 