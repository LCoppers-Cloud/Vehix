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
        ProgressView("Processing receipt...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // View displayed when an image has been scanned
    private var scannedImageView: some View {
        ReceiptScannerContent(scannerManager: scannerManager, saveReceipt: saveReceipt)
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

// Extracted content view for scanned receipt
private struct ReceiptScannerContent: View {
    @ObservedObject var scannerManager: ReceiptScannerManager
    let saveReceipt: () async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Receipt image
                Image(uiImage: scannerManager.scannedImage ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                // Vendor section
                vendorSection
                
                // Date and total
                VStack(alignment: .leading, spacing: 12) {
                    Text("Receipt Details")
                        .font(.headline)
                    
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
                    
                    HStack {
                        Text("Total:")
                            .foregroundColor(.secondary)
                        
                        if let total = scannerManager.recognizedTotal {
                            Text(currencyFormatter.string(from: NSNumber(value: total)) ?? "$\(total)")
                        } else {
                            Text("Not detected")
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Line items
                if !scannerManager.recognizedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items")
                            .font(.headline)
                        
                        Divider()
                        
                        ForEach(scannerManager.recognizedItems) { item in
                            HStack {
                                Text(item.name)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(currencyFormatter.string(from: NSNumber(value: item.totalPrice)) ?? "$\(item.totalPrice)")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Raw text section (collapsible)
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
                
                // Save button
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
            .padding(.vertical)
        }
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

#Preview {
    // Create a model container with concrete types rather than protocol types
    let container = try! ModelContainer(for: Receipt.self, Vendor.self, ReceiptItem.self)
    
    // Add some sample data
    let vendor = Vendor(name: "Auto Parts Inc.", isVerified: true)
    container.mainContext.insert(vendor)
    
    return ReceiptScannerView()
        .modelContainer(container)
} 