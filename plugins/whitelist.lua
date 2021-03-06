---@type Plugin
local plugin = ...
plugin.name = 'Whitelist'
plugin.author = 'jdb'
plugin.description = 'Only let in certain players.'

plugin.defaultConfig = {
	-- How many people can be let in regardless of if they're whitelisted
	maxPublicSlots = 0
}

local json = require 'main.json'

local whitelistPath = 'whitelist.json'

---@type integer[]
local whitelistedPhoneNumbers

local function getWhitelistIndex (phoneNumber)
	for i, p in ipairs(whitelistedPhoneNumbers) do
		if p == phoneNumber then return i end
	end
	return nil
end

---Check if a phone number is in the whitelist.
---@param phoneNumber integer The phone number to check.
---@return boolean isWhitelisted
function isNumberWhitelisted (phoneNumber)
	if not plugin.isEnabled then
		return false
	end

	return not not getWhitelistIndex(phoneNumber)
end

local function saveWhitelist ()
	local f, errorMessage = io.open(whitelistPath, 'w')
	if f then
		f:write(json.encode(whitelistedPhoneNumbers))
		f:close()
		plugin:print('Saved phone numbers')
	else
		plugin:warn('Could not save phone numbers: ' .. errorMessage)
	end
end

function plugin.onEnable ()
	local f, errorMessage = io.open(whitelistPath, 'r')
	if f then
		whitelistedPhoneNumbers = json.decode(f:read('*all'))
		f:close()
		plugin:print('Loaded ' .. #whitelistedPhoneNumbers .. ' phone numbers')
	else
		whitelistedPhoneNumbers = {}
		plugin:warn('Could not load phone numbers: ' .. errorMessage)
	end
end

function plugin.onDisable ()
	saveWhitelist()
	whitelistedPhoneNumbers = nil
end

function plugin.hooks.AccountTicketFound (acc)
	local maxPublicSlots = plugin.config.maxPublicSlots
	local playerCount = #players.getNonBots()

	if playerCount >= maxPublicSlots then
		if acc then
			if getWhitelistIndex(acc.phoneNumber) then
				-- Let it through
				return
			end

			hook.once(
				'SendConnectResponse',
				function (_, _, data)
					if maxPublicSlots == 0 then
						data.message = 'Whitelisted accounts only'
					else
						data.message = string.format('All public slots are taken (%i // %i)', playerCount, maxPublicSlots)
					end
				end
			)
		end

		return hook.override
	end
end

plugin.commands['listwhitelist'] = {
	info = 'List all whitelisted players.',
	call = function ()
		print(table.concat(whitelistedPhoneNumbers, ', '))
	end
}

plugin.commands['/whitelist'] = {
	info = 'Add a player to the whitelist.',
	usage = '/whitelist <phoneNumber>',
	canCall = function (ply) return ply.isConsole or ply.isAdmin end,
	---@param ply Player
	---@param args string[]
	call = function (ply, _, args)
		assert(#args >= 1, 'usage')

		local phoneNumber = undashPhoneNumber(args[1])
		assert(phoneNumber, 'Invalid phone number')

		if getWhitelistIndex(phoneNumber) then
			error('Phone number already whitelisted')
		end

		table.insert(whitelistedPhoneNumbers, phoneNumber)
		saveWhitelist()

		if adminLog then
			adminLog('%s whitelisted %s', ply.name, dashPhoneNumber(phoneNumber))
		end
	end
}

plugin.commands['/unwhitelist'] = {
	info = 'Remove a player from the whitelist.',
	usage = '/unwhitelist <phoneNumber>',
	canCall = function (ply) return ply.isConsole or ply.isAdmin end,
	---@param ply Player
	---@param args string[]
	call = function (ply, _, args)
		assert(#args >= 1, 'usage')

		local phoneNumber = undashPhoneNumber(args[1])
		assert(phoneNumber, 'Invalid phone number')

		local index = getWhitelistIndex(phoneNumber)
		if not index then
			error('Phone number not whitelisted')
		end

		table.remove(whitelistedPhoneNumbers, index)
		saveWhitelist()

		if adminLog then
			adminLog('%s unwhitelisted %s', ply.name, dashPhoneNumber(phoneNumber))
		end
	end
}