import AVFoundation
import Combine
import SceneKit
import SwiftUI
import UIKit

struct GamesView: View {
    @Environment(AppModel.self) private var model
    @State private var presentedGame: BrickGame?
    @AppStorage("brickStackBestScore") private var brickStackBest = 0
    @AppStorage("studMatchBestScore") private var studMatchBest = 0
    @AppStorage("buildSprintBestScore") private var buildSprintBest = 0
    @AppStorage("revealStadiumBestScore") private var revealStadiumBest = 0
    @AppStorage("gamesStreakCount") private var streakCount = 0
    @AppStorage("gamesLastPlayedDay") private var lastPlayedDay = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Games")
                            .font(BrickFont.pageTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        Text("Quick brick-sized challenges")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                    Spacer()
                    if streakCount > 0 {
                        VStack(spacing: 0) {
                            Text("🔥")
                                .font(.system(size: 22))
                            Text("\(streakCount) day\(streakCount == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(BrickColor.gold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Play streak: \(streakCount) days")
                    }
                }

                leaderboardStrip

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        gameTile(.brickStack).cardAppear(0)
                        gameTile(.studMatch).cardAppear(1)
                    }
                    .frame(maxHeight: .infinity)

                    HStack(spacing: 12) {
                        gameTile(.buildSprint).cardAppear(2)
                        gameTile(.revealTheStadium).cardAppear(3)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .background { BrickScreenBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $presentedGame) { game in
                FullScreenGameContainer(game: game)
            }
        }
    }

    /// Weekly champion banner + link to the full boards.
    @ViewBuilder
    private var leaderboardStrip: some View {
        NavigationLink {
            LeaderboardView()
        } label: {
            HStack(spacing: 10) {
                Text("🏆")
                    .font(.system(size: 20))
                if let champion = model.weeklyChampion {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(champion.displayName) leads \(champion.game.displayName) with \(champion.score)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(BrickColor.primaryText)
                            .lineLimit(1)
                        Text("Weekly leaderboards — resets Monday")
                            .font(.system(size: 11))
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                } else {
                    Text("Weekly leaderboards — be the first on the board")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BrickColor.primaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BrickColor.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(BrickColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func bestScore(for game: BrickGame) -> Int {
        switch game {
        case .brickStack: return brickStackBest
        case .studMatch: return studMatchBest
        case .buildSprint: return buildSprintBest
        case .revealTheStadium: return revealStadiumBest
        }
    }

    /// Consecutive-day play streak — ticked whenever a game is launched.
    private func recordStreak() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        guard lastPlayedDay != today else { return }
        let yesterday = formatter.string(from: Date().addingTimeInterval(-86_400))
        streakCount = lastPlayedDay == yesterday ? streakCount + 1 : 1
        lastPlayedDay = today
    }

    private func gameTile(_ game: BrickGame) -> some View {
        Button {
            recordStreak()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            presentedGame = game
        } label: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: game.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: game.symbol)
                    .font(.system(size: 86, weight: .black))
                    .foregroundStyle(BrickColor.primaryText.opacity(0.08))
                    .offset(x: 26, y: -34)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: game.symbol)
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(game.iconColor)
                        Spacer()
                        if bestScore(for: game) > 0 {
                            Text("★ \(bestScore(for: game))")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(BrickColor.gold)
                                .clipShape(Capsule())
                                .accessibilityLabel("Best score \(bestScore(for: game))")
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 30, height: 30)
                                .background(BrickColor.gold)
                                .clipShape(Circle())
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(game.title)
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(BrickColor.primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Text(game.subtitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(BrickColor.secondaryText)
                            .lineLimit(4)
                            .minimumScaleFactor(0.84)
                        Text(game.gameTag)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.black.opacity(0.82))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(game.iconColor)
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(BrickColor.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(GameTilePressStyle())
    }
}

/// Springy scale-down on press — makes the tiles feel like physical bricks.
private struct GameTilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct FullScreenGameContainer: View {
    var game: BrickGame
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @AppStorage("brickStackBestScore") private var brickStackBest = 0
    @AppStorage("studMatchBestScore") private var studMatchBest = 0
    @AppStorage("buildSprintBestScore") private var buildSprintBest = 0
    @AppStorage("revealStadiumBestScore") private var revealStadiumBest = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            selectedGameView

            if game != .brickStack && game != .studMatch && game != .buildSprint {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(BrickColor.primaryText)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                }
                .padding(.top, 14)
                .padding(.trailing, 16)
                .accessibilityLabel("Close game")
            }
        }
        .background(BrickColor.background)
        // Every exit path (game over, quit mid-game, swipe down) pushes the
        // stored bests onto the weekly leaderboard. The Today-tab onChange
        // hooks never fire while this tab is open, so sync must happen here.
        .onDisappear {
            model.submitGameScore(.brickStack, score: brickStackBest)
            model.submitGameScore(.studMatch, score: studMatchBest)
            model.submitGameScore(.buildSprint, score: buildSprintBest)
            model.submitGameScore(.revealStadium, score: revealStadiumBest)
        }
    }

    @ViewBuilder
    private var selectedGameView: some View {
        switch game {
        case .brickStack:
            BrickStackGameView()
        case .studMatch:
            StudMatchGameView()
        case .buildSprint:
            BuildSprintGameView()
        case .revealTheStadium:
            RevealTheStadiumGameView()
        }
    }
}

private enum BrickGame: CaseIterable, Identifiable {
    case brickStack
    case studMatch
    case buildSprint
    case revealTheStadium

    var id: Self { self }

    var title: String {
        switch self {
        case .brickStack: return "Brick Stack"
        case .studMatch: return "Stud Match"
        case .buildSprint: return "Build Sprint"
        case .revealTheStadium: return "Reveal Stadium"
        }
    }

    var subtitle: String {
        switch self {
        case .brickStack: return "Stack moving plates, trim the misses, and chase the tallest tower."
        case .studMatch: return "Spot colour chains under pressure before the move timer snaps shut."
        case .buildSprint: return "Memorise the board, rebuild it, then see how close you got."
        case .revealTheStadium: return "Uncover as little as possible and name the stadium before time runs out."
        }
    }

    var symbol: String {
        switch self {
        case .brickStack: return "square.stack.3d.up.fill"
        case .studMatch: return "circle.grid.3x3.fill"
        case .buildSprint: return "timer"
        case .revealTheStadium: return "sportscourt.fill"
        }
    }

    var gameTag: String {
        switch self {
        case .brickStack: return "Timing"
        case .studMatch: return "Speed"
        case .buildSprint: return "Memory"
        case .revealTheStadium: return "Quiz"
        }
    }

    var iconColor: Color {
        switch self {
        case .brickStack: return Color(hex: 0xFFD23F)
        case .studMatch: return Color(hex: 0x32D583)
        case .buildSprint: return Color(hex: 0x5CC8FF)
        case .revealTheStadium: return Color(hex: 0xFF6B6B)
        }
    }

    var gradient: [Color] {
        switch self {
        case .brickStack:
            return [Color.brickAdaptive(light: 0xFFF3BF, dark: 0x3A3020), Color.brickAdaptive(light: 0xFFFFFF, dark: 0x171717)]
        case .studMatch:
            return [Color.brickAdaptive(light: 0xCFF7DF, dark: 0x123829), Color.brickAdaptive(light: 0xFFFFFF, dark: 0x171717)]
        case .buildSprint:
            return [Color.brickAdaptive(light: 0xCDEFFF, dark: 0x17324A), Color.brickAdaptive(light: 0xFFFFFF, dark: 0x171717)]
        case .revealTheStadium:
            return [Color.brickAdaptive(light: 0xFFE0E0, dark: 0x3B2025), Color.brickAdaptive(light: 0xFFFFFF, dark: 0x171717)]
        }
    }
}

// MARK: - Shared

/// Frosted glass surface for in-game chrome (score pills, badges, menus):
/// a real blur with a dark tint layered between the blur and the content,
/// so white HUD text stays legible over bright, moving playfields.
private struct GameGlassStyle<S: InsettableShape>: ViewModifier {
    var shape: S
    var darken: Double

    func body(content: Content) -> some View {
        content
            .background(shape.fill(.black.opacity(darken)))
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.75))
    }
}

private extension View {
    func gameGlass<S: InsettableShape>(in shape: S, darken: Double = 0.2) -> some View {
        modifier(GameGlassStyle(shape: shape, darken: darken))
    }
}

private enum GameStudColor: String, CaseIterable {
    case yellow, red, green, blue, white

    var color: Color {
        switch self {
        case .yellow: return Color(hex: 0xFFD500)
        case .red: return Color(hex: 0xD62828)
        case .green: return Color(hex: 0x009B48)
        case .blue: return Color(hex: 0x0055BF)
        case .white: return .white
        }
    }

    var uiColor: UIColor {
        switch self {
        case .yellow: return UIColor(hex: 0xFFD500)
        case .red: return UIColor(hex: 0xD62828)
        case .green: return UIColor(hex: 0x009B48)
        case .blue: return UIColor(hex: 0x0055BF)
        case .white: return UIColor(hex: 0xF2F3F2)
        }
    }
}

private struct GameHeader: View {
    var title: String
    var score: Int
    var detail: String
    var reset: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BrickFont.sectionTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Text(detail)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(BrickColor.gold)
                Text("score")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            Button(action: reset) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                    .frame(width: 38, height: 38)
                    .background(BrickColor.card)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Restart")
        }
    }
}

// MARK: - Brick Stack

