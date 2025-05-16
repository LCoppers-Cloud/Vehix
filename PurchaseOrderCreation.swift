import SwiftUI
import SwiftData
import AVFoundation
import CoreLocation
import UIKit
import UserNotifications

// All component types are already available in the project without special imports

// The enhanced VendorSelectionView is in a separate file
// which is used in place of the original implementation

// MARK: - Models and Enums

// Models
struct PurchaseOrderDraft: Identifiable {
    var id = UUID().uuidString
    var jobId: String
    var jobNumber: String
    var vendorId: String
    var vendorName: String
    var poNumber: String
    var date: Date = Date()
    var total: Double?
    var receiptImage: UIImage?
    var locationDescription: String?
    var coordinates: CLLocationCoordinate2D?
    
    // Convert to the actual PurchaseOrder model
    func toPurchaseOrder(userId: String, userName: String) -> PurchaseOrder {
        let po = PurchaseOrder(
            poNumber: poNumber,
            date: date,
            vendorId: vendorId,
            vendorName: vendorName,
            status: .submitted,
            subtotal: total ?? 0,
            tax: 0, // Could calculate this based on location
            total: total ?? 0,
            notes: nil,
            createdByUserId: userId,
            createdByName: userName,
            serviceTitanJobId: jobId,
            serviceTitanJobNumber: jobNumber
        )
        return po
    }
}

// Purchase Order Creation Flow
class PurchaseOrderCreationManager: ObservableObject {
    @Published var currentStep: POCreationStep = .selectJob
    @Published var draft: PurchaseOrderDraft?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAlert = false
    @Published var requiresReceipt: Bool = true  // Always require receipt
    
    let syncManager: ServiceTitanSyncManager
    
    var locationManager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?
    var locationDescription: String?
    private var locationDelegate: LocationDelegate?
    private var poIdentifier: String?
    
