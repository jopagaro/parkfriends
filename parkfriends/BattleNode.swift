import SpriteKit

// MARK: - Battle phase

enum BattlePhase { case none, playerMenu, animating, enemyTurn, victory, defeat, fled }

// MARK: - BattleNode

/// Full-screen SKNode overlay — EarthBound-style turn combat (§6).
@MainActor
final class BattleNode: SKNode {

    // MARK: Callbacks
    var onVictory: ((EnemyKind) -> Void)?
    var onDefeat:  (() -> Void)?
    var onFled:    (() -> Void)?
    var onSaved:   (() -> Void)?

    // MARK: Sub-nodes
    private let backdrop              = SKSpriteNode()
    private let backgroundContainer   = SKNode()
    private let panel                 = SKShapeNode()
    private let enemySprite           = SKSpriteNode()
    private let enemyShadow           = SKSpriteNode(color: SKColor(white: 0, alpha: 0.24),
                                                     size: CGSize(width: 116, height: 18))
    private let impactFlash           = SKSpriteNode(color: .white,
                                                     size: CGSize(width: 4000, height: 4000))
    private let enemyNameLbl          = SKLabelNode()
    private let enemyHPBg             = SKSpriteNode(color: SKColor(white: 0.15, alpha: 1),
                                                      size: CGSize(width: 200, height: 10))
    private let enemyHPFill           = SKSpriteNode(color: .red, size: CGSize(width: 200, height: 10))
    private let logBox                = SKShapeNode()
    private let logLabel              = SKLabelNode()
    private var partySlots:           [PartySlot]    = []
    private let menuNode              = SKNode()
    private var menuButtons:          [BattleButton] = []
    private let enemyBaseY: CGFloat   = 118

    // MARK: State
    private var currentEnemy:         EnemyNode?
    private var gameState:            GameState?
    private(set) var phase:           BattlePhase = .none

    // ── Battle-session state ──────────────────────────────────────────────────
    private var battleTurnCount:      Int    = 0
    private var enemyBonusATK:        Int    = 0   // temp ATK modifier on enemy
    private var enemyBonusDEF:        Int    = 0
    private var enemyBonusSPD:        Int    = 0
    private var enemyBonusTurns:      Int    = 0   // countdown
    private var isEnemyCharging:      Bool   = false  // ranger Procedure
    private var isEnemyRageMode:      Bool   = false  // goose below 20%
    private var raccoonHasStolenItem: Bool   = false
    private var playerLectureTurns:   Int    = 0      // sternAdult lecture
    private var playerBonusATK:       Int    = 0
    private var playerBonusDEF:       Int    = 0      // from defend action
    private var isPlayerDefending:    Bool   = false
    private var coinMultiplier:       Double = 1.0    // vending Price Hike
    private var wingBeatLastTurn:     Int    = -10
    private var bossPhase:            Int    = 1
    private var hardhatUsed:          Bool   = false

    private let panelW: CGFloat = 760
    private let panelH: CGFloat = 580

    // MARK: - Init

