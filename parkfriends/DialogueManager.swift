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
    var activeSpeaker: Species?   // which party member is doing the talking
    var lines: [Line] = []
    var isResponding: Bool = false
    var modelAvailable: Bool = false

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

    func startConversation(with npc: NPCKind, asSpecies species: Species) {
        activeNPC = npc
        activeSpeaker = species
        lines.removeAll()

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *), modelAvailable {
            let instructions = Self.buildInstructions(npc: npc, species: species)
            session = LanguageModelSession(instructions: instructions)
        }
        #endif

        // Greeting — either from the model or a canned fallback.
        Task { await send("*\(species.displayName) the \(species.rawValue) waves and approaches*") }
    }

    func endConversation() {
        activeNPC = nil
        activeSpeaker = nil
        lines.removeAll()
        #if canImport(FoundationModels)
        session = nil
        #endif
    }

    func send(_ message: String) async {
        guard let npc = activeNPC else { return }
        // Don't show the stage-direction greeting as a player line.
        let isGreeting = message.hasPrefix("*")
        if !isGreeting {
            lines.append(Line(speaker: "You", text: message))
        }

        isResponding = true
        defer { isResponding = false }

        let reply = await generateReply(to: message, from: npc)
        lines.append(Line(speaker: npc.displayName, text: reply))
    }

    private func generateReply(to message: String, from npc: NPCKind) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *),
           modelAvailable,
           let session {
            do {
                let response = try await session.respond(to: message)
                return response.content
            } catch {
                return fallbackReply(for: npc, to: message) +
                    "\n(model error: \(error.localizedDescription))"
            }
        }
        #endif
        return fallbackReply(for: npc, to: message)
    }

    private func fallbackReply(for npc: NPCKind, to message: String) -> String {
        // Lightweight canned replies so the game works without the LLM.
        switch npc {
        case .jogger: return "*huff* …haven't got time… *puff*… watch out for rangers."
        case .child: return "Whoaaa are you a REAL talking animal?? Can I pet you?? My mom said—"
        case .birdwatcher: return "Shh… a goldfinch just landed. …What brings you here, little one?"
        case .dogwalker: return "Oh hi! — NO, Biscuit, drop it — sorry, what were you saying?"
        case .gardener: return "Mind the tulips. You seen anyone stomping through my beds?"
        }
    }

    private static func buildInstructions(npc: NPCKind, species: Species) -> String {
        """
        You are roleplaying as an NPC in a cozy park-adventure game.

        YOUR CHARACTER: \(npc.persona)

        THE PLAYER: A small talking \(species.rawValue) named \(species.displayName) \
        has just approached you. \(species.personalityPrompt)

        RULES:
        - Stay in character at all times.
        - Keep replies to 1-3 short sentences.
        - Never break the fourth wall.
        - React with mild surprise that an animal is talking, but go with it.
        - If asked about the park, invent vivid local details (paths, benches, \
          a pond, rangers patrolling).
        - You may give the player hints about items, puzzles, or hidden spots \
          if they ask.
        """
    }
}
