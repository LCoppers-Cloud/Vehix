import Foundation
import SwiftUI
import SwiftData
import UIKit

// MARK: - Smart Purchase Order Workflow Manager

@MainActor
class SmartPurchaseOrderWorkflow: ObservableObject {
    // Dependencies
    private let aiProcessor: EnhancedReceiptProcessor
    private let serviceTitanAPI: ServiceTitanAPIService
    private let modelContext: ModelContext?
    private let vendorManager: VendorRecognitionManager
    
    // Published state
    @Published var currentStep: WorkflowStep = .selectJob
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var currentTechnician: ServiceTitanAPITechnician?
    @Published var availableJobs: [ServiceTitanJob] = []
    @Published var selectedJob: ServiceTitanJob?
    @Published var processedReceipt: EnhancedReceiptProcessor.ProcessedReceipt?
    @Published var finalPurchaseOrder: PurchaseOrder?
    @Published var showingJobSelection = false
    @Published var showingReceiptCapture = false
    @Published var showingAmountVerification = false
    @Published var showingSubmissionConfirmation = false
    
    // AI and validation
    @Published var aiConfidence: Double = 0.0
    @Published var extractedVendor: AppVendor?
    @Published var suggestedAmount: Double?
    @Published var lineItems: [AIReceiptAnalysis.LineItemInfo] = []
    @Published var requiresManualVerification = false
    
    // ServiceTitan integration
    @Published var isConnectedToServiceTitan = false
    @Published var technicianJobs: [ServiceTitanJob] = []
    @Published var currentJobProgress: JobProgress?
    
    enum WorkflowStep {
        case selectJob
        case captureReceipt
        case processReceipt
        case verifyAmount
        case reviewDetails
        case submitForApproval
        case complete
    }
    
    struct JobProgress {
        let jobId: String
        let jobNumber: String
        let customerName: String
        let address: String
        let status: String
        let isCurrentlyActive: Bool
    }
    
    init(modelContext: ModelContext?, serviceTitanAPI: ServiceTitanAPIService) {
        self.modelContext = modelContext
        self.serviceTitanAPI = serviceTitanAPI
        self.aiProcessor = EnhancedReceiptProcessor()
        self.vendorManager = VendorRecognitionManager(modelContext: modelContext)
        
        // Initialize with current technician data
        Task {
            await loadTechnicianData()
        }
    }
    
    // MARK: - Workflow Initialization
    
    func startNewPurchaseOrder(for technician: AppUser) async {
        isProcessing = true
        
        // Load technician's ServiceTitan data
        if isConnectedToServiceTitan {
            await loadServiceTitanTechnicianData(for: technician)
        }
        
        // Load available jobs
        await loadTechnicianJobs()
        
        currentStep = .selectJob
        isProcessing = false
    }
    
    private func loadTechnicianData() async {
        // Check ServiceTitan connection
        isConnectedToServiceTitan = serviceTitanAPI.isAuthenticated
        
        if isConnectedToServiceTitan {
            // Load current technician's jobs
            await loadTechnicianJobs()
        }
    }
    
    private func loadServiceTitanTechnicianData(for appUser: AppUser) async {
        // Find matching ServiceTitan technician
        let allTechs = await serviceTitanAPI.fetchTechnicians()
        currentTechnician = allTechs.first { tech in
            tech.email.lowercased() == appUser.email.lowercased() ||
            tech.name.lowercased().contains(appUser.fullName?.lowercased() ?? "")
        }
    }
    
    private func loadTechnicianJobs() async {
        guard let technician = currentTechnician else {
            // Fallback to GPS-based customer detection
            technicianJobs = []
            return
        }
        
        let jobs = await serviceTitanAPI.fetchTechnicianJobs(technicianId: Int(technician.id) ?? 0)
        technicianJobs = jobs.filter { $0.status != "Completed" && $0.status != "Cancelled" }
        
        // Identify current job (In Progress status)
        if let currentJob = jobs.first(where: { $0.status == "In Progress" }) {
            selectedJob = currentJob
            currentJobProgress = JobProgress(
                jobId: currentJob.id,
                jobNumber: currentJob.jobNumber,
                customerName: currentJob.customerName,
                address: currentJob.address,
                status: currentJob.status,
                isCurrentlyActive: true
            )
        }
    }
    
