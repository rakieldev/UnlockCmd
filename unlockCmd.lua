-- UnlockCmd: Unlock chars via commands in the select screen.
-- Version: 1.2
-- Date: 12/22/2025
-- Author: Rakíel
-- Compatible with: Ikemen GO 1.0
-- Description: This mod lets you create special commands to unlock chars in the select screen. These commands are defined in the unlockCmdConfig.def file.
-- To use this mod, you must declare specific parameters inside the unlockCmdConfig.def file. After that, you can call the commands in the select.def.

--------------------------------------------------------
--- General functions
--------------------------------------------------------
function loadUnlockConfig(path) --Load def file which contains data
    local defaultDef = [[
; Default Unlock Config
[UnlockConfig]
name = 
command = 
holdstart = 0
unlocked = false
unlocksnd = 0,0,0
hidden = 0
keep = 0
anim = 0,0, 0,0, -1
link = 
storyboard = 
]]

    local file = io.open(path, "r")
    if not file then
        file = io.open(path, "w")
        file:write(defaultDef)
        file:close()
    else
        file:close()
    end

    -- Read the .def file
    local config = {chars = {}}
    local section = nil
    local isAnimSection = false
    local animLines = {}
    local isUnlockAnimSection = false
    local unlockAnimLines = {}

    local content = main.f_fileRead(path)
    content = content:gsub('([^\r\n;]*)%s*;[^\r\n]*', '%1')
    content = content:gsub('\n%s*\n', '\n')
    for line in content:gmatch('[^\r\n]+') do
        local lineCase = line:lower()

        if lineCase:match('^%s*%[unlockconfig%]%s*$') then
            if section then
                if #animLines > 0 then section.anim = animLines end
                if #unlockAnimLines > 0 then section.unlockanim = unlockAnimLines end
            end
            section = {}
            table.insert(config.chars, section)
            isAnimSection = false
            isUnlockAnimSection = false
            animLines = {}
            unlockAnimLines = {}
        elseif section then
            local param, value = line:match('^%s*(.-)%s*=%s*(.-)%s*$')
            if param and value then

                if isAnimSection and #animLines > 0 then
                    section.anim = animLines
                    animLines = {}
                end

                if isUnlockAnimSection and #unlockAnimLines > 0 then
                    section.unlockanim = unlockAnimLines
                    unlockAnimLines = {}
                end

                isAnimSection = false
                isUnlockAnimSection = false
                if param:match('^anim$') then
                    isAnimSection = true
                    table.insert(animLines, value)
                elseif param:match('^unlockanim$') then
                    isUnlockAnimSection = true
                    table.insert(unlockAnimLines, value)
                elseif param:match('^unlocksnd$') then
                    local values = {}
                    for num in value:gmatch('[^,]+') do
                        table.insert(values, tonumber(num) or num)
                    end
                    section[param] = values
                elseif param:match('^link$') or param:match('^charpath$') then 
                    section.link = value
                elseif tonumber(value) then
                    section[param] = tonumber(value)
                elseif value == "true" or value == "false" then
                    section[param] = value == "true"
                else
                    section[param] = value
                end
            elseif isAnimSection then
                table.insert(animLines, line:match('^%s*(.-)%s*$'))
            elseif isUnlockAnimSection then -- [NOVO]
                table.insert(unlockAnimLines, line:match('^%s*(.-)%s*$'))
            end
        end
    end

    -- Default Values
    for _, charData in ipairs(config.chars) do
        if charData.hidden == nil then
            charData.hidden = 0
        end
        if charData.holdstart == nil then
            charData.holdstart = 0
        end
        if charData.unlocked == nil then
            charData.unlocked = false
        end
        if charData.unlocksnd == nil then
            charData.unlocksnd = {0, 0, 0}
        end
        if charData.keep == nil then
            charData.keep = 0
        end
        if charData.anim == nil or #charData.anim == 0 then
            charData.anim = {"0,0, 0,0, -1"}
        end
        if charData.storyboard == nil then
            charData.storyboard = ""
        end
    end
    
    pathMap = {} -- Init
    for _, charData in ipairs(config.chars) do
        if charData.link and charData.link ~= "" then
            -- Ex: pathMap["SF/EvilKen/EvilKen.def"] = "Super Command"
            pathMap[charData.link] = charData.name
        end
    end
    
    return config