    override init() {
        super.init()
        zPosition = GameConstants.ZPos.battle
        isHidden  = true
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build UI

    private func buildUI() {
        backdrop.color    = SKColor(white: 0, alpha: 0.72)
        backdrop.size     = CGSize(width: 4000, height: 4000)
        backdrop.zPosition = -1
        addChild(backdrop)

        let pr = CGRect(x: -panelW/2, y: -panelH/2, width: panelW, height: panelH)
        panel.path        = CGPath(roundedRect: pr, cornerWidth: 18, cornerHeight: 18, transform: nil)
        panel.fillColor   = SKColor(red: 0.08, green: 0.07, blue: 0.12, alpha: 0.97)
        panel.strokeColor = SKColor(red: 0.50, green: 0.42, blue: 0.78, alpha: 1)
        panel.lineWidth   = 3
        addChild(panel)

        backgroundContainer.zPosition = -0.5
        panel.addChild(backgroundContainer)

        enemyShadow.position = CGPoint(x: 220, y: enemyBaseY - 58)
        enemyShadow.alpha = 0.6
        enemyShadow.zPosition = 0.2
        panel.addChild(enemyShadow)

        enemySprite.size     = CGSize(width: 110, height: 110)
        enemySprite.position = CGPoint(x: 220, y: enemyBaseY)
        panel.addChild(enemySprite)

        enemyNameLbl.fontName               = "AvenirNext-Bold"
        enemyNameLbl.fontSize               = 18
        enemyNameLbl.fontColor              = .white
        enemyNameLbl.horizontalAlignmentMode = .left
        enemyNameLbl.position               = CGPoint(x: -panelW/2+28, y: enemyBaseY+52)
        panel.addChild(enemyNameLbl)

        enemyHPBg.anchorPoint = CGPoint(x: 0, y: 0.5)
        enemyHPBg.position    = CGPoint(x: -panelW/2+28, y: enemyBaseY+28)
        panel.addChild(enemyHPBg)
        enemyHPFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        enemyHPFill.zPosition   = 1
        enemyHPBg.addChild(enemyHPFill)

        let hpTag = label("HP", size: 13, color: SKColor(white: 0.6, alpha: 1))
        hpTag.position = CGPoint(x: -8, y: -5); hpTag.horizontalAlignmentMode = .right
        enemyHPBg.addChild(hpTag)

        let div = SKSpriteNode(color: SKColor(white: 1, alpha: 0.10),
                                size: CGSize(width: panelW-40, height: 2))
        div.position = CGPoint(x: 0, y: 64)
        panel.addChild(div)

        let lrect = CGRect(x: -panelW/2+18, y: -48, width: panelW-36, height: 100)
        logBox.path        = CGPath(roundedRect: lrect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        logBox.fillColor   = SKColor(white: 0, alpha: 0.28)
        logBox.strokeColor = SKColor(white: 1, alpha: 0.06)
        logBox.lineWidth   = 1
        panel.addChild(logBox)

        logLabel.fontName                = "AvenirNext-Medium"
        logLabel.fontSize                = 15
        logLabel.fontColor               = .white
        logLabel.numberOfLines           = 4
        logLabel.preferredMaxLayoutWidth = panelW - 50
        logLabel.horizontalAlignmentMode = .left
        logLabel.verticalAlignmentMode   = .center
        logLabel.position                = CGPoint(x: -panelW/2+30, y: 2)
        panel.addChild(logLabel)

        buildPartySlots()

        menuNode.position = CGPoint(x: 0, y: -panelH/2+68)
        panel.addChild(menuNode)
        buildMenuButtons()

        let hint = label("1 Attack · 2 Special · 3 Defend · 4 Item · 5 Flee",
                         size: 11, color: SKColor(white: 1, alpha: 0.30))
        hint.position = CGPoint(x: 0, y: -panelH/2+20)
        panel.addChild(hint)

        impactFlash.alpha = 0
        impactFlash.zPosition = 10
        addChild(impactFlash)
    }

    private func buildPartySlots() {
        let slotY: CGFloat = -148
        let spacing: CGFloat = 162
        for i in 0..<4 {
            let slot = PartySlot()
            slot.position = CGPoint(x: (CGFloat(i) - 1.5) * spacing, y: slotY)
            panel.addChild(slot)
            partySlots.append(slot)
        }
    }

    private func buildMenuButtons() {
        let defs: [(String, String, SKColor)] = [
            ("⚔️", "ATTACK",  SKColor(red: 0.85, green: 0.35, blue: 0.15, alpha: 1)),
            ("✨",  "SPECIAL", SKColor(red: 0.40, green: 0.25, blue: 0.85, alpha: 1)),
            ("🛡️", "DEFEND",  SKColor(red: 0.15, green: 0.50, blue: 0.75, alpha: 1)),
            ("🎒", "ITEM",    SKColor(red: 0.20, green: 0.60, blue: 0.30, alpha: 1)),
            ("👟", "FLEE",    SKColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1)),
        ]
        let bW: CGFloat = 120, bH: CGFloat = 48, gap: CGFloat = 10
        let total = CGFloat(defs.count)*bW + CGFloat(defs.count-1)*gap
        for (i, (g, lbl, tint)) in defs.enumerated() {
            let x = -total/2 + CGFloat(i)*(bW+gap) + bW/2
            let btn = BattleButton(glyph: g, label: lbl, tint: tint, width: bW, height: bH)
            btn.position = CGPoint(x: x, y: 0)
            menuNode.addChild(btn)
            menuButtons.append(btn)
        }
        menuButtons[0].onTap = { [weak self] in self?.playerAttack() }
        menuButtons[1].onTap = { [weak self] in self?.playerSpecial() }
        menuButtons[2].onTap = { [weak self] in self?.playerDefend() }
        menuButtons[3].onTap = { [weak self] in self?.playerItem() }
        menuButtons[4].onTap = { [weak self] in self?.playerFlee() }
    }

    private func label(_ text: String, size: CGFloat, color: SKColor = .white) -> SKLabelNode {
        let l = SKLabelNode(text: text)
        l.fontName = "AvenirNext-Medium"
        l.fontSize = size; l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode   = .center
        return l
    }

    // MARK: - Show / Hide

    func show(enemy: EnemyNode, state: GameState) {
        guard phase == .none else { return }
        currentEnemy = enemy
        gameState    = state
        phase        = .playerMenu
        resetBattleState()
        rebuildBackground(for: enemy.kind)

        enemySprite.texture = WorldSprites.texture(enemy: enemy.kind)
        enemySprite.size    = enemy.kind.isBoss ? CGSize(width: 150, height: 150) : CGSize(width: 110, height: 110)
        enemyShadow.size    = enemy.kind.isBoss ? CGSize(width: 148, height: 22) : CGSize(width: 116, height: 18)
        enemyNameLbl.text   = "\(enemy.kind.displayName)  (Lv.\(levelForEnemy(enemy)))"
        refreshEnemyHP(animated: false)
        refreshPartySlots()
        logLabel.text = "A \(enemy.kind.displayName) approaches!\nChoose an action."

        isHidden = false
        alpha = 1
        setScale(0.86)
        enemySprite.alpha = 0
        enemySprite.position = CGPoint(x: 340, y: enemyBaseY + 16)
        enemyShadow.alpha = 0
        let pop = SKAction.group([.scale(to: 1.0, duration: 0.18), .fadeIn(withDuration: 0.18)])
        pop.timingMode = .easeOut
        run(pop)
        animateBattleIntro(isBoss: enemy.kind.isBoss)
        setMenu(true)
    }

    func hide(completion: @escaping () -> Void = {}) {
        let shrink = SKAction.group([.scale(to: 0.90, duration: 0.14),
                                      .fadeOut(withDuration: 0.14)])
        run(.sequence([shrink, .run {
            self.isHidden = true; self.phase = .none
            self.currentEnemy = nil; self.gameState = nil
            completion()
        }]))
    }

    private func resetBattleState() {
        battleTurnCount      = 0
        enemyBonusATK        = 0
        enemyBonusDEF        = 0
        enemyBonusSPD        = 0
        enemyBonusTurns      = 0
        isEnemyCharging      = false
        isEnemyRageMode      = false
        raccoonHasStolenItem = false
        playerLectureTurns   = 0
        playerBonusATK       = 0
        playerBonusDEF       = 0
        isPlayerDefending    = false
        coinMultiplier       = 1.0
        wingBeatLastTurn     = -10
        bossPhase            = 1
        hardhatUsed          = false
    }

    // MARK: - Keyboard routing

    func handleKey(_ keyCode: UInt16) {
        guard phase == .playerMenu else { return }
        switch keyCode {
        case 18: playerAttack()
        case 19: playerSpecial()
        case 20: playerDefend()
        case 21: playerItem()
        case 23: playerFlee()
        default: break
        }
    }

    // MARK: - Menu state

    private func setMenu(_ on: Bool) {
        menuButtons.forEach { $0.isUserInteractionEnabled = on; $0.alpha = on ? 1 : 0.4 }
    }

    // MARK: - Damage Formula §6.2

    private struct Hit {
        let damage: Int
        let isCrit: Bool
        let isMiss: Bool
    }

    /// §6.2 full damage formula.
    private func calcHit(atk: Int, def: Int, lck: Int,
                          attackerSPD: Int, defenderSPD: Int,
                          isSpecial: Bool = false, mult: Double = 1.0,
                          ignoresDEF: Bool = false) -> Hit {
        // Miss (physical only)
        if !isSpecial && !ignoresDEF {
            let speedRatio = Double(defenderSPD) / Double(max(attackerSPD, 1))
            let missChance = max(0.03, min(0.25, speedRatio * 0.15))
            if Double.random(in: 0...1) < missChance {
                return Hit(damage: 0, isCrit: false, isMiss: true)
            }
        }
        // Crit (LCK/100)
        let critThreshold = Double(lck) / 100.0
        let isCrit = Double.random(in: 0...1) < critThreshold
        // Base
        let effectiveDEF = ignoresDEF ? 0 : def / 2
        let effective = max(1, atk - effectiveDEF)
        let variance  = Double.random(in: 0.88...1.12)
        let critMult  = isCrit ? 1.75 : 1.0
        let raw = Double(effective) * variance * critMult * mult
        return Hit(damage: max(1, Int(raw)), isCrit: isCrit, isMiss: false)
    }

    // MARK: - Player Actions

    private func playerAttack() {
        guard phase == .playerMenu,
              let enemy = currentEnemy,
              let state = gameState else { return }
        phase = .animating; setMenu(false)

        let member = state.activeMember
        // Defend clears on action
        isPlayerDefending = false
        playerBonusDEF    = 0

        // Lecture: player deals half damage
        let lectureActive = playerLectureTurns > 0

        let hit = calcHit(atk: member.atk + playerBonusATK,
                          def: enemy.kind.defense + enemyBonusDEF,
                          lck: member.lck,
                          attackerSPD: member.spd,
                          defenderSPD: enemy.kind.battleSPD + enemyBonusSPD)
        let finalDmg = lectureActive ? max(1, hit.damage / 2) : hit.damage
        if playerLectureTurns > 0 { playerLectureTurns -= 1 }

        var msg = "\(member.species.displayName) attacks!"
        if hit.isMiss          { msg += "\nMiss! The attack went wide." }
        else if hit.isCrit     { msg += "\nCritical hit! \(finalDmg) damage!" }
        else if lectureActive  { msg += "\nDealt \(finalDmg) damage (half — still lecturing)." }
        else                   { msg += "\nDealt \(finalDmg) damage." }

        showLog(msg) {
            if !hit.isMiss {
                self.animatePlayerStrike()
                self.flashEnemy()
                let defeated = enemy.takeDamage(finalDmg)
                self.refreshEnemyHP(animated: true)
                self.checkBossPhaseTransition(enemy: enemy)
                if defeated { self.doVictory(enemy) } else { self.startEnemyTurn() }
            } else {
                self.animatePlayerFeint()
                self.startEnemyTurn()
            }
        }
    }

    private func playerSpecial() {
        guard phase == .playerMenu,
              let enemy = currentEnemy,
              let state = gameState else { return }

        let member  = state.activeMember
        let ppCost  = member.species.specialPPCost
        guard member.pp >= ppCost else {
            showLog("Not enough PP for \(member.species.specialName)!\n(Need \(ppCost) PP, have \(member.pp))") {
                self.phase = .playerMenu; self.setMenu(true)
            }
            return
        }

        phase = .animating; setMenu(false)
        state.party[state.activeIndex].pp -= ppCost
        isPlayerDefending = false
        playerBonusDEF    = 0
        refreshPartySlots()

        switch member.species {

        case .turtle:   // Shell Slam §7.1 Lv3
            let hit = calcHit(atk: member.atk + playerBonusATK, def: enemy.kind.defense + enemyBonusDEF,
                              lck: member.lck, attackerSPD: member.spd, defenderSPD: enemy.kind.battleSPD,
                              isSpecial: true, mult: 1.4)
            if hit.isMiss {
                showLog("Shell Slam! 🐢\nShelly overbalanced — miss!") {
                    self.animatePlayerFeint()
                    self.startEnemyTurn()
                }
            } else {
                let recoil = 1
                showLog("Shell Slam! 💥 \(hit.damage) damage!\n(Shelly takes \(recoil) recoil)") {
                    self.animatePlayerStrike(heavy: true)
                    self.flashEnemy()
                    _ = enemy.takeDamage(hit.damage)
                    state.party[state.activeIndex].hp = max(0, state.party[state.activeIndex].hp - recoil)
                    self.refreshEnemyHP(animated: true)
                    self.refreshPartySlots()
                    self.checkBossPhaseTransition(enemy: enemy)
                    if enemy.isDead { self.doVictory(enemy) } else { self.startEnemyTurn() }
                }
            }

        case .squirrel: // Acorn Toss §7.1 Lv1 — inflicts Distraction 35%
            let hit = calcHit(atk: member.atk + playerBonusATK, def: enemy.kind.defense + enemyBonusDEF,
                              lck: member.lck, attackerSPD: member.spd, defenderSPD: enemy.kind.battleSPD,
                              isSpecial: false, mult: 1.0)
            let distracted = Double.random(in: 0...1) < 0.35
            var msg = "Acorn Toss! 🌰\n\(hit.isMiss ? "Miss!" : "Dealt \(hit.damage) damage.")"
            if distracted && !hit.isMiss { msg += "\nEnemy is Distracted!" }
            showLog(msg) {
                if !hit.isMiss {
                    self.animateProjectileArc()
                    self.flashEnemy()
                    _ = enemy.takeDamage(hit.damage)
                    if distracted { self.enemyBonusSPD -= 4; self.enemyBonusTurns = max(self.enemyBonusTurns, 2) }
                    self.refreshEnemyHP(animated: true)
                    self.checkBossPhaseTransition(enemy: enemy)
                } else {
                    self.animatePlayerFeint()
                }
                if enemy.isDead { self.doVictory(enemy) } else { self.startEnemyTurn() }
            }

        case .hedgehog: // Curl & Roll §7.1 Lv5 — AoE 1.6×, Distraction 20%
            let hit = calcHit(atk: member.atk + playerBonusATK, def: enemy.kind.defense + enemyBonusDEF,
                              lck: member.lck, attackerSPD: member.spd, defenderSPD: enemy.kind.battleSPD,
                              isSpecial: true, mult: 1.6)
            showLog("Curl & Roll! ⭐️\nSpike hits for \(hit.damage) damage!") {
                self.animatePlayerStrike(heavy: true)
                self.flashEnemy()
                _ = enemy.takeDamage(hit.damage)
                self.refreshEnemyHP(animated: true)
                self.checkBossPhaseTransition(enemy: enemy)
                if enemy.isDead { self.doVictory(enemy) } else { self.startEnemyTurn() }
            }

        case .hamster:
            resolveChaosToss(with: member, against: enemy, state: state)
        }
    }

    private func playerDefend() {
        guard phase == .playerMenu, let state = gameState else { return }
        phase = .animating; setMenu(false)
        isPlayerDefending = true
        playerBonusDEF    = state.activeMember.def  // effectively DEF *1.8 approximated as +def bonus

        let name = state.activeMember.species.displayName
        showLog("\(name) takes a defensive stance!\nDEF ×1.8 until next turn.") {
            self.startEnemyTurn()
        }
    }

    private func playerItem() {
        guard phase == .playerMenu,
              let state = gameState else { return }
        phase = .animating; setMenu(false)
        isPlayerDefending = false
        playerBonusDEF    = 0

        let idx = state.activeIndex
        if useFirstAvailableItem(in: state, memberIndex: idx) {
            refreshPartySlots()
            showLog(logLabel.text ?? "Used an item.") { self.startEnemyTurn() }
        } else {
            showLog("No usable items in the bag! 🎒") {
                self.phase = .playerMenu; self.setMenu(true)
            }
        }
    }

    private func playerFlee() {
        guard phase == .playerMenu,
              let state = gameState,
              let enemy = currentEnemy else { return }
        phase = .animating; setMenu(false)
        isPlayerDefending = false
        playerBonusDEF    = 0

        // Goose / Gerald: immune to flee
        if enemy.kind == .goose || enemy.kind == .grandGooseGerald {
            showLog("Can't flee! The goose has decided this is a permanent arrangement.") {
                self.startEnemyTurn()
            }
            return
        }

        // §6.5 flee formula
        let alive = state.party.filter(\.isAlive)
        let avgSpd = alive.isEmpty ? 1 : alive.map(\.spd).reduce(0, +) / alive.count
        var fleeChance = Double(avgSpd) / Double(avgSpd + enemy.kind.battleSPD) * 0.85
        fleeChance = max(0.10, min(0.90, fleeChance))
        if state.party[state.activeIndex].isEmbarrassed { fleeChance *= 0.5 }

        if Double.random(in: 0...1) < fleeChance {
            showLog("Got away safely! 👟") { self.phase = .fled; self.hide { self.onFled?() } }
        } else {
            showLog("Can't flee! 😱") { self.startEnemyTurn() }
        }
    }

    // MARK: - Enemy Turn

    private func startEnemyTurn() {
        guard let enemy = currentEnemy,
              let state = gameState else { return }
        phase = .enemyTurn
        battleTurnCount += 1

        // Decay enemy buffs
        if enemyBonusTurns > 0 {
            enemyBonusTurns -= 1
            if enemyBonusTurns == 0 {
                enemyBonusATK = 0; enemyBonusDEF = 0; enemyBonusSPD = 0
            }
        }

        // Status ticks on active member
        var statusMsg = ""
        let idx = state.activeIndex
        if state.party[idx].isPoisoned {
            let dmg = max(1, Int(ceil(Double(state.party[idx].maxHP) * 0.08)))
            state.party[idx].hp = max(0, state.party[idx].hp - dmg)
            statusMsg += "\n💚 \(state.party[idx].species.displayName) takes \(dmg) poison damage!"
        }
        if state.party[idx].isBadlyPoisoned {
            let dmg = max(1, Int(ceil(Double(state.party[idx].maxHP) * 0.12)))
            state.party[idx].hp = max(0, state.party[idx].hp - dmg)
            statusMsg += "\n☣️ Severe poison! \(dmg) damage!"
        }
        if state.party[idx].isAsleep {
            if Double.random(in: 0...1) < 0.40 {
                state.party[idx].statusEffects.remove(.sleep)
                statusMsg += "\n\(state.party[idx].species.displayName) woke up!"
            }
        }

        refreshPartySlots()

        // Fear skip (30%)
        if state.party[idx].isAfraid, Double.random(in: 0...1) < 0.30 {
            let msg = "\(state.party[idx].species.displayName) is too afraid to act!\(statusMsg)"
            showLog(msg) { self.afterEnemyAction(state: state) }
            return
        }

        // Sleep skip
        if state.party[idx].isAsleep {
            let msg = "\(state.party[idx].species.displayName) is fast asleep!\(statusMsg)"
            showLog(msg) { self.afterEnemyAction(state: state) }
            return
        }

        // Goose Rage Mode (below 20%)
        if (enemy.kind == .goose || enemy.kind == .grandGooseGerald) &&
           !isEnemyRageMode &&
           Double(enemy.hp) / Double(enemy.kind.maxHP) < 0.20 {
            isEnemyRageMode = true
            enemyBonusATK += 8; enemyBonusSPD += 5; enemyBonusTurns = 9999
            showLog("The goose enters RAGE MODE!\nATK +8, SPD +5.\(statusMsg)") {
                self.executeEnemyAction(enemy: enemy, state: state, preMsg: "")
            }
            return
        }

        executeEnemyAction(enemy: enemy, state: state, preMsg: statusMsg)
    }

    private func executeEnemyAction(enemy: EnemyNode, state: GameState, preMsg: String) {
        let playerHPFrac = state.party.filter(\.isAlive)
            .map { Double($0.hp) / Double($0.maxHP) }.min() ?? 1.0
        let ctx = EnemyKind.ActionContext(
            playerHPFraction: playerHPFrac,
            hasStolenItem: raccoonHasStolenItem,
            isCharging: isEnemyCharging,
            bossPhase: bossPhase,
            turn: battleTurnCount,
            wingBeatLastTurn: wingBeatLastTurn
        )

        let choice = enemy.kind.selectAction(ctx)

        // Hardhat is one-use
        if case .flatDamage = choice.action, enemy.kind == .foremanRex, bossPhase == 2, hardhatUsed {
            let fallback = EnemyActionChoice(weight: 1,
                action: .aoeFlat(20), name: "Demo Order",
                message: "Rex keeps hammering. Demo Order never ends.")
            dispatchEnemyAction(fallback, enemy: enemy, state: state, preMsg: preMsg)
            return
        }
        if choice.name == "Hardhat Throw" { hardhatUsed = true }

        dispatchEnemyAction(choice, enemy: enemy, state: state, preMsg: preMsg)
    }

    private func dispatchEnemyAction(_ choice: EnemyActionChoice,
                                      enemy: EnemyNode, state: GameState, preMsg: String) {
        let eName = enemy.kind.displayName
        let targetIdx = bestTarget(state: state)
        let target    = state.party[targetIdx]

        switch choice.action {

        // ── Physical attack ────────────────────────────────────────────────────
        case .attack(let mult, let inflictStatus, let statusChance):
            if isEnemyCharging {
                isEnemyCharging = false
            }
            let skipDueWingBeat = (choice.name == "Wing Beat")
            if choice.name == "Wing Beat" { wingBeatLastTurn = battleTurnCount }

            let hit = calcHit(
                atk: enemy.kind.attackPower + enemyBonusATK,
                def: target.def + playerBonusDEF,
                lck: enemy.kind.battleLCK,
                attackerSPD: enemy.kind.battleSPD + enemyBonusSPD,
                defenderSPD: target.spd,
                mult: mult)
            let dmg = resolvePlayerDamageTaken(hit.damage, target: target, idx: targetIdx)
            var msg = "\(eName) uses \(choice.name)!\n\(choice.message)"
            if hit.isMiss { msg += "\nMiss!" }
            else if hit.isCrit { msg += "\nCritical! \(dmg) damage!" }
            else { msg += "\n\(dmg) damage." }
            if let se = inflictStatus, !hit.isMiss {
                if Double.random(in: 0...1) < statusChance,
                   !enemy.kind.immunities.contains(se) {
                    state.party[targetIdx].applyStatus(se)
                    msg += "\n\(target.species.displayName) became \(se.displayName)!"
                }
            }
            msg += preMsg
            showLog(msg) {
                if !hit.isMiss {
                    self.animateEnemyStrike()
                    self.flashParty()
                    state.party[targetIdx].hp = max(0, state.party[targetIdx].hp - dmg)
                    self.refreshPartySlots()
                }
                self.afterEnemyAction(state: state)
            }

        // ── AoE physical ───────────────────────────────────────────────────────
        case .aoeAttack(let mult):
            var totalMsg = "\(eName) uses \(choice.name)!\n\(choice.message)"
            showLog(totalMsg + preMsg) {
                self.animateEnemyStrike(heavy: true)
                for i in state.party.indices where state.party[i].isAlive {
                    let hit = self.calcHit(
                        atk: enemy.kind.attackPower + self.enemyBonusATK,
                        def: state.party[i].def + self.playerBonusDEF,
                        lck: enemy.kind.battleLCK,
                        attackerSPD: enemy.kind.battleSPD,
                        defenderSPD: state.party[i].spd,
                        mult: mult * 0.7)
                    let dmg = self.resolvePlayerDamageTaken(hit.damage, target: state.party[i], idx: i)
                    state.party[i].hp = max(0, state.party[i].hp - dmg)
                }
                self.flashParty()
                self.refreshPartySlots()
                self.afterEnemyAction(state: state)
            }

        // ── Flat damage ────────────────────────────────────────────────────────
        case .flatDamage(let amount, let ignoresDEF):
            let actualDef = ignoresDEF ? 0 : (target.def + playerBonusDEF) / 2
            let dmg = resolvePlayerDamageTaken(max(1, amount - actualDef), target: target, idx: targetIdx)
            let msg = "\(eName) uses \(choice.name)!\n\(choice.message)\n\(dmg) damage.\(preMsg)"
            showLog(msg) {
                self.animateEnemyStrike()
                self.flashParty()
                state.party[targetIdx].hp = max(0, state.party[targetIdx].hp - dmg)
                self.refreshPartySlots()
                self.afterEnemyAction(state: state)
            }

        // ── AoE flat ───────────────────────────────────────────────────────────
        case .aoeFlat(let amount):
            let msg = "\(eName) uses \(choice.name)!\n\(choice.message)\n\(amount) flat damage to all.\(preMsg)"
            showLog(msg) {
                self.animateEnemyStrike(heavy: true)
                for i in state.party.indices where state.party[i].isAlive {
                    state.party[i].hp = max(0, state.party[i].hp - amount)
                }
                self.flashParty()
                self.refreshPartySlots()
                self.afterEnemyAction(state: state)
            }

        // ── AoE status ─────────────────────────────────────────────────────────
        case .aoeStatus(let se, let chance):
            var applied = 0
            for i in state.party.indices where state.party[i].isAlive {
                if Double.random(in: 0...1) < chance {
                    state.party[i].applyStatus(se)
                    applied += 1
                }
            }
            let seMsg = applied > 0 ? "Applied \(se.displayName) to \(applied) member(s)." : "Status missed."
            showLog("\(eName) uses \(choice.name)!\n\(choice.message)\n\(seMsg)\(preMsg)") {
                self.refreshPartySlots()
                self.afterEnemyAction(state: state)
            }

        // ── Steal ──────────────────────────────────────────────────────────────
        case .steal:
            if let stolenKey = state.inventory.keys.randomElement() {
                state.inventory[stolenKey]! -= 1
                if state.inventory[stolenKey]! <= 0 { state.inventory.removeValue(forKey: stolenKey) }
                raccoonHasStolenItem = true
                showLog("\(eName) uses \(choice.name)!\n\(choice.message)\nStole your \(stolenKey.displayName)! Raccoon looks pleased.\(preMsg)") {
                    self.refreshPartySlots()
                    self.afterEnemyAction(state: state)
                }
            } else {
                let dmg = 1
                showLog("\(eName) uses \(choice.name)!\nYou had nothing to steal. 1 damage from disappointment.\(preMsg)") {
                    state.party[targetIdx].hp = max(0, state.party[targetIdx].hp - dmg)
                    self.refreshPartySlots()
                    self.afterEnemyAction(state: state)
                }
            }

        // ── Self buff ──────────────────────────────────────────────────────────
        case .selfBuff(let atk, let def, let spd, let turns):
            enemyBonusATK  += atk
            enemyBonusDEF  += def
            enemyBonusSPD  += spd
            enemyBonusTurns = max(enemyBonusTurns, turns)
            var buffDesc = ""
            if atk != 0 { buffDesc += "ATK +\(atk) " }
            if def != 0 { buffDesc += "DEF +\(def) " }
            if spd != 0 { buffDesc += "SPD +\(spd) " }
            showLog("\(eName) uses \(choice.name)!\n\(choice.message)\n\(buffDesc.isEmpty ? "" : buffDesc.trimmingCharacters(in: .whitespaces))\(preMsg)") {
                self.afterEnemyAction(state: state)
            }

        // ── Target debuff ──────────────────────────────────────────────────────
        case .targetDebuff(let atk, let def, _):
            playerBonusATK -= atk
            showLog("\(eName) uses \(choice.name)!\n\(choice.message)\(preMsg)") {
                self.afterEnemyAction(state: state)
            }

        // ── Self heal ──────────────────────────────────────────────────────────
        case .selfHeal(let amount):
            enemy.healHP(amount)
            refreshEnemyHP(animated: true)
            showLog("\(eName) uses \(choice.name)!\n\(choice.message)\nEnemy recovered \(amount) HP.\(preMsg)") {
                self.afterEnemyAction(state: state)
            }

        // ── Self damage ────────────────────────────────────────────────────────
        case .selfDamage(let amount):
            let died = enemy.takeDamage(amount)
            refreshEnemyHP(animated: true)
            showLog("\(eName) uses \(choice.name)!\n\(choice.message)\nTook \(amount) self-damage.\(preMsg)") {
                if died { self.doVictory(enemy) } else { self.afterEnemyAction(state: state) }
            }

        // ── Lecture ────────────────────────────────────────────────────────────
        case .halfDamageLecture:
            playerLectureTurns = 2
            showLog("\(eName) uses \(choice.name)!\n\(choice.message)\nYour attacks deal half damage for 2 turns.\(preMsg)") {
                self.afterEnemyAction(state: state)
            }

        // ── Charge ─────────────────────────────────────────────────────────────
        case .charge:
            isEnemyCharging = true
            showLog("\(eName) is filling out a form…\n(Next turn: ATK ×2)\(preMsg)") {
                self.afterEnemyAction(state: state)
            }

        // ── Give item ─────────────────────────────────────────────────────────
        case .givePlayerItem:
            state.inventory[.warmCola, default: 0] += 1
            showLog("\(eName) uses \(choice.name)!\n\(choice.message)\nYou received a Warm Cola!\(preMsg)") {
                self.refreshPartySlots()
                self.afterEnemyAction(state: state)
            }

        // ── Coin debuff ────────────────────────────────────────────────────────
        case .coinDebuff:
            coinMultiplier = 0.5
            showLog("\(eName) uses \(choice.name)!\n\(choice.message)\(preMsg)") {
                self.afterEnemyAction(state: state)
            }

        // ── Enemy flee ─────────────────────────────────────────────────────────
        case .enemyFlee:
            if Double.random(in: 0...1) < 0.30 {
                showLog("\(eName) just… leaves. Battle over. No reward.\(preMsg)") {
                    self.phase = .fled; self.hide { self.onFled?() }
                }
            } else {
                showLog("\(eName) considered leaving. They're still there.\(preMsg)") {
                    self.afterEnemyAction(state: state)
                }
            }

        // ── Nothing ────────────────────────────────────────────────────────────
        case .nothing:
            showLog("\(eName) uses \(choice.name)!\n\(choice.message)\(preMsg)") {
                self.afterEnemyAction(state: state)
            }
        }
    }

    private func afterEnemyAction(state: GameState) {
        refreshPartySlots()
        if state.isGameOver {
            showLog("The party fainted… 💤") {
                self.phase = .defeat; self.hide { self.onDefeat?() }
            }
        } else {
            isPlayerDefending = false
            playerBonusDEF    = 0
            phase = .playerMenu
            setMenu(true)
            logLabel.text = "What will you do?"
        }
    }

    // MARK: - Damage helpers

    private func resolvePlayerDamageTaken(_ rawDmg: Int, target: PartyMember, idx: Int) -> Int {
        var dmg = rawDmg
        if target.isEmbarrassed { dmg = Int(Double(dmg) * 1.25) }
        if isPlayerDefending {
            if Double.random(in: 0...1) < 0.30 {
                return 0  // full block
            }
            dmg = Int(Double(dmg) * 0.45)
        }
        return max(1, dmg)
    }

    private func bestTarget(state: GameState) -> Int {
        state.party.indices
            .filter { state.party[$0].isAlive }
            .min(by: { state.party[$0].hp < state.party[$1].hp }) ?? state.activeIndex
    }

    // MARK: - Boss phase check

    private func checkBossPhaseTransition(enemy: EnemyNode) {
        guard enemy.kind.isBoss, bossPhase == 1 else { return }
        guard enemy.hp <= enemy.kind.bossPhase2HPThreshold else { return }
        bossPhase = 2
        let lines: [EnemyKind: String] = [
            .grandGooseGerald: "\"HONK.\"",
            .officerGrumble:   "\"This... is personal now.\"",
            .foremanRex:       "\"I've been building this park for 30 years. You're not going to tell me what's under it.\""
        ]
        let dialogue = lines[enemy.kind] ?? "The enemy enters phase 2!"
        showLog(dialogue, delay: 2.5) {}
    }

    // MARK: - Victory + Level-ups

    private func doVictory(_ enemy: EnemyNode) {
        guard let state = gameState else { return }

        let expGain  = enemy.kind.expReward
        let scorePts = enemy.kind.defeatScore
        let coinGain = Int(Double(Int.random(in: enemy.kind.coinRange)) * coinMultiplier)
        state.coins += coinGain

        showLog("\(enemy.kind.displayName) was defeated! ✨\n+\(scorePts) pts  +\(expGain) EXP  +\(coinGain) 🪙") {
            state.defeatEnemy(kind: enemy.kind, coinMultiplier: 0) // coins already added
            let levelUps = state.pendingLevelUps
            state.pendingLevelUps.removeAll()
            self.displayLevelUps(levelUps) {
                self.phase = .victory
                self.hide { self.onVictory?(enemy.kind) }
            }
        }
    }

    private func displayLevelUps(_ ups: [(name: String, level: Int, summary: String)],
                                   completion: @escaping () -> Void) {
        guard !ups.isEmpty else { completion(); return }
        var remaining = ups
        func next() {
            guard !remaining.isEmpty else { completion(); return }
            let lu = remaining.removeFirst()
            logLabel.text = "⭐ \(lu.name) reached Lv.\(lu.level)!\n\(lu.summary)"
            run(.wait(forDuration: 1.9)) { next() }
        }
        next()
    }

    // MARK: - HP bar animations

    private func refreshEnemyHP(animated: Bool) {
        guard let enemy = currentEnemy else { return }
        let frac = max(0, CGFloat(enemy.hp) / CGFloat(enemy.kind.maxHP))
        let targetW = frac * 200
        if animated {
            let current = enemyHPFill.size.width
            let duration = max(0.25, Double(abs(current - targetW)) / 200.0 * 0.9)
            let tick = SKAction.customAction(withDuration: duration) { node, t in
                let p = min(t / CGFloat(duration), 1)
                (node as? SKSpriteNode)?.size.width = current + (targetW - current) * p
            }
            enemyHPFill.run(tick)
        } else {
            enemyHPFill.size.width = targetW
        }
        enemyHPFill.color = frac > 0.5 ? .green : (frac > 0.25 ? .yellow : .red)
    }

    private func refreshPartySlots() {
        guard let state = gameState else { return }
        for (i, slot) in partySlots.enumerated() {
            if i < state.party.count {
                slot.configure(member: state.party[i], isActive: i == state.activeIndex)
            } else { slot.hide() }
        }
    }

    // MARK: - Flash effects

    private func flashEnemy() {
        pulseImpactFlash(alpha: 0.14)
        enemySprite.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 0.9, duration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0.15),
            .moveBy(x: -8, y: 0, duration: 0.04), .moveBy(x: 16, y: 0, duration: 0.06),
            .moveBy(x: -8, y: 0, duration: 0.04),
        ]))
    }

    private func flashParty() {
        pulseImpactFlash(alpha: 0.10)
        partySlots.forEach { slot in
            slot.run(.sequence([
                .colorize(with: .red, colorBlendFactor: 0.7, duration: 0.06),
                .colorize(withColorBlendFactor: 0, duration: 0.20)
            ]))
        }
    }

    // MARK: - Log helper

    private func showLog(_ text: String, delay: TimeInterval = 1.1,
                          completion: @escaping () -> Void) {
        logLabel.text = text
        run(.sequence([.wait(forDuration: delay), .run(completion)]))
    }

    private func rebuildBackground(for kind: EnemyKind) {
        backgroundContainer.removeAllChildren()
        let bg = kind.battleBackground.buildNode(size: CGSize(width: panelW - 8, height: panelH - 8))
        bg.position = CGPoint(x: -4, y: -4)
        bg.alpha = 0.92
        backgroundContainer.addChild(bg)
        let drift = SKAction.sequence([
            .moveBy(x: -10, y: 0, duration: 2.2),
            .moveBy(x: 10, y: 0, duration: 2.2)
        ])
        bg.run(.repeatForever(drift))
    }

    // MARK: - Item use

    private func useFirstAvailableItem(in state: GameState, memberIndex idx: Int) -> Bool {
        let member = state.party[idx]

        // Priority 1 — antidote if poisoned (cure before anything else)
        if (member.isPoisoned || member.isBadlyPoisoned),
           (state.inventory[.antidote] ?? 0) > 0 {
            consumeItem(.antidote, from: state)
            state.party[idx].clearStatus(.poison)
            state.party[idx].clearStatus(.strongPoison)
            logLabel.text = "Used an Antidote! 🧴\nPoison cured."
            return true
        }

        // Priority 2 — energy drink if PP is critically low (< 1/3 max)
        if member.pp < member.maxPP / 3,
           (state.inventory[.energyDrink] ?? 0) > 0 {
            consumeItem(.energyDrink, from: state)
            let ppGain = min(member.maxPP - member.pp, ItemKind.energyDrink.healPP)
            let hpGain = min(member.maxHP - member.hp, ItemKind.energyDrink.healHP)
            state.party[idx].pp += ppGain
            state.party[idx].hp += hpGain
            logLabel.text = "Used an Energy Drink! 🥤\n+\(ppGain) PP and +\(hpGain) HP."
            return true
        }

        // Priority 3 — HP restoration via ItemKind.healHP (single source of truth)
        // Order from weakest to strongest so we don't waste premium items.
        let hpHealers: [ItemKind] = [
            .parkWater, .staleChip, .warmCola, .berry,
            .granolaBar, .juiceBox, .comfortSnack, .superBerry, .megaBerry
        ]
        let hpMissing = member.maxHP - member.hp

        for kind in hpHealers {
            guard (state.inventory[kind] ?? 0) > 0 else { continue }
            // Don't waste a premium heal (>35 HP) when already near-full
            if kind.healHP > 35 && hpMissing < 15 { continue }
            // Don't waste megaBerry if not seriously hurt
            if kind == .megaBerry && hpMissing < 30 { continue }

            consumeItem(kind, from: state)
            let hpGain = min(hpMissing, kind.healHP)
            state.party[idx].hp += hpGain

            var msg = "Used \(kind.emoji) \(kind.displayName)!\n+\(hpGain) HP"
            if kind.healPP > 0 {
                let ppGain = min(member.maxPP - member.pp, kind.healPP)
                state.party[idx].pp += ppGain
                msg += " and +\(ppGain) PP"
            }
            if kind == .megaBerry && hpMissing >= member.maxHP {
                msg = "Used a Mega Berry! ✨\nFully restored HP!"
            }
            logLabel.text = msg + "."
            return true
        }

        // Priority 4 — mystery bag (random effect)
        if (state.inventory[.mysteryBag] ?? 0) > 0 {
            consumeItem(.mysteryBag, from: state)
            return useMysteryBag(state: state, idx: idx)
        }

        return false
    }

    private func consumeItem(_ kind: ItemKind, from state: GameState) {
        guard let count = state.inventory[kind], count > 0 else { return }
        state.inventory[kind] = count - 1
        if state.inventory[kind] == 0 { state.inventory.removeValue(forKey: kind) }
    }

    private func useMysteryBag(state: GameState, idx: Int) -> Bool {
        let roll = Int.random(in: 0...3)
        switch roll {
        case 0:
            let gain = min(state.party[idx].maxHP - state.party[idx].hp, 40)
            state.party[idx].hp += gain
            logLabel.text = "Mystery Bag! 🛍️\nSomething tasty. +\(gain) HP."
        case 1:
            let gain = min(state.party[idx].maxPP - state.party[idx].pp, 15)
            state.party[idx].pp += gain
            state.healParty(hp: 8)
            logLabel.text = "Mystery Bag! 🛍️\nFizzy feeling. +\(gain) PP, party +8 HP."
        case 2:
            // Temp ATK boost
            playerBonusATK = max(playerBonusATK, state.activeMember.atk / 3)
            logLabel.text = "Mystery Bag! 🛍️\nEnergized! ATK boosted this battle."
        default:
            // Heal party small amount
            state.healParty(hp: 12)
            logLabel.text = "Mystery Bag! 🛍️\nSmells like sunscreen. Everyone +12 HP."
        }
        return true
    }

    // MARK: - Chaos Toss (Pip §7.1)

    private func resolveChaosToss(with member: PartyMember, against enemy: EnemyNode, state: GameState) {
        // Weighted d10 from spec §7.2 — LCK shifts roll
        var roll = Int.random(in: 1...10)
        let lckBonus = max(0, (member.lck - 10) / 10)
        roll = min(10, roll + lckBonus)

        switch roll {
        case 1:
            let dmg = max(1, Int(Double(member.atk + playerBonusATK) * 2.5))
            showLog("Chaos Toss! 🎲\nPip nailed the best outcome.\n\(dmg) damage!") {
                self.flashEnemy()
                _ = enemy.takeDamage(dmg)
                self.refreshEnemyHP(animated: true)
                self.checkBossPhaseTransition(enemy: enemy)
                if enemy.isDead { self.doVictory(enemy) } else { self.startEnemyTurn() }
            }
        case 2:
            let dmg = max(1, Int(Double(member.atk + playerBonusATK) * 0.8))
            showLog("Chaos Toss! 🎲\nSmall damage. \(dmg) damage.") {
                self.flashEnemy()
                _ = enemy.takeDamage(dmg)
                self.refreshEnemyHP(animated: true)
                if enemy.isDead { self.doVictory(enemy) } else { self.startEnemyTurn() }
            }
        case 3:
            let heal = max(1, state.party[state.activeIndex].maxHP / 4)
            state.party[state.activeIndex].hp = min(state.party[state.activeIndex].maxHP,
                                                    state.party[state.activeIndex].hp + heal)
            refreshPartySlots()
            showLog("Chaos Toss! 🎲\nPip somehow healed himself. +\(heal) HP.") {
                self.startEnemyTurn()
            }
        case 4:
            let heal = max(1, state.party[state.activeIndex].maxHP / 8)
            state.healParty(hp: heal)
            refreshPartySlots()
            showLog("Chaos Toss! 🎲\nEveryone feels slightly better. +\(heal) HP.") {
                self.startEnemyTurn()
            }
        case 5:
            for i in state.party.indices where state.party[i].isAlive {
                state.party[i].applyStatus(.confusion)
            }
            showLog("Chaos Toss! 🎲\nAll enemies confused. (They're all confused. Pip included.)") {
                self.startEnemyTurn()
            }
        case 6:
            state.party[state.activeIndex].applyStatus(.sleep)
            refreshPartySlots()
            showLog("Chaos Toss! 🎲\nPip fell asleep mid-technique.") {
                self.startEnemyTurn()
            }
        case 7:
            for i in state.party.indices { state.party[i].atk += 6 }
            showLog("Chaos Toss! 🎲\nEveryone feels dangerously confident. ATK +6.") {
                self.startEnemyTurn()
            }
        case 8:
            state.inventory[.mysteryBag, default: 0] += 1
            showLog("Chaos Toss! 🎲\nPip found something in his cheeks.") {
                self.startEnemyTurn()
            }
        case 9:
            coinMultiplier *= 2.0
            showLog("Chaos Toss! 🎲\nCoin reward this battle is doubled!") {
                self.startEnemyTurn()
            }
        default:
            showLog("Chaos Toss! 🎲\nNothing happens. Pip still looks around.") {
                self.startEnemyTurn()
            }
        }
    }

    // MARK: - Misc helpers

    private func levelForEnemy(_ enemy: EnemyNode) -> Int {
        max(1, enemy.kind.maxHP / 8)
    }

    private func animateBattleIntro(isBoss: Bool) {
        let target = enemySprite.position
        let settle = CGPoint(x: 220, y: target.y - 16)
        enemySprite.run(.group([
            .fadeIn(withDuration: 0.18),
            .move(to: settle, duration: isBoss ? 0.32 : 0.24),
            .scale(to: 1.0, duration: 0.24)
        ]))
        enemyShadow.run(.fadeAlpha(to: 0.6, duration: 0.20))
        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 6, duration: 0.9),
            .moveBy(x: 0, y: -6, duration: 0.9)
        ])
        bob.timingMode = .easeInEaseOut
        enemySprite.run(.repeatForever(bob), withKey: "enemyBob")
    }

    private func animatePlayerStrike(heavy: Bool = false) {
        let shake = heavy ? 18.0 : 10.0
        panel.run(.sequence([
            .moveBy(x: -shake, y: 0, duration: 0.03),
            .moveBy(x: shake * 2, y: 0, duration: 0.05),
            .moveBy(x: -shake, y: 0, duration: 0.03)
        ]))
        partySlots.forEach { slot in
            slot.run(.sequence([
                .moveBy(x: 0, y: heavy ? 12 : 8, duration: 0.06),
                .moveBy(x: 0, y: heavy ? -12 : -8, duration: 0.08)
            ]))
        }
    }

    private func animatePlayerFeint() {
        partySlots.forEach { slot in
            slot.run(.sequence([
                .moveBy(x: 0, y: 6, duration: 0.05),
                .moveBy(x: 0, y: -6, duration: 0.08)
            ]))
        }
    }

    private func animateProjectileArc() {
        let pellet = SKSpriteNode(color: SKColor(red: 0.73, green: 0.52, blue: 0.22, alpha: 1),
                                  size: CGSize(width: 14, height: 14))
        pellet.position = CGPoint(x: -180, y: -148)
        pellet.zPosition = 4
        panel.addChild(pellet)
        let path = CGMutablePath()
        path.move(to: pellet.position)
        path.addQuadCurve(to: CGPoint(x: 210, y: 118), control: CGPoint(x: 20, y: 210))
        pellet.run(.sequence([
            .group([
                .follow(path, asOffset: false, orientToPath: false, duration: 0.24),
                .rotate(byAngle: .pi * 2, duration: 0.24)
            ]),
            .removeFromParent()
        ]))
    }

    private func animateEnemyStrike(heavy: Bool = false) {
        enemySprite.removeAction(forKey: "enemyBob")
        let original = CGPoint(x: 220, y: enemySprite.position.y)
        enemySprite.run(.sequence([
            .moveBy(x: heavy ? -34 : -22, y: 0, duration: 0.08),
            .move(to: original, duration: 0.12)
        ]))
        partySlots.forEach { slot in
            slot.run(.sequence([
                .moveBy(x: heavy ? -14 : -8, y: 0, duration: 0.05),
                .moveBy(x: heavy ? 14 : 8, y: 0, duration: 0.08)
            ]))
        }
        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 6, duration: 0.9),
            .moveBy(x: 0, y: -6, duration: 0.9)
        ])
        bob.timingMode = .easeInEaseOut
        enemySprite.run(.repeatForever(bob), withKey: "enemyBob")
    }

    private func pulseImpactFlash(alpha: CGFloat) {
        impactFlash.removeAllActions()
        impactFlash.alpha = 0
        impactFlash.run(.sequence([
            .fadeAlpha(to: alpha, duration: 0.04),
            .fadeOut(withDuration: 0.10)
        ]))
    }
}