private struct BrickStackGameView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("brickStackBestScore") private var bestScore = 0

    @State private var layers: [StackLayer] = [
        StackLayer(centerX: 0, centerZ: 0, studsX: 12, studsZ: 12, colorIndex: 0)
    ]
    @State private var movingOffset: CGFloat = -10
    @State private var movingAxis: StackAxis = .x
    @State private var direction: CGFloat = 1
    @State private var speed: CGFloat = 0.18
    @State private var score = 0
    @State private var combo = 0
    @State private var phase: StackPhase = .ready
    @State private var status = "Tap to start"
    @State private var colorOffset = Int.random(in: 0..<StackLayer.palette.count)
    @State private var countdownStartedAt: Date?
    @State private var countdownNumber = 3
    @State private var pulse: StackPulse?
    @StateObject private var audio = BrickStackAudioController()

    private let timer = Timer.publish(every: 0.018, on: .main, in: .common).autoconnect()
    private let startingStuds = 12
    private let travelLimit: CGFloat = 10.5

    var body: some View {
        ZStack {
            CartoonSkyBackground(progress: skyProgress)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                playfield
                    .ignoresSafeArea()
            }

            if phase == .ready {
                startOverlay
            } else if phase == .countdown {
                countdownOverlay
            } else if phase == .paused {
                pauseOverlay
            } else if phase == .gameOver {
                gameOverOverlay
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .onReceive(timer) { _ in
            tick()
        }
        .onAppear {
            audio.prepare()
        }
        .onDisappear {
            audio.stopMusic()
        }
        .onChange(of: phase) { _, newPhase in
            audio.setMusicActive(newPhase == .countdown || newPhase == .playing)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            scorePill(value: score, label: "score")
            scorePill(value: bestScore, label: "best")
            scorePill(value: combo, label: "combo")

            Button {
                if phase == .playing {
                    phase = .paused
                }
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .gameGlass(in: Circle(), darken: 0.2)
            }
            .buttonStyle(PressableStyle(scale: 0.88))
            .accessibilityLabel("Pause")
            .disabled(phase != .playing)
            .opacity(phase == .playing ? 1 : 0.46)
        }
        .padding(.top, 6)
        .padding(.horizontal, 14)
    }

    private var statusBadge: some View {
        Text(status)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .gameGlass(in: Capsule(), darken: 0.22)
    }

    private func scorePill(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(label == "score" ? BrickColor.gold : BrickColor.primaryText)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(BrickColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .gameGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous), darken: 0.18)
    }

    private var playfield: some View {
        BrickStackSceneView(
            layers: layers,
            movingOffset: movingOffset,
            movingAxis: movingAxis,
            movingColorIndex: layers.count + colorOffset,
            phase: phase,
            pulse: pulse
        )
    }

    private var startOverlay: some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(BrickColor.gold)
                Text("Tap To Stack")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                Text("Line up each moving brick. The overhang gets cut away.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(22)
            .gameGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), darken: 0.3)
            .cardAppear(0)
            .padding(.horizontal, 24)
            .padding(.bottom, 112)
        }
        .allowsHitTesting(false)
    }

    private var countdownOverlay: some View {
        VStack {
            Spacer()
            Text("\(countdownNumber)")
                .font(.system(size: 104, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.42), radius: 16, x: 0, y: 8)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.16), value: countdownNumber)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var pauseOverlay: some View {
        menuOverlay(title: "Paused", subtitle: "Take a breath. The tower can wait.", primaryTitle: "Resume", primaryAction: {
            phase = .playing
        }, secondaryTitle: "Restart", secondaryAction: {
            reset()
            startCountdown()
        }, quitAction: {
            dismiss()
        })
    }

    private var gameOverOverlay: some View {
        menuOverlay(title: "Stack Dropped", subtitle: "Score \(score)", primaryTitle: "Play Again", primaryAction: {
            reset()
            startCountdown()
        }, secondaryTitle: "Reset", secondaryAction: {
            reset()
        }, quitAction: {
            dismiss()
        })
    }

    private func menuOverlay(
        title: String,
        subtitle: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondaryAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(BrickColor.gold)

                VStack(spacing: 10) {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(StudButtonStyle(tint: BrickColor.gold))
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(StudButtonStyle(tint: .white, prominent: false))
                    Button("Quit Game", action: quitAction)
                        .buttonStyle(StudButtonStyle(tint: .white.opacity(0.72), prominent: false))
                }
                .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .gameGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), darken: 0.38)
            .cardAppear(0)
            .padding(.bottom, 104)
        }
    }

    private var nextColor: Color {
        StackLayer.palette[(layers.count + colorOffset) % StackLayer.palette.count].color
    }

    private var skyProgress: CGFloat {
        min(1, CGFloat(score) / 36)
    }

    private func tick() {
        if phase == .countdown {
            updateCountdown()
            return
        }

        guard phase == .playing, let top = layers.last else { return }
        movingOffset += direction * speed

        if movingOffset > travelLimit {
            movingOffset = travelLimit
            direction = -1
        } else if movingOffset < -travelLimit {
            movingOffset = -travelLimit
            direction = 1
        }

        let smallestSide = min(top.studsX, top.studsZ)
        let speedBoost = smallestSide < 8 ? CGFloat(8 - smallestSide) * 0.026 + CGFloat(score) * 0.003 : 0
        speed = min(0.36, 0.18 + speedBoost)
    }

    private func handleTap() {
        switch phase {
        case .ready:
            startCountdown()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .countdown:
            break
        case .playing:
            placeBrick()
        case .paused:
            break
        case .gameOver:
            break
        }
    }

    private func startCountdown() {
        countdownStartedAt = Date()
        countdownNumber = 3
        phase = .countdown
        status = "Get ready"
        movingOffset = direction > 0 ? -travelLimit : travelLimit
    }

    private func updateCountdown() {
        guard let countdownStartedAt else { return }
        let elapsed = Date().timeIntervalSince(countdownStartedAt)
        let nextNumber = max(1, 3 - Int(elapsed))
        if countdownNumber != nextNumber {
            countdownNumber = nextNumber
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        if elapsed >= 3 {
            self.countdownStartedAt = nil
            countdownNumber = 3
            phase = .playing
            status = "Tap to lock the brick"
        }
    }

    private func placeBrick() {
        guard let previous = layers.last else { return }

        let offset = movingOffset
        let missedStuds = Int(abs(offset).rounded())
        let activeStuds = movingAxis == .x ? previous.studsX : previous.studsZ

        guard missedStuds < activeStuds else {
            endGame()
            return
        }

        let shift = CGFloat(missedStuds) * 0.5 * (offset >= 0 ? 1 : -1)
        let newLayer: StackLayer
        if movingAxis == .x {
            newLayer = StackLayer(
                centerX: previous.centerX + shift,
                centerZ: previous.centerZ,
                studsX: previous.studsX - missedStuds,
                studsZ: previous.studsZ,
                colorIndex: layers.count + colorOffset
            )
        } else {
            newLayer = StackLayer(
                centerX: previous.centerX,
                centerZ: previous.centerZ + shift,
                studsX: previous.studsX,
                studsZ: previous.studsZ - missedStuds,
                colorIndex: layers.count + colorOffset
            )
        }

        if missedStuds == 0 {
            combo += 1
            score += 2 + combo
            status = "Perfect"
            audio.playClick()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            combo = 0
            score += 1
            status = "-\(missedStuds) stud\(missedStuds == 1 ? "" : "s")"
            audio.playClick()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        pulse = StackPulse(
            id: UUID(),
            centerX: newLayer.centerX,
            centerZ: newLayer.centerZ,
            studsX: newLayer.studsX,
            studsZ: newLayer.studsZ,
            y: CGFloat(layers.count)
        )
        layers.append(newLayer)
        bestScore = max(bestScore, score)
        movingAxis.toggle()
        direction *= -1
        movingOffset = direction > 0 ? -travelLimit : travelLimit
    }

    private func endGame() {
        phase = .gameOver
        status = "Missed the stack"
        let isNewBest = score > 0 && score >= bestScore
        bestScore = max(bestScore, score)
        audio.stopMusic()
        // A record run deserves a win buzz, not the failure thud.
        UINotificationFeedbackGenerator().notificationOccurred(isNewBest ? .success : .error)
    }

    private func reset() {
        colorOffset = Int.random(in: 0..<StackLayer.palette.count)
        layers = [StackLayer(centerX: 0, centerZ: 0, studsX: startingStuds, studsZ: startingStuds, colorIndex: colorOffset)]
        movingOffset = -10
        movingAxis = .x
        direction = 1
        speed = 0.18
        score = 0
        combo = 0
        phase = .ready
        status = "Tap to start"
        countdownStartedAt = nil
        countdownNumber = 3
        pulse = nil
    }
}

private struct CartoonSkyBackground: View {
    var progress: CGFloat

    private var nightOpacity: CGFloat {
        min(1, progress * 1.22)
    }

    private var spaceOpacity: CGFloat {
        max(0, min(1, (progress - 0.62) / 0.38))
    }

    private var cloudOpacity: CGFloat {
        max(0, 1 - progress * 1.55)
    }

    private var starOpacity: CGFloat {
        max(0, min(1, (progress - 0.45) / 0.55))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x26B8FF), Color(hex: 0x8DE8FF), Color(hex: 0xD7F56D)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [Color(hex: 0x29307A), Color(hex: 0x4453A3), Color(hex: 0x72B1D6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(nightOpacity)

                LinearGradient(
                    colors: [.black, Color(hex: 0x070B24), Color(hex: 0x111A3D)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(spaceOpacity)

                clouds(time: time)
                    .opacity(cloudOpacity)

                stars
                    .opacity(starOpacity)
            }
        }
    }

    private func clouds(time: TimeInterval) -> some View {
        ZStack {
            GameCloud(scale: 1.08)
                .offset(x: driftingX(base: -150, speed: 7, time: time), y: -232)
            GameCloud(scale: 0.78)
                .offset(x: driftingX(base: 150, speed: 5, time: time), y: -172)
            GameCloud(scale: 0.64)
                .offset(x: driftingX(base: -80, speed: 4, time: time), y: -44)
            GameCloud(scale: 0.9)
                .offset(x: driftingX(base: 100, speed: 6, time: time), y: 86)
        }
    }

    private func driftingX(base: CGFloat, speed: CGFloat, time: TimeInterval) -> CGFloat {
        let span: CGFloat = 560
        let raw = base + CGFloat(time).truncatingRemainder(dividingBy: 1000) * speed
        return raw.truncatingRemainder(dividingBy: span) - span / 2
    }

    private var stars: some View {
        ZStack {
            ForEach(0..<28, id: \.self) { index in
                let x = CGFloat((index * 73) % 360) - 180
                let y = CGFloat((index * 47) % 620) - 310
                let size = CGFloat((index % 3) + 2)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(index.isMultiple(of: 4) ? 0.95 : 0.62))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(Double(index * 17)))
                    .offset(x: x, y: y)
            }
        }
    }
}

private struct GameCloud: View {
    var scale: CGFloat

    var body: some View {
        ZStack {
            Image("GameCloud")
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(0.08), radius: 6, x: 6, y: 7)
                .opacity(0.94)
        }
        .frame(width: 154, height: 110)
        .scaleEffect(scale)
    }
}

private enum StackPhase: Equatable {
    case ready
    case countdown
    case playing
    case paused
    case gameOver
}

private enum StackAxis {
    case x
    case z

