-- UnlockCmd: Unlock chars via commands in the select screen.
-- Version: 2.0
-- Date: 18/26/2026
-- Author: Rakíel
-- Compatible with: Ikemen GO 1.0
-- Description: This mod lets you create special commands to unlock chars in the select screen. These commands are defined in the config.ini file.
-- To use this mod, you must declare specific parameters inside the config.ini file. After that, you can call the commands in the select.def.

--------------------------------------------------------
--- General functions
--------------------------------------------------------
function loadUnlockConfig(path) -- Load def file which contains data
	local ini = loadIni(path, false)
	local config = {}

	for name, charData in pairs(ini) do
		if name ~= "DEFAULT" then
			if type(charData.command) == "table" then
				charData.command = table.concat(charData.command, ",")
			end
			config[name] = charData
		end
	end

	pathMap = {} -- Init
	for name, charData in pairs(config) do
		if charData.charpath and charData.charpath ~= "" then
			pathMap[charData.charpath] = name
		end
	end

	return config
end

unlockConfig = loadUnlockConfig('external/mods/unlockCmd/config.ini')

function unlockCmd(name)
	local charData = unlockConfig[name]
	return charData and charData.unlocked == true or false
end

-- Tables to store char anims
local charAnims = {}
local unlockAnims = {}
local globalSff = sffNew('external/mods/unlockCmd/unlockCmdSprites.sff')
local globalAirTable = nil

if main.f_fileExists('external/mods/unlockCmd/unlockCmdAnims.air') then
	globalAirTable = loadAnimTable('external/mods/unlockCmd/unlockCmdAnims.air', globalSff)
else
	print("ERROR: unlockCmdAnims.air not found!")
	globalAirTable = {} -- Prevines crash
end

-- create anims from air file
function createAnimFromID(animID, charData, isPortraitContext)
	if not animID or animID == 0 or not globalAirTable[animID] then 
		return nil 
	end

	local a = animNew(globalSff, globalAirTable[animID])

	if a then
		local params = motif.select_info.portrait
		animSetLocalcoord(a, motif.info.localcoord[1], motif.info.localcoord[2])
		animSetLayerno(a, 0)
		local pScale = charData.portraitscale or 1.0
		local referenceLocalcoord = 320
		
		-- Apply scale if isPortraitContext
		animSetScale(
			a,
			params.scale[1] * pScale * motif.info.localcoord[1] / referenceLocalcoord,
			params.scale[2] * pScale * motif.info.localcoord[1] / referenceLocalcoord
		)
		animUpdate(a)
	end
	return a
end

-- Function to play the unlock sound
function playUnlockSound(charData)
	local centralSoundFile = sndNew('external/mods/unlockCmd/unlockCmdSounds.snd')  -- Load the .snd file
	if charData.unlocksnd and #charData.unlocksnd == 3 and centralSoundFile then
		sndPlay(centralSoundFile, charData.unlocksnd[1], charData.unlocksnd[2], charData.unlocksnd[3])
	end
end

-- Function to save the def file
function saveUnlockConfig(path, config)
	-- Reads the content of the original file
	local originalContent = {}
	local file = io.open(path, "r")

	if not file then
		return false
	end

	for line in file:lines() do
		table.insert(originalContent, line)
	end
	file:close()

	-- Builds a new table for the updated content
	local updatedContent = {}
	local currentSection = nil

	for _, line in ipairs(originalContent) do
		local section = line:match("^%s*%[(.-)%]%s*$")

		if section then
			currentSection = section
			table.insert(updatedContent, line)
		else
			local param = line:match("^%s*(.-)%s*=")

			if param and param:lower() == "unlocked" and currentSection then
				local charData = config[currentSection]

				if charData and charData.unlocked ~= nil then
					local prefix = line:match("^(%s*)")
					table.insert(
						updatedContent,
						prefix .. "unlocked = " .. tostring(charData.unlocked)
					)
				else
					table.insert(updatedContent, line)
				end
			else
				table.insert(updatedContent, line)
			end
		end
	end

	file = io.open(path, "w")
	if not file then
		return false
	end

	for _, line in ipairs(updatedContent) do
		file:write(line .. "\n")
	end

	file:close()
	return true
end

--------------------------------------------------------
--- Sprite/Anim rendering functions
--------------------------------------------------------
local function drawWithCellTransforms(anim, x, y, col, row, defaultParams)
	if not anim then 
		return 
	end
	-- inherit cell transformation
	local cellScale = getCellTransform(col, row, "scale", nil)
	animSetPos(anim, 0, 0)
	animSetFacing(anim, getCellFacing(defaultParams.facing, col, row))
	animSetAngle(anim, getCellTransform(col, row, "angle", 0))
	animSetXShear(anim, getCellTransform(col, row, "xshear", 0))
	animSetXAngle(anim, getCellTransform(col, row, "xangle", 0))
	animSetYAngle(anim, getCellTransform(col, row, "yangle", 0))
	animSetProjection(anim, getCellTransform(col, row, "projection", 0))
	animSetFocalLength(anim, getCellTransform(col, row, "focallength", 0))

	if defaultParams.isPortrait then
		local resFix = motif.info.localcoord[1] / 320
		local finalScale = cellScale or defaultParams.scale -- Uses override or the scale defined in the .def
		animSetScale(anim, finalScale[1] * resFix, finalScale[2] * resFix)
	else
		local finalScale = cellScale or defaultParams.scale
		animSetScale(anim, finalScale[1], finalScale[2])
	end
	animUpdate(anim)
	main.f_animPosDraw(anim, x, y, cellFacing)
end