end

unlockConfig = loadUnlockConfig('external/mods/unlockCmd/unlockCmdConfig.def')

function unlockCmd(name)
    for _, charData in ipairs(unlockConfig.chars) do
        if charData.name == name then
            return charData.unlocked == true
        end
    end
    return false
end

-- Tables to store char anims
local charAnims = {}
local unlockAnims = {}
local globalSff = sffNew('external/mods/unlockCmd/unlockCmdSprites.sff')

function createAnim(charData)
    if not charData.anim or #charData.anim == 0 or not globalSff then return nil end
    local a = animNew(globalSff, table.concat(charData.anim, "\n"))

    if a then
        local params = motif.select_info.portrait
        animSetLocalcoord(a, motif.info.localcoord[1], motif.info.localcoord[2])
        animSetLayerno(a, 0)
        local pScale = charData.portraitscale or 1.0
        local referenceLocalcoord = 320
        animSetScale(
            a,
            params.scale[1] * pScale * motif.info.localcoord[1] / referenceLocalcoord,
            params.scale[2] * pScale * motif.info.localcoord[1] / referenceLocalcoord
        )
        animUpdate(a)
    end
    return a
end

function createUnlockAnim(charData)
    if not charData.unlockanim or #charData.unlockanim == 0 or not globalSff then return nil end
    local a = animNew(globalSff, table.concat(charData.unlockanim, "\n"))
    
    if a then
        local params = motif.select_info.portrait
        animSetLocalcoord(a, motif.info.localcoord[1], motif.info.localcoord[2])
        animSetLayerno(a, 0)
        local pScale = charData.portraitscale or 1.0
        local referenceLocalcoord = 320
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
    if file then
        for line in file:lines() do
            table.insert(originalContent, line)
        end
        file:close()
    end

     -- Builds a new table for the updated content
    local updatedContent = {}
    local charIndex = 1
    local insideSection = false

    for _, line in ipairs(originalContent) do
        local trimmedLine = line:match("^%s*(.-)%s*$")
        if trimmedLine:match("^%[UnlockConfig%]$") then
             -- Detects the start of a new section
            if config.chars[charIndex] then
                table.insert(updatedContent, "[UnlockConfig]")
                for key, value in pairs(config.chars[charIndex]) do
                    if key == "unlocksnd" and type(value) == "table" then
                        table.insert(updatedContent, string.format("%s = %s", key, table.concat(value, ",")))
                    elseif key == "anim" and type(value) == "table" then
                        table.insert(updatedContent, string.format("%s = %s", key, table.concat(value, ",")))
                    elseif key == "link" then
                        table.insert(updatedContent, string.format("%s = %s", key, value))
                    elseif type(value) == "boolean" then
                        table.insert(updatedContent, string.format("%s = %s", key, value and "true" or "false"))
                    else
                        table.insert(updatedContent, string.format("%s = %s", key, tostring(value)))
                    end
                end
                table.insert(updatedContent, "")
                charIndex = charIndex + 1
                insideSection = true
            else
                insideSection = false
            end
        elseif not insideSection then
            table.insert(updatedContent, line)
        end
    end
    -- Writes the updated content back to the file
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
local function getCellFacing(default, col, row)
	local cell = motif.select_info.cell[col .. '-' .. row]
	if cell ~= nil and cell.facing ~= 0 then
		return cell.facing
	end
	return default
end

