import CoreLocation
import SwiftUI

/// Lists the stops along a bus's route so the user can pick one to be
/// alerted at — "tell me when this bus reaches here".
struct AlarmStopPickerSheet: View {
    @Environment(\.busAPI) private var api
    @Environment(\.dismiss) private var dismiss

    let serviceID: Int
    let lineName: String
    let onPick: (String, CLLocationCoordinate2D) -> Void

    @State private var stops: [Stop] = []
    @State private var query = ""
    @State private var isLoading = true

    private var filteredStops: [Stop] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return stops }
        return stops.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading stops…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if stops.isEmpty {
                    BPEmptyState(symbol: "mappin.slash",
                                 title: "No stops found",
                                 message: "We couldn't load the stops for the \(lineName) just now.")
                } else {
                    List(filteredStops) { stop in
                        Button {
                            onPick(stop.displayName, stop.coordinate)
                            dismiss()
                        } label: {
                            HStack(spacing: BPSpacing.md) {
                                Image(systemName: "mappin.circle")
                                    .foregroundStyle(BPColor.signal)
                                Text(stop.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                    .searchable(text: $query, prompt: "Find a stop")
                }
            }
            .navigationTitle("Alert me at…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                stops = (try? await api.stops(onService: serviceID)) ?? []
                isLoading = false
            }
        }
    }
}
