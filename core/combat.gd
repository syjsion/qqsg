class_name CombatRules
extends RefCounted

# Physical/magical damage is an explicit provisional low-level formula.
# The research paper hides A..J constants; do not label this as official damage.
static func damage(stats: Dictionary, defense: float, skill: Dictionary, roll: float) -> Dictionary:
	var magic = skill.get("type", "physical") == "magic"
	var attribute: float = stats.intelligence if magic else stats.force
	var attack: float = stats.magic_attack if magic else stats.physical_attack
	var raw: float = (attack + attribute * 0.7) * float(skill.get("coefficient", 1)) + float(skill.get("power", 0))
	var critical = roll < 0.08
	return {"amount": maxi(1, roundi((raw - defense * 0.6) * (2.0 if critical else 1.0))), "critical": critical}

static func healing(stats: Dictionary, skill: Dictionary) -> int:
	# qqsganalysis: 治疗结算与治疗量计算.md, no endgame modifiers in v1.
	return maxi(1, floori(0.5 * (float(stats.intelligence) - 45.0) * (1.0 + float(stats.magic_attack) / 24.0) * float(skill.coefficient) + float(skill.power)))
