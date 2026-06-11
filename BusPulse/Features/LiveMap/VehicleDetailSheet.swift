import SwiftUI

/// Bottom sheet for a tapped bus: where it's going, how it's doing,
/// the rest of its journey, follow mode, and sharing.
struct VehicleDetailSheet: View {
    @Environment(\.busAPI) private var api

    let initialVehicle: VehiclePosition
    let stream: LiveVehiclesModel?
    @Binding var followedVehicleID: Int?

    @State private var journey: TimetableTrip?
    @State private var journeyFailed = false

    /// Freshest data wins — the sheet stays live while the feed updates.
    private var vehicle: VehiclePosition {
        stream?.vehicle(withID: initialVehicle.id) ?? initialVehicle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                header
                followAndShare
                journeySection
                footer
            }
            .padding(BPSpacing.screenMargin)
        }
        .background(BPColor.backgroundPrimary)
        .task {
            await loadJourney()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            HStack(spacing: BPSpacing.md) {
                RoutePill(lineName: vehicle.routeLabel,
                          backgroundHex: vehicle.liveryBackground,
                          foregroundHex: vehicle.liveryForeground)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.destination ?? "In service")
                        .font(BPFont.cardTitle)
                    if let name = vehicle.vehicleName {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                LiveBadge()
            }
            HStack(spacing: BPSpacing.md) {
                if let delay = vehicle.delaySeconds {
                    DelayChip(status: DelayStatus(delaySeconds: delay))
                }
                if let recorded = vehicle.recordedAt {
                    Text("Seen \(recorded.formatted(.relative(presentation: .numeric)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .bpCard()
    }

    private var followAndShare: some View {
        HStack(spacing: BPSpacing.md) {
            Button {
                followedVehicleID = followedVehicleID == vehicle.id ? nil : vehicle.id
            } label: {
                Label(followedVehicleID == vehicle.id ? "Following" : "Follow",
                      systemImage: followedVehicleID == vehicle.id
                          ? "location.fill.viewfinder" : "location.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(followedVehicleID == vehicle.id ? BPColor.live : BPColor.signal)

            ShareLink(item: shareURL, message: Text(shareText)) {
                Label("Share live bus", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var journeySection: some View {
        if let journey, !journey.times.isEmpty {
            VStack(alignment: .leading, spacing: BPSpacing.sm) {
                Text("This journey")
                    .font(BPFont.cardTitle)
                ForEach(Array(journey.times.enumerated()), id: \.offset) { _, time in
                    HStack {
                        Image(systemName: "smallcircle.filled.circle")
                            .font(.caption2)
                            .foregroundStyle(BPColor.signal)
                        Text(time.stopName ?? time.atcoCode ?? "Stop")
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        if let seconds = time.departureSeconds ?? time.arrivalSeconds {
                            Text(TimeOfDay.label(forSeconds: seconds))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .bpCard()
        } else if vehicle.tripID != nil && !journeyFailed {
            HStack {
                ProgressView()
                Text("Loading journey…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var footer: some View {
        Group {
            if let url = vehicle.webURL {
                Link(destination: url) {
                    Label("Vehicle history on bustimes.org", systemImage: "safari")
                        .font(.caption)
                }
            }
        }
    }

    private var shareURL: URL {
        vehicle.webURL ?? URL(string: "https://bustimes.org")!
    }

    private var shareText: String {
        var text = "🚌 Route \(vehicle.routeLabel)"
        if let destination = vehicle.destination { text += " to \(destination)" }
        if let delay = vehicle.delaySeconds {
            text += " — \(DelayStatus(delaySeconds: delay).label.lowercased())"
        }
        text += ". Tracked live with BusPulse."
        return text
    }

    private func loadJourney() async {
        guard let tripID = vehicle.tripID else {
            journeyFailed = true
            return
        }
        do {
            journey = try await api.trip(id: tripID)
        } catch {
            journeyFailed = true
        }
    }
}
