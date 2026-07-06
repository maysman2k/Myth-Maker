import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var scope: SearchScope = .all

    private var results: [SearchResult] {
        SearchEngine.search(query, in: model.searchDocuments, scope: scope)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrickSpacing.s) {
                        ForEach(SearchScope.allCases) { candidate in
                            FilterChip(title: candidate.rawValue, isSelected: scope == candidate) {
                                scope = candidate
                            }
                        }
                    }
                }

                if query.trimmingCharacters(in: .whitespaces).count < SearchEngine.minimumQueryLength {
                    recentAndPopular
                } else if results.isEmpty {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        message: "No results for \"\(query)\". Try a different word or category."
                    )
                } else {
                    ForEach(results) { result in
                        if let route = ContentRoute(type: result.document.contentType, id: result.document.id) {
                            NavigationLink(value: route) {
                                SearchResultRow(document: result.document)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                model.recordSearch(query)
                            })
                        }
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "News, reviews, builds, lessons…")
        .contentRouteDestinations()
    }

    @ViewBuilder
    private var recentAndPopular: some View {
        if !model.recentSearches.isEmpty {
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                Text("Recent searches")
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                ForEach(model.recentSearches, id: \.self) { recent in
                    Button {
                        query = recent
                    } label: {
                        Label(recent, systemImage: "clock.arrow.circlepath")
                            .font(BrickFont.body)
                            .foregroundStyle(BrickColor.secondaryText)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            Text("Popular")
                .font(BrickFont.cardTitle)
                .foregroundStyle(BrickColor.primaryText)
            FlowChips(items: ["stadium", "mosaic", "modular", "rumour", "retiring", "deal", "review"]) { term in
                query = term
            }
        }
    }
}

private struct FlowChips: View {
    var items: [String]
    var onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrickSpacing.s) {
                ForEach(items, id: \.self) { item in
                    FilterChip(title: item, isSelected: false) { onTap(item) }
                }
            }
        }
    }
}

private struct SearchResultRow: View {
    var document: SearchDocument

    var body: some View {
        HStack(spacing: BrickSpacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(BrickColor.gold)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(BrickColor.gold.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack {
                    TagBadge(text: document.contentType.displayName)
                    Text(document.summary)
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(BrickColor.secondaryText)
        }
        .padding(BrickSpacing.m)
        .brickCard()
    }

    private var symbol: String {
        switch document.contentType {
        case .article: return "newspaper"
        case .review: return "star.bubble"
        case .product: return "bag"
        case .lesson: return "graduationcap"
        default: return "doc"
        }
    }
}
