import SwiftUI

struct CreateVoteView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let eventID: String

    @State private var kind: VoteKind = .dateAvailability
    @State private var title = ""
    @State private var detail = ""
    @State private var allowsMultipleSelection = false
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now

    // Date-availability options
    @State private var candidateDates: [Date] = []
    @State private var newCandidateDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: .now) ?? .now

    // Location / freeform options
    @State private var optionTexts: [String] = ["", ""]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
                    Picker("Vote type", selection: $kind) {
                        ForEach(VoteKind.allCases, id: \.self) { kind in
                            Label(kind.label, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                        Text("Question").font(PlanrFont.cardTitle)
                        TextField(defaultTitle, text: $title)
                            .textFieldStyle(.roundedBorder)
                        TextField("Extra context (optional)", text: $detail)
                            .textFieldStyle(.roundedBorder)
                    }
                    .softCard()

                    optionsSection

                    VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                        if kind != .dateAvailability {
                            Toggle("Allow picking more than one", isOn: $allowsMultipleSelection)
                        }
                        Toggle("Set a deadline", isOn: $hasDeadline.animation())
                        if hasDeadline {
                            DatePicker("Closes", selection: $deadline, in: Date.now...,
                                       displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    .softCard()
                }
                .padding(.horizontal, PlanrSpacing.screenMargin)
                .padding(.vertical, PlanrSpacing.lg)
            }
            .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("New vote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var defaultTitle: String {
        switch kind {
        case .dateAvailability: return "Which dates work?"
        case .location: return "Where are we going?"
        case .freeform: return "e.g. Fancy dress or not?"
        }
    }

    @ViewBuilder
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
            Text("Options").font(PlanrFont.cardTitle)

            if kind == .dateAvailability {
                ForEach(candidateDates.indices, id: \.self) { index in
                    HStack {
                        Label(DateUtilities.shortDay(candidateDates[index]), systemImage: "calendar")
                        Spacer()
                        Button(role: .destructive) {
                            candidateDates.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .accessibilityLabel("Remove date")
                    }
                }
                HStack {
                    DatePicker("Add a date", selection: $newCandidateDate, in: Date.now...,
                               displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                    Button {
                        let day = Calendar.current.startOfDay(for: newCandidateDate)
                        if !candidateDates.contains(day) {
                            candidateDates.append(day)
                            candidateDates.sort()
                        }
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                }
                Text("People tap every day they can make. Planr surfaces the best date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(optionTexts.indices, id: \.self) { index in
                    HStack {
                        TextField("Option \(index + 1)", text: $optionTexts[index])
                            .textFieldStyle(.roundedBorder)
                        if optionTexts.count > 2 {
                            Button(role: .destructive) {
                                optionTexts.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .accessibilityLabel("Remove option")
                        }
                    }
                }
                Button {
                    optionTexts.append("")
                } label: {
                    Label("Add option", systemImage: "plus.circle.fill")
                }
            }
        }
        .softCard()
    }

    private var isValid: Bool {
        let titleOK = !effectiveTitle.isEmpty
        switch kind {
        case .dateAvailability:
            return titleOK && candidateDates.count >= 2
        case .location, .freeform:
            return titleOK && optionTexts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
        }
    }

    private var effectiveTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        switch kind {
        case .dateAvailability: return "Which dates work?"
        case .location: return "Where are we going?"
        case .freeform: return ""
        }
    }

    private func create() {
        let options: [VoteOption]
        switch kind {
        case .dateAvailability:
            options = candidateDates.map { VoteOption(label: DateUtilities.shortDay($0), date: $0) }
        case .location, .freeform:
            options = optionTexts
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { VoteOption(label: $0) }
        }
        model.createVote(eventID: eventID,
                         title: effectiveTitle,
                         detail: detail.trimmingCharacters(in: .whitespaces).isEmpty ? nil : detail,
                         kind: kind,
                         options: options,
                         allowsMultipleSelection: allowsMultipleSelection,
                         deadline: hasDeadline ? deadline : nil)
        dismiss()
    }
}
