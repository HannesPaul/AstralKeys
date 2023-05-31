local _, addon = ...
local strformat = string.format

local COLOUR = {}
COLOUR[1] = 'ffffffff' -- Common
COLOUR[2] = 'ff0070dd' -- Rare
COLOUR[3] = 'ffa335ee' -- Epic
COLOUR[4] = 'ffff8000' -- Legendary
COLOUR[5] = 'ffe6cc80' -- Artifact

addon.keystone = {}

addon.MYTHICKEY_ITEMID = 180653
addon.TIMEWALKINGKEY_ITEMID = 187786
addon.MYTHICKEY_REROLL_NPCID = 197915
addon.MYTHICKEY_CITY_NPCID = 197711

local function UpdateWeekly()
	addon.UpdateCharacterBest()
	local characterID = addon.GetCharacterID(addon.Player())
	local characterWeeklyBest = addon.GetCharacterBestLevel(characterID)
	if IsInGuild() then
		AstralComs:NewMessage('AstralKeys', 'updateWeekly ' .. characterWeeklyBest, 'GUILD')
	else
		local id = addon.UnitID(addon.Player())
		if id then
			AstralKeys[id].weekly_best = characterWeeklyBest
			addon.UpdateFrames()
		end
	end
	addon.UpdateCharacterFrames()
end

function addon.GetCurrentKeystone()
	return C_MythicPlus.GetOwnedKeystoneChallengeMapID(), C_MythicPlus.GetOwnedKeystoneLevel()
end

function addon.CheckKeystone()
	local id, l = addon.GetCurrentKeystone()
	if (not addon.keystone.id) or (id == addon.keystone.id and l < addon.keystone.level) then
		addon.PushKeystone(false)
	elseif id ~= addon.keystone.id or l ~= addon.keystone.level then
    addon.PushKeystone(true)
  else
    addon.keystone = {level = l, id = id}
  end
end

--|cffa335ee|Hkeystone:158923:251:12:10:5:13:117|h[Keystone: The Underrot (12)]|h|r
-- COLOUR[3] returns epic color hex code
function addon.CreateKeyLink(mapID, keyLevel)
	local mapName
	if mapID == 369 or mapID == 370 then
		mapName = C_ChallengeMode.GetMapUIInfo(mapID)
	else
		mapName = addon.GetMapName(mapID, true)
	end
	local thisAff1, thisAff2, thisAff3, thisAff4 = 0
	if addon.AffixFour() == 0 then
		if keyLevel > 1 then
		thisAff1 = addon.AffixOne()
		end
		if keyLevel > 6 then
		thisAff2 = addon.AffixTwo()
		end
		if keyLevel > 13 then
		thisAff3 = addon.AffixThree() -- season affix removed in DF S2
		end
	else
		if keyLevel > 1 then
			thisAff1 = addon.AffixOne()
		 end
		 if keyLevel > 3 then
			thisAff2 = addon.AffixTwo()
		 end
		 if keyLevel > 6 then
			thisAff3 = addon.AffixThree()
		 end
		 if keyLevel > 8 then
			thisAff4 = addon.AffixFour()
		 end
	end
	return strformat('|c' .. COLOUR[3] .. '|Hkeystone:%d:%d:%d:%d:%d:%d:%d|h[%s %s (%d)]|h|r', addon.MYTHICKEY_ITEMID, mapID, keyLevel, thisAff1, thisAff2, thisAff3, thisAff4, L['KEYSTONE'], mapName, keyLevel):gsub('\124\124', '\124')
end

-- Prints out the same link as the CreateKeyLink but only if the Timewalking Key is found. Otherwise nothing is done.
function addon.CreateTimewalkingKeyLink(mapID, keyLevel)
   local mapName = addon.GetMapName(mapID, true)
   local thisAff1, thisAff2, thisAff3, thisAff4 = 0
	if keyLevel > 1 then
	 thisAff1 = addon.TimewalkingAffixOne()
	end
	if keyLevel > 3 then
	 thisAff2 = addon.TimewalkingAffixTwo()
	end
	if keyLevel > 6 then
	 thisAff3 = addon.TimewalkingAffixThree()
	end
	if keyLevel > 8 then
	 thisAff4 = addon.TimewalkingAffixFour()
	end
	return strformat('|c' .. COLOUR[3] .. '|Hkeystone:%d:%d:%d:%d:%d:%d:%d|h[%s %s (%d)]|h|r', addon.TIMEWALKINGKEY_ITEMID, mapID, keyLevel, thisAff1, thisAff2, thisAff3, thisAff4, L['KEYSTONE'], mapName, keyLevel):gsub('\124\124', '\124')
end

