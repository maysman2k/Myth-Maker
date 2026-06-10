import SwiftUI

struct NewTaskSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let eventID: String

    @State private var title = ""
    @State private var detail = ""
    @State private var assigneeID: String?
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section("The job") {
                    TextField("e.g. Book the hotel", text: $title)
                    TextField("Details (optional)", text: $detail)
                }
                Section("Who's on it") {
                    assigneePicker
                }
                Section {
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        model.addTask(eventID: eventID,
                                      title: title.trimmingCharacters(in: .whitespaces),
                                      detail: detail.isEmpty ? nil : detail,
                                      assigneeID: assigneeID ?? model.currentUser?.id ?? "",
                                      dueDate: hasDueDate ? dueDate : nil)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if assigneeID == nil { assigneeID = model.currentUser?.id }
            }
        }
    }

    @ViewBuilder
    private var assigneePicker: some View {
        if let event = model.event(withID: eventID) {
            Picker("Assignee", selection: $assigneeID) {
                ForEach(model.participants(in: event)) { person in
                    Text(person.displayName).tag(Optional(person.id))
                }
            }
        }
    }
}

struct NewPaymentSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let eventID: String

    @State private var title = ""
    @State private var amount: Decimal = 0
    @State private var owedByIDs: Set<String> = []
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section("What was paid for") {
                    TextField("e.g. Accommodation deposit", text: $title)
                    HStack {
                        Text("Each person owes")
                        Spacer()
                        TextField("0", value: $amount, format: .currency(code: "GBP"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Who owes you") {
                    whoOwesPicker
                }
                Section {
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("Planr only tracks what's owed. It never holds or moves money.")
                }
            }
            .navigationTitle("Track a payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        model.addPayment(eventID: eventID,
                                         title: title.trimmingCharacters(in: .whitespaces),
                                         amountPerPerson: amount,
                                         owedByIDs: Array(owedByIDs),
                                         dueDate: hasDueDate ? dueDate : nil)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                              || amount <= 0 || owedByIDs.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var whoOwesPicker: some View {
        if let event = model.event(withID: eventID) {
            let others = model.participants(in: event).filter { $0.id != model.currentUser?.id }
            ForEach(others) { person in
                Button {
                    if owedByIDs.contains(person.id) {
                        owedByIDs.remove(person.id)
                    } else {
                        owedByIDs.insert(person.id)
                    }
                } label: {
                    HStack {
                        AvatarView(profile: person, size: 28)
                        Text(person.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if owedByIDs.contains(person.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(PlanrColor.ember)
                        }
                    }
                }
                .accessibilityAddTraits(owedByIDs.contains(person.id) ? .isSelected : [])
            }
        }
    }
}
