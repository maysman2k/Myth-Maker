import SwiftUI

struct OnboardingFlow: View {
    @State private var showProfileStep = false

    var body: some View {
        if showProfileStep {
            CreateProfileView()
        } else {
            WelcomeView { showProfileStep = true }
        }
    }
}

/// Three quick value props, then straight into profile creation.
struct WelcomeView: View {
    let onContinue: () -> Void

    private struct Pitch: Identifiable {
        let symbol: String
        let title: String
        let message: String
        var id: String { title }
    }

    private let pitches = [
        Pitch(symbol: "checkmark.seal.fill", title: "Decide",
              message: "Dates, places, big calls — voted on in minutes, not 400 messages."),
        Pitch(symbol: "list.clipboard.fill", title: "Organise",
              message: "Tasks, money owed and the plan, all in one place. No spreadsheet required."),
        Pitch(symbol: "photo.on.rectangle.angled", title: "Remember",
              message: "Photos, awards and the full story, saved in the vault forever."),
    ]

    var body: some View {
        VStack(spacing: PlanrSpacing.xl) {
            Spacer()
            Text("🎉")
                .font(.system(size: 64))
            Text("Planr")
                .font(PlanrFont.heroTitle)
            Text("Plan great events without the group chat chaos.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PlanrSpacing.xxl)

            VStack(spacing: PlanrSpacing.md) {
                ForEach(pitches) { pitch in
                    HStack(spacing: PlanrSpacing.md) {
                        Image(systemName: pitch.symbol)
                            .font(.title3)
                            .foregroundStyle(PlanrColor.ember)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pitch.title).font(PlanrFont.cardTitle)
                            Text(pitch.message).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .softCard()
                }
            }
            .padding(.horizontal, PlanrSpacing.screenMargin)

            Spacer()

            Button(action: onContinue) {
                Text("Get started")
                    .font(PlanrFont.cardTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PlanrSpacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.bottom, PlanrSpacing.xl)
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
    }
}

struct CreateProfileView: View {
    @Environment(AppModel.self) private var model

    @State private var name = ""
    @State private var avatarSymbol = AvatarStyle.symbols[0]
    @State private var avatarColorIndex = 0
    @State private var includeSampleEvent = true

    var body: some View {
        ScrollView {
            VStack(spacing: PlanrSpacing.xl) {
                Text("Make it yours")
                    .font(PlanrFont.heroTitle)
                    .padding(.top, PlanrSpacing.xxl)

                AvatarView(profile: UserProfile(displayName: name.isEmpty ? "You" : name,
                                                avatarSymbol: avatarSymbol,
                                                avatarColorIndex: avatarColorIndex),
                           size: 88)

                VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                    Text("Your name").font(PlanrFont.cardTitle)
                    TextField("What do your mates call you?", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                }

                VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                    Text("Pick a vibe").font(PlanrFont.cardTitle)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6),
                              spacing: PlanrSpacing.sm) {
                        ForEach(AvatarStyle.symbols, id: \.self) { symbol in
                            Button {
                                avatarSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle().fill(symbol == avatarSymbol
                                                      ? PlanrColor.ember.opacity(0.25)
                                                      : Color.secondary.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Avatar symbol \(symbol)")
                            .accessibilityAddTraits(symbol == avatarSymbol ? .isSelected : [])
                        }
                    }
                    HStack(spacing: PlanrSpacing.sm) {
                        ForEach(AvatarPalette.colors.indices, id: \.self) { index in
                            Button {
                                avatarColorIndex = index
                            } label: {
                                Circle()
                                    .fill(AvatarPalette.color(at: index))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if index == avatarColorIndex {
                                            Circle().strokeBorder(.primary, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("Avatar colour \(index + 1)")
                            .accessibilityAddTraits(index == avatarColorIndex ? .isSelected : [])
                        }
                    }
                }

                Toggle(isOn: $includeSampleEvent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start with a sample event")
                            .font(PlanrFont.cardTitle)
                        Text("A Dublin trip mid-planning, so you can poke around.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .softCard()

                Button {
                    let profile = UserProfile(displayName: name.trimmingCharacters(in: .whitespaces),
                                              avatarSymbol: avatarSymbol,
                                              avatarColorIndex: avatarColorIndex)
                    model.completeOnboarding(profile: profile, includeSampleEvent: includeSampleEvent)
                } label: {
                    Text("Let's go")
                        .font(PlanrFont.cardTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PlanrSpacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.bottom, PlanrSpacing.xxl)
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
    }
}
