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

    var body: some View {
        ZStack {
            SpriteView(scene: g.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

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

            if g.state.isGameOver {
                GameOverView(onRestart: g.restart)
            }
        }
        #if os(iOS)
        .statusBarHidden(true)
        #endif
        .animation(.easeInOut(duration: 0.2), value: g.dialogue.activeNPC)
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
