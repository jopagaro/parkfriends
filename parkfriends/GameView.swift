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

                if g.dialogue.activeNPC != nil || g.dialogue.activeTitle != nil {
                    DialogueOverlay(dialogue: g.dialogue)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if g.state.shopOpen {
                    ShopView(state: g.state) { g.state.shopOpen = false }
                        .transition(.opacity)
                }

                if g.state.statsOpen {
                    StatsView(state: g.state) { g.state.statsOpen = false }
                        .transition(.opacity)
                }

                if g.state.isPaused {
                    PauseMenuView(state: g.state)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                if g.state.isGameOver {
                    GameOverView(onRestart: {
                        g.restart()
                        withAnimation { showTitle = true }
                    })
                }

                // Victory: Quack rescued + all 3 bosses beaten
                let allBossesBeaten = [EnemyKind.grandGooseGerald, .officerGrumble, .foremanRex]
                    .allSatisfy { g.state.defeatedBosses.contains($0) }
                if g.state.quackRescued && allBossesBeaten {
                    VictoryView(state: g.state) {
                        g.restart()
                        withAnimation(.easeInOut(duration: 0.6)) { showTitle = true }
                    }
                    .transition(.opacity)
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
        .animation(.easeInOut(duration: 0.2),  value: g.dialogue.activeNPC)
        .animation(.easeInOut(duration: 0.2),  value: g.dialogue.activeTitle)
        .animation(.easeInOut(duration: 0.25), value: g.state.shopOpen)
        .animation(.easeInOut(duration: 0.22), value: g.state.statsOpen)
        .animation(.easeInOut(duration: 0.20), value: g.state.isPaused)
        .animation(.easeInOut(duration: 0.45), value: g.state.quackRescued)
        .onChange(of: g.state.queueTitleReturn) { _, triggered in
            guard triggered else { return }
            g.restart()                              // resets state (clears flag) + restarts scene
            withAnimation(.easeInOut(duration: 0.5)) { showTitle = true }
        }
    }
}

private enum RetroUI {
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let navy = Color(red: 0.08, green: 0.10, blue: 0.18)
    static let navyLight = Color(red: 0.17, green: 0.21, blue: 0.34)
    static let panel = Color(red: 0.93, green: 0.91, blue: 0.82)
    static let panelShadow = Color(red: 0.76, green: 0.72, blue: 0.61)
    static let grass = Color(red: 0.36, green: 0.66, blue: 0.20)
    static let gold = Color(red: 0.83, green: 0.69, blue: 0.19)
    static let warning = Color(red: 0.78, green: 0.19, blue: 0.19)
}

private struct RetroPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(8)
            .background(RetroUI.panel)
            .overlay(
                Rectangle()
                    .stroke(RetroUI.ink, lineWidth: 3)
                    .padding(1)
            )
            .shadow(color: RetroUI.panelShadow, radius: 0, x: 4, y: 4)
    }
}

private struct RetroDarkPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .background(RetroUI.navy)
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.88), lineWidth: 2)
                    .padding(1)
            )
            .overlay(Rectangle().stroke(RetroUI.ink, lineWidth: 4))
            .shadow(color: Color.black.opacity(0.35), radius: 0, x: 4, y: 4)
    }
}

// MARK: - HUD

struct HUDView: View {
    let state: GameState
    let dialogue: DialogueManager

    @State private var storyExpanded = true
    @State private var collapseToken = UUID()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RetroPanel {
                VStack(alignment: .leading, spacing: 5) {
                    Text("PARTY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroUI.ink.opacity(0.75))
                    ForEach(Array(state.party.enumerated()), id: \.element.id) { idx, member in
                        let isActive = idx == state.activeIndex
                        HStack(spacing: 6) {
                            Text(isActive ? "▶" : " ")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(isActive ? RetroUI.warning : RetroUI.panelShadow)
                                .frame(width: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(member.species.displayName.uppercased())
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundStyle(RetroUI.ink)
                                    LevelPipsView(isActive: isActive)
                                    Text("LV \(member.level)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(isActive ? RetroUI.warning : RetroUI.ink.opacity(0.7))
                                }
                                HPBar(hp: member.hp, maxHP: member.maxHP)
                                    .frame(width: 74, height: 7)
                                ExpBar(exp: member.exp, expToNext: member.expToNext)
                                    .frame(width: 74, height: 3)
                                    .opacity(isActive ? 1.0 : 0.45)
                            }
                        }
                    }
                }
            }

            Spacer()

            StoryPanelView(
                state: state,
                dialogue: dialogue,
                isExpanded: $storyExpanded,
                collapseToken: $collapseToken
            )
        }
        .onAppear { scheduleCollapse(reset: true) }
        .onChange(of: state.storyPanelSignature) { _, _ in
            scheduleCollapse(reset: true)
        }
    }

    private func scheduleCollapse(reset: Bool) {
        if reset {
            storyExpanded = true
            collapseToken = UUID()
        }

        let token = collapseToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            guard token == collapseToken else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                storyExpanded = false
            }
        }
    }
}