    mutating func toggle() {
        self = self == .x ? .z : .x
    }
}

private struct StackLayer: Identifiable {
    let id = UUID()
    var centerX: CGFloat
    var centerZ: CGFloat
    var studsX: Int
    var studsZ: Int
    var colorIndex: Int

    static let palette: [StackBrickColor] = [
        .init(swiftUI: Color(hex: 0x1E88E5), uiKit: UIColor(hex: 0x1E88E5)),
        .init(swiftUI: Color(hex: 0x39A9DB), uiKit: UIColor(hex: 0x39A9DB)),
        .init(swiftUI: Color(hex: 0x24BFC8), uiKit: UIColor(hex: 0x24BFC8)),
        .init(swiftUI: Color(hex: 0x34C759), uiKit: UIColor(hex: 0x34C759)),
        .init(swiftUI: Color(hex: 0x9BE15D), uiKit: UIColor(hex: 0x9BE15D)),
        .init(swiftUI: Color(hex: 0xF7E85B), uiKit: UIColor(hex: 0xF7E85B)),
        .init(swiftUI: Color(hex: 0xF5A623), uiKit: UIColor(hex: 0xF5A623)),
        .init(swiftUI: Color(hex: 0xEF5350), uiKit: UIColor(hex: 0xEF5350)),
        .init(swiftUI: Color(hex: 0xAB47BC), uiKit: UIColor(hex: 0xAB47BC))
    ]

    var brickColor: StackBrickColor {
        Self.palette[colorIndex % Self.palette.count]
    }
}

private struct StackBrickColor {
    var swiftUI: Color
    var uiKit: UIColor

    var color: Color { swiftUI }
}

private struct StackPulse {
    var id: UUID
    var centerX: CGFloat
    var centerZ: CGFloat
    var studsX: Int
    var studsZ: Int
    var y: CGFloat
}

@MainActor
private final class BrickStackAudioController: ObservableObject {
    private var musicPlayer: AVAudioPlayer?
    private var clickPlayer: AVAudioPlayer?

    func prepare() {
        configureSession()
        musicPlayer = makePlayer(named: "block-party", extension: "mp3", volume: 0.34, loops: -1)
        clickPlayer = makePlayer(named: "brick-click", extension: "wav", volume: 0.85, loops: 0)
    }

    func setMusicActive(_ active: Bool) {
        active ? playMusic() : pauseMusic()
    }

    func playClick() {
        guard let clickPlayer else { return }
        clickPlayer.stop()
        clickPlayer.currentTime = 0
        clickPlayer.play()
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer?.currentTime = 0
    }

    private func playMusic() {
        guard let musicPlayer, !musicPlayer.isPlaying else { return }
        musicPlayer.play()
    }

    private func pauseMusic() {
        musicPlayer?.pause()
    }

    private func configureSession() {
        // AVAudioSession activation can block, so keep it off the main
        // thread (the session API is thread-safe for these calls). Fixes
        // the "AVAudioSession Hang Risk" runtime warnings.
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)
        }
    }

    private func makePlayer(named name: String, extension fileExtension: String, volume: Float, loops: Int) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.numberOfLoops = loops
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }
}

private struct BrickStackSceneView: UIViewRepresentable {
    var layers: [StackLayer]
    var movingOffset: CGFloat
    var movingAxis: StackAxis
    var movingColorIndex: Int
    var phase: StackPhase
    var pulse: StackPulse?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var layerNodes: [UUID: SCNNode] = [:]
        var layerStudVisibility: [UUID: Bool] = [:]
        var baseNode: SCNNode?
        var movingSignature = ""
        var lastPulseID: UUID?
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        view.isPlaying = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60

        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 38
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(8.5, 9.6, 12.2)
        scene.rootNode.addChildNode(cameraNode)

        let cameraTarget = SCNNode()
        cameraTarget.name = "brickStackCameraTarget"
        cameraTarget.position = SCNVector3(0, 1.7, 0)
        scene.rootNode.addChildNode(cameraTarget)
        let lookAt = SCNLookAtConstraint(target: cameraTarget)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .omni
        keyLight.light?.intensity = 760
        keyLight.position = SCNVector3(-5, 10, 8)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.intensity = 620
        scene.rootNode.addChildNode(fillLight)

        let root = SCNNode()
        root.name = "brickStackRoot"
        scene.rootNode.addChildNode(root)

        let layersRoot = SCNNode()
        layersRoot.name = "brickStackLayersRoot"
        root.addChildNode(layersRoot)

        let movingRoot = SCNNode()
        movingRoot.name = "brickStackMovingRoot"
        root.addChildNode(movingRoot)

        let pulseRoot = SCNNode()
        pulseRoot.name = "brickStackPulseRoot"
        root.addChildNode(pulseRoot)

        view.scene = scene
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard
            let root = view.scene?.rootNode.childNode(withName: "brickStackRoot", recursively: false),
            let layersRoot = root.childNode(withName: "brickStackLayersRoot", recursively: false),
            let movingRoot = root.childNode(withName: "brickStackMovingRoot", recursively: false),
            let pulseRoot = root.childNode(withName: "brickStackPulseRoot", recursively: false)
        else { return }

        let unit: CGFloat = 0.42
        let worldYOffset = Float(-max(0, layers.count - 6)) * 0.32
        let focusLayer = layers.last
        let focusX = Float(-(focusLayer?.centerX ?? 0) * unit)
        let focusZ = Float(-(focusLayer?.centerZ ?? 0) * unit)
        root.position = SCNVector3(focusX, worldYOffset, focusZ)

        syncLayerNodes(in: layersRoot, context: context)

        updateMovingPlate(in: movingRoot, context: context)
        updatePulse(in: pulseRoot, context: context)
    }

    private func syncLayerNodes(in layersRoot: SCNNode, context: Context) {
        let visibleLayers = Array(layers.suffix(12))
        let visibleIDs = Set(visibleLayers.map(\.id))
        let firstVisibleIndex = max(0, layers.count - visibleLayers.count)

        for (id, node) in context.coordinator.layerNodes where !visibleIDs.contains(id) {
            node.removeFromParentNode()
            context.coordinator.layerNodes[id] = nil
            context.coordinator.layerStudVisibility[id] = nil
        }

        SCNTransaction.begin()
        SCNTransaction.disableActions = true

        for (visibleIndex, layer) in visibleLayers.enumerated() {
            let absoluteIndex = firstVisibleIndex + visibleIndex
            let showStuds = visibleIndex >= max(0, visibleLayers.count - 5)

            if let node = context.coordinator.layerNodes[layer.id],
               context.coordinator.layerStudVisibility[layer.id] == showStuds {
                node.position = platePosition(centerX: layer.centerX, centerZ: layer.centerZ, y: CGFloat(absoluteIndex))
            } else {
                context.coordinator.layerNodes[layer.id]?.removeFromParentNode()
                let node = plateNode(
                    centerX: layer.centerX,
                    centerZ: layer.centerZ,
                    y: CGFloat(absoluteIndex),
                    studsX: layer.studsX,
                    studsZ: layer.studsZ,
                    color: layer.brickColor.uiKit,
                    showStuds: showStuds
                )
                context.coordinator.layerNodes[layer.id] = node
                context.coordinator.layerStudVisibility[layer.id] = showStuds
                layersRoot.addChildNode(node)
            }
        }

        if context.coordinator.baseNode == nil {
            let base = basePlateNode()
            context.coordinator.baseNode = base
            layersRoot.addChildNode(base)
        }

        SCNTransaction.commit()
    }

    private func updateMovingPlate(in movingRoot: SCNNode, context: Context) {
        guard phase != .gameOver, let top = layers.last else {
            movingRoot.isHidden = true
            return
        }

        movingRoot.isHidden = false
        let movingColor = StackLayer.palette[movingColorIndex % StackLayer.palette.count].uiKit
        let signature = "\(top.studsX)|\(top.studsZ)|\(movingColorIndex)|\(movingAxis)"
        if context.coordinator.movingSignature != signature {
            context.coordinator.movingSignature = signature
            movingRoot.childNodes.forEach { $0.removeFromParentNode() }
            movingRoot.addChildNode(plateNode(
                centerX: 0,
                centerZ: 0,
                y: 0,
                studsX: top.studsX,
                studsZ: top.studsZ,
                color: movingColor,
                showStuds: true
            ))
        }

        let unit: CGFloat = 0.42
        let centerX = movingAxis == .x ? top.centerX + movingOffset : top.centerX
        let centerZ = movingAxis == .z ? top.centerZ + movingOffset : top.centerZ
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        movingRoot.position = SCNVector3(
            Float(centerX * unit),
            Float(CGFloat(layers.count) * 0.31),
            Float(centerZ * unit)
        )
        SCNTransaction.commit()
    }

    private func updatePulse(in pulseRoot: SCNNode, context: Context) {
        guard let pulse, context.coordinator.lastPulseID != pulse.id else { return }
        context.coordinator.lastPulseID = pulse.id

        let node = pulseNode(pulse)
        pulseRoot.addChildNode(node)
        node.opacity = 0.86
        node.scale = SCNVector3(0.92, 0.92, 0.92)

        let scale = SCNAction.scale(to: 1.22, duration: 0.34)
        scale.timingMode = .easeOut
        let fade = SCNAction.fadeOut(duration: 0.34)
        fade.timingMode = .easeOut
        node.runAction(.sequence([.group([scale, fade]), .removeFromParentNode()]))
    }

    private func pulseNode(_ pulse: StackPulse) -> SCNNode {
        let unit: CGFloat = 0.42
        let width = CGFloat(pulse.studsX) * unit + 0.28
        let depth = CGFloat(pulse.studsZ) * unit + 0.28
        let thickness: CGFloat = 0.045

        let node = SCNNode()
        node.position = SCNVector3(
            Float(pulse.centerX * unit),
            Float(pulse.y * 0.31 + 0.19),
            Float(pulse.centerZ * unit)
        )

        let material = pulseMaterial()
        let top = SCNBox(width: width, height: thickness, length: thickness, chamferRadius: 0.012)
        top.materials = [material]
        let bottom = SCNBox(width: width, height: thickness, length: thickness, chamferRadius: 0.012)
        bottom.materials = [material]
        let left = SCNBox(width: thickness, height: thickness, length: depth, chamferRadius: 0.012)
        left.materials = [material]
        let right = SCNBox(width: thickness, height: thickness, length: depth, chamferRadius: 0.012)
        right.materials = [material]

        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, 0, Float(depth / 2))
        let bottomNode = SCNNode(geometry: bottom)
        bottomNode.position = SCNVector3(0, 0, Float(-depth / 2))
        let leftNode = SCNNode(geometry: left)
        leftNode.position = SCNVector3(Float(-width / 2), 0, 0)
        let rightNode = SCNNode(geometry: right)
        rightNode.position = SCNVector3(Float(width / 2), 0, 0)

        node.addChildNode(topNode)
        node.addChildNode(bottomNode)
        node.addChildNode(leftNode)
        node.addChildNode(rightNode)
        return node
    }

    private func plateNode(centerX: CGFloat, centerZ: CGFloat, y: CGFloat, studsX: Int, studsZ: Int, color: UIColor, showStuds: Bool) -> SCNNode {
        let unit: CGFloat = 0.42
        let width = CGFloat(studsX) * unit
        let height: CGFloat = 0.22
        let depth = CGFloat(studsZ) * unit

        let node = SCNNode()
        node.position = platePosition(centerX: centerX, centerZ: centerZ, y: y)

        let outline = SCNBox(width: width + 0.08, height: height + 0.055, length: depth + 0.08, chamferRadius: 0.045)
        outline.materials = [outlineMaterial()]
        let outlineNode = SCNNode(geometry: outline)
        outlineNode.position = SCNVector3(0, -0.014, 0)
        node.addChildNode(outlineNode)

        let body = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.035)
        body.materials = [material(color)]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.018, 0)
        node.addChildNode(bodyNode)

        if showStuds {
            for studX in 0..<studsX {
                for studZ in 0..<studsZ {
                    let studOutlineGeometry = SCNCylinder(radius: 0.15, height: 0.086)
                    studOutlineGeometry.radialSegmentCount = 8
                    studOutlineGeometry.materials = [outlineMaterial()]
                    let studOutlineNode = SCNNode(geometry: studOutlineGeometry)
                    studOutlineNode.position = SCNVector3(
                        Float((CGFloat(studX) - CGFloat(studsX - 1) / 2) * unit),
                        Float(height / 2 + 0.047),
                        Float((CGFloat(studZ) - CGFloat(studsZ - 1) / 2) * unit)
                    )
                    node.addChildNode(studOutlineNode)

                    let studGeometry = SCNCylinder(radius: 0.13, height: 0.08)
                    studGeometry.radialSegmentCount = 8
                    studGeometry.materials = [material(color)]
                    let studNode = SCNNode(geometry: studGeometry)
                    studNode.position = SCNVector3(
                        Float((CGFloat(studX) - CGFloat(studsX - 1) / 2) * unit),
                        Float(height / 2 + 0.065),
                        Float((CGFloat(studZ) - CGFloat(studsZ - 1) / 2) * unit)
                    )
                    node.addChildNode(studNode)
                }
            }
        }

        return node
    }

    private func platePosition(centerX: CGFloat, centerZ: CGFloat, y: CGFloat) -> SCNVector3 {
        let unit: CGFloat = 0.42
        return SCNVector3(Float(centerX * unit), Float(y * 0.31), Float(centerZ * unit))
    }

    private func basePlateNode() -> SCNNode {
        let base = SCNBox(width: 6.2, height: 0.12, length: 6.2, chamferRadius: 0.025)
        base.materials = [material(UIColor(hex: 0x1594FF))]
        let node = SCNNode(geometry: base)
        node.position = SCNVector3(0, -0.24, 0)
        return node
    }

    private func material(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = color
        material.ambient.contents = color
        material.emission.contents = color.withAlphaComponent(0.08)
        material.specular.contents = UIColor.white.withAlphaComponent(0.08)
        material.shininess = 0.18
        return material
    }

    private func outlineMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor(hex: 0x1F2B34)
        material.emission.contents = UIColor(hex: 0x1F2B34)
        return material
    }

    private func pulseMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.86)
        material.emission.contents = UIColor.white.withAlphaComponent(0.86)
        return material
    }
}

