import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    lastUpdatedSection
                    introductionSection
                    informationCollectionSection
                    dataUsageSection
                    dataOwnershipSection
                    sharingSection
                    dataRetentionSection
                    securitySection
                    rightsSection
                    internationalTransferSection
                    childrenSection
                    changesSection
                    contactSection
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vehix Privacy Policy")
                .font(.title.bold())
                .foregroundColor(Color.vehixBlue)
            
            Text("Protecting Your Privacy and Data Rights")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private var lastUpdatedSection: some View {
        Text("Last Updated: December 2024")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 10)
    }
    
    private var introductionSection: some View {
        PolicySection(
            title: "1. Introduction",
            content: """
            Vehix ("we," "our," or "us") is committed to protecting your privacy and personal information. This Privacy Policy explains how we collect, use, disclose, and protect your information when you use our vehicle and inventory management application and services.

            This policy applies to all users in the United States and Canada and complies with applicable privacy laws including the California Consumer Privacy Act (CCPA), California Privacy Rights Act (CPRA), and Canada's Personal Information Protection and Electronic Documents Act (PIPEDA).

            By using Vehix, you agree to the collection and use of information in accordance with this policy.
            """
        )
    }
    
    private var informationCollectionSection: some View {
        PolicySection(
            title: "2. Information We Collect",
            content: """
            We collect information you provide directly to us:

            • Account Information: Name, email address, phone number, business information
            • Business Data: Vehicle information, inventory data, employee records, work schedules
            • Financial Information: Subscription details, payment method information (processed by third-party payment processors)
            • Communications: Messages, support requests, feedback

            Information collected automatically:
            • Usage Data: How you use our app, features accessed, time spent
            • Device Information: Device type, operating system, app version
            • Location Data: GPS coordinates for vehicle tracking (with explicit consent)
            • Log Data: IP address, access times, error logs

            Information from third parties:
            • Integration data from ServiceTitan, Samsara, and other connected services
            • Payment information from payment processors
            """
        )
    }
    
    private var dataUsageSection: some View {
        PolicySection(
            title: "3. How We Use Your Information",
            content: """
            We use your information to:

            Service Provision:
            • Provide, operate, and maintain our services
            • Process transactions and manage subscriptions
            • Provide customer support and respond to inquiries
            • Send service-related communications

            Business Operations:
            • Improve and optimize our services
            • Develop new features and functionality
            • Analyze usage patterns and trends
            • Ensure security and prevent fraud

            Legal Compliance:
            • Comply with legal obligations
            • Protect our rights and interests
            • Enforce our Terms of Service
            • Respond to legal requests

            We DO NOT:
            • Sell your personal information to third parties
            • Use your data for advertising purposes
            • Share your business data with competitors
            """
        )
    }
    
    private var dataOwnershipSection: some View {
        PolicySection(
            title: "4. Data Ownership and Rights",
            content: """
            Important: You retain ownership of all data you input into Vehix.

            Your Rights:
            • You own all business data, vehicle information, and inventory records you create
            • We process your data as a service provider, not as an owner
            • You have the right to export your data at any time
            • You can request deletion of your account and associated data

            Our Rights:
            • We may retain and use aggregated, anonymized data for service improvement
            • We may access your data to provide support or ensure service security
            • We retain the right to suspend or terminate accounts that violate our terms
            • We may retain certain data for legal compliance after account deletion

            Data Processing Legal Basis:
            • Contract performance (providing services you've requested)
            • Legitimate interests (service improvement, security)
            • Legal compliance (tax records, legal requests)
            • Consent (for optional features like location tracking)
            """
        )
    }
    
    private var sharingSection: some View {
        PolicySection(
            title: "5. Information Sharing",
            content: """
            We may share your information in limited circumstances:

            Service Providers:
            • Cloud hosting providers (for data storage)
            • Payment processors (for subscription billing)
            • Analytics providers (anonymized usage data only)
            • Customer support tools

            Business Transfers:
            • In connection with merger, sale, or acquisition of our business
            • You will be notified of any such transfer

            Legal Requirements:
            • When required by law or legal process
            • To protect our rights, users, or the public
            • To prevent fraud or security threats

            With Your Consent:
            • Integration with third-party services you authorize
            • Sharing specific data you explicitly approve

            We DO NOT share your data for marketing purposes or sell it to advertisers.
            """
        )
    }
    
    private var dataRetentionSection: some View {
        PolicySection(
            title: "6. Data Retention",
            content: """
            We retain your information for as long as necessary to provide services and comply with legal obligations:

            Account Data: Retained while your account is active and for 7 years after deletion for legal compliance
            Business Records: Retained for 7 years for tax and regulatory purposes
            Usage Data: Retained for 2 years for service improvement
            Security Logs: Retained for 1 year for security purposes

            You may request earlier deletion of your data, subject to legal retention requirements.
            """
        )
    }
    
    private var securitySection: some View {
        PolicySection(
            title: "7. Data Security",
            content: """
            We implement comprehensive security measures:

            Technical Safeguards:
            • Encryption in transit and at rest
            • Multi-factor authentication
            • Regular security audits and testing
            • Secure cloud infrastructure

            Administrative Safeguards:
            • Employee access controls
            • Security training programs
            • Incident response procedures
            • Regular security policy reviews

            Physical Safeguards:
            • Secure data centers
            • Access controls and monitoring
            • Environmental protections

            Despite our efforts, no system is 100% secure. We will notify you of any security breaches as required by law.
            """
        )
    }
    
    private var rightsSection: some View {
        PolicySection(
            title: "8. Your Privacy Rights",
            content: """
            Under US and Canadian privacy laws, you have the following rights:

            Access Rights:
            • Right to know what personal information we collect
            • Right to access your personal information
            • Right to receive a copy of your data

            Control Rights:
            • Right to correct inaccurate information
            • Right to delete your personal information
            • Right to opt-out of certain data processing
            • Right to data portability

            California Residents (CCPA/CPRA):
            • Right to non-discrimination for exercising privacy rights
            • Right to limit use of sensitive personal information
            • Right to opt-out of "sales" (we don't sell data)

            Canadian Residents (PIPEDA):
            • Right to withdraw consent
            • Right to file complaints with privacy commissioners
            • Right to access and correct personal information

            To exercise these rights, contact us at privacy@vehix.com
            """
        )
    }
    
    private var internationalTransferSection: some View {
        PolicySection(
            title: "9. International Data Transfers",
            content: """
            Your data may be processed in the United States or other countries where our service providers operate. We ensure appropriate safeguards for international transfers:

            • Contractual protections with service providers
            • Compliance with applicable cross-border data transfer laws
            • Use of providers with adequate privacy certifications

            For Canadian users, we comply with PIPEDA requirements for cross-border data transfers.
            """
        )
    }
    
    private var childrenSection: some View {
        PolicySection(
            title: "10. Children's Privacy",
            content: """
            Vehix is not intended for use by children under 13 years of age. We do not knowingly collect personal information from children under 13. If we learn that we have collected personal information from a child under 13, we will delete that information immediately.

            If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately.
            """
        )
    }
    
    private var changesSection: some View {
        PolicySection(
            title: "11. Changes to This Policy",
            content: """
            We may update this Privacy Policy from time to time. We will notify you of any material changes by:

            • Posting the updated policy in the app
            • Sending email notification to your registered email address
            • Providing in-app notifications

            Changes take effect 30 days after notification, unless sooner implementation is required by law.
            """
        )
    }
    
    private var contactSection: some View {
        PolicySection(
            title: "12. Contact Information",
            content: """
            For questions about this Privacy Policy or to exercise your rights, contact us:

            Email: privacy@vehix.com
            Mail: Vehix Privacy Officer
                  50 Hegenberger Loop
                  Oakland, CA 94621

            For Canadian residents: You may also file complaints with the Office of the Privacy Commissioner of Canada.

            For California residents: You may also file complaints with the California Attorney General's Office.

            We will respond to privacy requests within 30 days (or as required by applicable law).
            """
        )
    }
}

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            Text(content)
                .font(.body)
                .foregroundColor(Color.vehixText)
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    PrivacyPolicyView()
} 