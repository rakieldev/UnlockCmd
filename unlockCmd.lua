-- UnlockCmd: Unlock chars via commands in the select screen.
-- Version: 1.1
-- Date: 01/14/2025
-- Author: Rakíel
-- Compatible with: Ikemen GO v0.99 and nightly
-- Description: This mod lets you create special commands to unlock chars in the select screen. These commands are defined in the unlockCmdConfig.json file.
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

    local content = main.f_fileRead(path)
    content = content:gsub('([^\r\n;]*)%s*;[^\r\n]*', '%1')
    content = content:gsub('\n%s*\n', '\n')
    for line in content:gmatch('[^\r\n]+') do
        local lineCase = line:lower()
        if lineCase:match('^%s*%[unlockconfig%]%s*$') then
            if section and isAnimSection then
                section.anim = animLines
            end
            section = {}
            table.insert(config.chars, section)
            isAnimSection = false
            animLines = {}
        elseif section then
            local param, value = line:match('^%s*(.-)%s*=%s*(.-)%s*$')
            if param and value then
                if param:match('anim') then
                    isAnimSection = true
                    table.insert(animLines, value)
                elseif param:match('unlocksnd') then
                    local values = {}
                    for num in value:gmatch('[^,]+') do
                        table.insert(values, tonumber(num) or num)
                    end
                    section[param] = values
                elseif tonumber(value) then
                    section[param] = tonumber(value)
                elseif value == "true" or value == "false" then
                    section[param] = value == "true"
                else
                    section[param] = value
                end
            elseif isAnimSection then
                table.insert(animLines, line:match('^%s*(.-)%s*$'))
            end
        end
    end

    if section and isAnimSection then
        section.anim = animLines
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

-- Table to store char anims
local charAnims = {}
-- Function to create a custom anim
function createAnim(charData)
    if not charData.anim or #charData.anim == 0 then
        return nil
    end
    local spriteData = sffNew('external/mods/unlockCmd/unlockCmdSprites.sff')  -- Loads the sff file
    local animString = table.concat(charData.anim, "\n")
    local anim = animNew(spriteData, animString)
    spriteData = 0
    return anim
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
function drawLockedCell()
    -- Draw cell art
    for row = 1, motif.select_info.rows do
        for col = 1, motif.select_info.columns do
            local t = start.t_grid[row][col]
            if t.skip ~= 1 then
                --draw face cell
                if t.char ~= nil and t.hidden == 0 then
                    main.f_animPosDraw(
                        start.f_getCharData(t.char_ref).cell_data,
                        motif.select_info.pos[1] + t.x + motif.select_info.portrait_offset[1],
                        motif.select_info.pos[2] + t.y + motif.select_info.portrait_offset[2],
                        (motif.select_info['cell_' .. col .. '_' .. row .. '_facing'] or motif.select_info.portrait_facing)
                    )
                end
                if t.hidden == 2 then
                    local charAnim = charAnims[t.char]  -- Use specific char anim
                    for _, charData in ipairs(unlockConfig.chars) do
                        if charData.name == t.char and charData.hidden then
                            hidden = (charData.hidden == 1)
                            break
                        end
                    end
                    if charAnim and not hidden then
                        if motif.select_info.showemptyboxes == 0 then
                            main.f_animPosDraw(
                                motif.select_info.cell_bg_data,
                                motif.select_info.pos[1] + t.x,
                                motif.select_info.pos[2] + t.y,
                                (motif.select_info['cell_' .. col .. '_' .. row .. '_facing'] or motif.select_info.cell_bg_facing)
                            )
                        end
                        main.f_animPosDraw(
                            charAnim,
                            motif.select_info.pos[1] + t.x + motif.select_info.portrait_offset[1],
                            motif.select_info.pos[2] + t.y + motif.select_info.portrait_offset[2],
                            (motif.select_info['cell_' .. col .. '_' .. row .. '_facing'] or motif.select_info.cell_random_facing)
                        )
                        animSetScale(
                            charAnim,
                            motif.select_info.portrait_scale[1] / (motifViewport43(2) / motifLocalcoord(0)),
                            motif.select_info.portrait_scale[2] / (motifViewport43(2) / motifLocalcoord(0)),
                            false
                        )
                    elseif not hidden then -- fallback to the screenpack default '?'
                        main.f_animPosDraw(
                            motif.select_info.cell_random_data,
                            motif.select_info.pos[1] + t.x + motif.select_info.portrait_offset[1],
                            motif.select_info.pos[2] + t.y + motif.select_info.portrait_offset[2],
                            (motif.select_info['cell_' .. col .. '_' .. row .. '_facing'] or motif.select_info.cell_random_facing)
                        )
                    end
                end
            end
        end
    end
    --draw done cursors
    for side = 1, 2 do
        for _, v in pairs(start.p[side].t_selected) do
            if v.cursor ~= nil then
                --get cell coordinates
                local x = v.cursor[1]
                local y = v.cursor[2]
                local t = start.t_grid[y + 1][x + 1]
                --render only if cell is not hidden
                if t.hidden ~= 1 and t.hidden ~= 2 then
                    start.f_drawCursor(v.pn, x, y, '_cursor_done', true)
                end
            end
        end
       if not start.p[side].selEnd then
            --for each player with active controls
            for k, v in ipairs(start.p[side].t_selCmd) do
                if v.selectState < 4 and start.f_selGrid(start.c[v.player].cell + 1).hidden ~= 1 and not start.c[v.player].blink then
                    start.f_drawCursor(v.player, start.c[v.player].selX, start.c[v.player].selY, '_cursor_active', false)
                end
            end
        end
    end
end

--------------------------------------------------------
--- Hooks and command check code
--------------------------------------------------------
function checkcommand()
    for p = 1, #main.t_players do
        for _, charData in ipairs(unlockConfig.chars) do
            if not charData.unlocked then
                main.f_commandAdd("hold_start", "/s", 1, 1)
                main.f_commandAdd(charData.name, charData.command, 150, 1)
                local commandExecuted = commandGetState(main.t_cmd[p], charData.name)
                if charData.holdstart == 1 then
                    commandExecuted = commandExecuted and commandGetState(main.t_cmd[p], "hold_start")
                end
                if commandExecuted then
                    charData.unlocked = true
                    main.f_unlock(true)
                    playUnlockSound(charData)
                    start.needUpdateDrawList = true
                    if charData.storyboard ~= nil and charData.storyboard ~= "" then
                    local path = charData.storyboard
                        launchStoryboard(path)
                    end
                    if charData.keep == 1 then
                        -- Save the .def
                        saveUnlockConfig('external/mods/unlockCmd/unlockCmdConfig.def', unlockConfig)
                    end
                end
            end
            -- Load sprites/anim for locked chars
            if not charAnims[charData.name] and charData.anim then
                charAnims[charData.name] = createAnim(charData)
            end
        end
    end
    drawLockedCell()
end

hook.add("start.f_selectScreen", "unlockchar", checkcommand)