// MARK: - Stud Match

private struct StudMatchGameView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("studMatchBestScore") private var bestScore = 0

    @State private var board: [GameStudColor] = Self.makeBoard()
    @State private var selected: Set<Int> = []
    @State private var score = 0
    @State private var moves = 24
    @State private var phase: StudMatchPhase = .playing
    @State private var message = "Select 3+ matching bricks"
    @State private var matchPulseCount = 0
    @State private var roundToken = 0
    @State private var roundStartedAt: Date?
    @State private var wrongTapFlashCount = 0
    @State private var wrongTapIndices: Set<Int> = []
    @State private var countdownNumber = 3
    @State private var roundProgress: CGFloat = 0
    @StateObject private var audio = StudMatchAudioController()

    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let roundDuration: TimeInterval = 2.0

    var body: some View {
        ZStack {
            CartoonSkyBackground(progress: min(1, CGFloat(score) / 4200))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                StudMatchSceneView(
                    board: board,
                    selected: selected,
                    matchPulseCount: matchPulseCount,
                    wrongTapFlashCount: wrongTapFlashCount,
                    wrongTapIndices: wrongTapIndices
                ) { index in
                    tap(index)
                }
                .ignoresSafeArea()

                moveWindowStatus
                    .padding(.horizontal, 24)
                    .padding(.bottom, 26)
            }

            if roundStartedAt != nil, phase == .playing {
                countdownBadge("\(countdownNumber)")
            }

            if phase == .paused {
                menuOverlay(title: "Paused", subtitle: message, primaryTitle: "Resume", primaryAction: {
                    phase = .playing
                }, secondaryTitle: "Restart", secondaryAction: {
                    reset()
                }, quitAction: {
                    dismiss()
                })
            } else if phase == .gameOver {
                menuOverlay(title: "Game Over", subtitle: "Score \(score)", primaryTitle: "Play Again", primaryAction: {
                    reset()
                }, secondaryTitle: "Reset", secondaryAction: {
                    reset()
                }, quitAction: {
                    dismiss()
                })
            }
        }
        .onAppear {
            audio.prepare()
            audio.setMusicActive(true)
        }
        .onDisappear {
            audio.stopMusic()
        }
        .onChange(of: phase) { _, newPhase in
            audio.setMusicActive(newPhase == .playing)
        }
        .onReceive(timer) { _ in
            tick()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            scorePill(value: score, label: "score")
            scorePill(value: bestScore, label: "best")
            scorePill(value: moves, label: "moves")

            Button {
                if phase == .playing {
                    phase = .paused
                }
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .gameGlass(in: Circle(), darken: 0.2)
            }
            .buttonStyle(PressableStyle(scale: 0.88))
            .accessibilityLabel("Pause")
            .disabled(phase != .playing)
            .opacity(phase == .playing ? 1 : 0.46)
        }
        .padding(.top, 6)
        .padding(.horizontal, 14)
    }

    private func scorePill(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(label == "score" ? BrickColor.gold : BrickColor.primaryText)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(BrickColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .gameGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous), darken: 0.18)
    }

    private var moveWindowStatus: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .gameGlass(in: Capsule(), darken: 0.22)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.24))
                    Capsule()
                        .fill(BrickColor.gold)
                        .frame(width: proxy.size.width * max(0, min(1, roundProgress)))
                }
            }
            .frame(height: 8)
            .opacity(roundStartedAt == nil ? 0.35 : 1)
        }
    }

    private var elapsedRoundTime: TimeInterval {
        guard let roundStartedAt else { return 0 }
        return Date().timeIntervalSince(roundStartedAt)
    }

    private func countdownBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 96, weight: .black))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 8)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.12), value: text)
            .offset(y: -132)
            .allowsHitTesting(false)
    }

    private func menuOverlay(
        title: String,
        subtitle: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondaryAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(BrickColor.gold)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(StudButtonStyle(tint: BrickColor.gold))
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(StudButtonStyle(tint: .white, prominent: false))
                    Button("Quit Game", action: quitAction)
                        .buttonStyle(StudButtonStyle(tint: .white.opacity(0.72), prominent: false))
                }
                .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .gameGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), darken: 0.38)
            .cardAppear(0)
            .padding(.bottom, 104)
        }
    }

    private func tap(_ index: Int) {
        guard phase == .playing, moves > 0, board.indices.contains(index) else { return }
        audio.playClick()

        if selected.contains(index) {
            selected.remove(index)
            message = selected.isEmpty ? "Select 3+ matching bricks" : "\(selected.count) selected"
            return
        }

        if roundStartedAt == nil {
            roundStartedAt = Date()
            roundToken += 1
            countdownNumber = 3
            roundProgress = 1
            selected = [index]
            message = "2 seconds. Go."
            return
        }

        if let first = selected.first, board[first] != board[index] {
            failMove()
        } else {
            selected.insert(index)
            message = "\(selected.count) selected"
        }
    }

    private func tick() {
        guard phase == .playing, roundStartedAt != nil else { return }
        let elapsed = elapsedRoundTime
        roundProgress = CGFloat(1 - min(1, elapsed / roundDuration))
        if elapsed < roundDuration / 3 {
            countdownNumber = 3
        } else if elapsed < roundDuration * 2 / 3 {
            countdownNumber = 2
        } else {
            countdownNumber = 1
        }

        if elapsedRoundTime >= roundDuration {
            resolveMove()
        }
    }

    private func resolveMove() {
        guard roundStartedAt != nil else { return }
        if selected.count >= 3 {
            clearSelection()
        } else {
            failMove()
        }
    }

    private func clearSelection() {
        guard selected.count >= 3, phase == .playing else { return }
        let matched = selected.count
        for item in selected {
            board[item] = Self.randomColor(excluding: board[item])
        }
        score += matched * matched * 10
        bestScore = max(bestScore, score)
        moves -= 1
        selected.removeAll()
        matchPulseCount += 1
        roundStartedAt = nil
        roundProgress = 0
        message = "+\(matched * matched * 10)"
        audio.playClick()

        if moves <= 0 {
            phase = .gameOver
            message = "No moves left"
        }
    }

    private func failMove() {
        guard phase == .playing else { return }
        let failedSelection = selected
        moves -= 1
        selected.removeAll()
        roundStartedAt = nil
        roundProgress = 0
        wrongTapIndices = failedSelection
        wrongTapFlashCount += 1
        message = "Missed. Keep it clean."
        audio.playClick()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        if moves <= 0 {
            phase = .gameOver
            message = "No moves left"
        }
    }

    private func reset() {
        board = Self.makeBoard()
        selected.removeAll()
        score = 0
        moves = 24
        phase = .playing
        message = "Select 3+ matching bricks"
        matchPulseCount = 0
        roundToken = 0
        roundStartedAt = nil
        wrongTapFlashCount = 0
        wrongTapIndices = []
        countdownNumber = 3
        roundProgress = 0
    }

    private static func makeBoard() -> [GameStudColor] {
        (0..<25).map { _ in GameStudColor.allCases.randomElement() ?? .yellow }
    }

    private static func randomColor(excluding color: GameStudColor) -> GameStudColor {
        let options = GameStudColor.allCases.filter { $0 != color }
        return options.randomElement() ?? .yellow
    }
}

