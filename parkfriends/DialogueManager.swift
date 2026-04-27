import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Wraps Apple's on-device Foundation Model for NPC chat.
/// Falls back to canned responses if the model isn't available (e.g. on older
/// simulators or devices without Apple Intelligence).
@Observable
@MainActor
final class DialogueManager {

    struct Line: Identifiable {
        let id = UUID()
        let speaker: String   // "You" or NPC displayName
        let text: String
    }

    /// The active conversation, if one is open.
    var activeNPC: NPCKind?
    var activeTitle: String?
    var activeSpeaker: Species?   // which party member is doing the talking
    var lines: [Line] = []
    var isResponding: Bool = false
    var modelAvailable: Bool = false
    var allowsInput: Bool = true
    var onDismiss: (() -> Void)?

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    init() {
        checkAvailability()
    }

    private func checkAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                modelAvailable = true
            default:
                modelAvailable = false
            }
        }
        #else
        modelAvailable = false
        #endif
    }

    func startConversation(with npc: NPCKind, asSpecies species: Species,
                           quackClues: Set<QuackClue> = []) {
        activeNPC = npc
        activeTitle = nil
        activeSpeaker = species
        lines.removeAll()
        allowsInput = true
        onDismiss = nil

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *), modelAvailable {
            let instructions = Self.buildInstructions(npc: npc, species: species,
                                                      quackClues: quackClues)
            let s = LanguageModelSession(instructions: instructions)
            s.prewarm()
            session = s
        }
        #endif
    }

    func endConversation() {
        let callback = onDismiss
        activeNPC = nil
        activeTitle = nil
        activeSpeaker = nil
        lines.removeAll()
        allowsInput = true
        onDismiss = nil
        #if canImport(FoundationModels)
        session = nil
        #endif
        callback?()
    }

    func presentScriptedConversation(title: String, lines scripted: [(speaker: String, text: String)],
                                     onDismiss: (() -> Void)? = nil) {
        activeNPC = nil
        activeTitle = title
        activeSpeaker = nil
        lines = scripted.map { Line(speaker: $0.speaker, text: $0.text) }
        isResponding = false
        allowsInput = false
        self.onDismiss = onDismiss
        #if canImport(FoundationModels)
        session = nil
        #endif
    }

    func send(_ message: String) async {
        guard let npc = activeNPC else { return }
        let isGreeting = message.hasPrefix("*")
        if !isGreeting {
            lines.append(Line(speaker: "You", text: message))
        }

        isResponding = true
        defer { isResponding = false }

        // Append a placeholder line we'll fill in as tokens stream.
        let placeholder = Line(speaker: npc.displayName, text: "…")
        lines.append(placeholder)
        let replyIndex = lines.count - 1

        await streamReply(to: message, from: npc, into: replyIndex)
    }

    private func streamReply(to message: String, from npc: NPCKind, into index: Int) async {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *),
           modelAvailable,
           let session {
            do {
                let stream = session.streamResponse(to: message)
                for try await partial in stream {
                    // ResponseStream yields cumulative snapshots, not raw Strings.
                    let mirror = Mirror(reflecting: partial)
                    let text = mirror.children.first(where: { $0.label == "content" })
                        .flatMap { $0.value as? String }
                        ?? String(describing: partial)
                    guard index < lines.count else { return }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    lines[index] = Line(speaker: npc.displayName, text: trimmed.isEmpty ? "…" : trimmed)
                }
                return
            } catch {
                if index < lines.count {
                    lines[index] = Line(speaker: npc.displayName,
                                        text: fallbackReply(for: npc, clues: activeQuackClues))
                }
                return
            }
        }
        #endif
        if index < lines.count {
            lines[index] = Line(speaker: npc.displayName,
                                text: fallbackReply(for: npc, clues: activeQuackClues))
        }
    }

    /// Quack clues at the time the conversation started (injected by GameScene).
    var activeQuackClues: Set<QuackClue> = []

    private func fallbackReply(for npc: NPCKind, clues: Set<QuackClue>) -> String {
        let rescued = clues.contains(.quackRescued)
        let hasFeather = clues.contains(.foundFeather)

        switch npc {
        case .rangerGuide:
            return "Officially, everything is under control. Unofficially, the animals have started acting like they held a meeting without me."

        case .hazel:
            return "If pigeons are organized now, that means the park is trying to say something and doing a terrible job of it."

        case .jogger:
            if rescued {
                return "*huff* Heard you found your duck friend! Amazing. *puff* Keep it up, little one."
            } else if clues.contains(.joggerSawCity) {
                return "*huff* Yeah, I saw that duck again… heading toward the construction zone. *puff* Be careful up there."
            } else if hasFeather {
                return "*huff* Missing duck? *puff* I saw one waddling fast past the south gate… looked scared."
            }
            return "*huff* …haven't got time… *puff*… watch out for rangers."

        case .child:
            if rescued {
                return "YOU SAVED QUACK!! I told everyone!! Everyone says I was lying but I WASN'T!"
            } else if clues.contains(.childSawChase) {
                return "I already told you everything I know! The duck went THAT way — toward the big city buildings!"
            } else if clues.isEmpty || !hasFeather {
                return "Whoaaa are you a REAL talking animal?? Can I pet you?? My mom said—"
            } else {
                return "Wait — is that Quack's feather?? Oh no! I SAW a duck running really fast past the swings yesterday! Some loud machine scared it!"
            }

        case .birdwatcher:
            if rescued {
                return "Wonderful news about the duck. The pond feels alive again. *adjusts binoculars*"
            } else if clues.contains(.visitedNorthPond) {
                return "Shh… yes, I noticed the pond seems empty too. The mallard that lives there — gone since Tuesday. I suspect the construction noise drove it south."
            }
            return "Shh… a goldfinch just landed. …What brings you here, little one?"

        case .dogwalker:
            if rescued {
                return "Oh my gosh that's the best news! — NO, Biscuit, DROP it — sorry, I'm so happy for your duck friend!"
            } else if clues.contains(.pigeonCityClue) {
                return "Biscuit kept barking at something near the old warehouse — NO, sit! — probably your duck, now that I think about it."
            }
            return "Oh hi! — NO, Biscuit, drop it — sorry, what were you saying?"

        case .gardener:
            if rescued {
                return "Good. That duck belongs near the pond, not near all that concrete. *goes back to weeding*"
            } else if hasFeather {
                return "Found a duck feather, did you? Saw that bird myself — waddled right through my tulip beds heading toward the city. *grumbles*"
            }
            return "Mind the tulips. You seen anyone stomping through my beds?"

        case .worker:
            if rescued {
                return "Yeah, heard you found it. Duck was in the way of our crane all week. Good riddance — I mean, glad it's safe."
            } else if clues.contains(.workerSawDuck) {
                return "Like I said — big white duck, near the east warehouse, a few days back. Spooked by the drill press. Haven't seen it since."
            }
            return "You lost a duck? …Huh. Actually, yeah. Big white one kept poking around the east warehouse. Seemed real scared. Last I saw it went behind the old crane."

        case .shopkeeper:
            return "We're open. Buy something or move along."

        case .cat:
            if clues.contains(.foundFeather) {
                return "…I saw the duck. South gate, moving fast, didn't look back. That's all I'll say."
            }
            return "…"
        case .dog:
            if clues.contains(.foundFeather) {
                return "DUCK!! I SMELLED DUCK!! Near the south fence!! Did you find the duck?! I can help find the duck!!"
            }
            return "HELLO!! You smell interesting!! Are we friends now?!"
        case .raccoon:
            if clues.contains(.raccoonDroppedTag) {
                return "Look, I found that tag near the drain, alright? Something big came through here real fast. Smelled like pond."
            }
            return "I don't know nothin'. *moves bin lid suspiciously*"
        case .bird:
            if rescued {
                return "Cooo. Glad the duck's back. Cooo."
            }
            return "Coo. Coo. *pecks ground* Yeah, it left. *pecks* Not my business."
        }
    }

    private static func buildInstructions(npc: NPCKind, species: Species,
                                          quackClues: Set<QuackClue>) -> String {
        let storyContext = Self.storyContext(npc: npc, clues: quackClues)
        return """
        Roleplay an NPC in Bellwether Park. Stay in character; never break the fourth wall.

        YOU: \(npc.persona)
        PLAYER: a talking \(species.displayName) approaches you — react with mild surprise but roll with it.
        QUEST: a duck named Quack is missing from the north pond. \(storyContext)

        Reply in 1–2 short sentences. Weave clue info in naturally only if asked about the duck.
        """
    }

    private static func storyContext(npc: NPCKind, clues: Set<QuackClue>) -> String {
        let rescued = clues.contains(.quackRescued)
        if rescued { return "The duck has already been rescued — react with relief and joy." }

        switch npc {
        case .rangerGuide:
            return "You are trying to keep Bellwether Park calm with official language, even though the animals have started behaving in ways that definitely do not fit the handbook."

        case .hazel:
            return "You are a sharp squirrel from the fountain plaza. You already believe the animal weirdness is organized, not random, and you want the player to take that seriously."

        case .child:
            if clues.contains(.foundFeather) && !clues.contains(.childSawChase) {
                return "YOU saw the duck being chased toward the city by a loud machine noise two days ago. Tell the player if they ask about the feather or missing duck."
            }
            return "You saw nothing unusual yet."
        case .jogger:
            if clues.contains(.childSawChase) || clues.contains(.foundFeather) {
                return "You jogged past the south gate and spotted a distressed duck waddling toward the city district. Mention it if they ask."
            }
            return "You haven't noticed anything unusual yet."
        case .birdwatcher:
            return "You noticed the pond's regular mallard duck has been absent since Tuesday and suspect construction noise is to blame."
        case .dogwalker:
            if clues.contains(.pigeonCityClue) {
                return "Your dog Biscuit kept barking near the old City North warehouse area recently — it was probably the missing duck."
            }
            return "You haven't noticed anything duck-related."
        case .gardener:
            if clues.contains(.foundFeather) {
                return "You saw a duck waddling hurriedly through your flower beds toward the city, going south. You're mildly annoyed it trampled your tulips."
            }
            return "You haven't seen the duck."

        case .worker:
            return "You spotted a large white duck near the east warehouse in City North a few days ago. It seemed panicked by construction noise and ran behind the old crane. Tell the player if they ask about the duck or Quack."

        case .shopkeeper:
            return "You run a corner store. You sell snacks and supplies. You don't get involved in duck drama."

        case .cat:
            return "You are an independent cat who prowls the park. You've seen a large white duck rushing south. You'll share this only if the player seems serious."
        case .dog:
            return "You are an excited dog who has sniffed everywhere! You definitely smelled duck near the south fence. You want to tell everyone!"
        case .raccoon:
            return "You forage near the bins. You've seen and heard things. A panicked duck, a loud rumbling from the city — you know more than you let on."
        case .bird:
            return "You are a chill park pigeon. You saw the duck leave. You don't get involved. But you'll confirm it happened if pressed."
        }
    }
}