struct StoryPanelView: View {
    let state: GameState
    let dialogue: DialogueManager
    @Binding var isExpanded: Bool
    @Binding var collapseToken: UUID

    var body: some View {
        RetroDarkPanel {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.storyArcTitle.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.96, green: 0.89, blue: 0.55))
                        Text(state.currentZone.displayTitle)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button(isExpanded ? "HIDE" : "OPEN") {
                        collapseToken = UUID()
                        withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.22), lineWidth: 2))
                }

                if isExpanded {
                    Text(state.currentZone.zoneSubtitle)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.72))
                    Divider().overlay(Color.white.opacity(0.18))
                    Text(state.currentObjectiveText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(state.storyBeatText)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(red: 0.74, green: 0.83, blue: 0.92))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        Text("SCR \(state.score)")
                        Text("COIN \(state.coins)")
                        Text("FIGHTS \(state.enemiesDefeated)")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    InventoryStrip(inventory: state.inventory)
                    QuackQuestView(clues: state.quackClues)
                    if !dialogue.modelAvailable {
                        Text("DIALOGUE: OFFLINE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.52))
                    }
                } else {
                    HStack(spacing: 12) {
                        Text(state.currentObjectiveText.replacingOccurrences(of: "Objective: ", with: "NEXT: "))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("SCR \(state.score)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                }
            }
        }
    }
}

struct LevelPipsView: View {
    let isActive: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { idx in
                Rectangle()
                    .fill(isActive ? RetroUI.gold : RetroUI.panelShadow)
                    .frame(width: 3, height: 3 + CGFloat(idx))
                    .opacity(isActive ? (pulse ? 1.0 : 0.45 + CGFloat(idx) * 0.12) : 0.45)
            }
        }
        .onAppear {
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
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
                Rectangle().fill(RetroUI.ink.opacity(0.24))
                Rectangle()
                    .fill(barColor(frac))
                    .frame(width: geo.size.width * max(frac, 0))
                    .animation(.easeInOut(duration: 0.3), value: frac)
            }
            .overlay(Rectangle().stroke(RetroUI.ink, lineWidth: 1))
        }
    }

    private func barColor(_ frac: CGFloat) -> Color {
        if frac > 0.5 { return RetroUI.grass }
        if frac > 0.2 { return Color(red: 0.83, green: 0.69, blue: 0.19) }
        return RetroUI.warning
    }
}

struct ExpBar: View {
    let exp: Int
    let expToNext: Int