private enum StudMatchPhase: Equatable {
    case playing
    case paused
    case gameOver
}

@MainActor
private final class StudMatchAudioController: ObservableObject {
    private var musicPlayer: AVAudioPlayer?
    private var clickPlayer: AVAudioPlayer?

    func prepare() {
        configureSession()
        musicPlayer = makePlayer(named: "lets-go", extension: "mp3", volume: 0.34, loops: -1)
        clickPlayer = makePlayer(named: "brick-click", extension: "wav", volume: 0.82, loops: 0)
    }

    func setMusicActive(_ active: Bool) {
        active ? playMusic() : pauseMusic()
    }

    func playClick() {
        guard let clickPlayer else { return }
        clickPlayer.stop()
        clickPlayer.currentTime = 0
        clickPlayer.play()
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer?.currentTime = 0
    }

    private func playMusic() {
        guard let musicPlayer, !musicPlayer.isPlaying else { return }
        musicPlayer.play()
    }

    private func pauseMusic() {
        musicPlayer?.pause()
    }

    private func configureSession() {
        // AVAudioSession activation can block, so keep it off the main
        // thread (the session API is thread-safe for these calls). Fixes
        // the "AVAudioSession Hang Risk" runtime warnings.
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)
        }
    }

    private func makePlayer(named name: String, extension fileExtension: String, volume: Float, loops: Int) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.numberOfLoops = loops
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }
}

private struct StudMatchSceneView: UIViewRepresentable {
    var board: [GameStudColor]
    var selected: Set<Int>
    var matchPulseCount: Int
    var wrongTapFlashCount: Int
    var wrongTapIndices: Set<Int>
    var onTap: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        var onTap: (Int) -> Void
        var brickNodes: [Int: SCNNode] = [:]
        var boardSignature = ""
        var selectionSignature = ""
        var previousSelected: Set<Int> = []
        var lastPulseCount = 0
        var lastWrongTapFlashCount = 0

        init(onTap: @escaping (Int) -> Void) {
            self.onTap = onTap
        }

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? SCNView else { return }
            let point = recognizer.location(in: view)
            guard let node = view.hitTest(point, options: nil).first?.node else { return }
            var current: SCNNode? = node
            while let item = current {
                if let index = item.value(forKey: "studMatchIndex") as? Int {
                    onTap(index)
                    return
                }
                current = item.parent
            }
        }
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isPlaying = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60

        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 48
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 7.55, 9.05)
        scene.rootNode.addChildNode(cameraNode)

        let target = SCNNode()
        target.position = SCNVector3(0, 0.05, 0)
        scene.rootNode.addChildNode(target)
        let lookAt = SCNLookAtConstraint(target: target)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .omni
        keyLight.light?.intensity = 760
        keyLight.position = SCNVector3(-5, 8, 7)
        scene.rootNode.addChildNode(keyLight)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 650
        scene.rootNode.addChildNode(ambient)

        let root = SCNNode()
        root.name = "studMatchRoot"
        root.eulerAngles.x = 0
        root.position = SCNVector3(0, -0.72, -0.55)
        scene.rootNode.addChildNode(root)

        let pulseRoot = SCNNode()
        pulseRoot.name = "studMatchPulseRoot"
        root.addChildNode(pulseRoot)

        view.scene = scene
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:))))
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onTap = onTap
        guard
            let root = view.scene?.rootNode.childNode(withName: "studMatchRoot", recursively: false),
            let pulseRoot = root.childNode(withName: "studMatchPulseRoot", recursively: false)
        else { return }

        let newBoardSignature = board.map(\.rawValue).joined(separator: "|")
        if context.coordinator.boardSignature != newBoardSignature {
            context.coordinator.boardSignature = newBoardSignature
            context.coordinator.brickNodes.values.forEach { $0.removeFromParentNode() }
            context.coordinator.brickNodes.removeAll()
            context.coordinator.previousSelected = []

            for index in board.indices {
                let node = brickNode(index: index, color: board[index].uiColor)
                context.coordinator.brickNodes[index] = node
                root.addChildNode(node)
            }
        }

        let newSelectionSignature = selected.sorted().map(String.init).joined(separator: "|")
        if context.coordinator.selectionSignature != newSelectionSignature {
            context.coordinator.selectionSignature = newSelectionSignature
            let changedIndices = selected.symmetricDifference(context.coordinator.previousSelected)
            context.coordinator.previousSelected = selected
            for index in changedIndices {
                guard let node = context.coordinator.brickNodes[index] else { continue }
                let row = index / 5
                let col = index % 5
                let pressed = selected.contains(index)
                let targetY: Float = pressed ? -0.1 : 0
                let targetScale = pressed ? SCNVector3(0.96, 0.96, 0.96) : SCNVector3(1, 1, 1)
                let move = SCNAction.move(to: SCNVector3(Float(col - 2) * 0.98, targetY, Float(row - 2) * 0.98), duration: 0.08)
                move.timingMode = .easeOut
                let scale = SCNAction.scale(to: CGFloat(targetScale.x), duration: 0.08)
                scale.timingMode = .easeOut
                node.runAction(.group([move, scale]))
            }
        }

        if context.coordinator.lastPulseCount != matchPulseCount {
            context.coordinator.lastPulseCount = matchPulseCount
            if matchPulseCount > 0 {
                addPulse(to: pulseRoot)
            }
        }

        if context.coordinator.lastWrongTapFlashCount != wrongTapFlashCount {
            context.coordinator.lastWrongTapFlashCount = wrongTapFlashCount
            if wrongTapFlashCount > 0 {
                let nodes = wrongTapIndices.compactMap { context.coordinator.brickNodes[$0] }
                popBack(nodes: nodes)
            }
        }
    }

    private func brickNode(index: Int, color: UIColor) -> SCNNode {
        let row = index / 5
        let col = index % 5
        let node = SCNNode()
        node.position = SCNVector3(Float(col - 2) * 0.98, 0, Float(row - 2) * 0.98)
        node.setValue(index, forKey: "studMatchIndex")

        let outline = SCNBox(width: 0.96, height: 0.44, length: 0.96, chamferRadius: 0.055)
        outline.materials = [outlineMaterial()]
        let outlineNode = SCNNode(geometry: outline)
        outlineNode.position = SCNVector3(0, -0.02, 0)
        node.addChildNode(outlineNode)

        let body = SCNBox(width: 0.88, height: 0.38, length: 0.88, chamferRadius: 0.05)
        body.materials = [material(color)]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.02, 0)
        node.addChildNode(bodyNode)

        for x in [-0.215, 0.215] {
            for z in [-0.215, 0.215] {
                let studOutline = SCNCylinder(radius: 0.155, height: 0.115)
                studOutline.radialSegmentCount = 10
                studOutline.materials = [outlineMaterial()]
                let studOutlineNode = SCNNode(geometry: studOutline)
                studOutlineNode.position = SCNVector3(Float(x), 0.24, Float(z))
                node.addChildNode(studOutlineNode)

                let stud = SCNCylinder(radius: 0.135, height: 0.105)
                stud.radialSegmentCount = 10
                stud.materials = [material(color)]
                let studNode = SCNNode(geometry: stud)
                studNode.position = SCNVector3(Float(x), 0.275, Float(z))
                node.addChildNode(studNode)
            }
        }

        return node
    }

    private func addPulse(to root: SCNNode) {
        let node = SCNNode()
        node.position = SCNVector3(0, 0.2, 0)
        let material = pulseMaterial()
        let size: CGFloat = 5.7
        let thickness: CGFloat = 0.045

        let top = SCNBox(width: size, height: thickness, length: thickness, chamferRadius: 0.01)
        top.materials = [material]
        let bottom = SCNBox(width: size, height: thickness, length: thickness, chamferRadius: 0.01)
        bottom.materials = [material]
        let left = SCNBox(width: thickness, height: thickness, length: size, chamferRadius: 0.01)
        left.materials = [material]
        let right = SCNBox(width: thickness, height: thickness, length: size, chamferRadius: 0.01)
        right.materials = [material]

        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, 0, Float(size / 2))
        let bottomNode = SCNNode(geometry: bottom)
        bottomNode.position = SCNVector3(0, 0, Float(-size / 2))
        let leftNode = SCNNode(geometry: left)
        leftNode.position = SCNVector3(Float(-size / 2), 0, 0)
        let rightNode = SCNNode(geometry: right)
        rightNode.position = SCNVector3(Float(size / 2), 0, 0)

        node.addChildNode(topNode)
        node.addChildNode(bottomNode)
        node.addChildNode(leftNode)
        node.addChildNode(rightNode)
        root.addChildNode(node)

        node.opacity = 0.82
        node.scale = SCNVector3(0.92, 0.92, 0.92)
        let scale = SCNAction.scale(to: 1.18, duration: 0.34)
        scale.timingMode = .easeOut
        let fade = SCNAction.fadeOut(duration: 0.34)
        fade.timingMode = .easeOut
        node.runAction(.sequence([.group([scale, fade]), .removeFromParentNode()]))
    }

    private func popBack(nodes: [SCNNode]) {
        let up = SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 0.06)
        up.timingMode = .easeOut
        let down = SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 0.08)
        down.timingMode = .easeIn
        let scaleUp = SCNAction.scale(to: 1.04, duration: 0.06)
        let scaleBack = SCNAction.scale(to: 1, duration: 0.08)
        for node in nodes {
            node.runAction(.sequence([.group([up, scaleUp]), .group([down, scaleBack])]))
        }
    }

    private func material(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = color
        material.ambient.contents = color
        material.emission.contents = color.withAlphaComponent(0.08)
        material.specular.contents = UIColor.white.withAlphaComponent(0.08)
        material.shininess = 0.18
        return material
    }

    private func outlineMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor(hex: 0x1F2B34)
        material.emission.contents = UIColor(hex: 0x1F2B34)
        return material
    }

    private func pulseMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.86)
        material.emission.contents = UIColor.white.withAlphaComponent(0.86)
        return material
    }
}