    // MARK: - Job Selection
    
    func selectJob(_ job: ServiceTitanJob) {
        selectedJob = job
        currentJobProgress = JobProgress(
            jobId: job.id,
            jobNumber: job.jobNumber,
            customerName: job.customerName,
            address: job.address,
            status: job.status,
            isCurrentlyActive: job.status == "In Progress"
        )
        
        proceedToNextStep()
    }
    
    func skipJobSelection() {
        // For offline mode or when ServiceTitan is not connected
        currentJobProgress = JobProgress(
            jobId: "OFFLINE-\(UUID().uuidString.prefix(8))",
            jobNumber: "OFFLINE-\(Date().timeIntervalSince1970)",
            customerName: "Manual Entry",
            address: "To be determined",
            status: "Manual",
            isCurrentlyActive: false
        )
        
        proceedToNextStep()
    }
    
    // MARK: - Receipt Processing with AI
    
    func processReceiptImage(_ image: UIImage) async {
        currentStep = .processReceipt
        isProcessing = true
        errorMessage = nil
        
        // Use AI-powered receipt processing
        if let result = await aiProcessor.processReceipt(image, preferredMethod: .hybrid) {
            processedReceipt = result
            aiConfidence = result.confidence
            
            // Extract vendor information
            await processVendorInformation(result.vendor)
            
            // Extract line items
            lineItems = result.lineItems.map { item in
                AIReceiptAnalysis.LineItemInfo(
                    description: item.description,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    total: item.total,
                    category: item.category
                )
            }
            
            // Set suggested amount
            suggestedAmount = result.total
            
            // Determine if manual verification is needed
            requiresManualVerification = result.confidence < 0.85 || result.total > 500.0
            
            proceedToNextStep()
        } else {
            errorMessage = "Failed to process receipt. Please try again or enter details manually."
        }
        
        isProcessing = false
    }
    
    private func processVendorInformation(_ vendorInfo: EnhancedReceiptProcessor.ProcessedReceipt.VendorInfo) async {
        // Try to find existing vendor
        await vendorManager.loadVendors()
        
        let existingVendor = vendorManager.vendorList.first { vendor in
            vendor.name.lowercased() == vendorInfo.name.lowercased() ||
            vendor.name.lowercased().contains(vendorInfo.name.lowercased()) ||
            vendorInfo.name.lowercased().contains(vendor.name.lowercased())
        }
        
        if let vendor = existingVendor {
            extractedVendor = vendor
        } else {
            // Create new vendor suggestion
            extractedVendor = AppVendor(
                id: UUID().uuidString,
                name: vendorInfo.name,
                email: "",
                phone: vendorInfo.phone,
                isActive: true
            )
        }
    }
    
    // MARK: - Amount Verification
    
    func verifyAmount(_ amount: Double) {
        guard let processedReceipt = processedReceipt else { return }
        
        let difference = abs(amount - processedReceipt.total)
        let percentageDifference = difference / processedReceipt.total
        
        if percentageDifference > 0.05 { // 5% difference threshold
            requiresManualVerification = true
            errorMessage = "Amount differs significantly from receipt. Please verify."
        } else {
            suggestedAmount = amount
            proceedToNextStep()
        }
    }
    
    func confirmManualAmount(_ amount: Double) {
        suggestedAmount = amount
        requiresManualVerification = false
        proceedToNextStep()
    }
    
    // MARK: - Purchase Order Creation
    
