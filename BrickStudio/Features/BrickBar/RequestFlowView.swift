import SwiftUI
import PhotosUI

/// Multi-step Brick Bar request form (§15.3, §27.14). Each step validates
/// before continuing; guests can fill it in but must sign in to submit.
struct RequestFlowView: View {
    struct Prefill {
        var buildType: BuildType = .footballStadium
        var title = ""
        var description = ""
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var step: RequestStep = .buildType
    @State private var buildType: BuildType
    @State private var title: String
    @State private var descriptionText: String
    @State private var sizePreference: SizePreference = .notSure
    @State private var budgetRange: BudgetRange = .notSure
    @State private var deadlineType: DeadlineType = .noRush
    @State private var deadlineDate = Date().addingTimeInterval(30 * 86_400)
    @State private var contactEmail = ""
    @State private var contactPhone = ""
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var referenceImages: [UIImage] = []
    @State private var validationMessage: String?
    @State private var submitted = false

    init(prefill: Prefill = Prefill()) {
        _buildType = State(initialValue: prefill.buildType)
        _title = State(initialValue: prefill.title)
        _descriptionText = State(initialValue: prefill.description)
    }

    private var draft: BrickBarRequest {
        BrickBarRequest(
            id: UUID(),
            userID: model.currentUserID ?? UUID(),
            buildType: buildType,
            title: title,
            description: descriptionText,
            referenceImageFilenames: [],
            sizePreference: sizePreference,
            budgetRange: budgetRange,
            deadlineType: deadlineType,
            deadlineDate: deadlineType == .specificDate ? deadlineDate : nil,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
            status: .draft,
            adminNotes: "",
            quotedPrice: nil,
            quoteStatus: .notQuoted,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    var body: some View {
        Group {
            if submitted {
                submittedView
            } else {
                formView
            }
        }
        .background { BrickScreenBackground() }
        .navigationTitle("Custom Request")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if contactEmail.isEmpty, let email = model.currentUser?.email {
                contactEmail = email
            }
        }
    }

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                progressHeader

                Text(step.title)
                    .font(BrickFont.sectionTitle)
                    .foregroundStyle(BrickColor.primaryText)

                stepContent

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.circle")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.brickRed)
                }

