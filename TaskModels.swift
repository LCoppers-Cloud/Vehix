import Foundation
import SwiftData

// Frequency type for recurring tasks
enum TaskFrequency: String, Codable, CaseIterable {
    case oneTime = "One Time"
    case daily = "Daily"
    case weekly = "Weekly"
    case biWeekly = "Bi-Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
}

// Status of the task
enum TaskStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
    case delayed = "Delayed"
    case cancelled = "Cancelled"
}

// Task priority levels
enum TaskPriority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
}

// Task model for vehicle maintenance and service tasks
@Model
final class AppTask {
    var id: String = UUID().uuidString
    var title: String = "" // Default value to satisfy CloudKit
    var taskDescription: String = "" // Default value to satisfy CloudKit
    var status: String = TaskStatus.pending.rawValue
    var priority: String = TaskPriority.medium.rawValue
    var dueDate: Date = Date() // Default value to satisfy CloudKit
    var completedDate: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Task assignment
    var assignedToId: String?
    var assignedToName: String?
    var assignedById: String?
    var assignedByName: String?
    
    // Recurrence fields
    var isRecurring: Bool = false
    var frequency: String = TaskFrequency.oneTime.rawValue
    var recurringDayOfWeek: Int? // 1-7 for Monday-Sunday
    var recurringDayOfMonth: Int? // 1-31
    var startDate: Date?
    var endDate: Date?
    
    // Vehicle association
    var vehicleId: String?
    
    // Relationships with inverse declarations to resolve CloudKit integration errors
    @Relationship(deleteRule: .nullify, inverse: \AppVehicle.tasks) 
    var vehicle: AppVehicle?
    
    @Relationship(deleteRule: .nullify, inverse: \AuthUser.assignedTasks) 
    var assignedTo: AuthUser?
    
    @Relationship(deleteRule: .nullify, inverse: \AuthUser.createdTasks) 
    var assignedBy: AuthUser?
    
    @Relationship(deleteRule: .cascade) 
    var subtasks: [AppSubtask]?
    
    // Task type for predefined tasks
    var taskType: String?
    
