import SwiftUI

struct NotificationsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: BrickSpacing.m) {
                if !model.isSignedIn {
                    EmptyStateView(
                        symbol: "bell",
                        message: "Sign in to get replies, Brick Bar updates and news alerts.",
                        actionTitle: "Sign In",
                        action: { model.isShowingAuth = true }
                    )
                } else if model.myNotifications.isEmpty {
                    EmptyStateView(
                        symbol: "bell",
                        message: "Nothing yet. Replies to your comments and Brick Bar updates will appear here."
                    )
                } else {
                    ForEach(model.myNotifications) { notification in
                        row(for: notification)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.unreadNotificationCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") { model.markAllNotificationsRead() }
                        .font(BrickFont.meta)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for notification: NotificationItem) -> some View {
        let content = HStack(alignment: .top, spacing: BrickSpacing.m) {
            Image(systemName: notification.kind.symbol)
                .font(.system(size: 17))
                .foregroundStyle(notification.readAt == nil ? BrickColor.gold : BrickColor.secondaryText)
                .frame(width: 38, height: 38)
                .background(Circle().fill(BrickColor.gold.opacity(notification.readAt == nil ? 0.14 : 0.06)))
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 15, weight: notification.readAt == nil ? .bold : .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                    .multilineTextAlignment(.leading)
                Text(notification.body)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(AppDate.relative(notification.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(BrickColor.secondaryText)
            }
            Spacer()
            if notification.readAt == nil {
                Circle()
                    .fill(BrickColor.brickRed)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(BrickSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()

        if let targetType = notification.targetType,
           let targetID = notification.targetID,
           let route = ContentRoute(type: targetType, id: targetID) {
            NavigationLink(value: route) { content }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    model.markNotificationRead(notification.id)
                })
        } else {
            Button {
                model.markNotificationRead(notification.id)
            } label: { content }
                .buttonStyle(.plain)
        }
    }
}
