---@type Plugin
local plugin = ...
plugin.name = 'Web Uploader'
plugin.author = 'jdb'
plugin.description = 'Streams player info to a web server.'

plugin.defaultConfig = {
	host = 'https://oxs.international',
	path = '/api/v1/players',
	-- Seconds allowed between requests even if nothing has changed (default 10 min)
	maximumWaitTime = 10 * 60
}

local json = require 'main.json'

local mute400
local ready
local lastCheckTime
local lastPostTime
local lastPostString

function plugin.onEnable ()
	mute400 = false
	ready = false
	lastCheckTime = 0
	lastPostTime = 0
	lastPostString = ''
end

function plugin.onDisable ()
	mute400 = nil
	ready = nil
	lastCheckTime = nil
	lastPostTime = nil
	lastPostString = nil
end

function plugin.hooks.PostResetGame ()
	if not ready then ready = true end
end

local function onResponse (res)
	if not res then
		plugin:print('Request failed')
		return
	end

	if res.status < 200 or res.status > 299 then
		if res.status >= 400 and res.status <= 499 and res.status ~= 429 then
			if mute400 then return end
			mute400 = true
			plugin:warn('There are client problems, further 4XX problems will be muted.')
		end
		plugin:warn('Error ' .. res.status .. ': ' .. res.body)
		return
	end
end

function plugin.hooks.PostSendPacket ()
	if not ready then return end

	local now = os.clock()

	if now - lastCheckTime <= 6 then return end
	lastCheckTime = now

	hook.run('WebUploadBody')

	local body = {
		port = server.port,
		gameType = server.type,
		players = {}
	}

	for _, ply in pairs(players.getNonBots()) do
		table.insert(body.players, {
			name = ply.name,
			team = ply.team,
			phoneNumber = ply.phoneNumber,
			gender = ply.gender,
			head = ply.head,
			skinColor = ply.skinColor,
			hairColor = ply.hairColor,
			hair = ply.hair,
			eyeColor = ply.eyeColor
		})
	end

	hook.run('PostWebUploadBody', body)

	local cfg = plugin.config
	local postString = json.encode(body)

	if postString == lastPostString and now - lastPostTime < cfg.maximumWaitTime then return end
	lastPostTime = now
	lastPostString = postString

	plugin:print('Ping!')

	http.post(cfg.host, cfg.path, {}, postString, 'application/json', onResponse)
end