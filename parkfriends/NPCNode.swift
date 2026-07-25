import SpriteKit

enum NPCKind: String, CaseIterable {
    // ── Story / fixed NPCs ──────────────────────────────────────────────────
    case rangerGuide    // Park ranger — quest giver
    case hazel          // Fox companion
    case worker         // Construction worker (City North — workerSawDuck clue)
    case shopkeeper     // Corner store — opens shop UI

    // ── Human ambient NPCs (interactive dialogue) ──────────────────────────
    case jogger, child, birdwatcher, dogwalker, gardener

    // ── Animal ambient NPCs (wander + animate, predator/passive roles) ─────
    case cat            // Predator — stalks around, curious
    case dog            // Predator — excitable, bouncy runs
    case raccoon        // Predator — forages at edges, shifty
    case bird           // Passive — pecks ground, startles easily

    var displayName: String {
        switch self {
        case .rangerGuide: "Ranger"
        case .hazel:       "Hazel"
        case .jogger:      "Jogger"
        case .child:       "Kid"
        case .birdwatcher: "Birdwatcher"
        case .dogwalker:   "Dog Walker"
        case .gardener:    "Gardener"
        case .worker:      "Worker"
        case .shopkeeper:  "Corner Store"
        case .cat:         "Cat"
        case .dog:         "Dog"
        case .raccoon:     "Raccoon"
        case .bird:        "Bird"
        }
    }

    var isAnimal: Bool {
        switch self {
        case .cat, .dog, .raccoon, .bird: true
        default: false
        }
    }

    var isShopkeeper: Bool { self == .shopkeeper }

    var isFixed: Bool {
        switch self {
        case .rangerGuide, .hazel, .worker, .shopkeeper: true
        default: false
        }
    }

    var persona: String {
        switch self {
        case .rangerGuide:
            "You are Bellwether Park's ranger. Every ridiculous problem needs to be filed correctly before anyone panics."
        case .hazel:
            "You are Hazel, a sharp fox with urgent opinions, fast timing, and zero patience for pigeons touching your belongings."
        case .jogger:
            "You are a breathless park jogger who speaks in clipped sentences between breaths. You share gossip only if asked nicely."
        case .child:
            "You are a curious 7-year-old at the park. You talk in excited run-on sentences. You think the animals are magic."
        case .birdwatcher:
            "You are a soft-spoken elderly birdwatcher with encyclopedic knowledge of park wildlife. You whisper so you don't scare the birds."
        case .dogwalker:
            "You are a chatty twenty-something walking three dogs. Easily distracted by your dogs mid-sentence."
        case .gardener:
            "You are a weathered park gardener who grumbles about litter but secretly loves animals."
        case .worker:
            "You are a no-nonsense construction worker eating lunch. Terse, practical, vaguely surprised to be talking to an animal."
        case .shopkeeper:
            "You are a tired corner store owner who sells snacks. Short dry quips only."
        case .cat:
            "You are a street cat — independent, cryptic, briefly tolerant. You speak in short observations."
        case .dog:
            "You are a very good dog. Enthusiastic. Everything is exciting. Short sentences. Lots of energy."
        case .raccoon:
            "You are a scrappy raccoon. You speak like someone who knows where all the trash cans are and isn't sorry about it."
        case .bird:
            "You are a park pigeon. You are chill. You have seen things. You're not scared of anyone."
        }
    }
}

// MARK: - NPCNode

@MainActor
final class NPCNode: SKSpriteNode {
    let kind: NPCKind

    // Stable per-instance variant (e.g. dog breed 0-7)
    private let animalVariant: Int
    private var currentDirectionRow = 0

