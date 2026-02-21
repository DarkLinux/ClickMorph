local CM = ClickMorph
if CM.isRetail then return end

iMorphLua = CreateFrame("Frame")
iMorphLua.debug = false
CM.override = false

-- Handshake: Tell ClickMorph this module exists
_G["iMorphLua"] = iMorphLua
iMorphLua.isLoaded = true

-- dummy func to fix imorph error
iMorphLua.OnInject = function()
    if ClickMorphDB and ClickMorphDB.imorphv1 and ClickMorphDB.imorphv1.remember then
        if iMorphV1 and iMorphV1.Remorph then
            iMorphV1:Remorph()
        end
    end
end

-- Initialize IMorphInfo if it doesn't exist
if CM.override or not IMorphInfo then
    IMorphInfo = IMorphInfo or {
        items = {},
        enchants = {},
        styles = {},
        forms = {}
    }
end

local VERSION = 1
local db
local state
local initTime = time()
local skipevent
local isManuallyMorphing
local activeMorphRace

local SEX_MALE = 1
local SEX_FEMALE = 2

local EnchantSlots = {
    [1] = INVSLOT_MAINHAND,
    [2] = INVSLOT_OFFHAND,
}

-- for scanning the current model
local p = CreateFrame("PlayerModel")

local PlayerModelFD = {
    [119940] = "humanmale.m2", [119563] = "humanfemale.m2",
    [121287] = "orcmale.m2",   [121087] = "orcfemale.m2",
    [118355] = "dwarfmale.m2", [118135] = "dwarffemale.m2",
    [120791] = "nightelfmale.m2", [120590] = "nightelffemale.m2",
    [121768] = "scourgemale.m2", [121608] = "scourgefemale.m2",
    [122055] = "taurenmale.m2", [121961] = "taurenfemale.m2",
    [119159] = "gnomemale.m2", [119063] = "gnomefemale.m2",
    [122560] = "trollmale.m2", [122414] = "trollfemale.m2",
    [119376] = "goblinmale.m2", [119369] = "goblinfemale.m2",
}

local PlayerModelRace = {
    {119940, 119563}, {121287, 121087}, {118355, 118135},
    {120791, 120590}, {121768, 121608}, {122055, 121961},
    {119159, 119063}, {122560, 122414}, {119376, 119369},
}

local player = {
    race = select(3, UnitRace("player")),
    sex = UnitSex("player"),
    class = select(2, UnitClass("player")),
}
player.playermodel = PlayerModelRace[player.race] and PlayerModelRace[player.race][player.sex-1]

local canShapeshift = player.class == "DRUID" or player.class == "SHAMAN"
local shapeshifted

tinsert(CM.db_callbacks, function()
    db = ClickMorphDB
    db.version = VERSION
    db.imorphlua = db.imorphlua or {}
    state = db.imorphlua
    state.form = state.form or {}
end)

function iMorphLua:OnEvent(event, ...)
    if self[event] then
        self[event](self, ...)
    end
end

iMorphLua:RegisterEvent("PLAYER_ENTERING_WORLD")
iMorphLua:SetScript("OnEvent", iMorphLua.OnEvent)

function iMorphLua:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    initTime = time()
    C_Timer.After(0.1, function()
        if isInitialLogin or isReloadingUi then
            self:Initialize(isInitialLogin)
        else
            self:Remorph()
        end
    end)
end

function iMorphLua:UPDATE_SHAPESHIFT_FORM()
    shapeshifted = true
end

function iMorphLua:UNIT_MODEL_CHANGED(unit)
    if unit == "player" then
        p:SetUnit("player")
        local fileID = p:GetModelFileID()
        if fileID then
            if shapeshifted then
                shapeshifted = false
                local form = GetShapeshiftForm()
                if form and form > 0 and state.form[form] then
                    if Morph then Morph(state.form[form]) end
                elseif form == 0 and state.morph then
                    if Morph then Morph(state.morph) end
                end
            elseif PlayerModelFD[fileID] and player.playermodel == fileID and not isManuallyMorphing then
                if state.morph then
                    self:Remorph()
                end
            end
        end
        isManuallyMorphing = false
    end
