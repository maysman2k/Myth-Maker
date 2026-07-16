import SwiftUI
import PhotosUI

/// Post-signup onboarding: claim a unique @handle, set an avatar, pick
/// interests and follow a few builders. Presented until a handle exists.
struct ProfileSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private enum Step: Int, CaseIterable {
        case handle
        case avatar
        case interests
        case follows
    }

    @State private var step: Step = .handle
    @State private var handle = ""
    @State private var handleStatus: HandleStatus = .idle
    @State private var pickedItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var selectedInterests: Set<String> = []
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var availabilityTask: Task<Void, Never>?

    private enum HandleStatus: Equatable {
        case idle
        case checking
        case available
        case unavailable
        case invalid
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressDots
                    .padding(.top, BrickSpacing.m)

                ScrollView {
                    VStack(spacing: BrickSpacing.l) {
                        switch step {
                        case .handle: handleStep
                        case .avatar: avatarStep
                        case .interests: interestsStep
                        case .follows: followsStep
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(BrickFont.meta)
                                .foregroundStyle(BrickColor.brickRed)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(BrickSpacing.l)
                }

                footerButtons
                    .padding(BrickSpacing.l)
            }
            .background { BrickScreenBackground() }
            .navigationTitle("Set up your profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: handle) { _, newValue in
            checkAvailability(of: newValue)
        }
        .onChange(of: pickedItem) { _, item in
            loadAvatar(from: item)
        }
    }

    // MARK: Steps

    private var handleStep: some View {
        VStack(spacing: BrickSpacing.m) {
            stepHeader(
                symbol: "at",
                title: "Claim your handle",
                detail: "Your unique name on Brick Studio. Lowercase letters, numbers and underscores."
            )

            HStack(spacing: BrickSpacing.s) {
                Text("@")
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.secondaryText)
                TextField("brickbuilder", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                statusIcon
            }
            .padding(BrickSpacing.m)
            .background(BrickColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(statusBorderColor, lineWidth: 1))

            if handleStatus == .unavailable {
                Text("That handle is taken. Try another.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.brickRed)
            } else if handleStatus == .invalid, !handle.isEmpty {
                Text("3–20 characters, starting with a letter.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
        }
    }

    private var avatarStep: some View {
        VStack(spacing: BrickSpacing.m) {
            stepHeader(
                symbol: "person.crop.circle.badge.plus",
                title: "Add a photo",
                detail: "Show off a minifig, your favourite build, or yourself."
            )

            PhotosPicker(selection: $pickedItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 132, height: 132)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(BrickColor.card)
                            .frame(width: 132, height: 132)
                            .overlay(
                                Image(systemName: "camera")
                                    .font(.system(size: 34))
                                    .foregroundStyle(BrickColor.secondaryText)
                            )
                    }
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(BrickColor.accentText)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(BrickGradient.sunrise))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                }
            }
            .buttonStyle(PressableStyle())

            Text("You can change this any time in your profile.")
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
        }
    }

    private var interestsStep: some View {
        VStack(spacing: BrickSpacing.m) {
            stepHeader(
                symbol: "square.grid.3x3.topleft.filled",
                title: "What do you build?",
                detail: "Pick a few themes so your feed starts in the right place."
            )

            FlowChips(
                options: FavouriteTopic.all,
                selection: $selectedInterests
            )
        }
    }

    private var followsStep: some View {
        VStack(spacing: BrickSpacing.m) {
            stepHeader(
                symbol: "person.2",
                title: "Follow some builders",
                detail: "Their posts will appear in your feed."
            )

            ForEach(suggestedBuilders) { builder in
                HStack(spacing: BrickSpacing.m) {
                    AvatarView(name: builder.displayName, imageReference: builder.avatarImageReference, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(builder.displayName)
                            .font(BrickFont.cardTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        if !builder.bio.isEmpty {
                            Text(builder.bio)
                                .font(BrickFont.meta)
                                .foregroundStyle(BrickColor.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Button(model.isFollowing(builder.id) ? "Following" : "Follow") {
                        model.toggleFollow(builder.id)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: !model.isFollowing(builder.id)))
                    .font(.system(size: 13, weight: .bold))
                }
                .padding(BrickSpacing.m)
                .brickCard()
            }
        }
    }

    // MARK: Chrome

    private func stepHeader(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: BrickSpacing.s) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(BrickColor.gold)
            Text(title)
                .font(BrickFont.sectionTitle)
                .foregroundStyle(BrickColor.primaryText)
            Text(detail)
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { candidate in
                Capsule()
                    .fill(candidate.rawValue <= step.rawValue ? BrickColor.gold : BrickColor.border)
                    .frame(width: candidate == step ? 22 : 8, height: 8)
            }
        }
        .animation(BrickMotion.bouncy, value: step)
        .accessibilityHidden(true)
    }

    private var footerButtons: some View {
        HStack(spacing: BrickSpacing.m) {
            if step != .handle {
                Button("Back") {
                    withAnimation(BrickMotion.smooth) {
                        step = Step(rawValue: step.rawValue - 1) ?? .handle
                    }
                }
                .buttonStyle(StudButtonStyle(tint: BrickColor.primaryText, prominent: false))
            }

            Button {
                advance()
            } label: {
                HStack {
                    if isSubmitting { ProgressView().padding(.trailing, 4) }
                    Text(step == .follows ? "Finish" : "Continue")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudButtonStyle())
            .disabled(!canAdvance || isSubmitting)
        }
    }

    // MARK: State

    private var suggestedBuilders: [UserAccount] {
        model.accounts
            .filter { $0.id != model.currentUserID && $0.publicProfileEnabled }
            .prefix(6)
            .map { $0 }
    }

    private var canAdvance: Bool {
        switch step {
        case .handle: return handleStatus == .available || (handleStatus == .idle && AppModel.isValidHandle(handle.lowercased()))
        case .avatar, .interests, .follows: return true
        }
    }

    private var statusBorderColor: Color {
        switch handleStatus {
        case .available: return BrickColor.stadiumGreen
        case .unavailable: return BrickColor.brickRed
        default: return BrickColor.border
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch handleStatus {
        case .checking:
            ProgressView()
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(BrickColor.stadiumGreen)
        case .unavailable:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(BrickColor.brickRed)
        case .idle, .invalid:
            EmptyView()
        }
    }

    // MARK: Actions

    private func checkAvailability(of raw: String) {
        availabilityTask?.cancel()
        let candidate = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard AppModel.isValidHandle(candidate) else {
            handleStatus = candidate.isEmpty ? .idle : .invalid
            return
        }
        guard SupabaseService.isConfigured else {
            handleStatus = .available
            return
        }
        handleStatus = .checking
        availabilityTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            let available = (try? await SupabaseService.isHandleAvailable(candidate)) ?? true
            guard !Task.isCancelled else { return }
            handleStatus = available ? .available : .unavailable
        }
    }

    private func loadAvatar(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                avatarImage = image
            }
        }
    }

    private func advance() {
        errorMessage = nil
        if step == .follows {
            finish()
        } else {
            withAnimation(BrickMotion.smooth) {
                step = Step(rawValue: step.rawValue + 1) ?? .follows
            }
        }
    }

    private func finish() {
        isSubmitting = true
        Task {
            do {
                var avatarReference: String?
                if let avatarImage, let filename = ImageStore.save(avatarImage) {
                    avatarReference = filename
                }
                try await model.completeProfileSetup(
                    handle: handle,
                    interests: Array(selectedInterests),
                    avatarImageReference: avatarReference
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                if case AuthError.handleTaken = error {
                    withAnimation(BrickMotion.smooth) { step = .handle }
                    handleStatus = .unavailable
                }
            }
            isSubmitting = false
        }
    }
}

/// Simple wrapping chip grid for multi-select options.
private struct FlowChips: View {
    var options: [String]
    @Binding var selection: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: BrickSpacing.s)], spacing: BrickSpacing.s) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.contains(option)
                Button {
                    withAnimation(BrickMotion.bouncy) {
                        if isSelected {
                            selection.remove(option)
                        } else {
                            selection.insert(option)
                        }
                    }
                } label: {
                    Text(option)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 38)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                Capsule().fill(BrickGradient.sunrise)
                            } else {
                                Capsule().fill(BrickColor.card)
                            }
                        }
                        .foregroundStyle(isSelected ? BrickColor.accentText : BrickColor.primaryText)
                        .overlay(Capsule().strokeBorder(BrickColor.border, lineWidth: isSelected ? 0 : 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
