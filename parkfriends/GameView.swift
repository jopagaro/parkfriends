import SwiftUI
import SpriteKit

// MARK: - GameContainer

/// Owns the long-lived objects so SwiftUI body re-renders never recreate them.
@Observable
@MainActor
final class GameContainer {
    let state = GameState()
    let dialogue = DialogueManager()
    let scene: GameScene

    init() {
        // Give the scene a real starting size — resizeFill adjusts it once
        // the SpriteView lays out, but SpriteKit needs a non-zero size up front.
        let s = GameScene(size: CGSize(width: 390, height: 844))
        s.scaleMode = .resizeFill
        scene = s
        // Inject references before didMove(to:) fires.
        s.gameState = state
        s.dialogue = dialogue
    }

    func restart() {
        state.reset()
        dialogue.endConversation()
        scene.restart()
    }
}

// MARK: - GameView

struct GameView: View {
    @State private var g = GameContainer()
    @State private var showTitle = true

    var body: some View {
        ZStack {
            // Game world (always rendered so the scene is alive/preloaded)
            SpriteView(scene: g.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            // In-game overlays — hidden while title is showing
            if !showTitle {
                VStack {
                    HUDView(state: g.state, dialogue: g.dialogue)
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)

                if g.dialogue.activeNPC != nil {
                    DialogueOverlay(dialogue: g.dialogue)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if g.state.shopOpen {
                    ShopView(state: g.state) { g.state.shopOpen = false }
                        .transition(.opacity)
                }

                if g.state.isGameOver {
                    GameOverView(onRestart: {
                        g.restart()
                        withAnimation { showTitle = true }
                    })
                }
            }

            // Title screen overlay
            if showTitle {
                TitleView(hasSave: g.state.hasSave) { fresh in
                    if fresh { g.state.reset() } else { g.state.load() }
                    g.scene.restart()
                    withAnimation(.easeInOut(duration: 0.55)) { showTitle = false }
                }
                .transition(.opacity)
            }
        }
        #if os(iOS)
        .statusBarHidden(true)
        #endif
        .animation(.easeInOut(duration: 0.2), value: g.dialogue.activeNPC)
        .animation(.easeInOut(duration: 0.25), value: g.state.shopOpen)
    }
}

// MARK: - HUD

struct HUDView: View {
    let state: GameState
    let dialogue: DialogueManager

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Party panel
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(state.party.enumerated()), id: \.element.id) { idx, member in
                    let isActive = idx == state.activeIndex
                    HStack(spacing: 5) {
                        Text(member.species.emoji)
                            .font(.system(size: 18))
                            .opacity(isActive ? 1.0 : 0.40)
                            .scaleEffect(isActive ? 1.10 : 1.0)
                            .animation(.spring(duration: 0.2), value: state.activeIndex)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Lv\(member.level)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isActive ? Color.yellow : Color.secondary)
                                HPBar(hp: member.hp, maxHP: member.maxHP)
                                    .frame(width: 60, height: 6)
                            }
                            // EXP bar
                            ExpBar(exp: member.exp, expToNext: member.expToNext)
                                .frame(width: 68, height: 3)
                                .opacity(isActive ? 1.0 : 0.35)
                        }
                    }
                }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            Spacer()

            // Score + zone + inventory
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 8) {
                    Text(state.currentZone.displayTitle)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("⭐️ \(state.score)")
                    Text("🪙 \(state.coins)")
                    Text("💀 \(state.enemiesDefeated)")
                }
                .font(.headline.monospacedDigit())
                InventoryStrip(inventory: state.inventory)
                // Quack side-quest tracker
                QuackQuestView(clues: state.quackClues)
                if !dialogue.modelAvailable {
                    Text("🤖 offline mode")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct HPBar: View {
    let hp: Int
    let maxHP: Int

    var body: some View {
        GeometryReader { geo in
            let frac = maxHP > 0 ? CGFloat(hp) / CGFloat(maxHP) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.3))
                Capsule()
                    .fill(barColor(frac))
                    .frame(width: geo.size.width * max(frac, 0))
                    .animation(.easeInOut(duration: 0.3), value: frac)
            }
        }
    }

    private func barColor(_ frac: CGFloat) -> Color {
        if frac > 0.5 { return .green }
        if frac > 0.2 { return .yellow }
        return .red
    }
}