                HStack(spacing: BrickSpacing.m) {
                    if step != .buildType {
                        Button("Back") { goBack() }
                            .buttonStyle(StudButtonStyle(tint: BrickColor.secondaryText, prominent: false))
                    }
                    Button(step == .review ? "Submit Request" : "Continue") { goForward() }
                        .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(BrickSpacing.l)
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 6) {
            ForEach(RequestStep.allCases, id: \.rawValue) { candidate in
                Capsule()
                    .fill(candidate.rawValue <= step.rawValue ? BrickColor.brickRed : BrickColor.border)
                    .frame(height: 5)
            }
        }
        .accessibilityLabel("Step \(step.rawValue + 1) of \(RequestStep.allCases.count)")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .buildType:
            VStack(spacing: BrickSpacing.s) {
                ForEach(BuildType.allCases) { type in
                    Button {
                        buildType = type
                    } label: {
                        HStack {
                            Image(systemName: type.symbol)
                                .frame(width: 28)
                            Text(type.rawValue)
                            Spacer()
                            if buildType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(BrickColor.brickRed)
                            }
                        }
                        .font(BrickFont.body)
                        .foregroundStyle(BrickColor.primaryText)
                        .padding(BrickSpacing.m)
                        .frame(minHeight: 44)
                        .brickCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        case .idea:
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                labelledField("Build title") {
                    TextField("e.g. St James' Park display model", text: $title)
                }
                labelledField("Describe the idea") {
                    TextField("What should we build? Size, colours, details that matter to you…", text: $descriptionText, axis: .vertical)
                        .lineLimit(4...8)
                }
                VStack(alignment: .leading, spacing: BrickSpacing.s) {
                    Text("Reference photos (optional)")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                    PhotosPicker(selection: $pickedItems, maxSelectionCount: 4, matching: .images) {
                        Label(referenceImages.isEmpty ? "Add photos" : "Change photos (\(referenceImages.count))", systemImage: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: false))
                    if !referenceImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: BrickSpacing.s) {
                                ForEach(Array(referenceImages.enumerated()), id: \.offset) { _, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 84, height: 84)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: pickedItems) { _, newItems in
                Task {
                    var images: [UIImage] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    referenceImages = images
                }
            }
        case .sizeAndBudget:
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                pickerCard(title: "Size", selection: $sizePreference, options: SizePreference.allCases, label: \.rawValue)
                pickerCard(title: "Budget range", selection: $budgetRange, options: BudgetRange.allCases, label: \.rawValue)
                Text("Ranges keep things honest — we design to the budget you pick.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
        case .deadline:
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                pickerCard(title: "Timing", selection: $deadlineType, options: DeadlineType.allCases, label: \.rawValue)
                if deadlineType == .specificDate {
                    DatePicker("Needed by", selection: $deadlineDate, in: Date()..., displayedComponents: .date)
                        .padding(BrickSpacing.m)
                        .brickCard()
                }
            }
        case .contact:
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                labelledField("Email") {
                    TextField("you@example.com", text: $contactEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                labelledField("Phone (optional)") {
                    TextField("For quick questions about the build", text: $contactPhone)
                        .keyboardType(.phonePad)
                }
            }
        case .review:
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                summaryRow("Build type", buildType.rawValue)
                summaryRow("Title", title)
                summaryRow("Description", descriptionText)
                summaryRow("Photos", referenceImages.isEmpty ? "None" : "\(referenceImages.count) attached")
                summaryRow("Size", sizePreference.rawValue)
                summaryRow("Budget", budgetRange.rawValue)
                summaryRow("Timing", deadlineType == .specificDate ? AppDate.medium(deadlineDate) : deadlineType.rawValue)
                summaryRow("Email", contactEmail)
                if !contactPhone.isEmpty { summaryRow("Phone", contactPhone) }
                if !model.isSignedIn {
                    Label("You'll be asked to sign in when you submit, so the request stays in your profile.", systemImage: "person.crop.circle.badge.questionmark")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                        .padding(.top, BrickSpacing.s)
                }
            }
            .padding(BrickSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brickCard()
        }
    }

    private var submittedView: some View {
        VStack(spacing: BrickSpacing.l) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(BrickColor.stadiumGreen)
            Text("Request submitted")
                .font(BrickFont.pageTitle)
                .foregroundStyle(BrickColor.primaryText)
            Text("Tell us what you'd like built and we'll review the idea before coming back with next steps. You can track progress from your profile.")
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed))
        }
        .padding(BrickSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func labelledField<Field: View>(_ label: String, @ViewBuilder field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.xs) {
            Text(label)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            field()
                .padding(BrickSpacing.m)
                .background(BrickColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
        }
    }

    private func pickerCard<Option: Hashable & Identifiable>(title: String, selection: Binding<Option>, options: [Option], label: KeyPath<Option, String>) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            Text(title)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            ForEach(options) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    HStack {
                        Text(option[keyPath: label])
                        Spacer()
                        if selection.wrappedValue == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BrickColor.brickRed)
                        }
                    }
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.primaryText)
                    .padding(BrickSpacing.m)
                    .frame(minHeight: 44)
                    .brickCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BrickColor.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func goBack() {
        validationMessage = nil
        if let previous = RequestStep(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    private func goForward() {
        if let message = RequestValidator.validate(step: step, request: draft) {
            validationMessage = message
            return
        }
        validationMessage = nil
        if step == .review {
            submit()
        } else if let next = RequestStep(rawValue: step.rawValue + 1) {
            step = next
        }
    }

    private func submit() {
        guard model.requireAccount(), let userID = model.currentUserID else { return }
        let filenames = referenceImages.compactMap { ImageStore.save($0) }
        var request = draft
        request.userID = userID
        request.referenceImageFilenames = filenames
        model.submitBrickBarRequest(request)
        submitted = true
    }
}
