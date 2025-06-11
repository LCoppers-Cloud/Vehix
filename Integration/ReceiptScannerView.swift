import SwiftUI
import SwiftData
import VisionKit
import PhotosUI

struct ReceiptScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var scannerManager = ReceiptScannerManager()
    
    @State private var showScanner = false
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingSaveConfirmation = false
    @State private var savedReceipt: Receipt?
    @State private var showTutorial = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Break complex conditional view structure into separate view components
                contentView
            }
            .navigationTitle("Receipt Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                toolbarActionButton
            }
            .sheet(isPresented: $showScanner) {
                documentScannerView
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                handleSelectedPhoto(newItem)
            }
            .alert("New Vendor Detected", isPresented: $scannerManager.showNewVendorAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Add Vendor") {
                    Task {
                        await scannerManager.approveNewVendor()
                    }
                }
            } message: {
                vendorAlertMessage
            }
            .alert("Receipt Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The receipt has been successfully saved.")
            }
            .fullScreenCover(isPresented: $showTutorial) {
                ReceiptScannerTutorial(showTutorial: $showTutorial)
            }
            .onAppear {
                scannerManager.setModelContext(modelContext)
                checkFirstTimeUser()
            }
        }
    }
    
    // MARK: - Extracted View Components
    
    // Main content view based on scanner state
    private var contentView: some View {
        Group {
            if scannerManager.isProcessing {
                processingView
            } else if let _ = scannerManager.scannedImage {
                // Using underscore to avoid compiler issues with optional binding
                scannedImageView
            } else {
                initialOptionsView
            }
        }
    }
    
    // Processing view shown during receipt scanning
    private var processingView: some View {
        VStack(spacing: 20) {
            // AI Processing indicator
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(scannerManager.isProcessing ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: scannerManager.isProcessing)
                
                if scannerManager.isUsingAI {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "eye")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(spacing: 8) {
                Text("Processing Receipt")
                    .font(.title2)
                    .fontWeight(.medium)
                
                if !scannerManager.processingMethod.isEmpty {
                    Text(scannerManager.processingMethod)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Text(scannerManager.isUsingAI ? "AI is analyzing the receipt for maximum accuracy..." : "Using traditional text recognition...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // View displayed when an image has been scanned
    private var scannedImageView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // AI Processing Status Banner
                processingStatusBanner
                
                // Receipt image
                receiptImageView
                
                // Vendor section
                vendorSection
                
                // Date and total with enhanced AI details
                receiptDetailsSection
                
                // Enhanced line items with categories
                lineItemsSection
                
                // Raw text section (collapsible)
                rawTextSection
                
                // Save button
                saveButton
            }
            .padding(.vertical)
        }
    }
    
    // Initial options view (camera or photos)
    private var initialOptionsView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("Scan a Receipt")
                .font(.title)
            
            Text("Capture or select a receipt to scan and process")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            scanOptionsButtons
            
            Spacer()
        }
    }
    
    // Button options for scanning
    private var scanOptionsButtons: some View {
        HStack(spacing: 20) {
            scannerButton
            photosButton
        }
        .padding(.horizontal)
    }
    
    // Camera scanner button
    private var scannerButton: some View {
        Button(action: {
            showScanner = true
        }) {
            VStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 30))
                
                Text("Camera")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    // Photo picker button
    private var photosButton: some View {
        Button(action: {
            showPhotosPicker = true
        }) {
            VStack {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 30))
                
                Text("Photos")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    // Toolbar action button (changes based on state)
    private var toolbarActionButton: some ToolbarContent {
        Group {
            if scannerManager.scannedImage != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Rescan") {
                        resetScan()
                    }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showTutorial = true
                    }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
        }
    }
    
    // Document scanner view
    private var documentScannerView: some View {
        DocumentScannerView { result in
            handleScanResult(result)
        }
        .ignoresSafeArea()
    }
    
    // Alert message for vendor detection
    private var vendorAlertMessage: some View {
        Group {
            if let vendorName = scannerManager.rawVendorName {
                Text("Would you like to add '\(vendorName)' as a new vendor?")
            } else {
                Text("Would you like to add this as a new vendor?")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Handle scan result
    private func handleScanResult(_ result: Result<VNDocumentCameraScan, Error>) {
        switch result {
        case .success(let scan):
            Task {
                if scan.pageCount > 0 {
                    let firstImage = scan.imageOfPage(at: 0)
                    await scannerManager.processReceiptImage(firstImage)
                }
            }
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
    
    // Handle selected photo
    private func handleSelectedPhoto(_ item: PhotosPickerItem?) {
        if let item = item {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await scannerManager.processReceiptImage(image)
                }
            }
        }
    }
    
    // Check if it's the first time using receipt scanner
    private func checkFirstTimeUser() {
        let hasSeenTutorial = UserDefaults.standard.bool(forKey: "hasSeenReceiptScannerTutorial")
        if !hasSeenTutorial {
            showTutorial = true
        }
    }
    
    // Reset the scanner
    private func resetScan() {
        scannerManager.scannedImage = nil
        scannerManager.recognizedText = ""
        scannerManager.recognizedVendor = nil
        scannerManager.recognizedDate = nil
        scannerManager.recognizedTotal = nil
        scannerManager.recognizedItems = []
    }
    
    // Save the receipt
    private func saveReceipt() async {
        if let receipt = await scannerManager.saveReceipt() {
            savedReceipt = receipt
            showingSaveConfirmation = true
        }
    }
    
    private var processingStatusBanner: some View {
        Group {
            if !scannerManager.processingMethod.isEmpty {
                HStack {
                    Image(systemName: scannerManager.isUsingAI ? "brain.head.profile" : "eye")
                        .foregroundColor(.blue)
                    
                    Text(scannerManager.processingMethod)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let analysis = scannerManager.aiAnalysisResult {
                        Spacer()
                        
                        Text("\(Int(analysis.confidence * 100))% confidence")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
    }
    
    private var receiptImageView: some View {
        Image(uiImage: scannerManager.scannedImage ?? UIImage())
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .cornerRadius(12)
            .padding(.horizontal)
    }
    
    private var receiptDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Receipt Details")
                .font(.headline)
            
            // Date
            HStack {
                Text("Date:")
                    .foregroundColor(.secondary)
                
                if let date = scannerManager.recognizedDate {
                    Text(date, style: .date)
                } else {
                    Text("Not detected")
                        .italic()
                        .foregroundColor(.secondary)
                }
            }
            
            // Total
            HStack {
                Text("Total:")
                    .foregroundColor(.secondary)
                
                if let total = scannerManager.recognizedTotal {
                    Text(currencyFormatter.string(from: NSNumber(value: total)) ?? "$\(total)")
                        .fontWeight(.semibold)
                } else {
                    Text("Not detected")
                        .italic()
                        .foregroundColor(.secondary)
                }
            }
            
            // Enhanced AI details
            aiDetailsView
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var aiDetailsView: some View {
        Group {
            if let analysis = scannerManager.aiAnalysisResult {
                VStack(alignment: .leading, spacing: 8) {
                    if let subtotal = analysis.subtotal {
                        HStack {
                            Text("Subtotal:")
                                .foregroundColor(.secondary)
                            Text(currencyFormatter.string(from: NSNumber(value: subtotal)) ?? "$\(subtotal)")
                        }
                    }
                    
                    if let tax = analysis.tax {
                        HStack {
                            Text("Tax:")
                                .foregroundColor(.secondary)
                            Text(currencyFormatter.string(from: NSNumber(value: tax)) ?? "$\(tax)")
                        }
                    }
                }
            }
        }
    }
    
    private var lineItemsSection: some View {
        Group {
            if !scannerManager.recognizedItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Items")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(scannerManager.recognizedItems.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    ForEach(scannerManager.recognizedItems) { item in
                        lineItemRow(item)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
    }
    
    private func lineItemRow(_ item: ReceiptItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currencyFormatter.string(from: NSNumber(value: item.totalPrice)) ?? "$\(item.totalPrice)")
                        .fontWeight(.medium)
                    
                    if item.quantity > 1 {
                        Text("\(Int(item.quantity)) × $\(String(format: "%.2f", item.unitPrice))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if item != scannerManager.recognizedItems.last {
                Divider()
            }
        }
        .padding(.vertical, 4)
    }
    
    private var rawTextSection: some View {
        DisclosureGroup("View Raw Text") {
            Text(scannerManager.recognizedText)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var saveButton: some View {
        Button(action: {
            Task {
                await saveReceipt()
            }
        }) {
            Text("Save Receipt")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
        .disabled(scannerManager.recognizedVendor == nil)
    }
    
    // Vendor section of the UI
    private var vendorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vendor")
                .font(.headline)
            
            if let vendor = scannerManager.recognizedVendor {
                HStack {
                    VStack(alignment: .leading) {
                        Text(vendor.name)
                            .font(.title3)
                        
                        if vendor.isActive {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                Text("Active Vendor")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        scannerManager.showNewVendorAlert = true
                    }) {
                        Text("Change")
                            .font(.caption)
                    }
                }
            } else if let rawName = scannerManager.rawVendorName {
                HStack {
                    VStack(alignment: .leading) {
                        Text(rawName)
                            .font(.title3)
                        
                        Text("Unverified Vendor")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await scannerManager.approveNewVendor()
                        }
                    }) {
                        Text("Approve")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(5)
                    }
                }
            } else {
                Text("No vendor detected")
                    .italic()
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Currency formatter
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

// Document Scanner View
struct DocumentScannerView: UIViewControllerRepresentable {
    let completionHandler: (Result<VNDocumentCameraScan, Error>) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let viewController = VNDocumentCameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completionHandler: completionHandler)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completionHandler: (Result<VNDocumentCameraScan, Error>) -> Void
        
        init(completionHandler: @escaping (Result<VNDocumentCameraScan, Error>) -> Void) {
            self.completionHandler = completionHandler
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            completionHandler(.success(scan))
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            completionHandler(.failure(error))
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    // Create a model container with concrete types rather than protocol types
    let container = try! ModelContainer(for: Receipt.self, Vendor.self, ReceiptItem.self)
    
    // Add some sample data
    let vendor = Vendor(name: "Auto Parts Inc.", isVerified: true)
    container.mainContext.insert(vendor)
    
    return ReceiptScannerView()
        .modelContainer(container)
} 