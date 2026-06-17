import SwiftUI

struct ServiceSearchView: View {
    @Environment(\.busAPI) private var api
    @Environment(FavoritesStore.self) private var favorites
    @Environment(TimetableStore.self) private var timetables

    @State private var query = ""
    @State private var results: [Service] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.md) {
                if query.isEmpty {
                    if !favorites.services.isEmpty {
                        Text("Favourite routes")
                            .font(BPFont.cardTitle)
                        ForEach(favorites.services) { service in
                            serviceRow(service)
                        }
                    } else {
                        BPEmptyState(symbol: "magnifyingglass",
                                     title: "Find a route",
                                     message: "Search by route number or destination — \"43\", \"X41\", \"Manchester Airport\"…")
                    }
                } else if isSearching && results.isEmpty {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity)
                        .padding(BPSpacing.xl)
                } else if results.isEmpty {
                    BPEmptyState(symbol: "bus",
                                 title: "No routes found",
                                 message: "Try the route number on the front of the bus, or a place it goes.")
                } else {
                    ForEach(results) { service in
                        serviceRow(service)
                    }
                }
            }
            .padding(.horizontal, BPSpacing.screenMargin)
            .padding(.vertical, BPSpacing.md)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Routes")
        .searchable(text: $query, prompt: "Route number or destination")
        .onChange(of: query) {
            search()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    JourneyPlannerView()
                } label: {
                    Label("Plan a journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
            }
        }
    }

    private func serviceRow(_ service: Service) -> some View {
        NavigationLink {
            ServiceDetailView(service: service)
        } label: {
            HStack(spacing: BPSpacing.md) {
                RoutePill(lineName: service.lineName)
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.description)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let mode = service.mode, !mode.isEmpty {
                        Text(mode.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if timetables.timetable(forServiceID: service.id) != nil {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(BPColor.signal)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .bpCard()
        }
        .buttonStyle(.plain)
    }

    private func search() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            if let found = try? await api.services(matching: trimmed) {
                results = found
            }
            isSearching = false
        }
    }
}