struct ExpBar: View {
    let exp: Int
    let expToNext: Int

    var body: some View {
        GeometryReader { geo in
            let frac = expToNext > 0 ? CGFloat(exp) / CGFloat(expToNext) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(Color.blue.opacity(0.80))
                    .frame(width: geo.size.width * max(min(frac, 1), 0))
                    .animation(.easeInOut(duration: 0.4), value: frac)
            }
        }
    }
}

struct InventoryStrip: View {
    let inventory: [ItemKind: Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ItemKind.allCases, id: \.self) { kind in
                if let count = inventory[kind], count > 0 {
                    HStack(spacing: 2) {
                        Text(kind.emoji)
                        Text("×\(count)")
                            .font(.caption.monospacedDigit())
                    }
                }
            }
            if inventory.isEmpty {
                Text("bag empty")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Quack Quest Tracker

struct QuackQuestView: View {
    let clues: Set<QuackClue>

    private let storyClues: [QuackClue] = [
        .visitedNorthPond,
        .foundFeather,
        .childSawChase,
        .joggerSawCity,
        .raccoonDroppedTag
    ]

    var body: some View {
        if clues.contains(.quackRescued) {
            HStack(spacing: 4) {
                Text("🦆 Quack: RESCUED!")
                    .font(.caption.bold())
                    .foregroundStyle(Color.yellow)
            }
        } else if !clues.isEmpty {
            HStack(spacing: 3) {
                Text("🦆")
                    .font(.caption)
                ForEach(storyClues, id: \.self) { clue in
                    Circle()
                        .fill(clues.contains(clue) ? Color.yellow : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
                Text("\(clues.subtracting([.quackRescued]).count)/5")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        // No clues yet — don't show the tracker (keeps HUD clean)
    }
}

// MARK: - Dialogue overlay

struct DialogueOverlay: View {
    let dialogue: DialogueManager
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(dialogue.activeNPC?.emoji ?? "")
                        .font(.system(size: 28))
                    Text(dialogue.activeNPC?.displayName ?? "")
                        .font(.headline)
                    Spacer()
                    Button {
                        dialogue.endConversation()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Transcript
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(dialogue.lines) { line in
                                DialogueLineView(line: line, npc: dialogue.activeNPC)
                                    .id(line.id)
                            }
                            if dialogue.isResponding {
                                HStack(spacing: 4) {
                                    ProgressView().controlSize(.mini)
                                    Text("thinking…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                    .onChange(of: dialogue.lines.count) { _, _ in
                        if let last = dialogue.lines.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                // Input row
                HStack {
                    TextField("Say something…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .focused($focused)
                        .onSubmit(sendMessage)
                    Button("Send", action: sendMessage)
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                  || dialogue.isResponding)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding()
        }
    }

    private func sendMessage() {
        let msg = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        draft = ""
        Task { await dialogue.send(msg) }
    }
}

struct DialogueLineView: View {
    let line: DialogueManager.Line
    let npc: NPCKind?

    var body: some View {
        let isPlayer = line.speaker == "You"
        HStack(alignment: .top, spacing: 6) {
            if !isPlayer {
                Text(npc?.emoji ?? "🧑")
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(line.speaker)
                    .font(.caption.bold())
                    .foregroundStyle(isPlayer ? Color.blue : Color.orange)
                Text(line.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Title Screen

struct TitleView: View {
    let hasSave: Bool
    let onStart: (_ fresh: Bool) -> Void

    var body: some View {
        ZStack {
            // Dark park gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.16, blue: 0.05),
                    Color(red: 0.02, green: 0.08, blue: 0.02)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Animated bouncing characters
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    HStack(spacing: 22) {
                        ForEach(Array(Species.allCases.enumerated()), id: \.element) { i, s in
                            VStack(spacing: 5) {
                                Text(s.emoji)
                                    .font(.system(size: 54))
                                    .offset(y: sin(t * 1.9 + Double(i) * 0.9) * 9)
                                Text(s.displayName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.45))
                            }
                        }
                    }
                }
                .padding(.bottom, 30)

                // Game logo
                VStack(spacing: 2) {
                    Text("PARK")
                        .font(.system(size: 70, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.52, green: 1.0, blue: 0.42),
                                         Color(red: 0.30, green: 0.85, blue: 0.30)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    Text("FRIENDS")
                        .font(.system(size: 70, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color(red: 0.3, green: 0.8, blue: 0.3, opacity: 0.45), radius: 24)
                .padding(.bottom, 10)

                Text("An EarthBound-style park adventure")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.32))
                    .padding(.bottom, 44)

                // Action buttons
                VStack(spacing: 13) {
                    if hasSave {
                        Button("▶  Continue") { onStart(false) }
                            .buttonStyle(TitleButtonStyle(accent: true))
                        Button("✦  New Game") { onStart(true) }
                            .buttonStyle(TitleButtonStyle(accent: false))
                    } else {
                        Button("▶  Start Adventure") { onStart(true) }
                            .buttonStyle(TitleButtonStyle(accent: true))
                    }
                }

                Spacer()

                Text("🌳  Walk  ·  Talk  ·  Battle  🌳")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.18))
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 36)
        }
    }
}

struct TitleButtonStyle: ButtonStyle {
    let accent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .foregroundStyle(accent ? Color.black : Color.white)
            .frame(width: 240, height: 52)
            .background(
                accent
                    ? Color(red: 0.52, green: 0.95, blue: 0.42)
                    : Color.white.opacity(0.10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accent ? Color.clear : Color.white.opacity(0.22), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Item Shop

struct ShopView: View {
    let state: GameState
    let onClose: () -> Void

    private static let forSale: [ItemKind] = ItemKind.allCases.filter { $0.buyPrice != nil }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Text("🏪")
                        .font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Corner Store")
                            .font(.headline.bold())
                        Text("Open late. No refunds. We don't ask questions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("🪙 \(state.coins)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(Color.yellow)
                        Text("your coins")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Self.forSale, id: \.self) { kind in
                            ShopItemRow(kind: kind, state: state)
                        }
                    }
                    .padding(12)
                }
            }
            .frame(maxWidth: 540, maxHeight: 480)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .shadow(radius: 24)
            .padding(28)
        }
    }
}

struct ShopItemRow: View {
    let kind: ItemKind
    let state: GameState

    private var price: Int { kind.buyPrice ?? 0 }
    private var canAfford: Bool { state.coins >= price }
    private var owned: Int { state.inventory[kind] ?? 0 }

    var body: some View {
        HStack(spacing: 10) {
            Text(kind.emoji)
                .font(.title2)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName)
                    .font(.subheadline.bold())
                Text(kind.shopDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("🪙\(price)")
                    .font(.subheadline.bold())
                    .foregroundStyle(canAfford ? Color.primary : Color.red)
                if owned > 0 {
                    Text("have ×\(owned)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                guard canAfford else { return }
                state.coins -= price
                state.inventory[kind, default: 0] += 1
                state.save()
            } label: {
                Text("Buy")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(canAfford ? Color.green.opacity(0.75) : Color.gray.opacity(0.25))
                    .foregroundStyle(canAfford ? .white : .secondary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Game Over

struct GameOverView: View {
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("💤")
                    .font(.system(size: 60))
                Text("The park friends need a rest!")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Button("Try again", action: onRestart)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(32)
        }
    }
}

#Preview {
    GameView()
}
