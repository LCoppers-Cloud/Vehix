import SwiftUI

struct AppWalkthroughView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    private let walkthroughPages = [
        WalkthroughPage(
            icon: "car.2.fill",
            title: "Manage Your Fleet",
            description: "Add vehicles, track maintenance, assign technicians, and monitor your entire fleet from one dashboard.",
            buttonText: "Next"
        ),
        WalkthroughPage(
            icon: "shippingbox.fill",
            title: "Track Inventory",
            description: "Monitor parts, tools, and supplies across multiple warehouses. Set reorder points and never run out of essentials.",
            buttonText: "Next"
        ),
        WalkthroughPage(
            icon: "person.3.fill",
            title: "Manage Your Team",
            description: "Invite technicians, assign roles, track performance, and ensure everyone has the tools they need.",
            buttonText: "Next"
        ),
        WalkthroughPage(
            icon: "chart.bar.fill",
            title: "Business Insights",
            description: "Get detailed reports on fleet performance, costs, maintenance schedules, and team productivity.",
            buttonText: "Next"
        ),
        WalkthroughPage(
            icon: "crown.fill",
            title: "You're All Set!",
            description: "Your business account is ready. Start by adding your first vehicle or inviting your team members.",
            buttonText: "Get Started"
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Walkthrough content
                TabView(selection: $currentPage) {
                    ForEach(0..<walkthroughPages.count, id: \.self) { index in
                        WalkthroughPageView(page: walkthroughPages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Navigation buttons
                navigationButtons
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 16) {
            HStack {
                Text("App Walkthrough")
                    .font(.title2.bold())
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                Button("Skip") {
                    dismiss()
                }
                .foregroundColor(Color.vehixBlue)
            }
            
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<walkthroughPages.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentPage ? Color.vehixBlue : Color.vehixSecondaryText.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            if currentPage > 0 {
                Button("Back") {
                    withAnimation {
                        currentPage -= 1
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button(currentPage == walkthroughPages.count - 1 ? "Get Started" : "Next") {
                if currentPage == walkthroughPages.count - 1 {
                    dismiss()
                } else {
                    withAnimation {
                        currentPage += 1
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
    }
}

// MARK: - Walkthrough Page View

struct WalkthroughPageView: View {
    let page: WalkthroughPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(Color.vehixBlue)
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.vehixText)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.title3)
                    .foregroundColor(Color.vehixSecondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Feature highlights for specific pages
            if page.icon == "car.2.fill" {
                featureHighlights([
                    "Add unlimited vehicles",
                    "Track maintenance schedules",
                    "Monitor real-time locations",
                    "Generate service reports"
                ])
            } else if page.icon == "shippingbox.fill" {
                featureHighlights([
                    "Multi-warehouse management",
                    "Barcode scanning",
                    "Automatic reorder alerts",
                    "Usage tracking by technician"
                ])
            } else if page.icon == "person.3.fill" {
                featureHighlights([
                    "Role-based permissions",
                    "Performance tracking",
                    "Task assignment",
                    "Time tracking"
                ])
            } else if page.icon == "chart.bar.fill" {
                featureHighlights([
                    "Cost analysis",
                    "Fleet utilization reports",
                    "Maintenance forecasting",
                    "Team productivity metrics"
                ])
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func featureHighlights(_ features: [String]) -> some View {
        VStack(spacing: 12) {
            ForEach(features, id: \.self) { feature in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.vehixGreen)
                        .font(.headline)
                    
                    Text(feature)
                        .font(.subheadline)
                        .foregroundColor(Color.vehixText)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.vehixSecondaryBackground)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Walkthrough Page Model

struct WalkthroughPage {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
}

#Preview {
    AppWalkthroughView()
} 