    init(syncManager: ServiceTitanSyncManager) {
        self.syncManager = syncManager
        setupLocationManager()
        
        // Check for any in-progress POs when initializing
        checkForInProgressPurchaseOrders()
    }
    
    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // Store the delegate instance and assign it to locationManager
        locationDelegate = LocationDelegate { [weak self] location, description in
            self?.currentLocation = location
            self?.locationDescription = description
        }
        locationManager.delegate = locationDelegate
    }
    
    // Generate a PO number based on job number
    func generatePONumber(jobNumber: String) -> String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        
        // Format: JobNumber-YYYYMMDD-001
        return "\(jobNumber)-\(dateString)-001"
    }
    
    // Check for any in-progress purchase orders
    private func checkForInProgressPurchaseOrders() {
        if let savedDraft = loadSavedDraft() {
            self.draft = savedDraft
            
            // Determine which step to resume from
            if savedDraft.receiptImage == nil {
                self.currentStep = .captureReceipt
            } else if savedDraft.total == nil {
                self.currentStep = .enterTotal
            } else {
                self.currentStep = .review
            }
            
            // Show notification to resume
            scheduleResumeNotification()
        }
    }
    
    // Save draft to UserDefaults
    private func saveDraft() {
        guard let draft = draft else { return }
        
        // Create dictionary representation of the draft
        var draftDict: [String: Any] = [
            "id": draft.id,
            "jobId": draft.jobId,
            "jobNumber": draft.jobNumber,
            "vendorId": draft.vendorId,
            "vendorName": draft.vendorName,
            "poNumber": draft.poNumber,
            "date": draft.date.timeIntervalSince1970
        ]
        
        if let total = draft.total {
            draftDict["total"] = total
        }
        
        if let locationDesc = locationDescription {
            draftDict["locationDescription"] = locationDesc
        }
        
        if let coordinates = currentLocation {
            draftDict["latitude"] = coordinates.latitude
            draftDict["longitude"] = coordinates.longitude
        }
        
        // Save image separately due to size
        if let image = draft.receiptImage, let imageData = image.jpegData(compressionQuality: 0.7) {
            UserDefaults.standard.set(imageData, forKey: "po_draft_receipt_\(draft.id)")
        }
        
        // Save the draft data
        UserDefaults.standard.set(draftDict, forKey: "po_draft_\(draft.id)")
        
        // Save the current draft ID
        UserDefaults.standard.set(draft.id, forKey: "current_po_draft_id")
        
        // Store for notification purposes
        self.poIdentifier = draft.id
    }
    
    // Load saved draft from UserDefaults
    private func loadSavedDraft() -> PurchaseOrderDraft? {
        guard let draftId = UserDefaults.standard.string(forKey: "current_po_draft_id"),
              let draftDict = UserDefaults.standard.dictionary(forKey: "po_draft_\(draftId)") else {
            return nil
        }
        
        // Extract values from dictionary
        guard let jobId = draftDict["jobId"] as? String,
              let jobNumber = draftDict["jobNumber"] as? String,
              let vendorId = draftDict["vendorId"] as? String,
              let vendorName = draftDict["vendorName"] as? String,
              let poNumber = draftDict["poNumber"] as? String,
              let timestamp = draftDict["date"] as? TimeInterval else {
            return nil
        }
        
        // Create draft object
        var draft = PurchaseOrderDraft(
            jobId: jobId,
            jobNumber: jobNumber,
            vendorId: vendorId,
            vendorName: vendorName,
            poNumber: poNumber,
            date: Date(timeIntervalSince1970: timestamp)
        )
        
        // Set optional properties
        if let total = draftDict["total"] as? Double {
            draft.total = total
        }
        
        draft.locationDescription = draftDict["locationDescription"] as? String
        
        if let latitude = draftDict["latitude"] as? Double,
           let longitude = draftDict["longitude"] as? Double {
            draft.coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        // Load receipt image
        if let imageData = UserDefaults.standard.data(forKey: "po_draft_receipt_\(draftId)"),
           let image = UIImage(data: imageData) {
            draft.receiptImage = image
        }
        
        return draft
    }
    
    // Clear saved draft
    private func clearSavedDraft() {
        guard let draftId = UserDefaults.standard.string(forKey: "current_po_draft_id") else { return }
        
        UserDefaults.standard.removeObject(forKey: "po_draft_\(draftId)")
        UserDefaults.standard.removeObject(forKey: "po_draft_receipt_\(draftId)")
        UserDefaults.standard.removeObject(forKey: "current_po_draft_id")
        
        // Clear any pending notifications
        if let poIdentifier = self.poIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["po_reminder_\(poIdentifier)"])
        }
    }
    
    // Schedule notification to remind user to complete PO
    private func scheduleResumeNotification() {
        guard let poIdentifier = draft?.id else { return }
        
        requestNotificationPermission { granted in
            guard granted else { return }
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Unfinished Purchase Order"
            content.body = "You have a purchase order that needs to be completed. Tap to continue."
            content.sound = .default
            content.categoryIdentifier = "PURCHASE_ORDER"
            content.userInfo = ["po_id": poIdentifier]
            
            // Create trigger - immediate and then repeating
            let immediateTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false) // After 1 minute
            
            // Create request
            let request = UNNotificationRequest(
                identifier: "po_reminder_\(poIdentifier)",
                content: content,
                trigger: immediateTrigger
            )
            
            // Add to notification center
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }
            
            // Register category for actions
            let resumeAction = UNNotificationAction(
                identifier: "RESUME_ACTION",
                title: "Continue PO",
                options: .foreground
            )
            
            let category = UNNotificationCategory(
                identifier: "PURCHASE_ORDER",
                actions: [resumeAction],
                intentIdentifiers: [],
                options: []
            )
            
            UNUserNotificationCenter.current().setNotificationCategories([category])
        }
    }
    
    // Request notification permission
    private func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }
    
    // Select a job for the PO
    func selectJob(_ job: ServiceTitanJob) {
        draft = PurchaseOrderDraft(
            jobId: job.id,
            jobNumber: job.jobNumber,
            vendorId: "",
            vendorName: "",
            poNumber: generatePONumber(jobNumber: job.jobNumber)
        )
        
        // Save the draft
        saveDraft()
        
        moveToNextStep()
    }
    
    // Select a vendor for the PO
    func selectVendor(_ vendor: AppVendor) {
        guard var draft = draft else { return }
        
        draft.vendorId = vendor.id
        draft.vendorName = vendor.name
        self.draft = draft
        
        // Save the updated draft
        saveDraft()
        
        moveToNextStep()
    }
    
    // Set receipt image for the PO
    func setReceiptImage(_ image: UIImage) {
        guard var draft = draft else { return }
        
        draft.receiptImage = image
        self.draft = draft
        
        // Save the updated draft
        saveDraft()
        
        // Move to next step if receipts are required
        if requiresReceipt {
            moveToNextStep()
        }
    }
    
    // Set total amount for the PO
    func setTotal(_ amount: Double) {
        guard var draft = draft else { return }
        
        draft.total = amount
        self.draft = draft
        
        // Save the updated draft
        saveDraft()
        
        moveToNextStep()
    }
    
    // Save the completed purchase order
    func savePurchaseOrder(userId: String, userName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let draft = draft else {
            completion(false, "No draft purchase order available")
            return
        }
        
        // Validate required fields
        if requiresReceipt && draft.receiptImage == nil {
            completion(false, "Receipt image is required")
            return
        }
        
        if draft.total == nil || draft.total == 0 {
            completion(false, "Total amount is required")
            return
        }
        
        guard let modelContext = syncManager.getModelContext() else {
            completion(false, "Database not available")
            return
        }
        
        // Convert draft to actual purchase order
        let purchaseOrder = draft.toPurchaseOrder(userId: userId, userName: userName)
        
        do {
            // Save to database
            modelContext.insert(purchaseOrder)
            try modelContext.save()
            
            // Attempt to sync with ServiceTitan (if available)
            if let serviceTitanPoId = self.syncWithServiceTitan(purchaseOrder: purchaseOrder) {
                purchaseOrder.serviceTitanPoId = serviceTitanPoId
                purchaseOrder.syncedWithServiceTitan = true
                purchaseOrder.serviceTitanSyncDate = Date()
                try modelContext.save()
            }
            
            // Clear saved draft
            clearSavedDraft()
            
            // Reset state
            self.draft = nil
            self.currentStep = .selectJob
            
            completion(true, "Purchase order created successfully")
        } catch {
            completion(false, "Failed to save purchase order: \(error.localizedDescription)")
        }
    }
    
    // Simulate syncing with ServiceTitan
    private func syncWithServiceTitan(purchaseOrder: PurchaseOrder) -> String? {
        // This would be a real API call to ServiceTitan in production
        // For now, we'll just return a mock ID
        return "STPO-\(Int.random(in: 10000...99999))"
    }
    
    // Move to the next step
    func moveToNextStep() {
        switch currentStep {
        case .selectJob:
            currentStep = .selectVendor
        case .selectVendor:
            currentStep = .captureReceipt
        case .captureReceipt:
            currentStep = .enterTotal
        case .enterTotal:
            currentStep = .review
        case .review:
            break // No further step
        }
    }
}