// MARK: - Build Sprint

private struct BuildSprintGameView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("buildSprintBestScore") private var bestScore = 0

    @State private var difficulty: BuildSprintDifficulty = .easy
    @State private var mode: BuildSprintMode = .ownTime
    @State private var phase: BuildSprintPhase = .setup
    @State private var pausedFrom: BuildSprintPhase = .setup
    @State private var target: [BuildSprintTileColor] = []
    @State private var answer: [BuildSprintTileColor?] = []
    @State private var roundColors: [BuildSprintTileColor] = [.blue, .yellow]
    @State private var selectedColor: BuildSprintTileColor = .blue
    @State private var score = 0
    @State private var round = 1
    @State private var totalCorrect = 0
    @State private var lastCorrect = 0
    @State private var lastRoundScore = 0
    @State private var memorizeStartedAt: Date?
    @State private var memorizeProgress: CGFloat = 1
    @StateObject private var audio = BuildSprintAudioController()

    private let totalRounds = 10
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2B2B2F), Color(hex: 0x19191C)],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                content
                    .padding(.horizontal, 22)

                Spacer(minLength: 0)
            }

            if phase == .paused {
                menuOverlay(
                    title: "Paused",
                    subtitle: "Round \(round) of \(totalRounds)",
                    primaryTitle: "Resume",
                    primaryAction: { phase = pausedFrom },
                    secondaryTitle: "Restart",
                    secondaryAction: { resetToSetup() },
                    quitAction: { dismiss() }
                )
            } else if phase == .gameOver {
                menuOverlay(
                    title: "Game Complete",
                    subtitle: "Score \(score) • \(averageAccuracy)% average",
                    primaryTitle: "Play Again",
                    primaryAction: { resetToSetup() },
                    secondaryTitle: "Restart",
                    secondaryAction: { resetToSetup() },
                    quitAction: { dismiss() }
                )
            }
        }
        .onAppear {
            audio.prepare()
        }
        .onDisappear {
            audio.stopMusic()
        }
        .onChange(of: phase) { _, newPhase in
            audio.setMusicActive(newPhase != .setup && newPhase != .paused && newPhase != .gameOver)
        }
        .onReceive(timer) { _ in
            tick()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .setup:
            setupView
        case .memorize:
            memorizeView
        case .build:
            buildView
        case .review:
            reviewView
        case .paused, .gameOver:
            EmptyView()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            scorePill(value: score, label: "score")
            scorePill(value: bestScore, label: "best")
            scorePill(value: round, label: "round")

            Button {
                guard phase != .setup, phase != .paused, phase != .gameOver else { return }
                pausedFrom = phase
                phase = .paused
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .gameGlass(in: Circle(), darken: 0.2)
            }
            .buttonStyle(PressableStyle(scale: 0.88))
            .accessibilityLabel("Pause")
            .disabled(phase == .setup || phase == .paused || phase == .gameOver)
            .opacity(phase == .setup || phase == .gameOver ? 0.46 : 1)
        }
        .padding(.top, 6)
        .padding(.horizontal, 14)
    }

    private func scorePill(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(label == "score" ? BrickColor.gold : BrickColor.primaryText)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(BrickColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .gameGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous), darken: 0.18)
    }

    private var setupView: some View {
        VStack(spacing: 18) {
            Image(systemName: "timer")
                .font(.system(size: 54, weight: .black))
                .foregroundStyle(BrickColor.gold)
            Text("Build Sprint")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(.white)
            Text("Memorise the board, then rebuild it from memory.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
                .multilineTextAlignment(.center)

            optionSection(title: "Complexity") {
                ForEach(BuildSprintDifficulty.allCases, id: \.self) { item in
                    choiceButton(item.title, isSelected: difficulty == item) {
                        difficulty = item
                        selectedColor = pickerColors[0]
                    }
                }
            }

            optionSection(title: "Game Type") {
                ForEach(BuildSprintMode.allCases, id: \.self) { item in
                    choiceButton(item.title, isSelected: mode == item) {
                        mode = item
                    }
                }
            }

            Button("Start Game") {
                startGame()
            }
            .buttonStyle(StudButtonStyle(tint: BrickColor.gold))
            .padding(.top, 6)
        }
        .padding(22)
        .gameGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), darken: 0.3)
        .cardAppear(0)
    }

    private func optionSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.72))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                content()
            }
        }
    }

    private func choiceButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BrickGradient.sunrise)
                    }
                }
                .gameGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous), darken: isSelected ? 0 : 0.2)
                .brickGlow(BrickColor.amber, radius: isSelected ? 10 : 0, strength: isSelected ? 0.4 : 0)
        }
        .buttonStyle(PressableStyle())
    }

    private var memorizeView: some View {
        VStack(spacing: 18) {
            Text(mode == .quickSmart ? "Memorise" : "Take a look")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)

            BuildSprintBoard(
                colors: target.map(Optional.some),
                gridSize: difficulty.gridSize,
                isInteractive: false,
                tap: { _ in }
            )
            .frame(maxWidth: boardSize, maxHeight: boardSize)

            if mode == .quickSmart {
                VStack(spacing: 8) {
                    Text("\(max(0, Int(ceil(remainingMemorizeTime))))")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(BrickColor.gold)
                    progressBar(progress: memorizeProgress)
                }
            } else {
                Button("Hide Pattern") {
                    beginBuild()
                }
                .buttonStyle(StudButtonStyle(tint: BrickColor.gold))
            }
        }
    }

    private var buildView: some View {
        VStack(spacing: 18) {
            Text("Rebuild round \(round)")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)

            BuildSprintBoard(
                colors: answer,
                gridSize: difficulty.gridSize,
                isInteractive: true,
                tap: placeTile
            )
            .frame(maxWidth: boardSize, maxHeight: boardSize)

            colorPicker

            Button("Check Board") {
                checkBoard()
            }
            .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen))
            .disabled(answer.contains(where: { $0 == nil }))
            .opacity(answer.contains(where: { $0 == nil }) ? 0.55 : 1)
        }
    }

    private var reviewView: some View {
        VStack(spacing: 14) {
            reviewBoard(title: "Your Board", colors: answer)

            VStack(spacing: 4) {
                Text("\(lastCorrect) / \(target.count) right")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white)
                Text("+\(lastRoundScore) points")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(BrickColor.gold)
            }
            .padding(.vertical, 4)

            reviewBoard(title: "True Board", colors: target.map(Optional.some))

            Button(round >= totalRounds ? "Finish Game" : "Next Round") {
                advanceFromReview()
            }
            .buttonStyle(StudButtonStyle(tint: BrickColor.gold))
            .padding(.top, 4)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: phase)
    }

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach(pickerColors, id: \.self) { color in
                Button {
                    selectedColor = color
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 42, height: 42)
                        .overlay(Circle().strokeBorder(selectedColor == color ? .white : .black.opacity(0.22), lineWidth: selectedColor == color ? 4 : 2))
                        .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
                        .scaleEffect(selectedColor == color ? 1.12 : 1)
                        .animation(BrickMotion.bouncy, value: selectedColor)
                }
                .buttonStyle(PressableStyle(scale: 0.85))
            }
        }
        .padding(.vertical, 4)
    }

    private func reviewBoard(title: String, colors: [BuildSprintTileColor?]) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.78))
            BuildSprintBoard(
                colors: colors,
                gridSize: difficulty.gridSize,
                isInteractive: false,
                tap: { _ in }
            )
            .frame(maxWidth: reviewBoardSize, maxHeight: reviewBoardSize)
        }
    }

    private var boardSize: CGFloat {
        difficulty.gridSize == 3 ? 330 : 348
    }

    private var reviewBoardSize: CGFloat {
        difficulty.gridSize == 3 ? 208 : 226
    }

    private var pickerColors: [BuildSprintTileColor] {
        difficulty == .easy ? BuildSprintTileColor.allCases : difficulty.colors
    }

    private var remainingMemorizeTime: TimeInterval {
        guard let memorizeStartedAt else { return mode.memorySeconds(for: difficulty) }
        return max(0, mode.memorySeconds(for: difficulty) - Date().timeIntervalSince(memorizeStartedAt))
    }

    private var averageAccuracy: Int {
        guard round > 1 || phase == .gameOver else { return 0 }
        let completedBoards = phase == .gameOver ? totalRounds : max(1, round - 1)
        let possible = completedBoards * difficulty.tileCount
        return possible == 0 ? 0 : Int((Double(totalCorrect) / Double(possible) * 100).rounded())
    }

    private func progressBar(progress: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.24))
                Capsule()
                    .fill(BrickColor.gold)
                    .frame(width: proxy.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 8)
        .frame(maxWidth: 320)
    }

    private func menuOverlay(
        title: String,
        subtitle: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondaryAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(BrickColor.gold)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(StudButtonStyle(tint: BrickColor.gold))
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(StudButtonStyle(tint: .white, prominent: false))
                    Button("Quit Game", action: quitAction)
                        .buttonStyle(StudButtonStyle(tint: .white.opacity(0.72), prominent: false))
                }
                .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .gameGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), darken: 0.38)
            .cardAppear(0)
            .padding(.bottom, 104)
        }
    }

    private func startGame() {
        score = 0
        round = 1
        totalCorrect = 0
        lastCorrect = 0
        lastRoundScore = 0
        selectedColor = pickerColors[0]
        newPattern()
    }

    private func newPattern() {
        roundColors = difficulty.patternColors()
        selectedColor = pickerColors.contains(selectedColor) ? selectedColor : pickerColors[0]
        target = (0..<difficulty.tileCount).map { _ in roundColors.randomElement() ?? roundColors[0] }
        answer = Array(repeating: nil, count: difficulty.tileCount)
        memorizeProgress = 1
        if mode == .quickSmart {
            memorizeStartedAt = Date()
        } else {
            memorizeStartedAt = nil
        }
        phase = .memorize
    }

    private func beginBuild() {
        memorizeStartedAt = nil
        memorizeProgress = 0
        phase = .build
    }

    private func tick() {
        guard phase == .memorize, mode == .quickSmart, let memorizeStartedAt else { return }
        let duration = mode.memorySeconds(for: difficulty)
        let elapsed = Date().timeIntervalSince(memorizeStartedAt)
        memorizeProgress = CGFloat(1 - min(1, elapsed / duration))
        if elapsed >= duration {
            beginBuild()
        }
    }

    private func placeTile(_ index: Int) {
        guard phase == .build, answer.indices.contains(index) else { return }
        answer[index] = selectedColor
        let placed = answer.compactMap { $0 }.count
        audio.playBeep(step: placed)
    }

    private func checkBoard() {
        lastCorrect = answer.enumerated().filter { index, color in color == target[index] }.count
        totalCorrect += lastCorrect
        lastRoundScore = lastCorrect * 30 + (lastCorrect == target.count ? target.count * 15 : 0)
        score += lastRoundScore
        bestScore = max(bestScore, score)
        phase = .review
    }

    private func advanceFromReview() {
        if round >= totalRounds {
            phase = .gameOver
        } else {
            round += 1
            newPattern()
        }
    }

    private func resetToSetup() {
        score = 0
        round = 1
        totalCorrect = 0
        lastCorrect = 0
        lastRoundScore = 0
        target = []
        answer = []
        roundColors = difficulty.patternColors()
        selectedColor = pickerColors[0]
        memorizeStartedAt = nil
        memorizeProgress = 1
        phase = .setup
        pausedFrom = .setup
    }
}

