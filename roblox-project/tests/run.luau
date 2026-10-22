--!strict
local specs = {
	"./migrations.spec",
	"./wallet.spec",
	"./rate_limiter.spec",
	"./validators.spec",
	"./payload.spec",
	"./pinatas.spec",
	"./data_service_contract.spec",
	"./gameplay.spec",
}

local failed = 0
for _, spec in specs do
	local ok, err = pcall(require, spec)
	if ok then
		print("PASS " .. spec)
	else
		failed += 1
		print("FAIL " .. spec)
		print(err)
	end
end

if failed > 0 then
	error(string.format("%d suite(s) failed", failed))
end

print("all tests passed")