// MARK: - PartySlot

@MainActor
private final class PartySlot: SKNode {
    private let sprite  = SKSpriteNode()
    private let nameL   = SKLabelNode()
    private let hpBg    = SKSpriteNode(color: SKColor(white: 0.15, alpha: 1),
                                        size: CGSize(width: 100, height: 7))
    private let hpFill  = SKSpriteNode(color: .green, size: CGSize(width: 100, height: 7))
    private let ppBg    = SKSpriteNode(color: SKColor(white: 0.10, alpha: 1),
                                        size: CGSize(width: 100, height: 5))
    private let ppFill  = SKSpriteNode(color: SKColor(red: 0.35, green: 0.55, blue: 1, alpha: 1),
                                        size: CGSize(width: 100, height: 5))
    private let hpNum   = SKLabelNode()
    private let lvlL    = SKLabelNode()
    private let statusL = SKLabelNode()

    override init() {
        super.init()
        sprite.size = CGSize(width: 52, height: 52)
        sprite.position = CGPoint(x: 0, y: 30)
        addChild(sprite)

        lvlL.fontName = "AvenirNext-Bold"; lvlL.fontSize = 10
        lvlL.fontColor = SKColor(white: 0.55, alpha: 1); lvlL.position = CGPoint(x: 0, y: 7)
        lvlL.horizontalAlignmentMode = .center; addChild(lvlL)

        nameL.fontName = "AvenirNext-Bold"; nameL.fontSize = 11
        nameL.fontColor = .white; nameL.position = CGPoint(x: 0, y: -5)
        nameL.horizontalAlignmentMode = .center; addChild(nameL)

        hpBg.anchorPoint = CGPoint(x: 0.5, y: 0.5); hpBg.position = CGPoint(x: 0, y: -18)
        addChild(hpBg)
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5); hpFill.position = CGPoint(x: -50, y: 0)
        hpFill.zPosition = 1; hpBg.addChild(hpFill)