private struct BuildSprintBoard: View {
    var colors: [BuildSprintTileColor?]
    var gridSize: Int
    var isInteractive: Bool
    var tap: (Int) -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: gridSize)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<colors.count, id: \.self) { index in
                Button {
                    tap(index)
                } label: {
                    BuildSprintTile(color: colors[index])
                }
                .buttonStyle(.plain)
                .disabled(!isInteractive)
            }
        }
        .padding(8)
        .gameGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), darken: 0.18)
    }
}

private struct BuildSprintTile: View {
    var color: BuildSprintTileColor?

    var body: some View {
        let tileColor = color?.color ?? .black.opacity(0.28)
        RoundedRectangle(cornerRadius: 8)
            .fill(tileColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.black.opacity(0.24), lineWidth: 3)
            }
            .overlay {
                Image("BIABLogoStamp")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color?.logoColor ?? .white.opacity(0.24))
                    .padding(6)
                    .opacity(color == nil ? 0.3 : 0.5)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.white.opacity(color == nil ? 0.04 : 0.16))
                    .frame(height: 8)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
            }
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
    }
}

private enum BuildSprintPhase: Equatable {
    case setup
    case memorize
    case build
    case review
    case paused
    case gameOver
}

private enum BuildSprintMode: CaseIterable {
    case quickSmart
    case ownTime

    var title: String {
        switch self {
        case .quickSmart: return "Quick Smart"
        case .ownTime: return "In Your Own Time"
        }
    }

    func memorySeconds(for difficulty: BuildSprintDifficulty) -> TimeInterval {
        switch self {
        case .ownTime: return .infinity
        case .quickSmart: return difficulty.gridSize == 3 ? 10 : 20
        }
    }
}

private enum BuildSprintDifficulty: CaseIterable {
    case easy
    case medium
    case hard
    case extraHard

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .extraHard: return "Extra Hard"
        }
    }

    var gridSize: Int {
        switch self {
        case .easy, .medium: return 3
        case .hard, .extraHard: return 4
        }
    }

    var tileCount: Int {
        gridSize * gridSize
    }

    var colors: [BuildSprintTileColor] {
        switch self {
        case .easy: return [.blue, .yellow]
        case .medium, .hard: return [.blue, .yellow, .red, .green]
        case .extraHard: return BuildSprintTileColor.allCases
        }
    }

    func patternColors() -> [BuildSprintTileColor] {
        switch self {
        case .easy:
            return Array(BuildSprintTileColor.allCases.shuffled().prefix(2))
        case .medium, .hard, .extraHard:
            return colors
        }
    }
}

private enum BuildSprintTileColor: String, CaseIterable {
    case blue
    case yellow
    case red
    case green
    case white
    case orange

    var color: Color {
        switch self {
        case .blue: return Color(hex: 0x0055BF)
        case .yellow: return Color(hex: 0xFFD500)
        case .red: return Color(hex: 0xD62828)
        case .green: return Color(hex: 0x009B48)
        case .white: return Color(hex: 0xF2F3F2)
        case .orange: return Color(hex: 0xF57C00)
        }
    }

    var logoColor: Color {
        switch self {
        case .blue: return Color(hex: 0x78B8FF)
        case .yellow: return Color(hex: 0xFFF29A)
        case .red: return Color(hex: 0xFF8888)
        case .green: return Color(hex: 0x69E69D)
        case .white: return .white
        case .orange: return Color(hex: 0xFFBD75)
        }
    }
}

@MainActor
private final class BuildSprintAudioController: ObservableObject {
    private var musicPlayer: AVAudioPlayer?
    private let engine = AVAudioEngine()
    private let beepPlayer = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100

    func prepare() {
        configureSession()
        musicPlayer = makePlayer(named: "block-partyv2", extension: "mp3", volume: 0.3, loops: -1)
        if beepPlayer.engine == nil {
            engine.attach(beepPlayer)
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
            engine.connect(beepPlayer, to: engine.mainMixerNode, format: format)
        }
        if !engine.isRunning {
            try? engine.start()
        }
    }

    func setMusicActive(_ active: Bool) {
        active ? playMusic() : pauseMusic()
    }

    func playBeep(step: Int) {
        if !engine.isRunning {
            try? engine.start()
        }
        let frequency = min(1_150, 360 + step * 48)
        guard let buffer = makeBeepBuffer(frequency: Double(frequency)) else { return }
        beepPlayer.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !beepPlayer.isPlaying {
            beepPlayer.play()
        }
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer?.currentTime = 0
        beepPlayer.stop()
        engine.stop()
    }

    private func playMusic() {
        guard let musicPlayer, !musicPlayer.isPlaying else { return }
        musicPlayer.play()
    }

    private func pauseMusic() {
        musicPlayer?.pause()
    }

    private func makeBeepBuffer(frequency: Double) -> AVAudioPCMBuffer? {
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * 0.075))
        else { return nil }
        buffer.frameLength = buffer.frameCapacity
        guard let data = buffer.floatChannelData?[0] else { return buffer }
        for frame in 0..<Int(buffer.frameLength) {
            let progress = Double(frame) / Double(buffer.frameLength)
            let envelope = sin(progress * .pi)
            data[frame] = Float(sin(2 * .pi * frequency * Double(frame) / sampleRate) * envelope * 0.22)
        }
        return buffer
    }

    private func configureSession() {
        // AVAudioSession activation can block, so keep it off the main
        // thread (the session API is thread-safe for these calls). Fixes
        // the "AVAudioSession Hang Risk" runtime warnings.
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)
        }
    }

    private func makePlayer(named name: String, extension fileExtension: String, volume: Float, loops: Int) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.numberOfLoops = loops
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }
}

// MARK: - Reveal the Stadium