    // Computed properties
    var taskStatus: TaskStatus {
        get { TaskStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }
    
    var taskPriority: TaskPriority {
        get { TaskPriority(rawValue: priority) ?? .medium }
        set { priority = newValue.rawValue }
    }
    
    var taskFrequency: TaskFrequency {
        get { TaskFrequency(rawValue: frequency) ?? .oneTime }
        set { frequency = newValue.rawValue }
    }
    
    var isOverdue: Bool {
        if taskStatus == .completed || taskStatus == .cancelled {
            return false
        }
        return Date() > dueDate
    }
    
    var statusColor: String {
        switch taskStatus {
        case .pending: return "yellow"
        case .inProgress: return "blue"
        case .completed: return "green"
        case .delayed: return "orange"
        case .cancelled: return "gray"
        }
    }
    
    var priorityColor: String {
        switch taskPriority {
        case .low: return "blue"
        case .medium: return "green"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        taskDescription: String = "",
        status: String = TaskStatus.pending.rawValue,
        priority: String = TaskPriority.medium.rawValue,
        dueDate: Date,
        completedDate: Date? = nil,
        isRecurring: Bool = false,
        frequency: String = TaskFrequency.oneTime.rawValue,
        recurringDayOfWeek: Int? = nil,
        recurringDayOfMonth: Int? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        vehicleId: String? = nil,
        assignedToId: String? = nil,
        assignedToName: String? = nil,
        assignedById: String? = nil,
        assignedByName: String? = nil,
        taskType: String? = nil,
        vehicle: AppVehicle? = nil,
        assignedTo: AuthUser? = nil,
        assignedBy: AuthUser? = nil,
        subtasks: [AppSubtask]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.completedDate = completedDate
        self.isRecurring = isRecurring
        self.frequency = frequency
        self.recurringDayOfWeek = recurringDayOfWeek
        self.recurringDayOfMonth = recurringDayOfMonth
        self.startDate = startDate
        self.endDate = endDate
        self.vehicleId = vehicleId
        self.assignedToId = assignedToId
        self.assignedToName = assignedToName
        self.assignedById = assignedById
        self.assignedByName = assignedByName
        self.taskType = taskType
        self.vehicle = vehicle
        self.assignedTo = assignedTo
        self.assignedBy = assignedBy
        self.subtasks = subtasks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Helper methods
    func markAsCompleted() {
        self.status = TaskStatus.completed.rawValue
        self.completedDate = Date()
        self.updatedAt = Date()
    }
    
    func reschedule(newDueDate: Date) {
        self.dueDate = newDueDate
        self.updatedAt = Date()
    }
    
    func changeStatus(to newStatus: TaskStatus) {
        self.status = newStatus.rawValue
        self.updatedAt = Date()
        
        if newStatus == .completed {
            self.completedDate = Date()
        }
    }
    
    // Create a recurring instance
    func createNextRecurringTask() -> AppTask? {
        guard isRecurring else { return nil }
        
        // Calculate next due date based on frequency
        let nextDueDate: Date?
        let calendar = Calendar.current
        
        switch taskFrequency {
        case .daily:
            nextDueDate = calendar.date(byAdding: .day, value: 1, to: dueDate)
        case .weekly:
            nextDueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate)
        case .biWeekly:
            nextDueDate = calendar.date(byAdding: .weekOfYear, value: 2, to: dueDate)
        case .monthly:
            nextDueDate = calendar.date(byAdding: .month, value: 1, to: dueDate)
        case .quarterly:
            nextDueDate = calendar.date(byAdding: .month, value: 3, to: dueDate)
        default:
            return nil
        }
        
        guard let nextDate = nextDueDate else { return nil }
        
        // Check if it's beyond the end date
        if let endDate = endDate, nextDate > endDate {
            return nil
        }
        
        // Create new task with same properties but new dates
        let newTask = AppTask(
            title: title,
            taskDescription: taskDescription,
            status: TaskStatus.pending.rawValue,
            priority: priority,
            dueDate: nextDate,
            isRecurring: isRecurring,
            frequency: frequency,
            recurringDayOfWeek: recurringDayOfWeek,
            recurringDayOfMonth: recurringDayOfMonth,
            startDate: startDate,
            endDate: endDate,
            vehicleId: vehicleId,
            assignedToId: assignedToId,
            assignedToName: assignedToName,
            assignedById: assignedById,
            assignedByName: assignedByName,
            taskType: taskType,
            vehicle: vehicle,
            assignedTo: assignedTo,
            assignedBy: assignedBy
        )
        
        return newTask
    }
}

// Subtask model for breaking down complex tasks
@Model
final class AppSubtask {
    var id: String = UUID().uuidString
    var title: String = "" // Default value to satisfy CloudKit
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    
    // Relationship to parent task
    @Relationship(deleteRule: .cascade, inverse: \AppTask.subtasks)
    var task: AppTask?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        isCompleted: Bool = false,
        task: AppTask? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.task = task
        self.createdAt = createdAt
    }
}

// Predefined task templates for common vehicle maintenance
struct PredefinedTask {
    static let oilChange = "Oil Change"
    static let vehicleCleaning = "Vehicle Cleaning"
    static let tireRotation = "Tire Rotation"
    static let brakeInspection = "Brake Inspection"
    static let fluidCheck = "Fluid Check"
    static let airFilterReplacement = "Air Filter Replacement"
    static let batteryCheck = "Battery Check"
    
    // Map task types to default subtasks
    static func defaultSubtasksFor(taskType: String) -> [String] {
        switch taskType {
        case oilChange:
            return [
                "Drain old oil",
                "Replace oil filter",
                "Add new oil",
                "Check oil level",
                "Reset maintenance light if applicable"
            ]
        case vehicleCleaning:
            return [
                "Vacuum interior",
                "Clean dashboard",
                "Wash exterior",
                "Clean windows",
                "Empty trash"
            ]
        case tireRotation:
            return [
                "Check tire pressure",
                "Rotate tires according to pattern",
                "Check tread wear",
                "Torque lug nuts to specification"
            ]
        case brakeInspection:
            return [
                "Inspect brake pads",
                "Check brake fluid level",
                "Inspect brake lines",
                "Test brake operation"
            ]
        case fluidCheck:
            return [
                "Check engine oil",
                "Check transmission fluid",
                "Check brake fluid",
                "Check power steering fluid",
                "Check coolant",
                "Check windshield washer fluid"
            ]
        case airFilterReplacement:
            return [
                "Remove air filter housing",
                "Replace air filter",
                "Clean housing if dirty",
                "Reinstall housing"
            ]
        case batteryCheck:
            return [
                "Check battery voltage",
                "Inspect terminals for corrosion",
                "Clean terminals if needed",
                "Check battery fluid level if applicable"
            ]
        default:
            return []
        }
    }
    
    // Get all predefined task types
    static var allTypes: [String] {
        [
            oilChange,
            vehicleCleaning,
            tireRotation,
            brakeInspection,
            fluidCheck,
            airFilterReplacement,
            batteryCheck
        ]
    }
}

// The relationships have been moved directly to the models
// to avoid circular references