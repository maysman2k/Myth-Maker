import SwiftUI

struct MyRequestsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                if model.myBrickBarRequests.isEmpty {
                    EmptyStateView(
                        symbol: "tray",
                        message: "No requests yet. Got an idea for a custom build? The Brick Bar is waiting."
                    )
                } else {
                    ForEach(model.myBrickBarRequests) { request in
                        NavigationLink(value: ContentRoute.brickBarRequest(request.id)) {
                            RequestSummaryCard(request: request)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("My Requests")
    }
}

struct RequestSummaryCard: View {
    var request: BrickBarRequest

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            HStack {
                Image(systemName: request.buildType.symbol)
                    .foregroundStyle(BrickColor.brickRed)
                Text(request.title.isEmpty ? request.buildType.rawValue : request.title)
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                    .lineLimit(1)
                Spacer()
                statusBadge
            }
            Text(request.description)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack {
                MetaLabel(symbol: "calendar", text: AppDate.medium(request.createdAt))
                if let quote = request.quotedPrice {
                    MetaLabel(symbol: "sterlingsign.circle", text: quote.formatted(.currency(code: "GBP")))
                }
                Spacer()
            }
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var statusBadge: some View {
        TagBadge(
            text: request.status.displayName,
            tint: request.status.isOpen ? BrickColor.stadiumGreen : BrickColor.secondaryText
        )
    }
}

struct RequestDetailView: View {
    @Environment(AppModel.self) private var model
    var requestID: UUID

    private var request: BrickBarRequest? {
        model.brickBarRequests.first { $0.id == requestID }
    }

    var body: some View {
        Group {
            if let request, request.userID == model.currentUserID || model.currentUser?.role.canModerate == true {
                content(for: request)
            } else {
                EmptyStateView(symbol: "tray", message: "This request isn't available.")
            }
        }
        .background(BrickColor.background)
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(for request: BrickBarRequest) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                HStack {
                    TagBadge(text: request.buildType.rawValue, tint: BrickColor.brickRed)
                    TagBadge(text: request.status.displayName, tint: request.status.isOpen ? BrickColor.stadiumGreen : BrickColor.secondaryText)
                    Spacer()
                }

                Text(request.title.isEmpty ? request.buildType.rawValue : request.title)
                    .font(BrickFont.pageTitle)
                    .foregroundStyle(BrickColor.primaryText)

                if let quote = request.quotedPrice {
                    VStack(alignment: .leading, spacing: BrickSpacing.s) {
                        Text("Quote")
                            .font(BrickFont.cardTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        Text(quote.formatted(.currency(code: "GBP")))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(BrickColor.stadiumGreen)
                        Text("Quotes stay open for 30 days. Reply to our email to accept or ask questions.")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                    .padding(BrickSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brickCard()
                }

                VStack(alignment: .leading, spacing: BrickSpacing.s) {
                    detailRow("Description", request.description)
                    detailRow("Size", request.sizePreference.rawValue)
                    detailRow("Budget", request.budgetRange.rawValue)
                    detailRow("Timing", request.deadlineDate.map { AppDate.medium($0) } ?? request.deadlineType.rawValue)
                    detailRow("Submitted", AppDate.medium(request.createdAt))
                    detailRow("Contact", request.contactEmail)
                }
                .padding(BrickSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brickCard()

                if !request.referenceImageFilenames.isEmpty {
                    VStack(alignment: .leading, spacing: BrickSpacing.s) {
                        Text("Reference images")
                            .font(BrickFont.cardTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: BrickSpacing.s) {
                                ForEach(request.referenceImageFilenames, id: \.self) { filename in
                                    if let image = ImageStore.load(filename) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                    }
                }

                if !request.adminNotes.isEmpty {
                    VStack(alignment: .leading, spacing: BrickSpacing.s) {
                        Text("From the workshop")
                            .font(BrickFont.cardTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        Text(request.adminNotes)
                            .font(BrickFont.body)
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                    .padding(BrickSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brickCard()
                }

                nextActionCard(for: request)
            }
            .padding(BrickSpacing.l)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 15))
                .foregroundStyle(BrickColor.primaryText)
        }
    }

    @ViewBuilder
    private func nextActionCard(for request: BrickBarRequest) -> some View {
        let message: String? = {
            switch request.status {
            case .submitted: return "We're reading your request now — expect an update within a couple of days."
            case .reviewing: return "Your idea is on the workbench. We'll come back with a quote or a question soon."
            case .needMoreInfo: return "We need a little more detail — check the email you gave us."
            case .quoted: return "Your quote is ready above. Reply to our email to accept."
            case .accepted, .inProgress: return "Bricks are being placed. We'll let you know when it ships."
            case .completed: return "This build is complete. Thanks for building with us!"
            default: return nil
            }
        }()
        if let message {
            Label(message, systemImage: "arrow.right.circle")
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .padding(BrickSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brickCard()
        }
    }
}
