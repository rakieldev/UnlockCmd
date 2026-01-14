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
anim = 
unlockanim = 
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

    local content = main.f_fileRead(path)
    content = content:gsub('([^\r\n;]*)%s*;[^\r\n]*', '%1')
    content = content:gsub('\n%s*\n', '\n')
    for line in content:gmatch('[^\r\n]+') do
        local lineCase = line:lower()

        if lineCase:match('^%s*%[unlockconfig%]%s*$') then
            section = {}
            table.insert(config.chars, section)
        elseif section then
            local param, value = line:match('^%s*(.-)%s*=%s*(.-)%s*$')
            if param and value then
                param = param:lower()
                if param:match('^anim$') or param:match('^unlockanim$') then
                    section[param] = tonumber(value) or 0
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
        if charData.anim == nil then
            charData.anim = 0
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
                local targetCharData = nil
                for _, cd in ipairs(unlockConfig.chars) do
                    if cd.name == configName then targetCharData = cd; break end
                end
                local c, r = col - 1, row - 1
                local cOffset = getCellOffset(c, r)
                -- Pos
                local bgX = motif.select_info.pos[1] + t.x
                local bgY = motif.select_info.pos[2] + t.y
                local pX = bgX + motif.select_info.portrait.offset[1] + cOffset[1]
                local pY = bgY + motif.select_info.portrait.offset[2] + cOffset[2]

                if targetCharData then
                    if t.hidden == 2 or (targetCharData.unlockTimer or 0) < 0 then
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
function checkcommand()
    -- Timer
    for _, charData in ipairs(unlockConfig.chars) do
        -- Init anims
        if not charAnims[charData.name] and charData.anim then
            charAnims[charData.name] = createAnimFromID(charData.anim, charData, true)
        end
        if not unlockAnims[charData.name] and charData.unlockanim then
            unlockAnims[charData.name] = createAnimFromID(charData.unlockanim, charData, true)
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