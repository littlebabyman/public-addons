--[[
Workshop:		https://steamcommunity.com/sharedfiles/filedetails/?id=2980423627
Profile Page:	https://steamcommunity.com/id/Piengineer12
GitHub Page:	https://github.com/Piengineer12/public-addons/tree/master/insane_stats
Donate:			https://ko-fi.com/piengineer12
]]

InsaneStats = {
	VERSION = "1.2.0",
	VERSION_DATE = "2023-09-03"
}

function InsaneStats:Log(msg)
	MsgC(
		Color(0, 255, 255),
		SERVER and "[Insane Stats Server] " or "[Insane Stats Client] ",
		color_white,
		msg,
		"\n"
	)
end

InsaneStats:Log(string.format("Loading Insane Stats version %s (%s) by Piengineer12", InsaneStats.VERSION, InsaneStats.VERSION_DATE))

local clientFiles = {
	"cl_base",
	"cl_coin",
	"cl_infhealth",
	"cl_net",
	"cl_options",
	"cl_wpass2",
	"cl_wpass2_basemods",
	"cl_xp"
}

local sharedFiles = {
	"sh_base",
	"sh_coin",
	"sh_infhealth",
	"sh_soundfixes",
	"sh_wpass2",
	"sh_wpass2_basemods",
	"sh_xp"
}

local serverFiles = {
	"sv_base",
	"sv_coin",
	"sv_infhealth",
	"sv_net",
	"sv_wpass2",
	"sv_wpass2_basemods",
	"sv_xp"
}

local baseFilePath = "insane_stats/%s.lua"

for i,v in ipairs(sharedFiles) do
	local filePath = string.format(baseFilePath, v)
	AddCSLuaFile(filePath)
	include(filePath)
end

if SERVER then
	for i,v in ipairs(serverFiles) do
		local filePath = string.format(baseFilePath, v)
		include(filePath)
	end
end

for i,v in ipairs(clientFiles) do
	local filePath = string.format(baseFilePath, v)
	if SERVER then
		AddCSLuaFile(filePath)
	else
		include(filePath)
	end
end