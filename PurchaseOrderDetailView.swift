import SwiftUI
import SwiftData
import UIKit

// All the component types are already available in the project without special imports

struct PurchaseOrderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AppAuthService
    
    let purchaseOrder: PurchaseOrder
    let purchaseOrderManager: PurchaseOrderManager
    
    @State private var isLoading = false
    @State private var showingActionSheet = false
    @State private var showingApproveAlert = false
    @State private var showingRejectAlert = false
    @State private var rejectionReason = ""
    @State private var showingImageViewer = false
    @State private var showingAddReceiptSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                purchaseOrderHeader
                
                Divider()
                
                // Details
                purchaseOrderDetails
                
                // Line items
                lineItemsSection
                
                // Receipt section
                receiptSection
                
                // Action buttons for appropriate roles
                if canTakeAction {
                    actionButtons
                }
            }
            .padding()
        }
        .navigationTitle("Purchase Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if canSharePO {
                    Button(action: {
                        sharePurchaseOrder()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingImageViewer) {
            if let imageData = purchaseOrder.receipt?.imageData,
               let image = UIImage(data: imageData) {
                ReceiptImageViewer(image: image)
            }
        }
        .sheet(isPresented: $showingAddReceiptSheet) {
            ReceiptCaptureView(onCapture: { image in
                Task {
                    isLoading = true
                    let success = await purchaseOrderManager.attachReceipt(
                        to: purchaseOrder,
                        image: image
                    )
                    isLoading = false
                    
                    if success {
                        showingAddReceiptSheet = false
                    }
                }
            })
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        .alert("Approve Purchase Order", isPresented: $showingApproveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Approve", role: .destructive) {
                Task {
                    isLoading = true
                    let success = await purchaseOrderManager.approvePurchaseOrder(purchaseOrder)
                    isLoading = false
                    
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to approve this purchase order?")
        }
        .alert("Reject Purchase Order", isPresented: $showingRejectAlert) {
            TextField("Reason for rejection", text: $rejectionReason)
            
            Button("Cancel", role: .cancel) { }
            Button("Reject", role: .destructive) {
                Task {
                    isLoading = true
                    let success = await purchaseOrderManager.rejectPurchaseOrder(
                        purchaseOrder,
                        reason: rejectionReason
                    )
                    isLoading = false
                    
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Please provide a reason for rejecting this purchase order.")
        }
    }
    
    // Header section
    private var purchaseOrderHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PO #\(purchaseOrder.poNumber)")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                StatusBadge(status: purchaseOrder.poStatus)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Created by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(purchaseOrder.createdByName)
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDate(purchaseOrder.date))
                        .font(.subheadline)
                }
            }
            .padding(.top, 4)
        }
    }
    
    // Details section
    private var purchaseOrderDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            
            DetailRow(label: "Vendor", value: purchaseOrder.vendorName)
            
            if let jobNumber = purchaseOrder.serviceTitanJobNumber {
                DetailRow(label: "Job", value: jobNumber)
            }
            
            DetailRow(label: "Total Amount", value: "$\(String(format: "%.2f", purchaseOrder.total))")
            
            if let notes = purchaseOrder.notes, !notes.isEmpty {
                DetailRow(label: "Notes", value: notes)
            }
            
            if purchaseOrder.syncedWithServiceTitan {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Synced with ServiceTitan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // Line items section
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Line Items")
                .font(.headline)
            
            if let lineItems = purchaseOrder.lineItems, !lineItems.isEmpty {
                ForEach(lineItems, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.itemDescription)
                            .font(.subheadline)
                        
                        HStack {
                            Text("Qty: \(item.quantity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("$\(String(format: "%.2f", item.unitPrice)) each")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("$\(String(format: "%.2f", item.lineTotal))")
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
            } else {
                Text("No line items")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    // Receipt section
    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Receipt")
                .font(.headline)
            
            if let receipt = purchaseOrder.receipt, let imageData = receipt.imageData, let image = UIImage(data: imageData) {
                // Receipt image preview
                Button(action: {
                    showingImageViewer = true
                }) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
            } else {
                // No receipt yet
                VStack {
                    Text("No receipt attached")
                        .foregroundColor(.secondary)
                    
                    if canEditPO {
                        Button(action: {
                            showingAddReceiptSheet = true
                        }) {
                            HStack {
                                Image(systemName: "camera")
                                Text("Add Receipt")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // Action buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)
            
            HStack(spacing: 20) {
                // Approve button (for managers/admins on submitted POs)
                if canApprove {
                    Button(action: {
                        showingApproveAlert = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                // Reject button (for managers/admins on submitted POs)
                if canReject {
                    Button(action: {
                        showingRejectAlert = true
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Reject")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Mark as received button (for approved POs)
            if canMarkReceived {
                Button(action: {
                    Task {
                        isLoading = true
                        let success = await purchaseOrderManager.markPurchaseOrderAsReceived(purchaseOrder)
                        isLoading = false
                        
                        if success {
                            dismiss()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "shippingbox.fill")
                        Text("Mark as Received")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // Helper for formatted date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Permission checks
    private var isManager: Bool {
        authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer
    }
    
    private var isOwner: Bool {
        authService.currentUser?.id == purchaseOrder.createdByUserId
    }
    
    private var canTakeAction: Bool {
        isManager || isOwner
    }
    
    private var canEditPO: Bool {
        (isOwner && purchaseOrder.poStatus == .draft) || isManager
    }
    
    private var canApprove: Bool {
        isManager && purchaseOrder.poStatus == .submitted
    }
    
    private var canReject: Bool {
        isManager && purchaseOrder.poStatus == .submitted
    }
    
    private var canMarkReceived: Bool {
        canTakeAction && purchaseOrder.poStatus == .approved
    }
    
    private var canSharePO: Bool {
        true // Anyone can share the PO details
    }
    
    // Share purchase order as PDF/text
    private func sharePurchaseOrder() {
        // Create a string representation of the PO for sharing
        let poDetails = """
        Purchase Order: \(purchaseOrder.poNumber)
        Vendor: \(purchaseOrder.vendorName)
        Date: \(formattedDate(purchaseOrder.date))
        Status: \(purchaseOrder.poStatus.rawValue)
        Total: $\(String(format: "%.2f", purchaseOrder.total))
        
        Notes: \(purchaseOrder.notes ?? "None")
        """
        
        // Share the text
        let activityVC = UIActivityViewController(activityItems: [poDetails], applicationActivities: nil)
        
        // Present the share sheet
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = rootViewController.view
            popoverController.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true)
    }
}

// Using shared DetailRow and ReceiptImageViewer from PurchaseOrderUIComponents.swift

// Using shared components from CameraComponents.swift 