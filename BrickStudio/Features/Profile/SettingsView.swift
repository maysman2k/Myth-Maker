import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("appAppearancePreference") private var appearancePreference = AppAppearancePreference.automatic.rawValue
    @State private var preferences = NotificationPreferences()

    var body: some View {
        Form {
            if model.isSignedIn {
                Section("Notification preferences") {
                    Toggle("News alerts", isOn: $preferences.newsAlerts)
                    Toggle("Comment replies", isOn: $preferences.commentReplies)
                    Toggle("Brick Bar updates", isOn: $preferences.brickBarUpdates)
                    Toggle("Shop & product updates", isOn: $preferences.shopUpdates)
                    Toggle("Studio Lessons", isOn: $preferences.studioLessons)
                    Toggle("Review alerts", isOn: $preferences.reviewAlerts)
                }
            }
            Section("Appearance") {
                Picker("Theme", selection: $appearancePreference) {
                    ForEach(AppAppearancePreference.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text("Auto follows your phone. Light and Dark override the phone setting.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            Section("Community") {
                if model.isSignedIn {
                    NavigationLink("Blocked users") { BlockedUsersView() }
                }
                NavigationLink("Community rules") { CommunityRulesView() }
                NavigationLink("Legal & about") { LegalView() }
            }
            if model.isSignedIn {
                Section("Account") {
                    Button("Request account deletion", role: .destructive) {
                        model.showToast("Deletion request noted — we'll email you to confirm.", symbol: "envelope")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: preferences) { _, newValue in
            model.updateNotificationPreferences(newValue)
        }
        .onAppear {
            if let existing = model.currentUser?.notificationPreferences {
                preferences = existing
            }
        }
    }
}

struct CommunityRulesView: View {
    private let rules = [
        ("Be respectful", "Builders of all ages and abilities hang out here."),
        ("No spam", "Don't post repeated content or unsolicited links."),
        ("No personal attacks", "Disagree with the take, not the person."),
        ("No illegal content", "Obvious, but it has to be said."),
        ("No private information", "Never post yours or anyone else's personal details."),
        ("Keep comments relevant", "Stay roughly on the topic of the article or review."),
        ("Rumours are rumours", "Treat unconfirmed news as unconfirmed — don't present it as fact.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                Text("A few simple rules keep the comments worth reading.")
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)
                ForEach(rules, id: \.0) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(rule.0, systemImage: "checkmark.circle")
                            .font(BrickFont.cardTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        Text(rule.1)
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                            .padding(.leading, 28)
                    }
                    .padding(BrickSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brickCard()
                }
                Text("Comments that break these rules can be hidden or removed, and repeat offenders may be restricted. Report anything that looks wrong — three reports hides a comment automatically pending review.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            .padding(BrickSpacing.l)
        }
        .background { BrickScreenBackground() }
        .navigationTitle("Community Rules")
    }
}

struct LegalView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                section("About this app", "Bricks in a Bag Studio is the official app of Bricks in a Bag — an independent brick-building fan and custom model brand.")
                section("Trademark notice", "LEGO® is a trademark of the LEGO Group, which does not sponsor, authorise or endorse this app. \"LEGO®\" is used only as a descriptive reference. References to compatible brick-building brands do not imply official compatibility unless confirmed by the manufacturer.")
                section("Your content", "You keep the rights to photos you upload. Uploaded photos are used only for the feature you requested — for example, generating a mosaic preview — and are never used for public content or AI training without your explicit permission.")
                section("Privacy", "Account data is used to run your account: comments, saved items, designs and Brick Bar requests. Your saved items and Brick Bar requests are always private. You can request account deletion at any time from Settings.")
                section("AI-assisted content", "Some articles are drafted with AI assistance. Every AI-assisted article is reviewed and approved by the Bricks in a Bag team before publishing, and is labelled as such.")
            }
            .padding(BrickSpacing.l)
        }
        .background { BrickScreenBackground() }
        .navigationTitle("Legal & About")
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            Text(title)
                .font(BrickFont.cardTitle)
                .foregroundStyle(BrickColor.primaryText)
            Text(body)
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .lineSpacing(3)
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }
}
