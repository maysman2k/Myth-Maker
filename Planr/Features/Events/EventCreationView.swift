import SwiftUI

struct EventCreationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var kind: EventKind = .nightOut
    @State private var moodEmoji = "🎉"
    @State private var coverPaletteIndex = 0
    @State private var knowsDate = false
    @State private var startDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: .now) ?? .now
    @State private var isMultiDay = false
    @State private var endDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: .now) ?? .now
    @State private var locationName = ""
    @State private var budgetNote = ""
    @State private var privacy: PrivacyLevel = .inviteOnly
    @State private var shameBoardEnabled = false

    private let moods = ["🎉", "🍀", "🍻", "🎶", "🏆", "🌙", "✈️", "🎬", "💃", "🏖️"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PlanrSpacing.xl) {
                    CoverArtView(paletteIndex: coverPaletteIndex, kind: kind,
                                 moodEmoji: moodEmoji, height: 120)

                    section("What's the occasion?") {
                        TextField("Event name", text: $title)
                            .textFieldStyle(.roundedBorder)
                        TextField("A line about the plan (optional)", text: $detail, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    section("Type") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104))], spacing: PlanrSpacing.sm) {
                            ForEach(EventKind.allCases) { option in
                                Button {
                                    kind = option
                                } label: {
                                    VStack(spacing: PlanrSpacing.xs) {
                                        Image(systemName: option.symbol)
                                            .font(.title3)
                                        Text(option.label)
                                            .font(.caption.weight(.semibold))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, PlanrSpacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: PlanrRadius.chip, style: .continuous)
                                            .fill(option == kind ? PlanrColor.ember.opacity(0.2)
                                                                 : PlanrColor.surfacePrimary)
                                    )
                                    .foregroundStyle(option == kind ? PlanrColor.ember : .primary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(option == kind ? .isSelected : [])
                            }
                        }
                    }

                    section("Mood & cover") {
                        HStack(spacing: PlanrSpacing.sm) {
                            ForEach(moods, id: \.self) { mood in
                                Button {
                                    moodEmoji = mood
                                } label: {
                                    Text(mood)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(mood == moodEmoji
                                                                  ? PlanrColor.ember.opacity(0.25)
                                                                  : Color.secondary.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Mood \(mood)")
                                .accessibilityAddTraits(mood == moodEmoji ? .isSelected : [])
                            }
                        }
                        .frame(maxWidth: .infinity)
                        HStack(spacing: PlanrSpacing.sm) {
                            ForEach(CoverPalette.palettes.indices, id: \.self) { index in
                                Button {
                                    coverPaletteIndex = index
                                } label: {
                                    LinearGradient(colors: CoverPalette.colors(at: index),
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                        .overlay {
                                            if index == coverPaletteIndex {
                                                Circle().strokeBorder(.primary, lineWidth: 2)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Cover style \(index + 1)")
                                .accessibilityAddTraits(index == coverPaletteIndex ? .isSelected : [])
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    section("The basics") {
                        Toggle("We already know the date", isOn: $knowsDate.animation())
                        if knowsDate {
                            DatePicker("Date", selection: $startDate, displayedComponents: .date)
                            Toggle("More than one day", isOn: $isMultiDay.animation())
                            if isMultiDay {
                                DatePicker("Until", selection: $endDate, in: startDate...,
                                           displayedComponents: .date)
                            }
                        } else {
                            Label("Leave it blank and open a date vote instead.",
                                  systemImage: "lightbulb")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        TextField("Location, if you know it", text: $locationName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Rough budget (optional)", text: $budgetNote)
                            .textFieldStyle(.roundedBorder)
                    }

                    section("Group settings") {
                        Picker("Who can join", selection: $privacy) {
                            ForEach(PrivacyLevel.allCases, id: \.self) { level in
                                Text(level.label).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                        Toggle(isOn: $shameBoardEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Shame board")
                                Text("Playful leaderboard of payers and slackers. Opt-in, never mean.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, PlanrSpacing.screenMargin)
                .padding(.bottom, PlanrSpacing.xxl)
            }
            .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ heading: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: PlanrSpacing.md) {
            Text(heading)
                .font(PlanrFont.cardTitle)
            content()
        }
        .softCard()
    }

    private func create() {
        model.createEvent(title: title.trimmingCharacters(in: .whitespaces),
                          detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                          kind: kind,
                          startDate: knowsDate ? startDate : nil,
                          endDate: knowsDate && isMultiDay ? endDate : (knowsDate ? startDate : nil),
                          locationName: locationName.trimmingCharacters(in: .whitespaces),
                          privacy: privacy,
                          moodEmoji: moodEmoji,
                          budgetNote: budgetNote.trimmingCharacters(in: .whitespaces),
                          coverPaletteIndex: coverPaletteIndex,
                          shameBoardEnabled: shameBoardEnabled)
        dismiss()
    }
}