end

function iMorphLua:Initialize(remorph)
    if Morph then
        hooksecurefunc("SetRace", function(race, sex)
            if PlayerModelRace[race] then
                activeMorphRace = PlayerModelRace[race][sex]
            end
        end)
        if remorph then self:Remorph() end
        if canShapeshift then self:RegisterEvent("UPDATE_SHAPESHIFT_FORM") end
        self:RegisterEvent("UNIT_MODEL_CHANGED")
    end
end

function iMorphLua:Remorph()
    if Morph then
        if state.race or state.sex then
            local race = state.race or select(3, UnitRace("player"))
            local sex = state.sex or UnitSex("player")-1
            if SetRace then SetRace(race, sex) end
        end
        if state.morph and Morph then Morph(state.morph) end
        if state.scale and SetScale then SetScale(state.scale) end
    end
end

function iMorphLua:Reset()
    if SetRace then SetRace(select(3, UnitRace("player")), UnitSex("player")-1) end
    if SetItem then
        for slot in pairs(CM.SlotNames or {}) do
            SetItem(slot, GetInventoryItemID("player", slot) or 0)
        end
    end
    if SetScale then SetScale(1) end
    wipe(state)
end

-- Commands Table
local commands = {
    reset = function() iMorphLua:Reset() end,
    race = function(raceID)
        raceID = tonumber(raceID)
        if raceID and SetRace then
            local sex = state.sex or UnitSex("player")-1
            SetRace(raceID, sex)
            state.race = raceID
            state.morph = nil
            isManuallyMorphing = true
        end
    end,
    gender = function(sexID)
        sexID = tonumber(sexID)
        local race = state.race or select(3, UnitRace("player"))
        if sexID and SetRace then
            SetRace(race, sexID)
            state.sex = sexID
        elseif SetRace then
            local sex = state.sex or UnitSex("player")-1
            local newSex = (sex == SEX_MALE) and SEX_FEMALE or SEX_MALE
            SetRace(race, newSex)
            state.sex = newSex
        end
        state.morph = nil
        isManuallyMorphing = true
    end,
    morph = function(id)
        id = tonumber(id)
        if id and Morph then
            Morph(id)
            local form = GetShapeshiftForm()
            if canShapeshift and form > 0 then
                state.form[form] = id
            else
                state.morph = id
            end
            state.race, state.sex = nil, nil
            isManuallyMorphing = true
        end
    end,
    scale = function(id)
        id = tonumber(id)
        if id and SetScale then
            SetScale(id)
            state.scale = id
        end
    end,
    -- Simplified other commands to avoid bloat
    npc = function(...) CM:MorphNpc(table.concat({...}, " ")) end,
    item = function(slot, item) if SetItem then SetItem(tonumber(slot), tonumber(item)) end end,
}

-- Modern Chat Hook for 11.0
if MenuNotifyText then -- Check for TWW editbox
    hooksecurefunc("ChatEdit_SendText", function(editBox)
        local text = editBox:GetText()
        if text:sub(1,1) == "." then
            local cmd = text:match("^%.(%a+)")
            local func = commands[cmd]
            if func and Morph then
                local params = text:match("^%.%a+ (.+)") or ""
                func(strsplit(" ", params))
            end
        end
    end)
else
    -- Fallback for Classic/Older clients
    local originalSendText = ChatEdit_SendText
    ChatEdit_SendText = function(editBox, addHistory)
        local text = editBox:GetText()
        local cmd = text:match("^%.(%a+)")
        local func = commands[cmd]
        if Morph and func then
            local params = text:match("^%.%a+ (.+)") or ""
            func(strsplit(" ", params))
        else
            originalSendText(editBox, addHistory)
        end
    end
end