function drawLockedCell()
    for row = 1, motif.select_info.rows do
        for col = 1, motif.select_info.columns do
            local t = start.t_grid[row][col]
            if t.skip ~= 1 then
                
                -- Locate the mod data for this cell
                local configName = pathMap[t.char] or t.char
                local targetCharData = nil
                for _, cd in ipairs(unlockConfig.chars) do
                    if cd.name == configName then 
                        targetCharData = cd 
                        break 
                    end
                end

                if targetCharData then

                    local isBuffer = (targetCharData.unlockTimer or 0) < 0
                    
                    if t.hidden == 2 or isBuffer then
                        local isHidden = (targetCharData.hidden == 1)
                        local pX = motif.select_info.pos[1] + t.x + motif.select_info.portrait.offset[1]
                        local pY = motif.select_info.pos[2] + t.y + motif.select_info.portrait.offset[2]
                        local pFacing = getCellFacing(motif.select_info.portrait.facing, col - 1, row - 1)

                        if targetCharData.unlockTimer and targetCharData.unlockTimer ~= 0 then
                            local uAnim = unlockAnims[configName]
                            local charAnim = charAnims[configName]

                            if targetCharData.unlockTimer > 0 and uAnim then
                                main.f_animPosDraw(uAnim, pX, pY, pFacing)
                            else
                                if charAnim then
                                    main.f_animPosDraw(charAnim, pX, pY, pFacing)
                                else
                                    main.f_animPosDraw(motif.select_info.cell.random.AnimData, pX, pY, pFacing)
                                end
                                if uAnim then
                                    main.f_animPosDraw(uAnim, pX, pY, pFacing)
                                end
                            end
                        -- Static frame
                        elseif not targetCharData.unlocked then
                            if not isHidden then
                                -- Cell BG
                                if motif.select_info.showemptyboxes then
                                    main.f_animPosDraw(
                                        motif.select_info.cell.bg.AnimData,
                                        motif.select_info.pos[1] + t.x,
                                        motif.select_info.pos[2] + t.y,
                                        getCellFacing(motif.select_info.cell.bg.facing, col - 1, row - 1)
                                    )
                                end
                                -- Custom Sprite, Anim or default '?'
                                local charAnim = charAnims[configName]
                                if charAnim then
                                    main.f_animPosDraw(charAnim, pX, pY, pFacing)
                                else
                                    main.f_animPosDraw(
                                        motif.select_info.cell.random.AnimData,
                                        pX, pY,
                                        getCellFacing(motif.select_info.cell.random.facing, col - 1, row - 1)
                                    )
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

--------------------------------------------------------
--- Hooks and command check code
--------------------------------------------------------
function checkcommand()
    -- Timer
    for _, charData in ipairs(unlockConfig.chars) do
        
        if not charAnims[charData.name] and charData.anim then
            charAnims[charData.name] = createAnim(charData)
        end
        if not unlockAnims[charData.name] and charData.unlockanim then
            unlockAnims[charData.name] = createUnlockAnim(charData)
        end
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
                        saveUnlockConfig('external/mods/unlockCmd/unlockCmdConfig.def', unlockConfig)
                    end
                end
                -- Buffer
                elseif charData.unlockTimer < 0 then
                    charData.unlockTimer = charData.unlockTimer + 1
                -- Timer Reset
                if charData.unlockTimer == 0 then
                    charData.unlockTimer = nil
                end
            end
        end
    end

    -- Check Player Inputs
    for p = 1, #main.t_players do
        for _, charData in ipairs(unlockConfig.chars) do
            
            if charData.unlocked or (charData.unlockTimer and charData.unlockTimer > 0) then
                goto continue
            end
            main.f_commandAdd("hold_start", "/s", 1, 1)
            main.f_commandAdd(charData.name, charData.command, 150, 1)
            
            local commandExecuted = commandGetState(main.t_cmd[p], charData.name)
            if charData.holdstart == 1 then
                commandExecuted = commandExecuted and commandGetState(main.t_cmd[p], "hold_start")
            end

            if commandExecuted then
                local uAnim = unlockAnims[charData.name]
                local duration = 0
                
                -- Check unlockanim and gets its duration
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
                        saveUnlockConfig('external/mods/unlockCmd/unlockCmdConfig.def', unlockConfig) 
                    end
                end
                start.needUpdateDrawList = true
            end
            ::continue::
        end
    end
    drawLockedCell()
end

hook.add("start.f_selectScreen", "unlockchar", checkcommand)