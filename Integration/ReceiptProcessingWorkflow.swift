import SwiftUI
import SwiftData
import PhotosUI
import VisionKit

// MARK: - Complete Receipt Processing Workflow

struct ReceiptProcessingWorkflow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var workflowManager = ReceiptWorkflowManager()
    @State private var currentStep: WorkflowStep = .jobSelection
    @State private var selectedJob: ServiceTitanJob?
    @State private var purchaseOrderNumber: String = ""
    @State private var showScanner = false
    @State private var processedReceipt: ProcessedReceiptData?
    @State private var showingConfirmation = false
    @State private var estimatedAmount: Double = 0
    
    enum WorkflowStep: Int, CaseIterable {
        case jobSelection = 0
        case purchaseOrderEntry = 1
        case receiptCapture = 2
        case aiProcessing = 3
        case verification = 4
        case submission = 5
        case completion = 6
        
        var title: String {
            switch self {
            case .jobSelection: return "Select Job"
            case .purchaseOrderEntry: return "Purchase Order"
            case .receiptCapture: return "Capture Receipt"
            case .aiProcessing: return "AI Processing"
            case .verification: return "Verify Details"
            case .submission: return "Submit for Approval"
            case .completion: return "Complete"
            }
        }
        
        var description: String {
            switch self {
            case .jobSelection: return "Choose the job this receipt is for"
            case .purchaseOrderEntry: return "Enter the PO number from ServiceTitan"
            case .receiptCapture: return "Take a photo of your receipt"
            case .aiProcessing: return "AI is analyzing the receipt"
            case .verification: return "Verify AI extracted information"
            case .submission: return "Submit receipt for manager approval"
            case .completion: return "Receipt submitted successfully"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                progressIndicator
                
                // Current step content
                stepContent
                
            }
            .navigationTitle("Receipt Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if currentStep != .completion {
                    ToolbarItem(placement: .primaryAction) {
                        nextButton
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                ReceiptScannerView()
                    .onDisappear {
                        if workflowManager.hasProcessedReceipt {
                            currentStep = .verification
                        }
                    }
            }
            .alert("Receipt Submitted", isPresented: $showingConfirmation) {
                Button("OK") {
                    currentStep = .completion
                }
            } message: {
                Text("Your receipt has been submitted for manager approval and will be synced with ServiceTitan.")
            }
            .onAppear {
                workflowManager.setModelContext(modelContext)
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            // Step progress bar
            HStack {
                ForEach(WorkflowStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(stepColor(for: step))
                        .frame(width: 12, height: 12)
                    
                    if step != WorkflowStep.allCases.last {
                        Rectangle()
                            .fill(step.rawValue <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal)
            
            // Current step info
            VStack(spacing: 4) {
                Text(currentStep.title)
                    .font(.headline)
                
                Text(currentStep.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func stepColor(for step: WorkflowStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return .green
        } else if step == currentStep {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .jobSelection:
            jobSelectionView
        case .purchaseOrderEntry:
            purchaseOrderView
        case .receiptCapture:
            receiptCaptureView
        case .aiProcessing:
            aiProcessingView
        case .verification:
            verificationView
        case .submission:
            submissionView
        case .completion:
            completionView
        }
    }
    
    // MARK: - Job Selection View
    
    private var jobSelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Select Active Job")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Choose which job this receipt is associated with")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Job list
            if workflowManager.activeJobs.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading active jobs...")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(workflowManager.activeJobs, id: \.id) { job in
                            JobSelectionRow(
                                job: job,
                                isSelected: selectedJob?.id == job.id,
                                onSelect: { selectedJob = job }
                            )
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
        .onAppear {
            Task {
                await workflowManager.loadActiveJobs()
            }
        }
    }
    
    // MARK: - Purchase Order View
    
    private var purchaseOrderView: some View {
        VStack(spacing: 30) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Purchase Order Number")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Enter the PO number from ServiceTitan")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Selected job info
            if let job = selectedJob {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Job")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(job.jobNumber)
                                .font(.headline)
                            Text(job.customerName)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let estimatedTotal = job.estimatedTotal {
                            Text("Est: \(currencyFormatter.string(from: NSNumber(value: estimatedTotal)) ?? "$\(estimatedTotal)")")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
            
            // PO Number input
            VStack(alignment: .leading, spacing: 8) {
                Text("Purchase Order Number")
                    .font(.headline)
                
                TextField("Enter PO number...", text: $purchaseOrderNumber)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // Estimated amount
            VStack(alignment: .leading, spacing: 8) {
                Text("Estimated Amount (Optional)")
                    .font(.headline)
                
                TextField("Expected total amount", value: $estimatedAmount, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Receipt Capture View
    
    private var receiptCaptureView: some View {
        VStack(spacing: 30) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Capture Receipt")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Take a clear photo of your receipt")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Receipt tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Tips for best results:")
                    .font(.headline)
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    Text("Ensure good lighting and the entire receipt is visible")
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "rectangle.and.hand.point.up.left")
                        .foregroundColor(.blue)
                    Text("Lay the receipt flat and avoid shadows")
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "eye")
                        .foregroundColor(.green)
                    Text("Check that all text is clear and readable")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Capture button
            Button(action: {
                showScanner = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Open Camera")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - AI Processing View
    
    private var aiProcessingView: some View {
        VStack(spacing: 30) {
            // AI Processing animation
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 6)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(workflowManager.isProcessing ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: workflowManager.isProcessing)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("AI is analyzing your receipt")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("ChatGPT Vision is extracting vendor details, line items, and amounts with high accuracy")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Processing status
            if !workflowManager.processingStatus.isEmpty {
                Text(workflowManager.processingStatus)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            Task {
                await workflowManager.processReceipt()
                if workflowManager.hasProcessedReceipt {
                    currentStep = .verification
                }
            }
        }
    }
    
    // MARK: - Verification View
    
    private var verificationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Verify AI Results")
                    .font(.title2)
                    .fontWeight(.medium)
                
                if let receipt = workflowManager.processedReceipt {
                    // Confidence indicator
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        
                        Text("\(Int(receipt.confidence * 100))% AI Confidence")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(receipt.processingMethod)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Receipt details
                    VStack(alignment: .leading, spacing: 16) {
                        // Vendor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Vendor")
                                .font(.headline)
                            
                            Text(receipt.vendorName)
                                .font(.title3)
                        }
                        
                        Divider()
                        
                        // Financial details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Financial Details")
                                .font(.headline)
                            
                            HStack {
                                Text("Total:")
                                Spacer()
                                Text(currencyFormatter.string(from: NSNumber(value: receipt.total)) ?? "$\(receipt.total)")
                                    .fontWeight(.semibold)
                            }
                            
                            if let subtotal = receipt.subtotal {
                                HStack {
                                    Text("Subtotal:")
                                    Spacer()
                                    Text(currencyFormatter.string(from: NSNumber(value: subtotal)) ?? "$\(subtotal)")
                                }
                            }
                            
                            if let tax = receipt.tax {
                                HStack {
                                    Text("Tax:")
                                    Spacer()
                                    Text(currencyFormatter.string(from: NSNumber(value: tax)) ?? "$\(tax)")
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Line items
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Items (\(receipt.lineItems.count))")
                                .font(.headline)
                            
                            ForEach(receipt.lineItems, id: \.description) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.description)
                                            .lineLimit(2)
                                        
                                        if let category = item.category {
                                            Text(category)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing) {
                                        Text(currencyFormatter.string(from: NSNumber(value: item.total)) ?? "$\(item.total)")
                                            .fontWeight(.medium)
                                        
                                        if item.quantity > 1 {
                                            Text("\(item.quantity) × $\(String(format: "%.2f", item.unitPrice))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                if item.description != receipt.lineItems.last?.description {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Amount verification
                    if estimatedAmount > 0 {
                        let difference = abs(receipt.total - estimatedAmount)
                        let percentDifference = (difference / estimatedAmount) * 100
                        
                        HStack {
                            Image(systemName: percentDifference > 10 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(percentDifference > 10 ? .orange : .green)
                            
                            VStack(alignment: .leading) {
                                Text("Amount Check")
                                    .font(.headline)
                                
                                Text("Expected: \(currencyFormatter.string(from: NSNumber(value: estimatedAmount)) ?? "$\(estimatedAmount)")")
                                Text("Actual: \(currencyFormatter.string(from: NSNumber(value: receipt.total)) ?? "$\(receipt.total)")")
                                
                                if percentDifference > 10 {
                                    Text("⚠️ Significant difference detected")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Submission View
    
    private var submissionView: some View {
        VStack(spacing: 30) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Ready to Submit")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Your receipt will be sent for manager approval and synced with ServiceTitan")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Summary
            if let job = selectedJob, let receipt = workflowManager.processedReceipt {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Submission Summary")
                            .font(.headline)
                        Spacer()
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Job:")
                            Spacer()
                            Text(job.jobNumber)
                        }
                        
                        HStack {
                            Text("PO Number:")
                            Spacer()
                            Text(purchaseOrderNumber)
                        }
                        
                        HStack {
                            Text("Vendor:")
                            Spacer()
                            Text(receipt.vendorName)
                        }
                        
                        HStack {
                            Text("Total:")
                            Spacer()
                            Text(currencyFormatter.string(from: NSNumber(value: receipt.total)) ?? "$\(receipt.total)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Items:")
                            Spacer()
                            Text("\(receipt.lineItems.count) items")
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            Button(action: {
                Task {
                    await submitReceipt()
                }
            }) {
                HStack {
                    if workflowManager.isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    
                    Text(workflowManager.isSubmitting ? "Submitting..." : "Submit Receipt")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(workflowManager.isSubmitting)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("Receipt Submitted!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your receipt has been successfully submitted for approval and will be synced with ServiceTitan")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Next steps
            VStack(alignment: .leading, spacing: 12) {
                Text("What happens next:")
                    .font(.headline)
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                    Text("Manager will review and approve the receipt")
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                    Text("Receipt data will sync with ServiceTitan")
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                    Text("You'll get a notification when processed")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            Button(action: {
                dismiss()
            }) {
                Text("Close")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Next Button
    
    private var nextButton: some View {
        Button(action: {
            advance()
        }) {
            Text("Next")
        }
        .disabled(!canAdvance)
    }
    
    private var canAdvance: Bool {
        switch currentStep {
        case .jobSelection:
            return selectedJob != nil
        case .purchaseOrderEntry:
            return !purchaseOrderNumber.isEmpty
        case .receiptCapture:
            return false // Handled by scanner
        case .aiProcessing:
            return false // Handled automatically
        case .verification:
            return workflowManager.hasProcessedReceipt
        case .submission:
            return false // Handled by submit button
        case .completion:
            return false
        }
    }
    
    private func advance() {
        switch currentStep {
        case .jobSelection:
            currentStep = .purchaseOrderEntry
        case .purchaseOrderEntry:
            currentStep = .receiptCapture
        case .receiptCapture:
            currentStep = .aiProcessing
        case .aiProcessing:
            currentStep = .verification
        case .verification:
            currentStep = .submission
        case .submission:
            currentStep = .completion
        case .completion:
            break
        }
    }
    
    private func submitReceipt() async {
        guard let job = selectedJob,
              let receipt = workflowManager.processedReceipt else { return }
        
        await workflowManager.submitReceipt(
            job: job,
            poNumber: purchaseOrderNumber,
            receipt: receipt
        )
        
        showingConfirmation = true
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

// MARK: - Supporting Views

struct JobSelectionRow: View {
    let job: ServiceTitanJob
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.jobNumber)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(job.customerName)
                        .foregroundColor(.secondary)
                    
                    if !job.address.isEmpty {
                        Text(job.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let total = job.estimatedTotal {
                        Text("Est: $\(String(format: "%.2f", total))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Workflow Manager

@MainActor
class ReceiptWorkflowManager: ObservableObject {
    @Published var activeJobs: [ServiceTitanJob] = []
    @Published var isProcessing = false
    @Published var isSubmitting = false
    @Published var processingStatus = ""
    @Published var processedReceipt: ProcessedReceiptData?
    @Published var hasProcessedReceipt = false
    
    private var modelContext: ModelContext?
    private let aiProcessor = EnhancedReceiptProcessor()
    private lazy var serviceTitanService = ServiceTitanAPIService(
        environment: .integration,
        clientId: Bundle.main.object(forInfoDictionaryKey: "ServiceTitanClientId") as? String ?? "",
        clientSecret: Bundle.main.object(forInfoDictionaryKey: "ServiceTitanClientSecret") as? String ?? ""
    )
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func loadActiveJobs() async {
        // Simulate loading active jobs from ServiceTitan
        processingStatus = "Loading active jobs..."
        
        // In a real implementation, this would fetch from ServiceTitan API
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        activeJobs = [
            ServiceTitanJob(
                id: "JOB001",
                jobNumber: "12345",
                customerName: "Smith Plumbing",
                address: "123 Main St, Anytown USA",
                scheduledDate: Date(),
                status: "In Progress",
                jobDescription: "HVAC System Maintenance",
                serviceTitanId: "ST-JOB-10045678",
                estimatedTotal: 450.00
            ),
            ServiceTitanJob(
                id: "JOB002",
                jobNumber: "12346",
                customerName: "Johnson HVAC",
                address: "456 Oak Ave, Anytown USA",
                scheduledDate: Date().addingTimeInterval(86400),
                status: "Scheduled",
                jobDescription: "Commercial Refrigeration Repair",
                serviceTitanId: "ST-JOB-10045679",
                estimatedTotal: 1200.00
            )
        ]
        
        processingStatus = ""
    }
    
    func processReceipt() async {
        // This would be called with the actual receipt image from the scanner
        isProcessing = true
        processingStatus = "🤖 Analyzing with ChatGPT Vision..."
        
        // Simulate AI processing
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Mock processed receipt data
        processedReceipt = ProcessedReceiptData(
            vendorName: "Auto Parts Plus",
            date: Date(),
            total: 127.45,
            subtotal: 118.50,
            tax: 8.95,
            lineItems: [
                ProcessedLineItem(
                    description: "Oil Filter - Premium",
                    quantity: 2,
                    unitPrice: 24.99,
                    total: 49.98,
                    category: "Parts"
                ),
                ProcessedLineItem(
                    description: "Motor Oil 5W-30 - 5Qt",
                    quantity: 1,
                    unitPrice: 68.52,
                    total: 68.52,
                    category: "Fluids"
                )
            ],
            confidence: 0.94,
            processingMethod: "ChatGPT Vision API",
            rawText: "AUTO PARTS PLUS\n123 Service Rd\nOil Filter - Premium  2 @ $24.99  $49.98\nMotor Oil 5W-30 - 5Qt  1 @ $68.52  $68.52\nSubtotal: $118.50\nTax: $8.95\nTotal: $127.45"
        )
        
        hasProcessedReceipt = true
        isProcessing = false
        processingStatus = "✅ Processing complete - 94% confidence"
    }
    
    func submitReceipt(job: ServiceTitanJob, poNumber: String, receipt: ProcessedReceiptData) async {
        isSubmitting = true
        
        // Create receipt record with correct constructor
        let receiptRecord = Receipt(
            date: receipt.date,
            total: receipt.total,
            taxAmount: receipt.tax,
            receiptNumber: poNumber,
            notes: "AI processed with \(String(format: "%.0f", receipt.confidence * 100))% confidence",
            rawVendorName: receipt.vendorName
        )
        
        // Add line items with correct types
        var items: [ReceiptItem] = []
        for item in receipt.lineItems {
            let receiptItem = ReceiptItem(
                name: item.description,
                quantity: Double(item.quantity),
                unitPrice: item.unitPrice,
                totalPrice: item.total
            )
            items.append(receiptItem)
        }
        receiptRecord.parsedItems = items
        
        // Save to local database
        if let context = modelContext {
            context.insert(receiptRecord)
            try? context.save()
        }
        
        // Submit to ServiceTitan (simulated)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        isSubmitting = false
    }
}

// MARK: - Data Models

struct ProcessedReceiptData {
    let vendorName: String
    let date: Date
    let total: Double
    let subtotal: Double?
    let tax: Double?
    let lineItems: [ProcessedLineItem]
    let confidence: Double
    let processingMethod: String
    let rawText: String
}

struct ProcessedLineItem {
    let description: String
    let quantity: Int
    let unitPrice: Double
    let total: Double
    let category: String?
}

#Preview {
    ReceiptProcessingWorkflow()
        .modelContainer(for: Receipt.self)
} 