// Location manager delegate
class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onLocationUpdate: (CLLocationCoordinate2D, String?) -> Void
    
    init(onLocationUpdate: @escaping (CLLocationCoordinate2D, String?) -> Void) {
        self.onLocationUpdate = onLocationUpdate
        super.init()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Get readable address from coordinates
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                self.onLocationUpdate(location.coordinate, nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                self.onLocationUpdate(location.coordinate, nil)
                return
            }
            
            // Format the address
            var addressString = ""
            if let city = placemark.locality {
                addressString += city
            }
            if let state = placemark.administrativeArea {
                addressString += addressString.isEmpty ? state : ", \(state)"
            }
            
            self.onLocationUpdate(location.coordinate, addressString)
        }
    }
}

// Steps in the purchase order creation flow
enum POCreationStep {
    case selectJob
    case selectVendor
    case captureReceipt
    case enterTotal
    case review
}

// Main purchase order creation view
struct PurchaseOrderCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AppAuthService
    
    @StateObject private var creationManager: PurchaseOrderCreationManager
    @State private var showTutorial = false
    
    init(syncManager: ServiceTitanSyncManager) {
        _creationManager = StateObject(wrappedValue: PurchaseOrderCreationManager(syncManager: syncManager))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress indicator
                ProgressView(value: progressValue, total: 5.0)
                    .padding()
                
                // Current step indicator
                Text(stepTitle)
                    .font(.headline)
                    .padding(.bottom)
                
                // Main content based on current step
                switch creationManager.currentStep {
                case .selectJob:
                    JobSelectionView(creationManager: creationManager)
                case .selectVendor:
                    VendorSelectionView(creationManager: creationManager)
                case .captureReceipt:
                    ReceiptCaptureStepView(creationManager: creationManager)
                case .enterTotal:
                    TotalEntryView(creationManager: creationManager)
                case .review:
                    PurchaseOrderReviewView(creationManager: creationManager)
                }
            }
            .navigationTitle("New Purchase Order")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button(action: {
                    showTutorial = true
                }) {
                    Image(systemName: "questionmark.circle")
                }
            )
            .alert(isPresented: $creationManager.showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(creationManager.errorMessage ?? "An error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                creationManager.syncManager.setModelContext(modelContext)
                checkFirstTimeTutorial()
            }
            .fullScreenCover(isPresented: $showTutorial) {
                PurchaseOrderTutorial(showTutorial: $showTutorial)
            }
        }
    }
    
    // Progress value for the progress bar
    private var progressValue: Double {
        switch creationManager.currentStep {
        case .selectJob: return 1.0
        case .selectVendor: return 2.0
        case .captureReceipt: return 3.0
        case .enterTotal: return 4.0
        case .review: return 5.0
        }
    }
    
    // Title for the current step
    private var stepTitle: String {
        switch creationManager.currentStep {
        case .selectJob: return "Select Job"
        case .selectVendor: return "Select Vendor"
        case .captureReceipt: return "Capture Receipt"
        case .enterTotal: return "Enter Total"
        case .review: return "Review Purchase Order"
        }
    }
    
    // Check if this is first time using Purchase Orders and show tutorial
    private func checkFirstTimeTutorial() {
        // Check if user has seen the tutorial before
        let hasSeenTutorial = UserDefaults.standard.bool(forKey: "hasSeenPOTutorial")
        if !hasSeenTutorial {
            showTutorial = true
        }
    }
}