private struct RevealTheStadiumGameView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("revealStadiumBestScore") private var bestScore = 0

    @State private var stadium = StadiumQuestion.samples[0]
    @State private var options: [String] = []
    @State private var revealed: Set<Int> = []
    @State private var deck: [StadiumQuestion] = []
    @State private var round = 1
    @State private var score = 0
    @State private var combo = 0
    @State private var message = "Reveal fast. Guess faster."
    @State private var phase: StadiumRevealPhase = .ready
    @State private var roundResult: StadiumRoundResult?
    @State private var timeRemaining: TimeInterval = 24

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 6)
    private let totalRounds = 10
    private let roundDuration: TimeInterval = 24
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x151519), Color(hex: 0x25252B)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                content
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }

            if phase == .ready {
                startOverlay
            } else if phase == .paused {
                menuOverlay(
                    title: "Paused",
                    subtitle: "Round \(round) of \(totalRounds)",
                    primaryTitle: "Resume",
                    primaryAction: { phase = .playing },
                    secondaryTitle: "Restart",
                    secondaryAction: { startGame() },
                    quitAction: { dismiss() }
                )
            } else if phase == .gameOver {
                menuOverlay(
                    title: "Game Complete",
                    subtitle: "Score \(score) - Best \(bestScore)",
                    primaryTitle: "Play Again",
                    primaryAction: { startGame() },
                    secondaryTitle: "Reset",
                    secondaryAction: { startGame() },
                    quitAction: { dismiss() }
                )
            }
        }
        .onAppear {
            if deck.isEmpty {
                prepareRound()
                phase = .ready
            }
        }
        .onReceive(timer) { _ in
            tick()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            scorePill(value: score, label: "score")
            scorePill(value: bestScore, label: "best")
            scorePill(value: round, label: "round")
            scorePill(value: Int(ceil(timeRemaining)), label: "time")

            Button {
                if phase == .playing {
                    phase = .paused
                }
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .gameGlass(in: Circle(), darken: 0.2)
            }
            .buttonStyle(PressableStyle(scale: 0.88))
            .accessibilityLabel("Pause")
            .disabled(phase != .playing)
            .opacity(phase == .playing ? 1 : 0.46)
        }
        .padding(.top, 6)
        .padding(.horizontal, 14)
    }

    private func scorePill(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(label == "score" || label == "time" ? BrickColor.gold : BrickColor.primaryText)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(BrickColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .gameGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous), darken: 0.22)
    }

    @ViewBuilder
    private var content: some View {
        if phase == .roundResult, let roundResult {
            resultView(roundResult)
                .cardAppear(0)
        } else {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Reveal Stadium")
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BrickColor.gold)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    StadiumArtwork(stadium: stadium, hidePrintedName: true)
                        .frame(height: 268)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.18), lineWidth: 1))

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<36, id: \.self) { index in
                            Button {
                                reveal(index)
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(revealed.contains(index) || phase != .playing ? .clear : tileColor(for: index))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        if !revealed.contains(index), phase == .playing {
                                            Image("BIABLogoStamp")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundStyle(BrickColor.gold.opacity(0.52))
                                                .padding(9)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(phase != .playing || revealed.contains(index))
                        }
                    }
                    .padding(5)
                }

                ProgressView(value: timeRemaining, total: roundDuration)
                    .tint(timeRemaining < 7 ? .red : BrickColor.gold)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            guess(option)
                        } label: {
                            Text(option)
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .padding(.horizontal, 8)
                                .gameGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous), darken: 0.24)
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(phase != .playing)
                    }
                }
            }
        }
    }

    private var startOverlay: some View {
        menuOverlay(
            title: "Reveal Stadium",
            subtitle: "10 stadiums. Less tiles and faster guesses score more.",
            primaryTitle: "Start Game",
            primaryAction: { startGame() },
            secondaryTitle: "Reset",
            secondaryAction: { startGame() },
            quitAction: { dismiss() }
        )
    }

    private func resultView(_ result: StadiumRoundResult) -> some View {
        VStack(spacing: 16) {
            StadiumArtwork(stadium: stadium, hidePrintedName: true)
                .frame(height: 245)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.18), lineWidth: 1))

            VStack(spacing: 8) {
                Text(result.correct ? "Correct" : "Round Lost")
                    .font(.system(size: 33, weight: .black))
                    .foregroundStyle(result.correct ? BrickColor.gold : .red)
                Text(stadium.name)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(result.summary)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(BrickColor.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button(round == totalRounds ? "Finish Game" : "Next Stadium") {
                advanceRound()
            }
            .buttonStyle(StudButtonStyle(tint: BrickColor.gold))
            .frame(maxWidth: 260)
        }
    }

    private func menuOverlay(
        title: String,
        subtitle: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondaryAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(BrickColor.gold)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(StudButtonStyle(tint: BrickColor.gold))
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(StudButtonStyle(tint: .white, prominent: false))
                    Button("Quit Game", action: quitAction)
                        .buttonStyle(StudButtonStyle(tint: .white.opacity(0.72), prominent: false))
                }
                .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 330)
            .gameGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), darken: 0.4)
            .cardAppear(0)
            .padding(.horizontal, 24)
        }
    }

    private func reveal(_ index: Int) {
        guard phase == .playing, !revealed.contains(index) else { return }
        revealed.insert(index)
        timeRemaining = max(0, timeRemaining - 0.35)
        message = "\(revealed.count) tile\(revealed.count == 1 ? "" : "s") revealed. Be decisive."
    }

    private func guess(_ option: String) {
        if option == stadium.name {
            let revealBonus = max(0, 360 - revealed.count * 9)
            let timeBonus = Int(timeRemaining.rounded()) * 18
            let comboBonus = combo * 45
            let roundScore = 280 + revealBonus + timeBonus + comboBonus
            combo += 1
            score += roundScore
            bestScore = max(bestScore, score)
            roundResult = StadiumRoundResult(correct: true, summary: "+\(roundScore) points - \(revealed.count) tiles - \(Int(ceil(timeRemaining)))s left")
            phase = .roundResult
        } else {
            combo = 0
            timeRemaining = max(0, timeRemaining - 4)
            message = "Wrong guess. 4 second penalty."
            if timeRemaining <= 0 {
                failRound()
            }
        }
    }

    private func startGame() {
        deck = Array(StadiumQuestion.samples.shuffled().prefix(totalRounds))
        round = 1
        score = 0
        combo = 0
        prepareRound()
        phase = .playing
    }

    private func prepareRound() {
        if deck.isEmpty {
            deck = Array(StadiumQuestion.samples.shuffled().prefix(totalRounds))
        }
        stadium = deck[min(round - 1, deck.count - 1)]
        options = StadiumQuestion.options(for: stadium)
        revealed.removeAll()
        timeRemaining = roundDuration
        roundResult = nil
        message = "Reveal fast. Guess faster."
    }

    private func advanceRound() {
        if round >= totalRounds {
            bestScore = max(bestScore, score)
            phase = .gameOver
        } else {
            round += 1
            prepareRound()
            phase = .playing
        }
    }

    private func failRound() {
        combo = 0
        roundResult = StadiumRoundResult(correct: false, summary: "No points this round. The clock wins.")
        phase = .roundResult
    }

    private func tick() {
        guard phase == .playing else { return }
        timeRemaining = max(0, timeRemaining - 0.1)
        if timeRemaining <= 0 {
            failRound()
        } else if timeRemaining < 7 {
            message = "Clock is running out."
        }
    }

    private func tileColor(for index: Int) -> Color {
        let palette: [Color] = [
            Color(hex: 0x2F3542),
            Color(hex: 0x363B48),
            Color(hex: 0x414858)
        ]
        return palette[index % palette.count]
    }
}

private enum StadiumRevealPhase {
    case ready
    case playing
    case paused
    case roundResult
    case gameOver
}

private struct StadiumRoundResult {
    var correct: Bool
    var summary: String
}

private struct StadiumQuestion: Hashable {
    var name: String
    var assetName: String

    static let samples: [StadiumQuestion] = [
        .init(name: "1st Cloud Stadium", assetName: "Stadium_1st_Cloud_Stadium"),
        .init(name: "Allianz Stadium", assetName: "Stadium_Allianz_Stadium"),
        .init(name: "Amex", assetName: "Stadium_Amex"),
        .init(name: "Boleyn Ground", assetName: "Stadium_Boleyn_Ground"),
        .init(name: "Bramall Lane", assetName: "Stadium_Bramall_Lane"),
        .init(name: "Brewery Fields", assetName: "Stadium_Brewery_Fields"),
        .init(name: "Brunton Park", assetName: "Stadium_Brunton_Park"),
        .init(name: "CBS Arena", assetName: "Stadium_CBS_Arena"),
        .init(name: "CBS Arena v2", assetName: "Stadium_CBS_Arena_v2"),
        .init(name: "Chase Stadium", assetName: "Stadium_Chase_Stadium"),
        .init(name: "Craven Cottage", assetName: "Stadium_Craven_Cottage"),
        .init(name: "Easter Road", assetName: "Stadium_Easter_Road"),
        .init(name: "Elland Road", assetName: "Stadium_Elland_Road"),
        .init(name: "Emirates", assetName: "Stadium_Emirates"),
        .init(name: "Exercise Stadium", assetName: "Stadium_Exercise_Stadium"),
        .init(name: "Fratton Park", assetName: "Stadium_Fratton_Park"),
        .init(name: "Go Media", assetName: "Stadium_Go_Media"),
        .init(name: "Goodison Park", assetName: "Stadium_Goodison_Park"),
        .init(name: "Gtech Arena", assetName: "Stadium_Gtech_Arena"),
        .init(name: "Hampden Park", assetName: "Stadium_Hampden_Park"),
        .init(name: "Highbury", assetName: "Stadium_Highbury"),
        .init(name: "Hillsborough", assetName: "Stadium_Hillsborough"),
        .init(name: "Home Park", assetName: "Stadium_Home_Park"),
        .init(name: "John Smith Stadium", assetName: "Stadium_John_Smith_Stadium"),
        .init(name: "Kenilworth Road", assetName: "Stadium_Kenilworth_Road"),
        .init(name: "Levi Stadium", assetName: "Stadium_Levi_Stadium"),
        .init(name: "Lincoln Financial Field", assetName: "Stadium_Lincoln_Financial_Field"),
        .init(name: "Mangata Pay Stadium", assetName: "Stadium_Mangata_Pay_Stadium"),
        .init(name: "Meadow Lane", assetName: "Stadium_Meadow_Lane"),
        .init(name: "Mile High Stadium", assetName: "Stadium_Mile_High_Stadium"),
        .init(name: "Molineux", assetName: "Stadium_Molineux"),
        .init(name: "Oakwell", assetName: "Stadium_Oakwell"),
        .init(name: "Old Trafford", assetName: "Stadium_Old_Trafford"),
        .init(name: "Pittodrie", assetName: "Stadium_Pittodrie"),
        .init(name: "Pride Park", assetName: "Stadium_Pride_Park"),
        .init(name: "Priestfield", assetName: "Stadium_Priestfield"),
        .init(name: "Providence Park", assetName: "Stadium_Providence_Park"),
        .init(name: "Riverside", assetName: "Stadium_Riverside"),
        .init(name: "Selhurst Park", assetName: "Stadium_Selhurst_Park"),
        .init(name: "Soldier Field", assetName: "Stadium_Soldier_Field"),
        .init(name: "St Andrews", assetName: "Stadium_St_Andrews"),
        .init(name: "St James Park", assetName: "Stadium_St_James_Park"),
        .init(name: "St Marys", assetName: "Stadium_St_Marys"),
        .init(name: "Stadium of Light", assetName: "Stadium_Stadium_of_Light"),
        .init(name: "Stamford Bridge", assetName: "Stadium_Stamford_Bridge"),
        .init(name: "Stark Park", assetName: "Stadium_Stark_Park"),
        .init(name: "Steaua Bucharest", assetName: "Stadium_Steaua_Bucharest"),
        .init(name: "STOk Cae Ras", assetName: "Stadium_STOk_Cae_Ras"),
        .init(name: "Sukru Saracoglu", assetName: "Stadium_Sukru_Saracoglu"),
        .init(name: "Swansea.com", assetName: "Stadium_Swansea_com"),
        .init(name: "The City Ground", assetName: "Stadium_The_City_Ground"),
        .init(name: "Totally Wicked", assetName: "Stadium_Totally_Wicked"),
        .init(name: "Tottenham Hotspur Stadium", assetName: "Stadium_Tottenham_Hotspur_Stadium"),
        .init(name: "Twickenham", assetName: "Stadium_Twickenham"),
        .init(name: "Tyne Castle", assetName: "Stadium_Tyne_Castle"),
        .init(name: "Villa Park", assetName: "Stadium_Villa_Park"),
        .init(name: "Wembley", assetName: "Stadium_Wembley"),
        .init(name: "Wembley Stadium", assetName: "Stadium_Wembley_Stadium"),
        .init(name: "White Hart Lane", assetName: "Stadium_White_Hart_Lane")
    ]

    static func options(for answer: StadiumQuestion) -> [String] {
        let wrong = samples.filter { $0.name != answer.name }.shuffled().prefix(5).map(\.name)
        return ([answer.name] + wrong).shuffled()
    }
}

private struct StadiumArtwork: View {
    var stadium: StadiumQuestion
    var hidePrintedName = true

    var body: some View {
        Image(stadium.assetName)
            .resizable()
            .scaledToFill()
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.06), .black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) {
                if hidePrintedName {
                    LinearGradient(
                        colors: [
                            Color(hex: 0x151519).opacity(0.98),
                            Color(hex: 0x151519).opacity(0.88),
                            Color(hex: 0x151519).opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 64)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 7) {
                            Image("BIABLogoStamp")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(BrickColor.gold.opacity(0.72))
                                .frame(width: 22, height: 22)
                            Text("Guess the stadium")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        .padding(.top, 10)
                        .padding(.leading, 10)
                    }
                }
            }
    }
}
