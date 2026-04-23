import Foundation
import Observation

@Observable
@MainActor
final class GameState {
    var party: [PartyMember] = PartyMember.defaultParty
    var activeIndex: Int = 0
    var inventory: [ItemKind: Int] = [:]
    var score: Int = 0
    var enemiesDefeated: Int = 0
    var isPaused: Bool = false

    /// Timestamp of last attack per species (for cooldown).
    var lastAttackTime: [Species: TimeInterval] = [:]

    var activeSpecies: Species { party[activeIndex].species }

    func cycleActive() {
        activeIndex = (activeIndex + 1) % party.count
    }

    func collect(_ kind: ItemKind) {
        inventory[kind, default: 0] += 1
        score += 10
    }

    func takeDamage(_ amount: Int) {
        party[activeIndex].hp = max(0, party[activeIndex].hp - amount)
        if party[activeIndex].hp == 0 {
            for step in 1..<party.count {
                let idx = (activeIndex + step) % party.count
                if party[idx].hp > 0 { activeIndex = idx; break }
            }
        }
    }

    func defeatEnemy(kind: EnemyKind) {
        enemiesDefeated += 1
        score += kind.defeatScore
    }

    /// Returns 0…1 where 1 = ready to attack again.
    func attackCharge(now: TimeInterval) -> Double {
        let cooldown = activeSpecies.attackCooldown
        let last = lastAttackTime[activeSpecies] ?? 0
        return min((now - last) / cooldown, 1.0)
    }

    func recordAttack(now: TimeInterval) {
        lastAttackTime[activeSpecies] = now
    }

    var isGameOver: Bool {
        party.allSatisfy { $0.hp == 0 }
    }

    func reset() {
        party = PartyMember.defaultParty
        activeIndex = 0
        inventory.removeAll()
        score = 0
        enemiesDefeated = 0
        isPaused = false
        lastAttackTime.removeAll()
    }
}