// View for selecting a job
struct JobSelectionView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @State private var jobs: [ServiceTitanJob] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading today's jobs...")
                    .padding()
            } else if jobs.isEmpty {
                VStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .padding()
                    
                    Text("No jobs found for today")
                        .font(.headline)
                        .padding()
                    
                    Text("Please sync with ServiceTitan or try again later.")
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Sync Now") {
                        loadJobs()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                Text("Select the job for this purchase:")
                    .font(.subheadline)
                    .padding()
                
                List {
                    ForEach(jobs) { job in
                        JobRow(job: job) {
                            creationManager.selectJob(job)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .onAppear {
            loadJobs()
        }
    }
    
    private func loadJobs() {
        isLoading = true
        
        // This would normally get the technician ID from the current user
        let techId = "1" // Placeholder
        
        creationManager.syncManager.syncJobsForTechnician(techId: techId) { success in
            isLoading = false
            if success {
                jobs = creationManager.syncManager.jobs
            }
        }
    }
}

// Job row component
struct JobRow: View {
    let job: ServiceTitanJob
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.displayName)
                    .font(.headline)
                
                Text(job.displayDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Status: \(job.status)")
                        .font(.caption)
                        .foregroundColor(job.status == "In Progress" ? .green : .blue)
                    
                    Spacer()
                    
                    // Format date
                    Text(formattedDate(job.scheduledDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// View for selecting a vendor - Using the enhanced VendorSelectionView from VendorSelectionView.swift
// This is needed for the PurchaseOrderCreationView to reference when switching between steps

// Custom receipt capture view for creating purchase orders
struct ReceiptCaptureStepView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @State private var showingReceiptCapture = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = creationManager.draft?.receiptImage {
                // Display the captured receipt
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                Text("Receipt captured successfully!")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Button("Continue") {
                    creationManager.moveToNextStep()
                }
                .padding()
                .frame(minWidth: 200)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Retake Photo") {
                    showingReceiptCapture = true
                }
                .padding(.top, 10)
            } else {
                // Show instructions and capture button
                VStack(spacing: 30) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                    
                    Text("Receipt Required")
                        .font(.title2)
                        .bold()
                    
                    VStack(spacing: 10) {
                        Text("A photo of the receipt is required to continue.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        
                        Text("Take a clear photo showing the vendor name, date, and total amount.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Receipt capture tips
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ensure good lighting")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Entire receipt visible in frame")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Focus on text clarity")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Button(action: {
                        showingReceiptCapture = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Capture Receipt")
                        }
                        .frame(minWidth: 200)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingReceiptCapture) {
            ReceiptCaptureView(onCapture: { image in
                creationManager.setReceiptImage(image)
            })
        }
    }
}

// Using shared CameraView from CameraComponents.swift

// View for entering total amount
struct TotalEntryView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @State private var totalText = ""
    @State private var showingAlert = false
    
    var body: some View {
        VStack {
            if let draft = creationManager.draft, let receiptImage = draft.receiptImage {
                // Receipt image
                Image(uiImage: receiptImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(10)
                    .padding()
                
                // Instructions
                Text("Enter the total amount from the receipt")
                    .font(.headline)
                    .padding()
                
                // Total amount entry
                HStack {
                    Text("$")
                        .font(.title)
                    
                    TextField("Amount", text: $totalText)
                        .keyboardType(.decimalPad)
                        .font(.title)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Continue button
                Button("Continue") {
                    if let total = Double(totalText) {
                        creationManager.setTotal(total)
                    } else {
                        showingAlert = true
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
                .disabled(totalText.isEmpty)
            } else {
                Text("Error: Receipt image not available")
                    .foregroundColor(.red)
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Invalid Amount"),
                message: Text("Please enter a valid number"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// View for reviewing the purchase order
struct PurchaseOrderReviewView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    var body: some View {
        VStack {
            if let draft = creationManager.draft {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Summary header
                        Text("Purchase Order Summary")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // PO details
                        Group {
                            PurchaseOrderDetailRow(label: "PO Number", value: draft.poNumber)
                            PurchaseOrderDetailRow(label: "Job", value: draft.jobNumber)
                            PurchaseOrderDetailRow(label: "Vendor", value: draft.vendorName)
                            PurchaseOrderDetailRow(label: "Date", value: formattedDate(draft.date))
                            
                            if let location = creationManager.locationDescription {
                                PurchaseOrderDetailRow(label: "Location", value: location)
                            }
                            
                            if let total = draft.total {
                                PurchaseOrderDetailRow(label: "Total Amount", value: "$\(String(format: "%.2f", total))")
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.vertical)
                        
                        // Receipt image
                        if let receiptImage = draft.receiptImage {
                            Text("Receipt")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Image(uiImage: receiptImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(10)
                                .padding()
                        }
                    }
                }
                
                Spacer()
                
                // Submit button
                Button(action: submitPurchaseOrder) {
                    if isSubmitting {
                        ProgressView()
                            .padding()
                    } else {
                        Text("Submit Purchase Order")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .disabled(isSubmitting)
                .padding(.bottom)
            } else {
                Text("Error: Purchase order data not available")
                    .foregroundColor(.red)
            }
        }
        .alert(isPresented: $showingSuccessAlert) {
            Alert(
                title: Text("Success"),
                message: Text(successMessage),
                dismissButton: .default(Text("OK")) {
                    dismiss()
                }
            )
        }
    }
    
    private func submitPurchaseOrder() {
        isSubmitting = true
        
        // Get current user info
        guard let user = authService.currentUser else {
            creationManager.errorMessage = "User not logged in"
            creationManager.showingAlert = true
            isSubmitting = false
            return
        }
        
        // Save the purchase order
        creationManager.savePurchaseOrder(
            userId: user.id,
            userName: user.fullName ?? user.email
        ) { success, message in
            isSubmitting = false
            
            if success {
                successMessage = message ?? "Purchase order created successfully"
                showingSuccessAlert = true
            } else {
                creationManager.errorMessage = message ?? "Failed to create purchase order"
                creationManager.showingAlert = true
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Helper view for displaying detail rows
struct PurchaseOrderDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
            
            Spacer()
        }
    }
} 