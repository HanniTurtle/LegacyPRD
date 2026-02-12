local addonName, ns = ...

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local castBar
local spellText
local timeText
local isCasting    = false
local isChanneling = false
local castEndTime  = 0
local castStartTime = 0
local castDuration  = 0

local CAST_COLOR    = { 1.0, 0.7, 0.0 }
local CHANNEL_COLOR = { 0.0, 1.0, 0.0 }
local FAILED_COLOR  = { 1.0, 0.0, 0.0 }

---------------------------------------------------------------------------
-- Stop casting / reset bar / shrink frame
---------------------------------------------------------------------------
local function StopCasting()
    isCasting = false
    isChanneling = false
    if castBar then
        castBar:SetMinMaxValues(0, 1)
        castBar:SetValue(0)
    end
    if spellText then spellText:SetText("") end
    if timeText then timeText:SetText("") end
    ns.castBarActive = false
    if LegacyPRD_UpdateLayout then LegacyPRD_UpdateLayout() end
end

---------------------------------------------------------------------------
-- Event handler
---------------------------------------------------------------------------
local function OnCastEvent(self, event, unit)
    if unit and unit ~= "player" then return end

    if event == "UNIT_SPELLCAST_START" then
        local name, _, _, startTimeMS, endTimeMS = UnitCastingInfo("player")
        if name then
            isCasting = true
            isChanneling = false
            castStartTime = startTimeMS / 1000
            castEndTime = endTimeMS / 1000
            castDuration = castEndTime - castStartTime
            castBar:SetMinMaxValues(0, castDuration)
            castBar:SetValue(0)
            castBar:SetStatusBarColor(unpack(CAST_COLOR))
            if spellText then spellText:SetText(name) end
            ns.castBarActive = true
            if LegacyPRD_UpdateLayout then LegacyPRD_UpdateLayout() end
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local name, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
        if name then
            isChanneling = true
            isCasting = false
            castStartTime = startTimeMS / 1000
            castEndTime = endTimeMS / 1000
            castDuration = castEndTime - castStartTime
            castBar:SetMinMaxValues(0, castDuration)
            castBar:SetValue(castDuration)
            castBar:SetStatusBarColor(unpack(CHANNEL_COLOR))
            if spellText then spellText:SetText(name) end
            ns.castBarActive = true
            if LegacyPRD_UpdateLayout then LegacyPRD_UpdateLayout() end
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local name, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
        if name then
            castStartTime = startTimeMS / 1000
            castEndTime = endTimeMS / 1000
            castDuration = castEndTime - castStartTime
            castBar:SetMinMaxValues(0, castDuration)
        end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        StopCasting()

    elseif event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if castBar then
            castBar:SetStatusBarColor(unpack(FAILED_COLOR))
            castBar:SetValue(castDuration)
        end
        local msg = (event == "UNIT_SPELLCAST_INTERRUPTED") and "Interrupted" or "Failed"
        if spellText then spellText:SetText(msg) end
        if timeText then timeText:SetText("") end
        isCasting = false
        isChanneling = false
        C_Timer.After(0.3, function()
            if not isCasting and not isChanneling then
                StopCasting()
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        StopCasting()
    end
end

---------------------------------------------------------------------------
-- OnUpdate: progress bar fill
---------------------------------------------------------------------------
local function OnUpdate(self, elapsed)
    if not isCasting and not isChanneling then return end

    local now = GetTime()

    if isCasting then
        local progress = now - castStartTime
        if progress >= castDuration then
            StopCasting()
            return
        end
        castBar:SetValue(progress)
        if timeText then
            timeText:SetText(string.format("%.1fs", castEndTime - now))
        end

    elseif isChanneling then
        local remaining = castEndTime - now
        if remaining <= 0 then
            StopCasting()
            return
        end
        castBar:SetValue(remaining)
        if timeText then
            timeText:SetText(string.format("%.1fs", remaining))
        end
    end
end

---------------------------------------------------------------------------
-- Update font size (called from ApplySettings)
---------------------------------------------------------------------------
function LegacyPRD_UpdateCastBarFont(barHeight)
    if not spellText or not timeText then return end
    local fontSize = math.max(6, math.floor(barHeight * 0.65))
    spellText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    timeText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function LegacyPRD_InitCastBar()
    if not ns.castBar then return end
    castBar = ns.castBar

    -- Spell name (left)
    spellText = castBar:CreateFontString(nil, "OVERLAY")
    spellText:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
    spellText:SetPoint("LEFT", castBar, "LEFT", 2, 0)
    spellText:SetJustifyH("LEFT")

    -- Cast time (right)
    timeText = castBar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
    timeText:SetPoint("RIGHT", castBar, "RIGHT", -2, 0)
    timeText:SetJustifyH("RIGHT")

    -- Event frame
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("UNIT_SPELLCAST_START")
    ef:RegisterEvent("UNIT_SPELLCAST_STOP")
    ef:RegisterEvent("UNIT_SPELLCAST_FAILED")
    ef:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    ef:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    ef:RegisterEvent("PLAYER_ENTERING_WORLD")

    ef:SetScript("OnEvent", OnCastEvent)
    castBar:SetScript("OnUpdate", OnUpdate)
end
