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
                NavigationLink {
                    LegalDocumentView(title: "Privacy Policy", text: LegalContent.privacyPolicy)
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                NavigationLink {
                    LegalDocumentView(title: "Terms of Use", text: LegalContent.termsOfUse)
                } label: {
                    Label("Terms of Use", systemImage: "doc.text")
                }
                NavigationLink {
                    LegalDocumentView(title: "Data & Attribution", text: LegalContent.dataAttribution)
                } label: {
                    Label("Data & Attribution", systemImage: "info.circle")
                }
            } header: {
                Text("Legal & privacy")
            } footer: {
                Text("Contains public sector information licensed under the Open Government Licence v3.0, from the Department for Transport's Bus Open Data Service.")
            }

            Section {
                Link(destination: URL(string: "https://www.bus-data.dft.gov.uk")!) {
                    LabeledContent("Bus Open Data Service", value: "bus-data.dft.gov.uk")
                }
                Link(destination: URL(string: "mailto:\(LegalContent.contactEmail)")!) {
                    LabeledContent("Contact", value: LegalContent.contactEmail)
                }
            } header: {
                Text("About")
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
