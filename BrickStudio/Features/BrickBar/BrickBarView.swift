import SwiftUI

struct BrickBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.l) {
                    BrickArtView(seed: 4711, tint: BrickColor.brickRed, symbol: "wrench.and.screwdriver")
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text("The Brick Bar")
                        .font(BrickFont.pageTitle)
                        .foregroundStyle(BrickColor.primaryText)

                    Text("Have an idea for a custom build? Send us the details and we'll help turn it into bricks.")
                        .font(BrickFont.body)
                        .foregroundStyle(BrickColor.secondaryText)

                    NavigationLink {
                        RequestFlowView()
                    } label: {
                        Text("Start a Request")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed))

                    if !model.myBrickBarRequests.isEmpty {
                        NavigationLink {
                            MyRequestsView()
                        } label: {
                            HStack {
                                Image(systemName: "tray.full")
                                Text("My requests (\(model.myBrickBarRequests.count))")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(BrickFont.cardTitle)
                            .foregroundStyle(BrickColor.primaryText)
                            .padding(BrickSpacing.l)
                            .brickCard()
                        }
                        .buttonStyle(.plain)
                    }

                    SectionHeader(title: "How it works")
                    processSteps

                    SectionHeader(title: "Popular build types")
                    buildTypeGrid

                    SectionHeader(title: "Questions people ask")
                    faqCard

                    LegalDisclaimerFooter()
                }
                .padding(.horizontal, BrickSpacing.l)
            }
            .background(BrickColor.background)
            .navigationTitle("Brick Bar")
            .navigationBarTitleDisplayMode(.inline)
            .contentRouteDestinations()
        }
    }

    private var processSteps: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            processStep(1, "Tell us the idea", "Build type, reference photos and a description.")
            processStep(2, "We review it", "We check feasibility and sizing, and may ask a question or two.")
            processStep(3, "You get a quote", "A price range and timeline, in the app. No obligation.")
            processStep(4, "We build it", "Hand-built, checked and delivered to your door.")
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private func processStep(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: BrickSpacing.m) {
            Text("\(number)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(BrickColor.brickRed))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                Text(detail)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
        }
    }

    private var buildTypeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BrickSpacing.m) {
            ForEach(BuildType.allCases) { type in
                NavigationLink {
                    RequestFlowView(prefill: RequestFlowView.Prefill(buildType: type))
                } label: {
                    VStack(spacing: BrickSpacing.s) {
                        Image(systemName: type.symbol)
                            .font(.system(size: 24))
                            .foregroundStyle(BrickColor.brickRed)
                        Text(type.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BrickColor.primaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .padding(BrickSpacing.s)
                    .brickCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            faqItem("How much does a custom build cost?", "Most commissions land between £100 and £1,000 depending on size and detail. You choose a budget range in the request and we design to it.")
            faqItem("How long does it take?", "Small builds ship in 2–3 weeks; large stadiums typically take 4–8 weeks. Tell us your deadline and we'll be straight about what's possible.")
            faqItem("Do I have to commit before the quote?", "No. Quotes are free, stay open for 30 days and carry no obligation.")
            faqItem("Can you build my club's stadium?", "Almost always. We build unofficial, fan-commissioned models from your photos — no club branding is used without permission.")
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private func faqItem(_ question: String, _ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BrickColor.primaryText)
            Text(answer)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
        }
    }
}