    func createPurchaseOrder() async -> Bool {
        guard let job = currentJobProgress,
              let vendor = extractedVendor,
              let amount = suggestedAmount,
              let receipt = processedReceipt,
              let modelContext = modelContext else {
            errorMessage = "Missing required information"
            return false
        }
        
        isProcessing = true
        
        // Generate PO number
        let poNumber = generatePONumber(jobNumber: job.jobNumber)
        
        // Create purchase order
        let purchaseOrder = PurchaseOrder(
            poNumber: poNumber,
            date: receipt.date,
            vendorId: vendor.id,
            vendorName: vendor.name,
            status: .submitted,
            subtotal: receipt.subtotal ?? amount,
            tax: receipt.tax ?? 0,
            total: amount,
            notes: "Created via AI receipt processing",
            createdByUserId: getCurrentTechnicianId(),
            createdByName: getCurrentTechnicianName(),
            serviceTitanJobId: job.jobId,
            serviceTitanJobNumber: job.jobNumber
        )
        
        // Add line items
        var poLineItems: [PurchaseOrderLineItem] = []
        for (_, item) in lineItems.enumerated() {
            let lineItem = PurchaseOrderLineItem(
                id: UUID().uuidString,
                purchaseOrderId: purchaseOrder.id,
                inventoryItemId: nil,
                itemDescription: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                lineTotal: item.total
            )
            poLineItems.append(lineItem)
            modelContext.insert(lineItem)
        }
        
        purchaseOrder.lineItems = poLineItems
        
        // Create receipt record
        if let receiptImageData = aiProcessor.result?.rawText.data(using: .utf8) {
            let receiptRecord = Receipt(
                date: receipt.date,
                total: amount,
                imageData: receiptImageData,
                vendorId: vendor.id,
                rawVendorName: vendor.name
            )
            receiptRecord.parsedItems = lineItems.map { item in
                ReceiptItem(
                    name: item.description,
                    quantity: Double(item.quantity),
                    unitPrice: item.unitPrice,
                    totalPrice: item.total,
                    inventoryItemId: nil
                )
            }
            
            purchaseOrder.receipt = receiptRecord
            modelContext.insert(receiptRecord)
        }
        
        // Save to local database
        do {
            modelContext.insert(purchaseOrder)
            try modelContext.save()
            finalPurchaseOrder = purchaseOrder
            
            // Submit to ServiceTitan if connected
            if isConnectedToServiceTitan {
                let items = lineItems.map { item in
                    PurchaseOrderItem(
                        description: item.description,
                        quantity: Int(item.quantity),
                        unitPrice: item.unitPrice,
                        totalPrice: item.total
                    )
                }
                
                let success = await serviceTitanAPI.createPurchaseOrder(
                    technicianId: Int(currentTechnician?.id ?? "0") ?? 0,
                    jobId: Int(job.jobId) ?? 0,
                    vendor: vendor.name,
                    amount: amount,
                    items: items
                )
                
                if success {
                    purchaseOrder.syncWithServiceTitan(
                        poId: "ST-\(purchaseOrder.id)",
                        jobId: job.jobId,
                        jobNumber: job.jobNumber
                    )
                    try modelContext.save()
                }
            }
            
            isProcessing = false
            currentStep = .complete
            return true
            
        } catch {
            errorMessage = "Failed to save purchase order: \(error.localizedDescription)"
            isProcessing = false
            return false
        }
    }
    
    // MARK: - Workflow Navigation
    
    func proceedToNextStep() {
        switch currentStep {
        case .selectJob:
            currentStep = .captureReceipt
        case .captureReceipt:
            currentStep = .processReceipt
        case .processReceipt:
            currentStep = requiresManualVerification ? .verifyAmount : .reviewDetails
        case .verifyAmount:
            currentStep = .reviewDetails
        case .reviewDetails:
            currentStep = .submitForApproval
        case .submitForApproval:
            Task {
                await createPurchaseOrder()
            }
        case .complete:
            break
        }
    }
    