    /// `variant` lets callers assign a stable breed/colour to this NPC (e.g. pass
    /// a sequential index so each dog on screen shows a different sprite).
    init(kind: NPCKind, worldSize: CGSize = .zero, variant: Int = 0) {
        self.kind = kind
        self.animalVariant = variant

        // EarthBound-style scale: adult humans stand taller than the animal
        // party (player is 44×66); ambient critters stay small.
        let displaySize: CGSize
        switch kind {
        case .rangerGuide, .jogger, .child, .birdwatcher, .dogwalker,
             .gardener, .worker, .shopkeeper:
            displaySize = CGSize(width: 50, height: 74)
        default:
            displaySize = CGSize(width: 40, height: 40)
        }

        let firstFrame = NPCNode.firstFrame(for: kind, variant: variant)
        super.init(texture: firstFrame, color: .clear, size: displaySize)

        name = "npc"
        zPosition = GameConstants.ZPos.entity

        let body = SKPhysicsBody(circleOfRadius: 20)
        body.isDynamic = kind.isAnimal   // animals move, humans are static
        body.categoryBitMask    = GameConstants.Category.npc
        body.contactTestBitMask = GameConstants.Category.player
        body.collisionBitMask   = kind.isAnimal ? GameConstants.Category.wall : 0
        body.allowsRotation = false
        body.linearDamping  = 8
        physicsBody = body

        startBehaviour(worldSize: worldSize)

        if !kind.isAnimal {
            addIndicator()
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Texture helpers

    private static func firstFrame(for kind: NPCKind, variant: Int = 0) -> SKTexture? {
        switch kind {
        case .cat:      return ImportedArt.catFrames(directionRow: 0).first
        case .dog:      return ImportedArt.dogFrames(variant: variant).first
        case .raccoon:  return ImportedArt.raccoonFrames(directionRow: 0).first
        case .bird:     return ImportedArt.birdFrames(white: false, directionRow: 0).first
        case .hazel:    return ImportedArt.foxFrames(directionRow: 0).first
        default:
            return ImportedArt.genNPCWalkFrames(kind: kind, direction: "south").first
                ?? WorldSprites.texture(npc: kind)
        }
    }

    private static func genDirection(forRow row: Int) -> String {
        switch row {
        case 6:    return "east"
        case 4, 5: return "north"
        case 2, 3: return "west"
        default:   return "south"
        }
    }

    private static func walkFrames(for kind: NPCKind, directionRow: Int, variant: Int = 0) -> [SKTexture] {
        switch kind {
        case .cat:    return ImportedArt.catFrames(directionRow: directionRow)
        case .dog:    return ImportedArt.dogFrames(variant: variant)
        case .raccoon:return ImportedArt.raccoonFrames(directionRow: directionRow)
        case .bird:   return ImportedArt.birdFrames(white: false, directionRow: directionRow)
        case .hazel:  return ImportedArt.foxFrames(directionRow: directionRow)
        default:
            return ImportedArt.genNPCWalkFrames(kind: kind, direction: genDirection(forRow: directionRow))
        }
    }

    private static func directionRow(for vector: CGVector) -> Int {
        let dx = vector.dx
        let dy = vector.dy
        if abs(dx) < 0.001 && abs(dy) < 0.001 { return 0 }

        let angle = atan2(dy, dx)
        let octant = Int(round(angle / (.pi / 4)))
        switch octant {
        case 0:   return 6   // east
        case 1:   return 5   // north-east
        case 2:   return 4   // north
        case 3:   return 3   // north-west
        case 4, -4: return 2 // west
        case -3:  return 1   // south-west
        case -2:  return 0   // south
        case -1:  return 7   // south-east
        default:  return 0
        }
    }

    private func updateAnimalDirection(dx: CGFloat, dy: CGFloat) {
        let row = NPCNode.directionRow(for: CGVector(dx: dx, dy: dy))
        let frames = NPCNode.walkFrames(for: kind, directionRow: row, variant: animalVariant)
        guard !frames.isEmpty else { return }
        if row != currentDirectionRow {
            currentDirectionRow = row
            removeAction(forKey: "animalWalk")
            let fps: TimeInterval = kind == .dog ? 0.08 : 0.12
            texture = frames.first
            run(.repeatForever(.animate(with: frames, timePerFrame: fps,
                                        resize: false, restore: true)),
                withKey: "animalWalk")
        }
        xScale = abs(xScale)
    }

    // MARK: - Behaviour

    private func startBehaviour(worldSize: CGSize) {
        let frames = NPCNode.walkFrames(for: kind, directionRow: currentDirectionRow, variant: animalVariant)

        if kind.isAnimal {
            if frames.count > 1 { texture = frames.first }
            // Wander continuously
            startWander(worldSize: worldSize)
        } else if frames.count > 1 {
            // Human NPCs: subtle idle animation (first 2 frames only)
            let idle = Array(frames.prefix(2))
            run(.repeatForever(.animate(with: idle, timePerFrame: 0.5,
                                        resize: false, restore: true)))
        } else {
            // Static human NPCs: gentle sway
            let sway = SKAction.sequence([
                .rotate(toAngle: 0.04, duration: 0.9),
                .rotate(toAngle: -0.04, duration: 0.9)
            ])
            run(.repeatForever(sway))
        }
    }

    private func startWander(worldSize: CGSize) {
        wanderStep(worldSize: worldSize)
    }

    private func wanderStep(worldSize: CGSize) {
        // How far and how fast depending on species
        let speed: CGFloat
        let range: CGFloat
        let pauseLo: TimeInterval
        let pauseHi: TimeInterval
        switch kind {
        case .dog:
            speed = 90;  range = 180; pauseLo = 0.3; pauseHi = 1.2
        case .cat:
            speed = 55;  range = 120; pauseLo = 1.0; pauseHi = 3.0
        case .raccoon:
            speed = 45;  range = 90;  pauseLo = 1.5; pauseHi = 4.0
        case .bird:
            speed = 35;  range = 60;  pauseLo = 0.8; pauseHi = 2.5
        default:
            speed = 50;  range = 80;  pauseLo = 1.0; pauseHi = 2.0
        }

        let angle = CGFloat.random(in: 0 ..< 2 * .pi)
        let dist  = CGFloat.random(in: range * 0.4 ... range)
        let dx    = cos(angle) * dist
        let dy    = sin(angle) * dist
        let dur   = TimeInterval(dist / speed)
        let pause = TimeInterval.random(in: pauseLo ... pauseHi)

        updateAnimalDirection(dx: dx, dy: dy)

        let move  = SKAction.moveBy(x: dx, y: dy, duration: dur)
        move.timingMode = .easeInEaseOut
        let wait  = SKAction.wait(forDuration: pause)
        let next  = SKAction.run { [weak self] in
            guard let self else { return }
            self.wanderStep(worldSize: worldSize)
        }
        run(.sequence([move, wait, next]))
    }

    // MARK: - Chat indicator (human NPCs only)

    private func addIndicator() {
        let bubble = SKShapeNode(rectOf: CGSize(width: kind.isShopkeeper ? 18 : 14, height: 14))
        bubble.fillColor = kind.isShopkeeper
            ? SKColor(red: 0.83, green: 0.69, blue: 0.19, alpha: 0.95)
            : SKColor(red: 0.93, green: 0.93, blue: 0.86, alpha: 0.95)
        bubble.strokeColor = GamePalette.outline
        bubble.lineWidth   = 2
        bubble.position    = CGPoint(x: 0, y: 34)
        bubble.zPosition   = 1

        let dot = SKShapeNode(rectOf: CGSize(width: kind.isShopkeeper ? 6 : 4,
                                              height: kind.isShopkeeper ? 6 : 4))
        dot.fillColor   = kind.isShopkeeper
            ? SKColor(red: 0.62, green: 0.36, blue: 0.14, alpha: 1)
            : GamePalette.outline
        dot.strokeColor = .clear
        bubble.addChild(dot)

        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 3, duration: 0.5),
            .moveBy(x: 0, y: -3, duration: 0.5)
        ])
        bubble.run(.repeatForever(bob))
        addChild(bubble)
    }
}
