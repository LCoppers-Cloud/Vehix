import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AppAuthService
    
    let task: AppTask
    
    @State private var showingEditTask = false
    @State private var showingDeleteConfirmation = false
    @State private var showingStatusSheet = false
    @State private var showingAssignSheet = false
    @State private var showingRescheduleSheet = false
    @State private var selectedSubtask: AppSubtask?
    @State private var newSubtaskTitle = ""
    @State private var isAddingSubtask = false
    
    @Query private var technicians: [AuthUser]
    
    private var canEdit: Bool {
        guard let currentUser = authService.currentUser else { return false }
        return currentUser.userRole == .admin || currentUser.userRole == .dealer || 
               currentUser.id == task.assignedById
    }
    
    private var isAssignedToCurrentUser: Bool {
        guard let currentUser = authService.currentUser else { return false }
        return currentUser.id == task.assignedToId
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Task header
                taskHeader
                
                // Timeline status indicator
                statusTimeline
                
                // Details section
                taskDetailsSection
                
                // Vehicle section (if assigned)
                if task.vehicle != nil {
                    vehicleSection
                }
                
                // Assignment section
                assignmentSection
                
                // Recurrence section (if recurring)
                if task.isRecurring {
                    recurrenceSection
                }
                
                // Subtasks section
                subtasksSection
                
                // Action buttons based on role
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingEditTask = true
                        } label: {
                            Label("Edit Task", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditTask) {
            EditTaskView(task: task)
        }
        .sheet(isPresented: $showingStatusSheet) {
            TaskStatusUpdateSheet(task: task)
        }
        .sheet(isPresented: $showingRescheduleSheet) {
            RescheduleTaskSheet(task: task)
        }
        .sheet(isPresented: $showingAssignSheet) {
            AssignTaskSheet(task: task)
        }
        .alert("Delete this task?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    // MARK: - View Components
    
    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                if task.isOverdue {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("Overdue")
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            
            HStack {
                // Priority pill
                Text(task.taskPriority.rawValue)
                    .font(.caption)
                    .foregroundColor(Color(task.priorityColor))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(task.priorityColor).opacity(0.2))
                    .cornerRadius(10)
                
                // Status pill
                Text(task.taskStatus.rawValue)
                    .font(.caption)
                    .foregroundColor(Color(task.statusColor))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(task.statusColor).opacity(0.2))
                    .cornerRadius(10)
                
                Spacer()
                
                // Date pill
                Text("Due: \(task.dueDate, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(task.isOverdue ? .red : .secondary)
            }
            
            if !task.taskDescription.isEmpty {
                Text(task.taskDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusTimeline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Status Timeline")
                .font(.headline)
            
            HStack(spacing: 0) {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    let isActive = task.taskStatus.rawValue == status.rawValue
                    let isPast = statusIndex(of: task.taskStatus) >= statusIndex(of: status)
                    
                    VStack {
                        Circle()
                            .fill(isActive ? Color(task.statusColor) : (isPast ? Color.gray : Color.gray.opacity(0.3)))
                            .frame(width: 12, height: 12)
                        
                        Text(status.rawValue)
                            .font(.caption2)
                            .foregroundColor(isActive ? Color(task.statusColor) : (isPast ? Color.gray : Color.gray.opacity(0.5)))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if status != TaskStatus.allCases.last {
                        Rectangle()
                            .fill(statusIndex(of: task.taskStatus) > statusIndex(of: status) ? Color.gray : Color.gray.opacity(0.3))
                            .frame(height: 2)
                            .offset(y: -10)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var taskDetailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.headline)
            
            if let taskType = task.taskType {
                labelRow(icon: "tag.fill", label: "Type", value: taskType)
            }
            
            if let completedDate = task.completedDate {
                labelRow(icon: "checkmark.circle.fill", label: "Completed", value: completedDate, formatter: dateTimeFormatter)
            }
            
            labelRow(icon: "calendar", label: "Created", value: task.createdAt, formatter: dateTimeFormatter)
            
            if task.createdAt != task.updatedAt {
                labelRow(icon: "arrow.clockwise", label: "Updated", value: task.updatedAt, formatter: dateTimeFormatter)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var vehicleSection: some View {
        Group {
            if let vehicle = task.vehicle {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Vehicle")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text(vehicle.displayName)
                                .font(.body)
                            
                            if let plate = vehicle.licensePlate {
                                Text("License: \(plate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        NavigationLink(destination: VehicleDetailView(vehicle: vehicle)) {
                            Text("View")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assignment")
                .font(.headline)
            
            if let assigneeName = task.assignedToName {
                labelRow(
                    icon: "person.fill", 
                    label: "Assigned To", 
                    value: assigneeName,
                    trailingView: canEdit ? 
                        AnyView(
                            Button("Change") {
                                showingAssignSheet = true
                            }
                            .font(.caption)
                        ) : nil
                )
            } else {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    
                    Text("Not assigned")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if canEdit {
                        Button("Assign") {
                            showingAssignSheet = true
                        }
                        .font(.caption)
                    }
                }
            }
            
            if let assignerName = task.assignedByName {
                labelRow(icon: "person.badge.shield.checkmark", label: "Created By", value: assignerName)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recurrence")
                .font(.headline)
            
            labelRow(icon: "repeat", label: "Frequency", value: task.taskFrequency.rawValue)
            
            if let startDate = task.startDate {
                labelRow(icon: "calendar", label: "Start Date", value: startDate, formatter: dateFormatter)
            }
            
            if let endDate = task.endDate {
                labelRow(icon: "calendar.badge.clock", label: "End Date", value: endDate, formatter: dateFormatter)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Subtasks")
                    .font(.headline)
                
                Spacer()
                
                if isAssignedToCurrentUser || canEdit {
                    Button {
                        isAddingSubtask = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if let subtasks = task.subtasks, !subtasks.isEmpty {
                ForEach(subtasks) { subtask in
                    subtaskRow(subtask)
                }
            } else if !isAddingSubtask {
                Text("No subtasks")
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            if isAddingSubtask {
                HStack {
                    TextField("New subtask", text: $newSubtaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button {
                        addSubtask()
                    } label: {
                        Text("Add")
                            .foregroundColor(.blue)
                    }
                    .disabled(newSubtaskTitle.isEmpty)
                    
                    Button {
                        isAddingSubtask = false
                        newSubtaskTitle = ""
                    } label: {
                        Text("Cancel")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if task.taskStatus == .pending || task.taskStatus == .inProgress || task.taskStatus == .delayed {
                if isAssignedToCurrentUser {
                    Button {
                        completeTask()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark as Completed")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                } else if canEdit {
                    Button {
                        showingStatusSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Change Status")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            
            if canEdit && (task.taskStatus != .completed && task.taskStatus != .cancelled) {
                Button {
                    showingRescheduleSheet = true
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                        Text("Reschedule")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            if task.isRecurring && task.taskStatus == .completed && canEdit {
                Button {
                    createNextRecurringTask()
                } label: {
                    HStack {
                        Image(systemName: "repeat.circle.fill")
                        Text("Create Next Recurring Task")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Helper Views
    
    private func labelRow(icon: String, label: String, value: String, trailingView: AnyView? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(label + ":")
                .foregroundColor(.secondary)
            
            Text(value)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let trailingView = trailingView {
                trailingView
            }
        }
    }
    
    private func labelRow(icon: String, label: String, value: Date, formatter: DateFormatter, trailingView: AnyView? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(label + ":")
                .foregroundColor(.secondary)
            
            Text(formatter.string(from: value))
                .foregroundColor(.primary)
            
            Spacer()
            
            if let trailingView = trailingView {
                trailingView
            }
        }
    }
    
    private func labelRow(icon: String, label: String, value: Double, formatter: NumberFormatter, trailingView: AnyView? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(label + ":")
                .foregroundColor(.secondary)
            
            Text(formatter.string(from: NSNumber(value: value)) ?? "\(value)")
                .foregroundColor(.primary)
            
            Spacer()
            
            if let trailingView = trailingView {
                trailingView
            }
        }
    }
    
    private func labelRow(icon: String, label: String, value: Int, formatter: NumberFormatter, trailingView: AnyView? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(label + ":")
                .foregroundColor(.secondary)
            
            Text(formatter.string(from: NSNumber(value: value)) ?? "\(value)")
                .foregroundColor(.primary)
            
            Spacer()
            
            if let trailingView = trailingView {
                trailingView
            }
        }
    }
    
    private func subtaskRow(_ subtask: AppSubtask) -> some View {
        HStack {
            Button {
                toggleSubtask(subtask)
            } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(subtask.isCompleted ? .green : .gray)
            }
            .disabled(!isAssignedToCurrentUser && !canEdit)
            
            Text(subtask.title)
                .strikethrough(subtask.isCompleted)
                .foregroundColor(subtask.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            if canEdit {
                Button {
                    deleteSubtask(subtask)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Functions
    
    private func statusIndex(of status: TaskStatus) -> Int {
        switch status {
        case .pending: return 0
        case .inProgress: return 1
        case .completed: return 2
        case .delayed: return 3
        case .cancelled: return 4
        }
    }
    
    private func completeTask() {
        task.changeStatus(to: .completed)
        try? modelContext.save()
    }
    
    private func toggleSubtask(_ subtask: AppSubtask) {
        subtask.isCompleted.toggle()
        try? modelContext.save()
        
        // Check if all subtasks are completed
        if let subtasks = task.subtasks, !subtasks.isEmpty {
            let allCompleted = subtasks.allSatisfy { $0.isCompleted }
            if allCompleted && task.taskStatus != .completed {
                // Prompt user to mark the whole task as completed
                // This could be implemented with an alert
            }
        }
    }
    
    private func addSubtask() {
        guard !newSubtaskTitle.isEmpty else { return }
        
        let subtask = AppSubtask(
            title: newSubtaskTitle,
            task: task
        )
        
        modelContext.insert(subtask)
        try? modelContext.save()
        
        newSubtaskTitle = ""
        isAddingSubtask = false
    }
    
    private func deleteSubtask(_ subtask: AppSubtask) {
        modelContext.delete(subtask)
        try? modelContext.save()
    }
    
    private func deleteTask() {
        modelContext.delete(task)
        try? modelContext.save()
        dismiss()
    }
    
    private func createNextRecurringTask() {
        guard let newTask = task.createNextRecurringTask() else { return }
        
        modelContext.insert(newTask)
        
        // Create new subtasks based on current task's subtasks
        if let currentSubtasks = task.subtasks {
            for subtask in currentSubtasks {
                let newSubtask = AppSubtask(
                    title: subtask.title,
                    task: newTask
                )
                modelContext.insert(newSubtask)
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Formatters
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

// Sheets for specific actions
struct TaskStatusUpdateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let task: AppTask
    @State private var selectedStatus: TaskStatus
    
    init(task: AppTask) {
        self.task = task
        self._selectedStatus = State(initialValue: task.taskStatus)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Update Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Change Task Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        task.changeStatus(to: selectedStatus)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RescheduleTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let task: AppTask
    @State private var newDueDate: Date
    
    init(task: AppTask) {
        self.task = task
        self._newDueDate = State(initialValue: task.dueDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select New Due Date") {
                    DatePicker("Due Date", selection: $newDueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Reschedule Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        task.reschedule(newDueDate: newDueDate)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AssignTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let task: AppTask
    @State private var selectedTechnician: AuthUser?
    
    @Query private var technicians: [AuthUser]
    
    var filteredTechnicians: [AuthUser] {
        technicians.filter { $0.userRole.rawValue == "technician" }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Technician") {
                    Button {
                        selectedTechnician = nil
                        dismissWithChanges()
                    } label: {
                        HStack {
                            Text("Unassigned")
                            Spacer()
                            if task.assignedToId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    
                    ForEach(filteredTechnicians) { user in
                        Button {
                            selectedTechnician = user
                            dismissWithChanges()
                        } label: {
                            HStack {
                                Text(user.fullName ?? user.email)
                                Spacer()
                                if user.id == task.assignedToId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Assign Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func dismissWithChanges() {
        if let tech = selectedTechnician {
            task.assignedToId = tech.id
            task.assignedToName = tech.fullName ?? tech.email
            task.assignedTo = tech
        } else {
            task.assignedToId = nil
            task.assignedToName = nil
            task.assignedTo = nil
        }
        
        task.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// Placeholder for the EditTaskView - to be implemented as needed
struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    let task: AppTask
    
    var body: some View {
        Text("Edit Task View - To be implemented")
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
    }
}

// Helper protocol for formatted values
protocol Formattable {}
extension Date: Formattable {}
extension Double: Formattable {}
extension Int: Formattable {}

#Preview {
    TaskDetailView(task: AppTask(
        title: "Oil Change for Van #12",
        taskDescription: "Perform standard oil change procedure with synthetic oil",
        dueDate: Date().addingTimeInterval(86400),
        taskType: "Oil Change"
    ))
} 