    var body: some View {
        GeometryReader { geo in
            let frac = expToNext > 0 ? CGFloat(exp) / CGFloat(expToNext) : 0
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.12))
                Rectangle()
                    .fill(Color(red: 0.29, green: 0.56, blue: 0.77))
                    .frame(width: geo.size.width * max(min(frac, 1), 0))
                    .animation(.easeInOut(duration: 0.4), value: frac)
            }
            .overlay(Rectangle().stroke(RetroUI.ink, lineWidth: 1))
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
                        Text(kind.hudLabel)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                        Text("x\(count)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                }
            }
            if inventory.isEmpty {
                Text("BAG EMPTY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.58))
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
        .raccoonDroppedTag,
        .pigeonCityClue,
        .workerSawDuck
    ]

    var body: some View {
        if clues.contains(.quackRescued) {
            HStack(spacing: 4) {
                Text("QUACK SAFE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.96, green: 0.89, blue: 0.55))
            }
        } else if !clues.isEmpty {
            HStack(spacing: 3) {
                ForEach(storyClues, id: \.self) { clue in
                    Rectangle()
                        .fill(clues.contains(clue) ? Color.yellow : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
                Text("TRACK \(clues.subtracting([.quackRescued]).count)/7")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.72))
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
            RetroDarkPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text((dialogue.activeTitle ?? dialogue.activeNPC?.displayName ?? "").uppercased())
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(red: 0.96, green: 0.89, blue: 0.55))
                            Text(dialogue.allowsInput ? "Press `END` to leave. Type to start the conversation." : "Scripted scene")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                        Spacer()
                        Button("END") {
                            dialogue.endConversation()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                    }

                    if dialogue.allowsInput && dialogue.lines.isEmpty {
                        DialogueEmptyStateView(npc: dialogue.activeNPC) { prompt in
                            draft = prompt
                            sendMessage()
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(dialogue.lines) { line in
                                        DialogueLineView(line: line)
                                            .id(line.id)
                                    }
                                    if dialogue.isResponding {
                                        HStack(spacing: 8) {
                                            Text("...")
                                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                                .foregroundStyle(Color(red: 0.96, green: 0.89, blue: 0.55))
                                            Text("Thinking")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.72))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.06))
                                        .overlay(Rectangle().stroke(Color.white.opacity(0.10), lineWidth: 2))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 220)
                            .onChange(of: dialogue.lines.count) { _, _ in
                                if let last = dialogue.lines.last {
                                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                                }
                            }
                        }
                    }

                    if dialogue.allowsInput {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SAY")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.58))
                            HStack(spacing: 8) {
                                Text(">")
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.96, green: 0.89, blue: 0.55))
                                    .padding(.leading, 10)
                                TextField("Ask about the park, the animals, or what they saw.", text: $draft)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .focused($focused)
                                    .onSubmit(sendMessage)
                                Button("SEND", action: sendMessage)
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(RetroUI.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.96, green: 0.89, blue: 0.55))
                                    .overlay(Rectangle().stroke(RetroUI.ink, lineWidth: 2))
                                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                              || dialogue.isResponding)
                            }
                            .padding(.vertical, 4)
                            .background(Color(red: 0.08, green: 0.10, blue: 0.18))
                            .overlay(Rectangle().stroke(Color.white.opacity(0.18), lineWidth: 2))
                        }
                    }
                }
            }
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

struct DialogueEmptyStateView: View {
    let npc: NPCKind?
    let onSelectPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start the conversation.")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("The NPC will wait until you ask something.")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))

            HStack(spacing: 8) {
                ForEach(promptOptions, id: \.self) { prompt in
                    Button(prompt.uppercased()) {
                        onSelectPrompt(prompt)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroUI.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.96, green: 0.89, blue: 0.55))
                    .overlay(Rectangle().stroke(RetroUI.ink, lineWidth: 2))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.06))
        .overlay(Rectangle().stroke(Color.white.opacity(0.12), lineWidth: 2))
    }

    private var promptOptions: [String] {
        switch npc {
        case .rangerGuide:
            return ["What's going on?", "Why the fountain?"]
        case .hazel:
            return ["What happened?", "What did the pigeons take?"]
        case .child:
            return ["What did you see?", "Any weird animals?"]
        case .jogger:
            return ["Seen anything strange?", "Where were the birds?"]
        default:
            return ["What's going on?", "Seen anything strange?"]
        }
    }
}

struct DialogueLineView: View {
    let line: DialogueManager.Line

    var body: some View {
        let isPlayer = line.speaker == "You"
        HStack {
            if isPlayer { Spacer(minLength: 36) }
            VStack(alignment: .leading, spacing: 6) {
                Text(line.speaker.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(isPlayer ? Color(red: 0.56, green: 0.80, blue: 0.96) : Color(red: 0.96, green: 0.89, blue: 0.55))
                Text(line.text)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .lineSpacing(3)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isPlayer ? Color(red: 0.12, green: 0.20, blue: 0.31) : Color.white.opacity(0.06))
            .overlay(
                Rectangle()
                    .stroke(isPlayer ? Color(red: 0.56, green: 0.80, blue: 0.96).opacity(0.55) : Color.white.opacity(0.14),
                            lineWidth: 2)
            )
            if !isPlayer { Spacer(minLength: 36) }
        }
    }
}

// MARK: - Title Screen

struct TitleView: View {
    let hasSave: Bool
    let onStart: (_ fresh: Bool) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.16, blue: 0.07),
                    Color(red: 0.05, green: 0.08, blue: 0.04)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                RetroPanel {
                    HStack(spacing: 12) {
                        ForEach(Species.allCases, id: \.self) { s in
                            VStack(spacing: 4) {
                                Text(s.displayName.uppercased())
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(RetroUI.ink)
                                Rectangle()
                                    .fill(RetroUI.grass)
                                    .frame(width: 44, height: 10)
                                    .overlay(Rectangle().stroke(RetroUI.ink, lineWidth: 2))
                            }
                        }
                    }
                }
                .padding(.bottom, 30)

