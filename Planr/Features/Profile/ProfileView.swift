import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model

    @State private var showResetConfirm = false
    @State private var notificationFeedback: String?

    var body: some View {
        if let user = model.currentUser {
            content(for: user)
        }
    }

    private func content(for user: UserProfile) -> some View {
        Form {
            Section {
                HStack(spacing: PlanrSpacing.lg) {
                    AvatarView(profile: user, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(PlanrFont.screenTitle)
                        Text("\(model.events.count) event\(model.events.count == 1 ? "" : "s") on the books")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TextField("Display name", text: Binding(
                    get: { user.displayName },
                    set: { newValue in
                        var updated = user
                        updated.displayName = newValue
                        model.updateProfile(updated)
                    }))
            } header: {
                Text("Profile")
            }

            Section("Avatar") {
                avatarPickers(for: user)
            }

            Section {
                Toggle("Notifications", isOn: Binding(
                    get: { user.notificationsEnabled },
                    set: { enabled in
                        var updated = user
                        updated.notificationsEnabled = enabled
                        model.updateProfile(updated)
                        if enabled { requestNotifications() }
                    }))
                if let notificationFeedback {
                    Text(notificationFeedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Calendar sync", isOn: Binding(
                    get: { user.calendarSyncEnabled },
                    set: { enabled in
                        var updated = user
                        updated.calendarSyncEnabled = enabled
                        model.updateProfile(updated)
                    }))
            } header: {
                Text("Reminders & calendar")
            } footer: {
                Text("Calendar sync adds locked-in events to your iPhone calendar from the event screen.")
            }

            Section {
                Toggle("Hide me from shame boards", isOn: Binding(
                    get: { user.hiddenFromShameBoard },
                    set: { hidden in
                        var updated = user
                        updated.hiddenFromShameBoard = hidden
                        model.updateProfile(updated)
                    }))
            } header: {
                Text("Safety")
            } footer: {
                Text("When hidden, you never appear on any event's shame board — hero or straggler.")
            }

            Section {
                Button("Erase all events and data", role: .destructive) {
                    showResetConfirm = true
                }
            } header: {
                Text("Your data")
            } footer: {
                Text("Everything lives on this device. Nothing is uploaded anywhere — group sync is coming in a future release.")
            }
        }
        .navigationTitle("Profile")
        .confirmationDialog("Erase everything?", isPresented: $showResetConfirm,
                            titleVisibility: .visible) {
            Button("Erase all data", role: .destructive) {
                model.resetAllData(keepProfile: true)
            }
        } message: {
            Text("All events, votes, chats and photos are deleted from this device. Your profile stays.")
        }
    }

    @ViewBuilder
    private func avatarPickers(for user: UserProfile) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6),
                  spacing: PlanrSpacing.sm) {
            ForEach(AvatarStyle.symbols, id: \.self) { symbol in
                Button {
                    var updated = user
                    updated.avatarSymbol = symbol
                    model.updateProfile(updated)
                } label: {
                    Image(systemName: symbol)
                        .font(.body)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(symbol == user.avatarSymbol
                                                  ? PlanrColor.ember.opacity(0.25)
                                                  : Color.secondary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Avatar symbol \(symbol)")
                .accessibilityAddTraits(symbol == user.avatarSymbol ? .isSelected : [])
            }
        }
        HStack(spacing: PlanrSpacing.sm) {
            ForEach(AvatarPalette.colors.indices, id: \.self) { index in
                Button {
                    var updated = user
                    updated.avatarColorIndex = index
                    model.updateProfile(updated)
                } label: {
                    Circle()
                        .fill(AvatarPalette.color(at: index))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if index == user.avatarColorIndex {
                                Circle().strokeBorder(.primary, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Avatar colour \(index + 1)")
                .accessibilityAddTraits(index == user.avatarColorIndex ? .isSelected : [])
            }
        }
    }

    private func requestNotifications() {
        Task {
            let granted = await model.notifications.requestPermission()
            notificationFeedback = granted
                ? "Notifications are on."
                : "Enable notifications for Planr in Settings to get reminders."
        }
    }
}
