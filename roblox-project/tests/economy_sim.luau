--!strict
-- Proyección de hitos. Imprime el reporte; no falla el CI si el balance queda corto:
-- eso se documenta en ECONOMY_SIM.md. Los tests de economy.spec cubren la matemática.
local EconomySim = require("../src/ReplicatedStorage/Shared/Gameplay/EconomySim")

local function line(name: string, report: any)
	local function at(key: string): string
		local row = report.milestones[key]
		if row == nil then
			return "—"
		end
		return string.format("%.1f min (día %d)", row.playMin, row.day)
	end
	print(string.format("## %s", name))
	print(
		string.format(
			"- juego: %.0f min, fin: %d pedestales, %d Re-Fiestas, %.0f Dulces/s, %d Dulces",
			report.playMin,
			report.pedestals,
			report.reFiestas,
			report.perSec,
			report.candy
		)
	)
	print("- Rara vista: " .. at("rareSeen"))
	print("- Rara propia: " .. at("rareOwned"))
	print("- 4 slots: " .. at("fourFull"))
	print("- 6 pedestales: " .. at("pedestals6"))
	print("- Épica: " .. at("epicOwned"))
	print("- Fiesta: " .. at("fiesta"))
	print("- Re-Fiesta: " .. at("rebirth"))
	print("- Legendaria: " .. at("legendaryOwned"))
	print("- Clásicas: " .. at("classics"))
	print("- min 10/30/60 marcados: " .. at("min10") .. " / " .. at("min30") .. " / " .. at("min60"))
end

local report = EconomySim.project(20261022)
line("D1", report.d1)
line("D7", report.d7)
line("D28", report.d28)
line("D7 pagador (2x+VIP)", report.payer)
print("## flags")
for _, flag in report.flags do
	print(string.format("- [%s] %s — %s", if flag.ok then "ok" else "FLAG", flag.id, flag.detail))
end
if EconomySim.imbalanced(report.flags) then
	print("IMBALANCE")
else
	print("BALANCED")
end