                VStack(spacing: 2) {
                    Text("PARK")
                        .font(.system(size: 58, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 0.74, green: 0.91, blue: 0.38))
                    Text("FRIENDS")
                        .font(.system(size: 58, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.black.opacity(0.45), radius: 0, x: 5, y: 5)
                .padding(.bottom, 10)

                Text("A strange city park is trying to talk back.")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.46))
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

                Text("WALK  TALK  BATTLE  INVESTIGATE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
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
            .font(.system(size: 16, weight: .black, design: .monospaced))
            .foregroundStyle(accent ? RetroUI.ink : Color.white)
            .frame(width: 240, height: 52)
            .background(
                accent
                    ? RetroUI.gold
                    : RetroUI.navyLight
            )
            .overlay(
                Rectangle()
                    .stroke(accent ? RetroUI.ink : Color.white.opacity(0.22), lineWidth: 3)
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
                    Text(state.shopNarrativeTitle.uppercased())
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.storyArcTitle.uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.96, green: 0.89, blue: 0.55))
                        Text(state.shopNarrativeText)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.70))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("COIN \(state.coins)")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.96, green: 0.89, blue: 0.55))
                        Text(state.currentZone.displayTitle.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    Button("END") { onClose() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.22), lineWidth: 2))
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
            .background(RetroUI.navy, in: RoundedRectangle(cornerRadius: 0))
            .overlay(Rectangle().stroke(RetroUI.ink, lineWidth: 4))
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
            Text(kind.hudLabel)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .frame(width: 38)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(kind.shopDescription)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("🪙\(price)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(canAfford ? Color(red: 0.96, green: 0.89, blue: 0.55) : Color.red)
                if owned > 0 {
                    Text("HAVE x\(owned)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.52))
                }
            }

            Button {
                guard canAfford else { return }
                state.coins -= price
                state.inventory[kind, default: 0] += 1
                state.save()
            } label: {
                Text("Buy")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(canAfford ? RetroUI.gold : Color.gray.opacity(0.25))
                    .foregroundStyle(canAfford ? RetroUI.ink : .secondary)
                    .overlay(Rectangle().stroke(canAfford ? RetroUI.ink : Color.white.opacity(0.18), lineWidth: 2))
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .overlay(Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 1))
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

// MARK: - Stats / Inventory Screen

struct StatsView: View {
    let state: GameState
    let onClose: () -> Void

    @State private var tab: Tab = .party

    enum Tab: String, CaseIterable {
        case party     = "Party"
        case inventory = "Inventory"
        case bosses    = "Bosses"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.68).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("📋  Status")
                        .font(.headline.bold())
                    Spacer()
                    Text("🪙 \(state.coins)  ⭐️ \(state.score)  💀 \(state.enemiesDefeated)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Picker("Tab", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                Divider()

                ScrollView {
                    switch tab {
                    case .party:     PartyStatsPanel(state: state)
                    case .inventory: InventoryPanel(state: state)
                    case .bosses:    BossesPanel(defeated: state.defeatedBosses)
                    }
                }
            }
            .frame(maxWidth: 560, maxHeight: 520)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .shadow(radius: 28)
            .padding(24)
        }
    }
}

// MARK: Party panel

