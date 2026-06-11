import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(TimetableStore.self) private var timetables

    @State private var showClearConfirm = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Live map") {
                Picker("Refresh every", selection: $settings.refreshSeconds) {
                    Text("10 seconds").tag(10.0)
                    Text("15 seconds").tag(15.0)
                    Text("30 seconds").tag(30.0)
                    Text("60 seconds").tag(60.0)
                }
                Toggle("Show stops when zoomed in", isOn: $settings.showStopsOnMap)
            }

            Section {
                LabeledContent("Saved timetables",
                               value: "\(timetables.timetables.count)")
                LabeledContent("Storage used",
                               value: ByteCountFormatter.string(
                                   fromByteCount: Int64(timetables.totalSizeBytes),
                                   countStyle: .file))
                Button("Delete all saved timetables", role: .destructive) {
                    showClearConfirm = true
                }
            } header: {
                Text("Offline storage")
            }

            Section {
                Link(destination: URL(string: "https://bustimes.org")!) {
                    LabeledContent("Data source", value: "bustimes.org")
                }
                Link(destination: URL(string: "https://www.bus-data.dft.gov.uk")!) {
                    LabeledContent("Underlying data", value: "DfT Bus Open Data")
                }
            } header: {
                Text("About the data")
            } footer: {
                Text("Live positions and timetables come from bustimes.org, a brilliant community project by Joshua Goodwin, built on the Department for Transport's Bus Open Data Service (Open Government Licence v3). BusPulse keeps its request rate deliberately gentle. If you find the data useful, consider supporting bustimes.org.")
            }

            Section {
                LabeledContent("Version", value: appVersion)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Settings")
        .confirmationDialog("Delete all saved timetables?",
                            isPresented: $showClearConfirm,
                            titleVisibility: .visible) {
            Button("Delete all", role: .destructive) {
                timetables.deleteAll()
            }
        } message: {
            Text("You can download them again any time you're online.")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return version
    }
}
