import SwiftUI
import SwiftData

struct TaskView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    // Query tasks based on the role
    @Query private var tasks: [AppTask]
    
    @State private var showingAddTask = false
    @State private var selectedTask: AppTask?
    @State private var showTaskDetail = false
    @State private var searchText = ""
    @State private var taskFilter: TaskFilter = .all
    
    enum TaskFilter {
        case all, pending, inProgress, completed, overdue
    }
    
    init(filter: TaskFilter = .all) {
        self._taskFilter = State(initialValue: filter)
        
        // Construct a predicate based on the filter
        let predicate: Predicate<AppTask>?
        
        switch filter {
        case .all:
            predicate = nil
        case .pending:
            predicate = #Predicate<AppTask> { task in
                task.status == "Pending"
            }
        case .inProgress:
            predicate = #Predicate<AppTask> { task in
                task.status == "In Progress"
            }
        case .completed:
            predicate = #Predicate<AppTask> { task in
                task.status == "Completed"
            }
        case .overdue:
            let currentDate = Date()
            predicate = #Predicate<AppTask> { task in
                (task.status != "Completed" && 
                task.status != "Cancelled") &&
                task.dueDate < currentDate
            }
        }
        
        let sortDescriptors = [
            SortDescriptor(\AppTask.dueDate, order: .forward),
            SortDescriptor(\AppTask.priority, order: .reverse)
        ]
        
        self._tasks = Query(filter: predicate, sort: sortDescriptors)
    }
    
    var filteredTasks: [AppTask] {
        if searchText.isEmpty {
            return tasks
        }
        
        return tasks.filter { task in
            task.title.localizedCaseInsensitiveContains(searchText) ||
            task.taskDescription.localizedCaseInsensitiveContains(searchText) ||
            (task.assignedToName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (task.vehicleId != nil && task.vehicle?.displayName.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        filterButton(title: "All", filter: .all)
                        filterButton(title: "Pending", filter: .pending)
                        filterButton(title: "In Progress", filter: .inProgress)
                        filterButton(title: "Completed", filter: .completed)
                        filterButton(title: "Overdue", filter: .overdue, highlight: true)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
                
                if filteredTasks.isEmpty {
                    emptyStateView
                } else {
                    VStack {
                        // Add Task Button at the top
                        if authService.currentUser?.userRole == .admin || 
                           authService.currentUser?.userRole == .dealer {
                            Button {
                                showingAddTask = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add New Task")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        List {
                            ForEach(filteredTasks) { task in
                                Button {
                                    selectedTask = task
                                    showTaskDetail = true
                                } label: {
                                    TaskListRow(task: task)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: deleteTasks)
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Only admins and dealers can create tasks
                    if authService.currentUser?.userRole == .admin || 
                       authService.currentUser?.userRole == .dealer {
                        Button {
                            showingAddTask = true
                        } label: {
                            Label("Add Task", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView()
            }
            .navigationDestination(isPresented: $showTaskDetail) {
                if let task = selectedTask {
                    TaskDetailView(task: task)
                }
            }
        }
    }
    
    private func filterButton(title: String, filter: TaskFilter, highlight: Bool = false) -> some View {
        Button {
            taskFilter = filter
        } label: {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    taskFilter == filter 
                    ? Color("vehix-blue") 
                    : (highlight ? Color.red.opacity(0.1) : Color(.systemGray6))
                )
                .foregroundColor(
                    taskFilter == filter 
                    ? .white 
                    : (highlight ? .red : .primary)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(highlight && taskFilter != filter ? Color.red : Color.clear, lineWidth: 1)
                )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 70))
                .foregroundColor(.blue.opacity(0.7))
            
            Text(getEmptyStateTitle())
                .font(.title2)
                .bold()
            
            Text(getEmptyStateMessage())
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            if authService.currentUser?.userRole == .admin || 
               authService.currentUser?.userRole == .dealer {
                Button {
                    showingAddTask = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create Task")
                    }
                    .frame(minWidth: 240)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
    }
    
    private func getEmptyStateTitle() -> String {
        switch taskFilter {
        case .all:
            return "No Tasks"
        case .pending:
            return "No Pending Tasks"
        case .inProgress:
            return "No Tasks In Progress"
        case .completed:
            return "No Completed Tasks"
        case .overdue:
            return "No Overdue Tasks"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        switch taskFilter {
        case .all:
            return "Start by creating tasks for your team to track vehicle maintenance and service needs."
        case .pending:
            return "No tasks are pending. All current tasks have been started or completed."
        case .inProgress:
            return "No tasks are currently in progress. Your team might be waiting to start work."
        case .completed:
            return "No tasks have been completed yet. Tasks will appear here when finished."
        case .overdue:
            return "Great! You don't have any overdue tasks. Everything is on schedule."
        }
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            let task = filteredTasks[index]
            modelContext.delete(task)
        }
        try? modelContext.save()
    }
}

struct TaskListRow: View {
    let task: AppTask
    
    var body: some View {
        HStack(alignment: .top) {
            // Task status indicator
            Circle()
                .fill(Color(task.statusColor))
                .frame(width: 12, height: 12)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(task.isOverdue ? .red : .primary)
                
                Text(task.taskDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    if let vehicle = task.vehicle {
                        Label(vehicle.displayName, systemImage: "car.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if task.isRecurring {
                        Label(task.taskFrequency.rawValue, systemImage: "repeat")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 2)
                
                HStack {
                    if let assignedName = task.assignedToName {
                        Label(assignedName, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Due: \(task.dueDate, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(task.isOverdue ? .red : .secondary)
                }
            }
            
            // Priority indicator
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(task.priorityColor).opacity(0.2))
                    .frame(width: 40, height: 20)
                
                Text(task.taskPriority.rawValue.prefix(1))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color(task.priorityColor))
            }
        }
        .padding(.vertical, 4)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
}

// TaskDetailView is implemented in TaskDetailView.swift

// Placeholder for the AddTaskView - to be implemented in full 
struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    @State private var title = ""
    @State private var taskDescription = ""
    @State private var selectedPriority = TaskPriority.medium
    @State private var dueDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var isRecurring = false
    @State private var selectedFrequency = TaskFrequency.weekly
    @State private var selectedVehicle: AppVehicle?
    @State private var selectedAssignee: AuthUser?
    @State private var selectedTaskType: String?
    @State private var subtasks: [String] = []
    
    @Query private var vehicles: [AppVehicle]
    @Query private var technicians: [AuthUser]
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic information
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...)
                    
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                // Task Type
                Section(header: Text("Task Type")) {
                    Picker("Task Type", selection: $selectedTaskType) {
                        Text("Custom Task").tag(nil as String?)
                        ForEach(PredefinedTask.allTypes, id: \.self) { taskType in
                            Text(taskType).tag(taskType as String?)
                        }
                    }
                    .onChange(of: selectedTaskType) { _, newValue in
                        if let newTaskType = newValue {
                            subtasks = PredefinedTask.defaultSubtasksFor(taskType: newTaskType)
                        } else {
                            subtasks = []
                        }
                    }
                }
                
                // Assignments
                Section(header: Text("Assignment")) {
                    Picker("Vehicle", selection: $selectedVehicle) {
                        Text("No Vehicle").tag(nil as AppVehicle?)
                        ForEach(vehicles) { vehicle in
                            Text(vehicle.displayName).tag(vehicle as AppVehicle?)
                        }
                    }
                    
                    Picker("Assign To", selection: $selectedAssignee) {
                        Text("Unassigned").tag(nil as AuthUser?)
                        ForEach(technicians.filter { user in
                            user.userRole.rawValue == "technician"
                        }) { user in
                            Text(user.fullName ?? user.email).tag(user as AuthUser?)
                        }
                    }
                }
                
                // Recurrence
                Section(header: Text("Recurrence")) {
                    Toggle("Recurring Task", isOn: $isRecurring)
                    
                    if isRecurring {
                        Picker("Frequency", selection: $selectedFrequency) {
                            ForEach(TaskFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                    }
                }
                
                // Subtasks
                Section(header: Text("Subtasks")) {
                    ForEach(subtasks.indices, id: \.self) { index in
                        HStack {
                            TextField("Subtask", text: $subtasks[index])
                            
                            Button {
                                subtasks.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button {
                        subtasks.append("")
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Subtask")
                        }
                    }
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        createTask()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func createTask() {
        guard let currentUser = authService.currentUser else { return }
        
        // Create the new task
        let task = AppTask(
            title: title,
            taskDescription: taskDescription,
            priority: selectedPriority.rawValue,
            dueDate: dueDate,
            isRecurring: isRecurring,
            frequency: selectedFrequency.rawValue,
            vehicleId: selectedVehicle?.id,
            assignedToId: selectedAssignee?.id,
            assignedToName: selectedAssignee?.fullName ?? selectedAssignee?.email,
            assignedById: currentUser.id,
            assignedByName: currentUser.fullName ?? currentUser.email,
            taskType: selectedTaskType,
            vehicle: selectedVehicle,
            assignedTo: selectedAssignee,
            assignedBy: currentUser
        )
        
        // Insert the task
        modelContext.insert(task)
        
        // Add subtasks
        for subtaskTitle in subtasks where !subtaskTitle.isEmpty {
            let subtask = AppSubtask(
                title: subtaskTitle,
                task: task
            )
            modelContext.insert(subtask)
        }
        
        // Save changes
        try? modelContext.save()
    }
}

#Preview {
    TaskView()
        .environmentObject(AppAuthService())
} 