function drawLockedCell()
	local portraitDefaults = {
		scale = motif.select_info.portrait.scale,
		facing = motif.select_info.portrait.facing,
		isPortrait = true
	}
	local motifDefaults = {
		scale = motif.select_info.cell.random.scale or {1, 1},
		facing = motif.select_info.cell.random.facing or 1,
		isPortrait = false
	}
	local bgDefaults = {
		scale = motif.select_info.cell.bg.scale or {1, 1},
		facing = motif.select_info.cell.bg.facing,
		isPortrait = false
	}
	for row = 1, motif.select_info.rows do
		for col = 1, motif.select_info.columns do
			local t = start.t_grid[row][col]
			if t.skip ~= 1 then
				-- Locate the mod data for this cell
				local configName = pathMap[t.char] or t.char
				local targetCharData = unlockConfig[configName]
				local c, r = col - 1, row - 1
				-- Pos
				local bgX = motif.select_info.pos[1] + t.x
				local bgY = motif.select_info.pos[2] + t.y
				local pX = bgX + motif.select_info.portrait.offset[1]
				local pY = bgY + motif.select_info.portrait.offset[2]

				if targetCharData then
					local locked = not targetCharData.unlocked and not targetCharData.unlockTimer
					local hideCell = targetCharData.hidecell == 1

					if not (hideCell and locked) and (t.hidden == 2 or (targetCharData.unlockTimer or 0) < 0) then
						-- Draw BG if showemptyboxes = 0
						if not motif.select_info.showemptyboxes then
							drawWithCellTransforms(motif.select_info.cell.bg.AnimData, bgX, bgY, c, r, bgDefaults)
						end
						-- Draw custom locked portrait
						local charAnim = charAnims[configName]
						if charAnim then
							drawWithCellTransforms(charAnim, pX, pY, c, r, portraitDefaults)
						else
							-- Default '?' icon
							drawWithCellTransforms(motif.select_info.cell.random.AnimData, pX, pY, c, r, motifDefaults)
						end
						-- Draw unlock anim
						if (targetCharData.unlockTimer or 0) ~= 0 then
							local uAnim = unlockAnims[configName]
							if uAnim then
								drawWithCellTransforms(uAnim, pX, pY, c, r, portraitDefaults)
							end
						end
					end
				end
			end
		end
	end
	-- Reset
	local function resetGlobalAnim(anim, defScale)
		if not anim then return end
		animSetXShear(anim, 0)
		animSetAngle(anim, 0)
		animSetXAngle(anim, 0)
		animSetYAngle(anim, 0)
		animSetProjection(anim, 0)
		animSetFocalLength(anim, 0)
		animSetScale(anim, defScale[1], defScale[2])
		animUpdate(anim)
	end
	resetGlobalAnim(motif.select_info.cell.bg.AnimData, motif.select_info.cell.bg.scale)
	resetGlobalAnim(motif.select_info.cell.random.AnimData, motif.select_info.cell.random.scale)
end

--------------------------------------------------------
--- Hooks and command check code
--------------------------------------------------------
function checkCommand()
	for p = 1, gameOption('Config.Players') do
		for name, charData in pairs(unlockConfig) do
			local locked = not charData.unlocked
				and not (charData.unlockTimer and charData.unlockTimer > 0)

			if locked then
				commandAdd("hold_start", "/s", 1, 1)
				commandAdd(name, charData.command, 150, 1)

				local commandExecuted = commandGetState(p, name)
				if charData.holdstart == 1 then
					commandExecuted = commandExecuted and commandGetState(p, "hold_start")
				end

				if commandExecuted then
					local uAnim = unlockAnims[name]
					local duration = 0

					-- Check unlockanim and get its duration
					if uAnim then
						animReset(uAnim)
						animUpdate(uAnim)
						duration = select(1, animGetLength(uAnim))
						duration = math.floor(duration / 1.1)
					end

					if duration > 0 then
						charData.unlockTimer = duration
						playUnlockSound(charData)
					else
						charData.unlocked = true
						main.f_unlock(true)
						playUnlockSound(charData)
						charData.unlockTimer = -3

						if charData.storyboard ~= nil and charData.storyboard ~= "" then
							launchStoryboard(charData.storyboard)
						end

						if charData.keep == 1 then
							saveUnlockConfig('external/mods/unlockCmd/config.ini', unlockConfig)
						end
					end

					start.needUpdateDrawList = true
				end
			end
		end
	end
end

function unlockChar()
	-- Update timers and initialize animations
	for name, charData in pairs(unlockConfig) do
		-- Init anims
		if not charAnims[name] and charData.anim then
			charAnims[name] = createAnimFromID(charData.anim, charData, true)
		end

		if not unlockAnims[name] and charData.unlockanim then
			unlockAnims[name] = createAnimFromID(charData.unlockanim, charData, true)
		end

		-- Timer
		if charData.unlockTimer then
			if charData.unlockTimer > 0 then
				charData.unlockTimer = charData.unlockTimer - 1
				start.needUpdateDrawList = true

				if charData.unlockTimer == 0 then
					charData.unlocked = true

					-- Buffer for Ikemen load default portraits
					main.f_unlock(true)

					charData.unlockTimer = -3

					-- Unlock storyboard
					if charData.storyboard ~= nil and charData.storyboard ~= "" then
						launchStoryboard(charData.storyboard)
					end

					if charData.keep == 1 then
						saveUnlockConfig('external/mods/unlockCmd/config.ini', unlockConfig)
					end
				end
			elseif charData.unlockTimer < 0 then
				-- Buffer
				charData.unlockTimer = charData.unlockTimer + 1
			end

			-- Timer Reset
			if charData.unlockTimer == 0 then
				charData.unlockTimer = nil
			end
		end
	end

	checkCommand()
	drawLockedCell()
end

hook.add("start.f_selectScreen", "unlockchar", unlockChar)