    func goBack() {
        switch currentStep {
        case .captureReceipt:
            currentStep = .selectJob
        case .processReceipt:
            currentStep = .captureReceipt
        case .verifyAmount:
            currentStep = .processReceipt
        case .reviewDetails:
            currentStep = requiresManualVerification ? .verifyAmount : .processReceipt
        case .submitForApproval:
            currentStep = .reviewDetails
        case .complete, .selectJob:
            break
        }
    }
    
    func resetWorkflow() {
        currentStep = .selectJob
        selectedJob = nil
        processedReceipt = nil
        finalPurchaseOrder = nil
        extractedVendor = nil
        suggestedAmount = nil
        lineItems = []
        requiresManualVerification = false
        aiConfidence = 0.0
        errorMessage = nil
    }
    
    // MARK: - Helper Methods
    
    private func generatePONumber(jobNumber: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        
        let sequence = getSequenceNumber()
        return "\(jobNumber)-\(dateString)-\(String(format: "%03d", sequence))"
    }
    
    private func getSequenceNumber() -> Int {
        // Get today's sequence number from database
        guard let modelContext = modelContext else { return 1 }
        
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        let descriptor = FetchDescriptor<PurchaseOrder>(
            predicate: #Predicate<PurchaseOrder> { po in
                po.createdAt >= today && po.createdAt < tomorrow
            }
        )
        
        do {
            let todaysPOs = try modelContext.fetch(descriptor)
            return todaysPOs.count + 1
        } catch {
            return 1
        }
    }
    
    private func getCurrentTechnicianId() -> String {
        return currentTechnician?.id.description ?? "unknown"
    }
    
    private func getCurrentTechnicianName() -> String {
        return currentTechnician?.name ?? "Unknown Technician"
    }
}

// MARK: - Smart Purchase Order Views

struct SmartPurchaseOrderView: View {
    @StateObject private var workflow: SmartPurchaseOrderWorkflow
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let technician: AppUser
    let serviceTitanAPI: ServiceTitanAPIService
    