        ppBg.anchorPoint = CGPoint(x: 0.5, y: 0.5); ppBg.position = CGPoint(x: 0, y: -26)
        addChild(ppBg)
        ppFill.anchorPoint = CGPoint(x: 0, y: 0.5); ppFill.position = CGPoint(x: -50, y: 0)
        ppFill.zPosition = 1; ppBg.addChild(ppFill)

        hpNum.fontName = "AvenirNext-Medium"; hpNum.fontSize = 9
        hpNum.fontColor = .white; hpNum.position = CGPoint(x: 0, y: -36)
        hpNum.horizontalAlignmentMode = .center; addChild(hpNum)

        statusL.fontName = "Helvetica"; statusL.fontSize = 10
        statusL.position = CGPoint(x: 0, y: -46); statusL.horizontalAlignmentMode = .center
        addChild(statusL)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(member: PartyMember, isActive: Bool) {
        isHidden = false
        let hpFrac = member.maxHP > 0 ? CGFloat(member.hp) / CGFloat(member.maxHP) : 0
        let tgtHPW = max(0, hpFrac * 100)
        let curHPW = hpFill.size.width
        if abs(tgtHPW - curHPW) > 0.5 {
            let dur = max(0.2, Double(abs(tgtHPW - curHPW)) / 100.0 * 0.7)
            let tick = SKAction.customAction(withDuration: dur) { node, t in
                let p = min(t / CGFloat(dur), 1)
                (node as? SKSpriteNode)?.size.width = curHPW + (tgtHPW - curHPW) * p
            }
            hpFill.run(tick)
        }
        hpFill.color = hpFrac > 0.5 ? .green : (hpFrac > 0.25 ? .yellow : .red)

        let ppFrac = member.maxPP > 0 ? CGFloat(member.pp) / CGFloat(member.maxPP) : 0
        ppFill.size.width = max(0, ppFrac * 100)

        sprite.texture = CharacterSprites.texture(species: member.species, frame: .a)
        nameL.text     = member.species.displayName
        lvlL.text      = "Lv.\(member.level)"
        hpNum.text     = "\(member.hp)/\(member.maxHP)  PP:\(member.pp)"
        alpha          = member.hp > 0 ? 1.0 : 0.32
        nameL.fontColor = isActive ? SKColor(red: 1, green: 0.92, blue: 0.28, alpha: 1) : .white

        let icons = member.statusEffects.prefix(3).map(\.emoji).joined()
        statusL.text = icons

        sprite.removeAction(forKey: "ring")
        if isActive {
            sprite.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.75, duration: 0.4),
                .fadeAlpha(to: 1, duration: 0.4)
            ])), withKey: "ring")
        } else {
            sprite.alpha = 1
        }
    }

    func hide() { isHidden = true }
}