struct PartyStatsPanel: View {
    let state: GameState

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(state.party.enumerated()), id: \.element.id) { idx, m in
                let isActive = idx == state.activeIndex
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Text(m.species.emoji)
                            .font(.system(size: 36))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(m.species.displayName)
                                    .font(.headline.bold())
                                if isActive {
                                    Text("ACTIVE")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.yellow.opacity(0.25))
                                        .clipShape(Capsule())
                                        .foregroundStyle(.yellow)
                                }
                                Spacer()
                                Text("Lv.\(m.level)")
                                    .font(.caption.bold().monospacedDigit())
                            }
                            // HP bar
                            StatsBarRow(label: "HP", value: m.hp, max: m.maxHP, color: .green)
                            // PP bar
                            StatsBarRow(label: "PP", value: m.pp, max: m.maxPP, color: .blue)
                            // EXP
                            StatsBarRow(label: "EXP", value: m.exp, max: m.expToNext, color: .purple)
                        }
                    }
                    // Stat grid
                    HStack(spacing: 0) {
                        StatCell(label: "ATK", value: m.atk)
                        StatCell(label: "DEF", value: m.def)
                        StatCell(label: "SPD", value: m.spd)
                        StatCell(label: "LCK", value: m.lck)
                        StatCell(label: "PP/turn", value: m.species.specialPPCost)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Special: \(m.species.specialName)")
                                .font(.caption.bold())
                            Text(m.species.attackGlyph + " " + (m.species.attackIsProjectile ? "Ranged" : "Melee"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 4)
                    }
                    // Status effects
                    if !m.statusEffects.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(m.statusEffects), id: \.self) { eff in
                                Text("\(eff.emoji) \(eff.displayName)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.red.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                    }
                }
                .padding(12)
                .background(isActive ? Color.yellow.opacity(0.06) : Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1))
            }
        }
        .padding(12)
    }
}

struct StatsBarRow: View {
    let label: String
    let value: Int
    let max: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            GeometryReader { geo in
                let frac = max > 0 ? CGFloat(value) / CGFloat(max) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule().fill(color.opacity(0.7))
                        .frame(width: geo.size.width * Swift.max(0, frac))
                }
            }
            .frame(height: 6)
            Text("\(value)/\(max)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
    }
}

struct StatCell: View {
    let label: String
    let value: Int
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Inventory panel

struct InventoryPanel: View {
    let state: GameState

    private var inventory: [ItemKind: Int] { state.inventory }

    private var consumables: [(ItemKind, Int)] {
        ItemKind.allCases.compactMap { k in
            guard let c = inventory[k], c > 0, k.isConsumable else { return nil }
            return (k, c)
        }
    }
    private var keyItems: [(ItemKind, Int)] {
        ItemKind.allCases.compactMap { k in
            guard let c = inventory[k], c > 0, !k.isConsumable else { return nil }
            return (k, c)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if consumables.isEmpty && keyItems.isEmpty {
                Text("Bag is empty.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
            }
            if !consumables.isEmpty {
                SectionHeader(title: "Consumables")
                ForEach(consumables, id: \.0) { kind, count in
                    InventoryRow(kind: kind, count: count, state: state)
                }
            }
            if !keyItems.isEmpty {
                SectionHeader(title: "Key Items")
                ForEach(keyItems, id: \.0) { kind, count in
                    InventoryRow(kind: kind, count: count, state: nil)
                }
            }
        }
        .padding(14)
    }
}

struct InventoryRow: View {
    let kind: ItemKind
    let count: Int
    let state: GameState?    // non-nil → show Use button for usable items

    @State private var usedFlash = false

