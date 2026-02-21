local CM = ClickMorph
if CM.isRetail then return end

iMorphV1 = CreateFrame("Frame")

-- Modern API Fix for this specific file
local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata

iMorphV1:RegisterEvent("PLAYER_ENTERING_WORLD")
iMorphV1:RegisterEvent("PLAYER_LOGOUT")
iMorphV1:RegisterEvent("ADDON_LOADED")

iMorphV1:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, event, ...)
    end
end)

function iMorphV1:ADDON_LOADED(event, addon)
    if addon == "ClickMorph" then
        ClickMorph_iMorphV1 = ClickMorph_iMorphV1 or {}
        
        -- FORCE THE HANDSHAKE
        -- This tells the main ClickMorph addon that the morpher is active
        self.isLoaded = true
        self.version = GetAddOnMetadata(addon, "Version") or "1.0"
        _G["iMorph"] = self 
        _G["IMorphInfo"] = _G["IMorphInfo"] or { items = {}, styles = {} }

        self:UnregisterEvent(event)
    end
end

function iMorphV1:PLAYER_ENTERING_WORLD(event, isInitialLogin, isReloadingUi)
    -- If you want it to automatically remorph on login, uncomment the line below:
    -- self:Remorph()
end

function iMorphV1:PLAYER_LOGOUT()
    if not IMorphInfo then return end
    local tempscale = ClickMorph_iMorphV1.tempscale
    ClickMorph_iMorphV1.state = CopyTable(IMorphInfo)
    ClickMorph_iMorphV1.state.scale = tempscale
end

function iMorphV1:Remorph()
    C_Timer.After(1, function()
        local state = ClickMorph_iMorphV1.state
        -- We check if the external injector functions (Morph, SetItem) actually exist
        if not state or not Morph then return end

        if state.shouldMorphRace and state.race and state.gender then
            SetRace(state.race, state.gender)
        elseif state.displayId then
            Morph(state.displayId)
        end
        
        if state.items and next(state.items) then
            for slotID, itemID in pairs(state.items) do
                SetItem(slotID, itemID)
            end
        end
        
        if state.scale then
            SetScale(state.scale)
        end
        
        if state.styles and next(state.styles) then
            for func, value in pairs(state.styles) do
                if _G[func] then _G[func](value) end
            end
        end
    end)
end

function iMorphV1:PLAYER_MOUNT_DISPLAY_CHANGED()
    if not SetScale or not ClickMorph_iMorphV1.state then return end
    local state = ClickMorph_iMorphV1.state

    C_Timer.After(.1, function()
        if state.scale then
            SetScale(state.scale)
        end
    end)
end