// MARK: - BattleButton

@MainActor
private final class BattleButton: SKNode {
    var onTap: (() -> Void)?

    init(glyph g: String, label lbl: String, tint: SKColor, width: CGFloat, height: CGFloat) {
        super.init()
        isUserInteractionEnabled = true

        let bg = SKShapeNode()
        bg.path        = CGPath(roundedRect: CGRect(x: -width/2, y: -height/2, width: width, height: height),
                                cornerWidth: 10, cornerHeight: 10, transform: nil)
        bg.fillColor   = tint.withAlphaComponent(0.85)
        bg.strokeColor = SKColor(white: 1, alpha: 0.22)
        bg.lineWidth   = 1.5
        addChild(bg)

        let gl = SKLabelNode(text: g)
        gl.fontSize = 20; gl.horizontalAlignmentMode = .center; gl.verticalAlignmentMode = .center
        gl.position = CGPoint(x: -width/2+24, y: 0); addChild(gl)

        let ll = SKLabelNode(text: lbl)
        ll.fontName = "AvenirNext-Bold"; ll.fontSize = 13; ll.fontColor = .white
        ll.horizontalAlignmentMode = .left; ll.verticalAlignmentMode = .center
        ll.position = CGPoint(x: -width/2+44, y: 0); addChild(ll)

        zPosition = 1
    }
    required init?(coder: NSCoder) { fatalError() }

#if canImport(AppKit)
    override func mouseDown(with event: NSEvent) {
        run(.sequence([.scale(to: 0.92, duration: 0.05), .scale(to: 1, duration: 0.08)]))
        onTap?()
    }
#endif
#if canImport(UIKit)
    override func touchesBegan(_ t: Set<UITouch>, with e: UIEvent?) { run(.scale(to: 0.92, duration: 0.05)) }
    override func touchesEnded(_ t: Set<UITouch>, with e: UIEvent?) { run(.scale(to: 1, duration: 0.08)); onTap?() }
#endif
}