    var body: some View {
        HStack(spacing: 10) {
            Text(kind.emoji).font(.title3).frame(width: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.displayName).font(.subheadline.bold())
                let desc = kind.itemDescription
                if !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if count > 1 {
                Text("×\(count)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let price = kind.buyPrice {
                Text("🪙\(price)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            // "Use" button for usable consumables
            if let state, kind.isUsable {
                Button {
                    if state.useConsumable(kind) != nil {
                        withAnimation { usedFlash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation { usedFlash = false }
                        }
                    }
                } label: {
                    Text(usedFlash ? "✓" : "Use")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(usedFlash
                            ? Color.green.opacity(0.55)
                            : Color.blue.opacity(0.18))
                        .foregroundStyle(usedFlash ? .white : Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(state.inventory[kind, default: 0] == 0)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}

// MARK: Bosses panel

struct BossesPanel: View {
    let defeated: Set<EnemyKind>
    private let bosses: [EnemyKind] = [.grandGooseGerald, .officerGrumble, .foremanRex]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(bosses, id: \.self) { boss in
                let done = defeated.contains(boss)
                HStack(spacing: 12) {
                    Text(boss.bossEmoji)
                        .font(.system(size: 36))
                        .opacity(done ? 1.0 : 0.35)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(boss.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(done ? .primary : .secondary)
                        Text(boss.bossIntroTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if done {
                        Text("✅ Defeated")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text("⚔️ Not yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(done ? Color.green.opacity(0.06) : Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(done ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1))
            }
            Spacer(minLength: 8)
            Text("Defeat all three bosses to unlock the final zone.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(14)
    }
}

// MARK: - Victory Screen

struct VictoryView: View {
    let state: GameState
    let onReturn: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 0) {
                // Confetti header
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    HStack(spacing: 14) {
                        ForEach(Array(["🎉","🦆","⭐️","🏆","🎊","✨","🌳"].enumerated()), id: \.offset) { i, e in
                            Text(e)
                                .font(.system(size: 38))
                                .offset(y: sin(t * 2.3 + Double(i) * 0.7) * 10)
                        }
                    }
                    .padding(.top, 30)
                }

                VStack(spacing: 6) {
                    Text("YOU DID IT!")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.85, blue: 0.20),
                                         Color(red: 1.0, green: 0.62, blue: 0.10)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    Text("The park is safe. Quack is home. 🦆")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)

                // Final stats
                VStack(spacing: 8) {
                    Divider().padding(.horizontal, 20)
                    HStack(spacing: 28) {
                        VictoryStat(label: "Score",    value: "\(state.score)")
                        VictoryStat(label: "Coins",    value: "🪙\(state.coins)")
                        VictoryStat(label: "Enemies",  value: "💀\(state.enemiesDefeated)")
                        VictoryStat(label: "Clues",    value: "\(state.quackClueCount)/7")
                    }
                    Divider().padding(.horizontal, 20)

                    // Boss checklist
                    HStack(spacing: 20) {
                        ForEach([EnemyKind.grandGooseGerald, .officerGrumble, .foremanRex], id: \.self) { boss in
                            VStack(spacing: 3) {
                                Text(boss.bossEmoji).font(.system(size: 28))
                                Text("✅").font(.caption)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Party
                HStack(spacing: 18) {
                    ForEach(Array(state.party.enumerated()), id: \.element.id) { _, m in
                        VStack(spacing: 4) {
                            Text(m.species.emoji).font(.system(size: 36))
                            Text("Lv.\(m.level)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 16)

                Button {
                    onReturn()
                } label: {
                    Text("🏠  Return to Title")
                        .font(.headline.bold())
                        .foregroundStyle(Color.black)
                        .frame(width: 220, height: 50)
                        .background(Color(red: 0.52, green: 0.95, blue: 0.42))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 480)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .shadow(radius: 40)
            .padding(24)
        }
    }
}

private struct VictoryStat: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Pause Menu

struct PauseMenuView: View {
    let state: GameState

    @State private var savedFlash = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                Text("⏸  Paused")
                    .font(.title2.bold())
                    .padding(.top, 24)
                    .padding(.bottom, 18)

                Divider()

                VStack(spacing: 10) {
                    // Resume
                    PauseButton(
                        label: "▶  Resume",
                        accent: true
                    ) {
                        state.isPaused = false
                    }

                    // Save
                    PauseButton(label: savedFlash ? "✅  Saved!" : "💾  Save Game") {
                        state.save()
                        withAnimation { savedFlash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            withAnimation { savedFlash = false }
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // Back to title
                    PauseButton(label: "🏠  Back to Title", destructive: true) {
                        state.isPaused = false
                        // Signal GameView to fade to title via queueTitleReturn
                        state.queueTitleReturn = true
                    }
                }
                .padding(18)

                // Tiny stats footer
                HStack(spacing: 16) {
                    Text("⭐️ \(state.score)")
                    Text("🪙 \(state.coins)")
                    Text("💀 \(state.enemiesDefeated)")
                    Text(state.currentZone.displayTitle)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.bottom, 18)
            }
            .frame(width: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 32)
        }
    }
}

private struct PauseButton: View {
    let label: String
    var accent: Bool       = false
    var destructive: Bool  = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if accent      { return Color(red: 0.52, green: 0.95, blue: 0.42) }
        if destructive { return Color.red.opacity(0.15) }
        return Color.primary.opacity(0.07)
    }

    private var foregroundColor: Color {
        if accent      { return Color.black }
        if destructive { return Color.red }
        return Color.primary
    }
}

// MARK: - Preview

#Preview {
    GameView()
}
