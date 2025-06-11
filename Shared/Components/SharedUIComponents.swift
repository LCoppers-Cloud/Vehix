import SwiftUI

// MARK: - Shared UI Components

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AlertCard: View {
    let title: String
    let count: Int
    let message: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Text("\(count) \(message)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    let backgroundColor: Color?
    
    init(text: String, color: Color, backgroundColor: Color? = nil) {
        self.text = text
        self.color = color
        self.backgroundColor = backgroundColor ?? color.opacity(0.1)
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }
}

struct AssignmentCard: View {
    let assignment: VehicleAssignment
    let user: AuthUser?
    let isActive: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundColor(isActive ? .green : .gray)
                .font(.title3)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                if let user = user {
                    Text(user.fullName ?? "Unknown Technician")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Assigned Technician")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("User ID: \(assignment.userId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Since \(assignment.startDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(
                    text: isActive ? "Active" : "Ended",
                    color: isActive ? .green : .gray
                )
                
                let days = Calendar.current.dateComponents([.day], from: assignment.startDate, to: assignment.endDate ?? Date()).day ?? 0
                Text("\(days) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct TechnicianInfoCard: View {
    let user: AuthUser?
    
    var body: some View {
        if let user = user {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Text(user.fullName ?? user.email)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Role: \(user.userRole.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.slash")
                        .foregroundColor(.gray)
                        .font(.title3)
                    
                    Text("No Technician Assigned")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                Text("Assign a technician to this vehicle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    SwiftUI.ScrollView(.vertical, showsIndicators: true) {
        VStack(spacing: 20) {
            StatCard(
                title: "Test Stat",
                value: "42",
                subtitle: "Items",
                icon: "cube.box.fill",
                color: .blue
            )
            
            SummaryCard(
                title: "Test Summary",
                value: "$1,234",
                subtitle: "Total",
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            AlertCard(
                title: "Low Stock",
                count: 3,
                message: "items need attention",
                color: .orange,
                icon: "exclamationmark.triangle"
            )
            
            StatusBadge(text: "Active", color: .green)
            
            EmptyStateView(
                icon: "cube.box",
                title: "No Items",
                message: "Add your first item to get started",
                actionTitle: "Add Item"
            ) {
                print("Add item tapped")
            }
        }
        .padding()
    }
} 