function addon.PushKeystone(announceKey)
	if UnitLevel('player') < addon.EXPANSION_LEVEL then return end

	local mapID, keyLevel = addon.GetCurrentKeystone()

	local weeklyBest = 0
	local runHistory = C_MythicPlus.GetRunHistory(false, true)

	addon.keystone = {level = keyLevel, id = mapID}

	for i = 1, #runHistory do
		if runHistory[i].thisWeek then
			if runHistory[i].level > weeklyBest then
				weeklyBest = runHistory[i].level
			end
		end
	end

	local msg = ''
	if mapID then
		msg = string.format('%s:%s:%d:%d:%d:%d:%s', addon.Player(), addon.PlayerClass(), mapID, keyLevel, weeklyBest, addon.Week, addon.FACTION)
	end
	if msg ~= '' then
		addon.PushKeyDataToFriends(msg)
		if IsInGuild() then
			AstralComs:NewMessage('AstralKeys', strformat('%s %s', addon.UPDATE_VERSION, msg), 'GUILD')
		else -- Not in a guild, who are you people? Whatever, gotta make it work for them as well
			local id = addon.UnitID(addon.Player())
			if id then -- Are we in the DB already?
				AstralKeys[id].dungeon_id = tonumber(mapID)
				AstralKeys[id].key_level = tonumber(keyLevel)
				AstralKeys[id].week = addon.Week
				AstralKeys[id].time_stamp = addon.WeekTime()
			else -- Nope, ok, let's add them to the DB manually.
				AstralKeys[#AstralKeys + 1] = {
					unit = addon.Player(),
					class = addon.PlayerClass(),
					dungeon_id = tonumber(mapID),
					key_level = tonumber(keyLevel),
					week = addon.Week,
					time_stamp = addon.WeekTime(),
				}
				addon.SetUnitID(addon.Player(), #AstralKeys)
			end
		end
	end
	msg = nil

	if announceKey then
		addon.AnnounceKey()
	end
end

-- Finds best map clear for the week for logged on character. If character already is in database
-- updates the information, else creates new entry for character
function addon.UpdateCharacterBest()
	if UnitLevel('player') < addon.EXPANSION_LEVEL then return end

	local weeklyBest = 0
	local runHistory = C_MythicPlus.GetRunHistory(false, true)

	for i = 1, #runHistory do
		if runHistory[i].thisWeek then
			if runHistory[i].level > weeklyBest then
				weeklyBest = runHistory[i].level
			end
		end
	end

	local found = false
	for i = 1, #AstralCharacters do
		if AstralCharacters[i].unit == addon.Player() then
			found = true
			AstralCharacters[i].weekly_best = weeklyBest
			break
		end
	end

	if not found then
		table.insert(AstralCharacters, { unit = addon.Player(), class = addon.PlayerClass(), weekly_best = weeklyBest, faction = addon.FACTION})
		addon.SetCharacterID(addon.Player(), #AstralCharacters)
	end
end

function addon.GetDifficultyColour(keyLevel)
	if type(keyLevel) ~= 'number' then return COLOUR[1] end -- return white for any strings or non-number values
	if keyLevel <= 4 then
		return COLOUR[1]
	elseif keyLevel <= 9 then
		return COLOUR[2]
	elseif keyLevel <= 14 then
		return COLOUR[3]
	elseif keyLevel <= 19 then
		return COLOUR[4]
	else
		return COLOUR[5]
	end
end

function InitKeystoneData()
	AstralEvents:Unregister('PLAYER_ENTERING_WORLD', 'initData')
	C_MythicPlus.RequestRewards()
	C_ChatInfo.RegisterAddonMessagePrefix('AstralKeys')
	addon.PushKeystone(false)
	addon.UpdateCharacterBest()
	if IsInGuild() then
		AstralComs:NewMessage('AstralKeys', 'request', 'GUILD')
	end

	if UnitLevel('player') < addon.EXPANSION_LEVEL then return end
	AstralEvents:Register('CHALLENGE_MODE_MAPS_UPDATE', UpdateWeekly, 'weeklyCheck')
	AstralEvents:Register('PLAYER_ENTERING_WORLD', addon.CheckKeystone, 'keystoneCheck')
end

AstralEvents:Register('PLAYER_ENTERING_WORLD', InitKeystoneData, 'initData')
AstralEvents:Register('ITEM_CHANGED', addon.CheckKeystone, 'keystoneMaybeChanged')
AstralEvents:Register('CHALLENGE_MODE_RESET', addon.CheckKeystone, 'dungeonReset')
AstralEvents:Register('CHALLENGE_MODE_START', addon.CheckKeystone, 'dungeonStart')
AstralEvents:Register('CHALLENGE_MODE_COMPLETED', function()
	C_Timer.After(3, function()
		C_MythicPlus.RequestRewards()
		addon.CheckKeystone()
	end)
end, 'dungeonCompleted')
AstralEvents:Register('GOSSIP_CLOSED', function()
	local guid = UnitGUID('target')
	if guid ~= nil then
		local _, _, _, _, _, npc_id, _ = strsplit('-', guid)
		if npc_id == addon.MYTHICKEY_CITY_NPC then
			addon.CheckKeystone()
		end
	end
end, 'keystoneObtained')