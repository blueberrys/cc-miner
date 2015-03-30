--[[
Blue Miner Installer
(installer) Version 1.1
]]

--[[
Install:
pastebin run yFhYMM9c

Run:
Miner
]]

local user = "blueberrys"
local repo = "cc-miner"
local dir = "blue-miner"
local exclFiles = {
	"README.md",
	".gitattributes",
	".gitignore",

	"pastebin"
}

local run = fs.combine(dir, "Miner.lua")
local alias = "Miner"

-- Selective install
local ensureBlueApiId = "xQfeXVgj"
local params = ""
--	-- Leave empty to check for version
--	local apis = {
--		-- "b_git",
--		}
--
--	for _, api in pairs(apis) do
--		params = params .. " " .. api
--	end
shell.run("pastebin run", ensureBlueApiId, params)

--	-- Full force install
--	local blueApiId = "yy7gqfBQ"
--	shell.run("pastebin run", blueApiId)

--

-- Install Miner
b_api.load("b_git")
b_git.install(user, repo, "master", dir, exclFiles)

-- Set alias
b_api.load("b_startup")
b_startup.addAlias(alias, run)
shell.setAlias(alias, run)

print("Type \"Miner\" to run")