    init(technician: AppUser, serviceTitanAPI: ServiceTitanAPIService) {
        self.technician = technician
        self.serviceTitanAPI = serviceTitanAPI
        self._workflow = StateObject(wrappedValue: SmartPurchaseOrderWorkflow(
            modelContext: nil, // Will be set in onAppear
            serviceTitanAPI: serviceTitanAPI
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                progressIndicator
                
                // Current step content
                currentStepView
            }
            .navigationTitle("Purchase Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if workflow.currentStep != .selectJob {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Back") {
                            workflow.goBack()
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await workflow.startNewPurchaseOrder(for: technician)
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack {
            ForEach(SmartPurchaseOrderWorkflow.WorkflowStep.allCases, id: \.self) { step in
                Circle()
                    .fill(stepColor(step))
                    .frame(width: 10, height: 10)
                
                if step != SmartPurchaseOrderWorkflow.WorkflowStep.allCases.last {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding()
    }
    
    private func stepColor(_ step: SmartPurchaseOrderWorkflow.WorkflowStep) -> Color {
        if step == workflow.currentStep {
            return .blue
        } else if step.rawValue < workflow.currentStep.rawValue {
            return .green
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    // MARK: - Step Views
    
    @ViewBuilder
    private var currentStepView: some View {
        switch workflow.currentStep {
        case .selectJob:
            JobSelectionStepView(workflow: workflow)
        case .captureReceipt:
            SmartReceiptCaptureStepView(workflow: workflow)
        case .processReceipt:
            ReceiptProcessingStepView(workflow: workflow)
        case .verifyAmount:
            AmountVerificationStepView(workflow: workflow)
        case .reviewDetails:
            ReviewDetailsStepView(workflow: workflow)
        case .submitForApproval:
            SubmissionStepView(workflow: workflow)
        case .complete:
            CompletionStepView(workflow: workflow)
        }
    }
}

// MARK: - Individual Step Views

struct JobSelectionStepView: View {
    @ObservedObject var workflow: SmartPurchaseOrderWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Job")
                .font(.title2)
                .bold()
            
            if workflow.isConnectedToServiceTitan {
                if workflow.technicianJobs.isEmpty {
                    Text("No active jobs found")
                        .foregroundColor(.secondary)
                    
                    Button("Continue Without Job") {
                        workflow.skipJobSelection()
                    }
                    .padding()
                } else {
                    // Display current job prominently
                    if let currentJob = workflow.currentJobProgress, currentJob.isCurrentlyActive {
                        VStack {
                            Text("Current Active Job")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            JobCardView(job: currentJob, isSelected: true) {
                                workflow.proceedToNextStep()
                            }
                        }
                        .padding()
                    }
                    
                    // Other available jobs
                    if workflow.technicianJobs.count > 1 {
                        Text("Other Jobs")
                            .font(.headline)
                        
                        LazyVStack {
                            ForEach(workflow.technicianJobs.filter { $0.status != "In Progress" }) { job in
                                JobRowView(job: job) {
                                    workflow.selectJob(job)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("ServiceTitan Not Connected")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Text("You can still create purchase orders. Job information will be added manually.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                
                Button("Continue") {
                    workflow.skipJobSelection()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

struct JobCardView: View {
    let job: SmartPurchaseOrderWorkflow.JobProgress
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(job.jobNumber)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(job.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            Text(job.customerName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(job.address)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if isSelected {
                Button("Use This Job") {
                    action()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            if !isSelected {
                action()
            }
        }
    }
    
    private var statusColor: Color {
        switch job.status {
        case "In Progress":
            return .green
        case "Scheduled":
            return .blue
        case "On Hold":
            return .orange
        default:
            return .gray
        }
    }
}

struct JobRowView: View {
    let job: ServiceTitanJob
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(job.jobNumber)
                    .font(.headline)
                
                Text(job.customerName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(job.status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .onTapGesture {
            action()
        }
    }
}

struct SmartReceiptCaptureStepView: View {
    @ObservedObject var workflow: SmartPurchaseOrderWorkflow
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Capture Receipt")
                .font(.title2)
                .bold()
            
            if let job = workflow.currentJobProgress {
                VStack {
                    Text("Job: \(job.jobNumber)")
                        .font(.headline)
                    Text(job.customerName)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                
                Button("Process Receipt") {
                    Task {
                        await workflow.processReceiptImage(image)
                    }
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Retake Photo") {
                    capturedImage = nil
                    showingCamera = true
                }
                .foregroundColor(.blue)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Take a clear photo of your receipt")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Open Camera") {
                        showingCamera = true
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingCamera) {
            CameraView(capturedImage: $capturedImage)
        }
    }
}

struct ReceiptProcessingStepView: View {
    @ObservedObject var workflow: SmartPurchaseOrderWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            if workflow.isProcessing {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Processing receipt with AI...")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Extracting vendor, amount, and line items")
                        .foregroundColor(.secondary)
                }
            } else if let result = workflow.processedReceipt {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Receipt Processed Successfully!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    // Confidence indicator
                    HStack {
                        Text("AI Confidence:")
                        ProgressView(value: workflow.aiConfidence)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text("\(Int(workflow.aiConfidence * 100))%")
                    }
                    
                    // Extracted information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted Information:")
                            .font(.subheadline)
                            .bold()
                        
                        Text("Vendor: \(result.vendor.name)")
                        Text("Date: \(result.date.formatted(date: .abbreviated, time: .omitted))")
                        Text("Total: $\(String(format: "%.2f", result.total))")
                        
                        if !workflow.lineItems.isEmpty {
                            Text("Items: \(workflow.lineItems.count)")
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    
                    if workflow.requiresManualVerification {
                        Text("⚠️ Manual verification required")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    }
                    
                    Button("Continue") {
                        workflow.proceedToNextStep()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                Text("Processing failed. Please try again.")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct AmountVerificationStepView: View {
    @ObservedObject var workflow: SmartPurchaseOrderWorkflow
    @State private var manualAmount = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Verify Amount")
                .font(.title2)
                .bold()
            
            if let suggestedAmount = workflow.suggestedAmount {
                VStack {
                    Text("AI detected amount:")
                    Text("$\(String(format: "%.2f", suggestedAmount))")
                        .font(.title)
                        .bold()
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                
                Text("Is this amount correct?")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    Button("Yes, Correct") {
                        workflow.proceedToNextStep()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("No, Let Me Fix") {
                        manualAmount = String(format: "%.2f", suggestedAmount)
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            if !manualAmount.isEmpty {
                VStack {
                    Text("Enter correct amount:")
                        .font(.headline)
                    
                    TextField("Amount", text: $manualAmount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                    
                    Button("Confirm Amount") {
                        if let amount = Double(manualAmount) {
                            workflow.confirmManualAmount(amount)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct ReviewDetailsStepView: View {
    @ObservedObject var workflow: SmartPurchaseOrderWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Review Details")
                .font(.title2)
                .bold()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Job information
                    if let job = workflow.currentJobProgress {
                        GroupBox("Job Information") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Job: \(job.jobNumber)")
                                Text("Customer: \(job.customerName)")
                                Text("Address: \(job.address)")
                            }
                        }
                    }
                    
                    // Vendor information
                    if let vendor = workflow.extractedVendor {
                        GroupBox("Vendor") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name: \(vendor.name)")
                                if let phone = vendor.phone {
                                    Text("Phone: \(phone)")
                                }
                            }
                        }
                    }
                    
                    // Amount information
                    if let amount = workflow.suggestedAmount {
                        GroupBox("Purchase Amount") {
                            Text("Total: $\(String(format: "%.2f", amount))")
                                .font(.title3)
                                .bold()
                        }
                    }
                    
                    // Line items
                    if !workflow.lineItems.isEmpty {
                        GroupBox("Items (\(workflow.lineItems.count))") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(workflow.lineItems.indices, id: \.self) { index in
                                    let item = workflow.lineItems[index]
                                    HStack {
                                        Text(item.description)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("$\(String(format: "%.2f", item.total))")
                                    }
                                    
                                    if index < workflow.lineItems.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Button("Submit for Approval") {
                workflow.proceedToNextStep()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

struct SubmissionStepView: View {
    @ObservedObject var workflow: SmartPurchaseOrderWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            if workflow.isProcessing {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Creating Purchase Order...")
                        .font(.headline)
                        .padding(.top)
                    
                    if workflow.isConnectedToServiceTitan {
                        Text("Submitting to ServiceTitan")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Purchase Order Created!")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.green)
                
                if let po = workflow.finalPurchaseOrder {
                    VStack(spacing: 8) {
                        Text("PO Number: \(po.poNumber)")
                            .font(.headline)
                        
                        Text("Status: \(po.status)")
                            .foregroundColor(.blue)
                        
                        if po.syncedWithServiceTitan {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Synced with ServiceTitan")
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                Text("Your manager will be notified for approval.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct CompletionStepView: View {
    @ObservedObject var workflow: SmartPurchaseOrderWorkflow
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Purchase Order Complete!")
                .font(.title2)
                .bold()
            
            if let po = workflow.finalPurchaseOrder {
                Text("PO #\(po.poNumber)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Text("You'll receive a notification when your manager approves or rejects this purchase order.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
            
            VStack(spacing: 12) {
                Button("Create Another PO") {
                    workflow.resetWorkflow()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Done") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

// MARK: - Extensions

extension SmartPurchaseOrderWorkflow.WorkflowStep: CaseIterable {
    static var allCases: [SmartPurchaseOrderWorkflow.WorkflowStep] {
        return [.selectJob, .captureReceipt, .processReceipt, .verifyAmount, .reviewDetails, .submitForApproval, .complete]
    }
    
    var rawValue: Int {
        switch self {
        case .selectJob: return 0
        case .captureReceipt: return 1
        case .processReceipt: return 2
        case .verifyAmount: return 3
        case .reviewDetails: return 4
        case .submitForApproval: return 5
        case .complete: return 6
        }
    }
} 