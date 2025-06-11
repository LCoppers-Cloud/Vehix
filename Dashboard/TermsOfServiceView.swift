import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    lastUpdatedSection
                    acceptanceSection
                    serviceDescriptionSection
                    accountSection
                    subscriptionSection
                    paymentSection
                    cancellationSection
                    dataOwnershipSection
                    userConductSection
                    serviceTerminationSection
                    intellectualPropertySection
                    disclaimersSection
                    limitationOfLiabilitySection
                    indemnificationSection
                    disputeResolutionSection
                    governingLawSection
                    modificationSection
                    contactSection
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
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
            Text("Vehix Terms of Service")
                .font(.title.bold())
                .foregroundColor(Color.vehixBlue)
            
            Text("Legal Agreement for Service Use")
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
    
    private var acceptanceSection: some View {
        TermsSection(
            title: "1. Acceptance of Terms",
            content: """
            These Terms of Service ("Terms") constitute a legally binding agreement between you ("User," "Customer," or "you") and Vehix ("Company," "we," "us," or "our") regarding your use of the Vehix application and services.

            BY CREATING AN ACCOUNT, ACCESSING, OR USING VEHIX, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THESE TERMS AND OUR PRIVACY POLICY.

            If you are entering into this agreement on behalf of a company or other legal entity, you represent that you have the authority to bind such entity to these terms.

            If you do not agree to these terms, you must not access or use our services.
            """
        )
    }
    
    private var serviceDescriptionSection: some View {
        TermsSection(
            title: "2. Service Description",
            content: """
            Vehix provides a cloud-based vehicle and inventory management platform that includes:

            • Vehicle tracking and maintenance management
            • Inventory management and tracking
            • Team and technician management
            • Integration with third-party services
            • Data analytics and reporting
            • Mobile and web application access

            We reserve the right to modify, suspend, or discontinue any aspect of our services at any time with reasonable notice. We are not liable for any modification, suspension, or discontinuation of services.
            """
        )
    }
    
    private var accountSection: some View {
        TermsSection(
            title: "3. Account Registration and Security",
            content: """
            Account Requirements:
            • You must provide accurate, current, and complete information
            • You must be at least 18 years old or the age of majority in your jurisdiction
            • One person or entity may not create multiple accounts
            • Business accounts require valid business information

            Account Security:
            • You are responsible for maintaining the confidentiality of your login credentials
            • You are responsible for all activities that occur under your account
            • You must notify us immediately of any unauthorized use
            • We reserve the right to suspend accounts with suspicious activity

            Account Termination:
            • You may close your account at any time
            • We may suspend or terminate your account for violations of these terms
            • We may terminate accounts with reasonable notice for business reasons
            """
        )
    }
    
    private var subscriptionSection: some View {
        TermsSection(
            title: "4. Subscription Plans and Billing",
            content: """
            Subscription Tiers:
            • Free Trial: Limited features and duration
            • Paid Plans: Various tiers with different feature sets and user limits
            • Enterprise: Custom plans with negotiated terms

            Billing Terms:
            • Subscriptions are billed in advance on a recurring basis
            • Billing occurs monthly or annually based on your selected plan
            • All fees are non-refundable except as required by law
            • Prices may change with 30 days' advance notice

            Auto-Renewal:
            • Subscriptions automatically renew unless cancelled
            • You will be charged on your renewal date
            • You can cancel auto-renewal in your account settings
            
            Failed Payments:
            • Service may be suspended for failed payments
            • We will attempt to collect payment using updated payment methods
            • Accounts may be terminated after 30 days of non-payment
            """
        )
    }
    
    private var paymentSection: some View {
        TermsSection(
            title: "5. Payment Terms",
            content: """
            Payment Processing:
            • Payments are processed by third-party payment processors
            • You authorize us to charge your designated payment method
            • You must provide current, accurate payment information
            • Payment processing fees may apply

            Refund Policy:
            • Annual subscriptions: Pro-rated refunds for unused time (at our discretion)
            • Monthly subscriptions: No refunds for partial months
            • Refunds processed within 30 days of request
            • No refunds for accounts terminated for Terms violations

            Taxes:
            • You are responsible for all applicable taxes
            • Prices do not include applicable taxes unless stated
            • We may collect taxes as required by law

            Price Changes:
            • We may modify pricing with 30 days' notice
            • Price changes take effect on your next billing cycle
            • Continued use after price changes constitutes acceptance
            """
        )
    }
    
    private var cancellationSection: some View {
        TermsSection(
            title: "6. Cancellation and Termination Rights",
            content: """
            Your Cancellation Rights:
            • Cancel your subscription at any time through account settings
            • Cancellation takes effect at the end of your current billing period
            • You retain access to paid features until the end of the billing period
            • You may export your data before or after cancellation

            Our Termination Rights:
            We may suspend or terminate your account immediately for:
            • Violation of these Terms of Service
            • Non-payment of fees
            • Fraudulent activity or misuse of services
            • Legal or regulatory requirements
            • Breach of acceptable use policies

            Effect of Termination:
            • Your right to use the service ends immediately
            • We may delete your account and data after 30 days
            • You remain liable for all charges incurred before termination
            • Survival: Certain provisions survive termination (payments, liability, intellectual property)

            Data Retrieval:
            • You have 30 days after termination to request data export
            • We may charge reasonable fees for data retrieval assistance
            • After 30 days, we may permanently delete your data
            """
        )
    }
    
    private var dataOwnershipSection: some View {
        TermsSection(
            title: "7. Data Ownership and Usage Rights",
            content: """
            Your Data Rights:
            • You retain all ownership rights to data you input into Vehix
            • Your business data, vehicle information, and records remain your property
            • You grant us a license to process your data to provide services
            • You may export your data at any time

            Our Data Rights:
            • We own all rights to the Vehix platform, software, and infrastructure
            • We may use aggregated, anonymized data for service improvement
            • We may access your data for support, security, and legal compliance
            • We retain system logs and usage data for operational purposes

            Data Processing:
            • We process your data as a service provider, not as an owner
            • We implement appropriate security measures for your data
            • We comply with applicable data protection laws
            • Third-party integrations are governed by their respective terms

            Data Deletion:
            • We may retain certain data for legal compliance after account deletion
            • Some data may be retained in backups for limited periods
            • Anonymous usage data may be retained indefinitely
            """
        )
    }
    
    private var userConductSection: some View {
        TermsSection(
            title: "8. Acceptable Use and Prohibited Conduct",
            content: """
            Acceptable Use:
            • Use services only for lawful business purposes
            • Comply with all applicable laws and regulations
            • Maintain accurate account information
            • Respect intellectual property rights

            Prohibited Activities:
            • Unauthorized access to accounts or systems
            • Distribution of malware or harmful code
            • Harassment, abuse, or threatening behavior
            • Spamming or unsolicited communications
            • Reverse engineering or attempting to extract source code
            • Using services to store or transmit illegal content
            • Violating any applicable laws or regulations
            • Impersonating others or providing false information

            Consequences of Violations:
            • Account suspension or termination
            • Legal action for damages
            • Cooperation with law enforcement
            • Permanent ban from services
            """
        )
    }
    
    private var serviceTerminationSection: some View {
        TermsSection(
            title: "9. Service Availability and Modifications",
            content: """
            Service Availability:
            • We strive for 99.9% uptime but do not guarantee uninterrupted service
            • Scheduled maintenance will be announced in advance when possible
            • Emergency maintenance may occur without notice
            • Third-party integrations may affect service availability

            Service Modifications:
            • We may modify features, functionality, or interfaces at any time
            • Material changes will be communicated with reasonable notice
            • Some modifications may affect your current workflows
            • Continued use after modifications constitutes acceptance

            Service Discontinuation:
            • We may discontinue services with 90 days' notice
            • You will have the opportunity to export your data
            • Pro-rated refunds may be provided for prepaid subscriptions
            """
        )
    }
    
    private var intellectualPropertySection: some View {
        TermsSection(
            title: "10. Intellectual Property Rights",
            content: """
            Our Intellectual Property:
            • Vehix owns all rights to the platform, software, trademarks, and content
            • You receive a limited, non-exclusive license to use our services
            • You may not copy, modify, or distribute our intellectual property
            • All improvements and feedback become our property

            Your Intellectual Property:
            • You retain rights to your business data and content
            • You grant us necessary licenses to provide services
            • You represent that you have rights to data you upload
            • You will not upload content that infringes third-party rights

            Third-Party Intellectual Property:
            • Third-party integrations are governed by their respective licenses
            • You are responsible for compliance with third-party terms
            • We do not grant rights to third-party intellectual property

            Copyright and DMCA:
            • We respect intellectual property rights
            • Report copyright infringement to legal@vehix.com
            • We will respond to valid DMCA takedown notices
            """
        )
    }
    
    private var disclaimersSection: some View {
        TermsSection(
            title: "11. Disclaimers and Warranties",
            content: """
            SERVICE PROVIDED "AS IS":
            THE VEHIX SERVICES ARE PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED.

            DISCLAIMER OF WARRANTIES:
            WE DISCLAIM ALL WARRANTIES, INCLUDING BUT NOT LIMITED TO:
            • MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
            • NON-INFRINGEMENT OF THIRD-PARTY RIGHTS
            • UNINTERRUPTED OR ERROR-FREE OPERATION
            • ACCURACY OR COMPLETENESS OF DATA
            • SECURITY OF DATA TRANSMISSION

            NO GUARANTEE OF RESULTS:
            • We do not guarantee specific business outcomes
            • We do not guarantee integration compatibility
            • We do not guarantee data accuracy from third-party sources

            User Responsibility:
            • You are responsible for backing up your important data
            • You should verify the accuracy of all data and calculations
            • You should maintain independent records as appropriate
            """
        )
    }
    
    private var limitationOfLiabilitySection: some View {
        TermsSection(
            title: "12. Limitation of Liability",
            content: """
            MAXIMUM LIABILITY:
            OUR TOTAL LIABILITY TO YOU FOR ALL CLAIMS ARISING FROM OR RELATED TO THESE TERMS OR THE SERVICES SHALL NOT EXCEED THE AMOUNT YOU PAID TO US IN THE 12 MONTHS PRECEDING THE CLAIM.

            EXCLUDED DAMAGES:
            WE SHALL NOT BE LIABLE FOR:
            • INDIRECT, INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES
            • LOSS OF PROFITS, REVENUE, OR BUSINESS OPPORTUNITIES
            • LOSS OF DATA OR BUSINESS INTERRUPTION
            • PUNITIVE OR EXEMPLARY DAMAGES
            • DAMAGES CAUSED BY THIRD-PARTY INTEGRATIONS

            EXCEPTIONS:
            Some jurisdictions do not allow limitation of liability for certain damages. In such cases, our liability is limited to the maximum extent permitted by law.

            FORCE MAJEURE:
            We are not liable for delays or failures due to circumstances beyond our reasonable control, including natural disasters, government actions, or third-party service failures.
            """
        )
    }
    
    private var indemnificationSection: some View {
        TermsSection(
            title: "13. Indemnification",
            content: """
            You agree to indemnify, defend, and hold harmless Vehix, its officers, directors, employees, and agents from and against any claims, damages, losses, and expenses (including reasonable attorney fees) arising from:

            • Your use of the services
            • Your violation of these Terms
            • Your violation of any law or third-party rights
            • Content you submit or transmit through the services
            • Your negligent acts or omissions

            We reserve the right to assume the exclusive defense and control of any matter subject to indemnification by you, and you agree to cooperate with our defense of such claims.
            """
        )
    }
    
    private var disputeResolutionSection: some View {
        TermsSection(
            title: "14. Dispute Resolution",
            content: """
            Informal Resolution:
            Before filing any legal claim, you agree to contact us at legal@vehix.com to resolve the dispute informally. We will work in good faith to resolve disputes within 30 days.

            Binding Arbitration:
            If informal resolution fails, disputes will be resolved through binding arbitration rather than in court, except for:
            • Intellectual property disputes
            • Small claims court matters
            • Injunctive relief requests

            Arbitration Rules:
            • Arbitration conducted by the American Arbitration Association (AAA)
            • AAA Commercial Arbitration Rules apply
            • Arbitration held in your state of residence or virtually
            • Each party bears their own arbitration costs and attorney fees

            Class Action Waiver:
            You agree not to participate in class action lawsuits against us. All disputes must be resolved individually.
            """
        )
    }
    
    private var governingLawSection: some View {
        TermsSection(
            title: "15. Governing Law and Jurisdiction",
            content: """
            These Terms are governed by the laws of California, without regard to conflict of law principles.

            For disputes not subject to arbitration:
            • US users: Federal and state courts in California
            • Canadian users: Provincial courts in your home province

            You consent to the personal jurisdiction of these courts and waive any objection to venue.

            International Users:
            If you access our services from outside the US or Canada, you do so at your own risk and are responsible for compliance with local laws.
            """
        )
    }
    
    private var modificationSection: some View {
        TermsSection(
            title: "16. Modification of Terms",
            content: """
            We may update these Terms from time to time. We will notify you of material changes by:

            • Posting updated Terms in the application
            • Sending email notification to your registered email
            • Providing in-app notifications

            Changes take effect 30 days after notification. Your continued use of the services after changes take effect constitutes acceptance of the new Terms.

            If you do not agree to modified Terms, you may terminate your account before the changes take effect.
            """
        )
    }
    
    private var contactSection: some View {
        TermsSection(
            title: "17. Contact Information",
            content: """
            For questions about these Terms or to report violations, contact us:

            General Inquiries: support@vehix.com
            Legal Matters: legal@vehix.com
            Privacy Issues: privacy@vehix.com

            Mail: Vehix Legal Department
                  50 Hegenberger Loop
                  Oakland, CA 94621

            We will respond to inquiries within 5 business days.

            By using Vehix, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.
            """
        )
    }
}

struct TermsSection: View {
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
    TermsOfServiceView()
} 