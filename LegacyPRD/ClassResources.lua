local addonName, ns = ...

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local BASE_ICON_HEIGHT = 12
local RESOURCE_GAP     = 3
local INDICATOR_GAP    = 2
local RUNE_TEXT_UPDATE_INTERVAL = 0.05
local EMPTY_TEXTURE    = "Interface\\Buttons\\WHITE8x8"
local FILLED_TEXTURE   = "Interface\\TargetingFrame\\UI-StatusBar"

---------------------------------------------------------------------------
-- Atlas helper: find the first valid atlas name from a list
---------------------------------------------------------------------------
local function FindWorkingAtlas(atlasList)
    if not atlasList then return nil end
    for _, name in ipairs(atlasList) do
        if C_Texture.GetAtlasInfo(name) then
            return name
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- DK spec-based rune atlases
---------------------------------------------------------------------------
local DK_RUNE_ATLASES = {
    [1] = { active = {"DK-Blood-Rune-Ready"},  empty = {"DK-Blood-Rune-Off"}  },
    [2] = { active = {"DK-Frost-Rune-Ready"},  empty = {"DK-Frost-Rune-Off"}  },
    [3] = { active = {"DK-Unholy-Rune-Ready"}, empty = {"DK-Unholy-Rune-Off"} },
}

---------------------------------------------------------------------------
-- Class configuration table
---------------------------------------------------------------------------
local CLASS_CONFIG = {
    WARLOCK = {
        powerType    = Enum.PowerType.SoulShards,
        maxDefault   = 5,
        aspectRatio  = 17 / 22,
        activeAtlas  = { "Warlock-ReadyShard" },
        emptyAtlas   = { "Warlock-EmptyShard" },
        activeColor  = { 0.58, 0.22, 0.93, 1 },
        emptyColor   = { 0.58, 0.22, 0.93, 0.2 },
    },
    ROGUE = {
        powerType    = Enum.PowerType.ComboPoints,
        maxDefault   = 5,
        aspectRatio  = 1,
        activeAtlas  = { "ClassOverlay-ComboPoint", "ComboPoint-pointed-on" },
        emptyAtlas   = { "ClassOverlay-ComboPoint-Off", "ComboPoint-pointed-off" },
        activeColor  = { 1, 0.8, 0, 1 },
        emptyColor   = { 1, 0.8, 0, 0.2 },
    },
    DRUID = {
        powerType    = Enum.PowerType.ComboPoints,
        maxDefault   = 5,
        aspectRatio  = 1,
        activeAtlas  = { "ClassOverlay-ComboPoint", "ComboPoint-pointed-on" },
        emptyAtlas   = { "ClassOverlay-ComboPoint-Off", "ComboPoint-pointed-off" },
        activeColor  = { 1, 0.8, 0, 1 },
        emptyColor   = { 1, 0.8, 0, 0.2 },
        requiresForm = true,
    },
    PALADIN = {
        powerType    = Enum.PowerType.HolyPower,
        maxDefault   = 5,
        aspectRatio  = 25 / 19,
        activeAtlas  = { "ClassOverlay-HolyPower" },
        emptyAtlas   = { "ClassOverlay-HolyPower-Off" },
        activeColor  = { 0.95, 0.9, 0.2, 1 },
        emptyColor   = { 0.95, 0.9, 0.2, 0.2 },
    },
    MONK = {
        powerType    = Enum.PowerType.Chi,
        maxDefault   = 5,
        aspectRatio  = 1,
        activeAtlas  = { "ClassOverlay-Chi" },
        emptyAtlas   = { "ClassOverlay-Chi-Off" },
        activeColor  = { 0, 1, 0.59, 1 },
        emptyColor   = { 0, 1, 0.59, 0.2 },
    },
    MAGE = {
        powerType    = Enum.PowerType.ArcaneCharges,
        maxDefault   = 4,
        aspectRatio  = 1,
        activeAtlas  = { "ClassOverlay-ArcaneCharge" },
        emptyAtlas   = { "ClassOverlay-ArcaneCharge-Off" },
        activeColor  = { 0.3, 0.5, 1, 1 },
        emptyColor   = { 0.3, 0.5, 1, 0.2 },
        requiresSpec = 1,
    },
    DEATHKNIGHT = {
        isRunes      = true,
        maxDefault   = 6,
        aspectRatio  = 1,
        activeColor  = { 0, 0.8, 1, 1 },
        emptyColor   = { 0, 0.8, 1, 0.2 },
    },
    EVOKER = {
        powerType    = Enum.PowerType.Essence,
        maxDefault   = 5,
        aspectRatio  = 1,
        activeAtlas  = { "ClassOverlay-Evoker-pointed-filled", "nameplates-Evoker-pointed-filled" },
        emptyAtlas   = { "ClassOverlay-Evoker-pointed-off", "nameplates-Evoker-pointed-off" },
        activeColor  = { 0.8, 0.7, 0.2, 1 },
        emptyColor   = { 0.8, 0.7, 0.2, 0.2 },
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local _, playerClass = UnitClass("player")
local classConfig    = CLASS_CONFIG[playerClass]
local resourceRow            -- floating row for Blizzard/Squares styles
local resourceBarFrame       -- bar-style resource display (inside main frame)
local indicators     = {}
local barSegments    = {}
local currentMax     = 0
local isVisible      = false
local currentDKSpec  = nil
local eventFrame
local runeTextElapsed = 0
local GetMax
local UpdateBarSegments

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function GetResourceStyle()
    return LegacyPRDDB and LegacyPRDDB.resourceStyle or "blizzard"
end

local function GetActiveResourceColor()
    local db = LegacyPRDDB
    local mode = db and db.resourceColorMode or "default"
    if mode == "class" then
        local cc = RAID_CLASS_COLORS[playerClass]
        if cc then return cc.r, cc.g, cc.b, 1 end
        return 1, 1, 1, 1
    elseif mode == "custom" then
        local c = db and db.resourceCustomColor or {r=1, g=1, b=1}
        return c.r, c.g, c.b, 1
    else
        return classConfig.activeColor[1], classConfig.activeColor[2],
               classConfig.activeColor[3], classConfig.activeColor[4]
    end
end

local function GetChargedResourceColor()
    local c = LegacyPRDDB and LegacyPRDDB.resourceChargedColor
    if type(c) == "table" then
        return c.r or 0.2, c.g or 0.8, c.b or 1.0, 1
    end
    return 0.2, 0.8, 1.0, 1
end

local function IsComboPointResource()
    if not classConfig then return false end
    return not classConfig.isRunes and classConfig.powerType == Enum.PowerType.ComboPoints
end

local function GetChargedPointLookup()
    if not IsComboPointResource() then return nil end
    if type(GetUnitChargedPowerPoints) ~= "function" then return nil end

    local points = GetUnitChargedPowerPoints("player")
    if type(points) ~= "table" or #points == 0 then return nil end

    local lookup = {}
    for _, idx in ipairs(points) do
        if type(idx) == "number" then
            lookup[idx] = true
        end
    end
    return lookup
end

local function GetResourceFillTexture()
    if type(LegacyPRD_GetStatusBarTexturePath) == "function" then
        return LegacyPRD_GetStatusBarTexturePath()
    end
    return FILLED_TEXTURE
end

local function ShouldShowResourceBorders()
    return LegacyPRDDB and LegacyPRDDB.resourceBorders == true
end

local function ShouldShowRuneRechargeTracker()
    return LegacyPRDDB == nil or LegacyPRDDB.showResourceRechargeTimer ~= false
end

local function ApplyResourceBorder(frame)
    if not frame then return end
    if not ShouldShowResourceBorders() then
        frame:SetBackdrop(nil)
        return
    end

    local edgeFile = type(LegacyPRD_GetBorderTexturePath) == "function" and LegacyPRD_GetBorderTexturePath() or nil
    local edgeSize = type(LegacyPRD_GetBorderSize) == "function" and LegacyPRD_GetBorderSize() or 1
    if not edgeFile or edgeSize <= 0 then
        frame:SetBackdrop(nil)
        return
    end

    frame:SetBackdrop({
        edgeFile = edgeFile,
        edgeSize = edgeSize,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local r, g, b, a = 0, 0, 0, 1
    if type(LegacyPRD_GetBorderColor) == "function" then
        r, g, b, a = LegacyPRD_GetBorderColor()
    end
    frame:SetBackdropBorderColor(r, g, b, a or 1)
end

local function FormatRemainingSeconds(sec)
    if not sec or sec <= 0 then return "" end
    if sec < 10 then
        return string.format("%.1f", sec)
    end
    return tostring(math.ceil(sec))
end

local function NormalizeCooldownValues(startTime, duration, now)
    if not startTime or not duration then
        return startTime, duration
    end

    -- Some clients/addons can expose cooldown values in milliseconds.
    if duration > 100 then
        duration = duration / 1000
    end
    if now and startTime > (now * 10) then
        startTime = startTime / 1000
    end

    return startTime, duration
end

local function ClearIndicatorCooldown(ind)
    if not ind then return end
    if ind.cooldown then
        if ind.cooldown.Clear then
            ind.cooldown:Clear()
        else
            ind.cooldown:SetCooldown(0, 0)
        end
        ind.cooldown:Hide()
    end
    if ind.cooldownText then
        ind.cooldownText:SetText("")
    end
end

local function UpdateRuneIndicatorCooldown(ind, runeIndex, now)
    if not ind then return false end
    if not ShouldShowRuneRechargeTracker() then
        ClearIndicatorCooldown(ind)
        return false
    end
    local startTime, duration, runeReady = GetRuneCooldown(runeIndex)
    startTime, duration = NormalizeCooldownValues(startTime, duration, now)
    if runeReady or not startTime or not duration or duration <= 0 then
        ClearIndicatorCooldown(ind)
        return false
    end

    local remaining = (startTime + duration) - now
    if remaining <= 0 then
        ClearIndicatorCooldown(ind)
        return false
    end

    if ind.cooldown then
        -- Cooldown swipes look square over round rune atlases; keep text-only tracker for icons.
        ind.cooldown:Hide()
    end
    if ind.cooldownText then
        ind.cooldownText:SetText(FormatRemainingSeconds(remaining))
    end
    return true
end

local function GetRuneIndexForDisplay(displayIndex, maxRunes)
    if not classConfig or not classConfig.isRunes then
        return displayIndex
    end

    local max = maxRunes or 6
    return (max - displayIndex + 1)
end

local function UpdateRuneCooldownVisuals()
    if not classConfig or not classConfig.isRunes then
        return false
    end

    if not ShouldShowRuneRechargeTracker() then
        for i = 1, #indicators do
            ClearIndicatorCooldown(indicators[i])
        end
        return false
    end

    if GetResourceStyle() == "bar" or not isVisible then
        for i = 1, #indicators do
            ClearIndicatorCooldown(indicators[i])
        end
        return false
    end

    local max = math.min(GetMax(), #indicators)
    local now = GetTime()
    local anyPending = false
    for i = 1, max do
        local runeIndex = GetRuneIndexForDisplay(i, max)
        if UpdateRuneIndicatorCooldown(indicators[i], runeIndex, now) then
            anyPending = true
        end
    end
    for i = max + 1, #indicators do
        ClearIndicatorCooldown(indicators[i])
    end
    return anyPending
end

local function StopRuneTextUpdates()
    runeTextElapsed = 0
    if eventFrame then
        eventFrame:SetScript("OnUpdate", nil)
    end
end

local function StartRuneTextUpdates()
    if not eventFrame then return end
    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        runeTextElapsed = runeTextElapsed + elapsed
        if runeTextElapsed < RUNE_TEXT_UPDATE_INTERVAL then return end
        runeTextElapsed = 0

        local pending
        if GetResourceStyle() == "bar" then
            pending = UpdateBarSegments and UpdateBarSegments() or false
        else
            pending = UpdateRuneCooldownVisuals()
        end

        if not pending then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function ShouldShowResources()
    if not classConfig then return false end
    if not LegacyPRDDB or not LegacyPRDDB.showClassResources then return false end

    if classConfig.requiresForm then
        if GetShapeshiftForm() ~= 2 then return false end
    end

    if classConfig.requiresSpec then
        if GetSpecialization() ~= classConfig.requiresSpec then return false end
    end

    return true
end

GetMax = function()
    if classConfig.isRunes then return 6 end
    local pt  = classConfig.powerType
    local max = UnitPowerMax("player", pt)
    if max == 0 then max = classConfig.maxDefault end
    return max
end

local function GetCurrent()
    if classConfig.isRunes then return 0 end -- per-rune handled separately
    return UnitPower("player", classConfig.powerType)
end

---------------------------------------------------------------------------
-- Scaled icon dimensions (Blizzard/Squares styles)
---------------------------------------------------------------------------
local function GetScaledIconDimensions()
    local db = LegacyPRDDB
    local style = GetResourceStyle()
    local heightPct   = (db and db.height or 100) / 100
    local iconSizePct = (db and db.resourceIconSize or 100) / 100
    local iconH = math.floor(BASE_ICON_HEIGHT * heightPct * iconSizePct + 0.5)
    if iconH < 4 then iconH = 4 end
    -- Squares are always 1:1; Blizzard uses class aspect ratio
    local ratio = (style == "squares") and 1 or (classConfig.aspectRatio or 1)
    local iconW = math.floor(iconH * ratio + 0.5)
    if iconW < 4 then iconW = 4 end
    return iconW, iconH
end

---------------------------------------------------------------------------
-- Resolve atlas names for current class (DK: spec-dependent)
---------------------------------------------------------------------------
local function GetActiveEmptyAtlasLists()
    if classConfig.isRunes then
        local spec = GetSpecialization() or 1
        local rune = DK_RUNE_ATLASES[spec] or DK_RUNE_ATLASES[1]
        return rune.active, rune.empty
    end
    return classConfig.activeAtlas, classConfig.emptyAtlas
end

local function ResolveIndicatorAtlases(ind)
    local activeList, emptyList = GetActiveEmptyAtlasLists()
    ind.filledAtlas = FindWorkingAtlas(activeList)
    ind.emptyAtlas  = FindWorkingAtlas(emptyList)
end

---------------------------------------------------------------------------
-- Set an indicator to filled or empty state (Blizzard / Squares)
---------------------------------------------------------------------------
local function SetIndicatorFilled(ind, isCharged)
    local style = GetResourceStyle()
    local r, g, b, a = GetActiveResourceColor()
    if isCharged then
        r, g, b, a = GetChargedResourceColor()
    end

    if style ~= "squares" and ind.filledAtlas then
        ind.texture:SetAtlas(ind.filledAtlas, false)
        if isCharged then
            ind.texture:SetVertexColor(r, g, b, a)
        else
            ind.texture:SetVertexColor(1, 1, 1, 1)
        end
    else
        ind.texture:SetTexture(GetResourceFillTexture())
        ind.texture:SetVertexColor(r, g, b, a)
    end
    ind.texture:SetDesaturated(false)
    ind.texture:SetAlpha(1.0)
    ind:Show()
end

local function SetIndicatorEmpty(ind, isCharged)
    local style = GetResourceStyle()
    local chargedR, chargedG, chargedB = GetChargedResourceColor()
    if style ~= "squares" and ind.emptyAtlas then
        ind.texture:SetAtlas(ind.emptyAtlas, false)
        if isCharged then
            ind.texture:SetVertexColor(chargedR, chargedG, chargedB, 0.65)
        else
            ind.texture:SetVertexColor(1, 1, 1, 1)
        end
        ind.texture:SetDesaturated(false)
        ind.texture:SetAlpha(1.0)
    elseif style ~= "squares" and ind.filledAtlas then
        ind.texture:SetAtlas(ind.filledAtlas, false)
        if isCharged then
            ind.texture:SetVertexColor(chargedR, chargedG, chargedB, 0.65)
            ind.texture:SetDesaturated(false)
            ind.texture:SetAlpha(0.35)
        else
            ind.texture:SetVertexColor(1, 1, 1, 1)
            ind.texture:SetDesaturated(true)
            ind.texture:SetAlpha(0.35)
        end
    else
        if isCharged then
            ind.texture:SetTexture(GetResourceFillTexture())
            ind.texture:SetVertexColor(chargedR * 0.45, chargedG * 0.45, chargedB * 0.45, 0.85)
        else
            ind.texture:SetTexture(EMPTY_TEXTURE)
            ind.texture:SetVertexColor(0.15, 0.15, 0.15, 0.8)
        end
        ind.texture:SetDesaturated(false)
        ind.texture:SetAlpha(1.0)
    end
    ind:Show()
end

---------------------------------------------------------------------------
-- Indicator creation
---------------------------------------------------------------------------
local function CreateIndicator(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f.texture = f:CreateTexture(nil, "ARTWORK")
    f.texture:SetAllPoints()

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    if f.cooldown.SetDrawBling then f.cooldown:SetDrawBling(false) end
    if f.cooldown.SetDrawEdge then f.cooldown:SetDrawEdge(false) end
    if f.cooldown.SetHideCountdownNumbers then f.cooldown:SetHideCountdownNumbers(true) end
    if f.cooldown.SetReverse then f.cooldown:SetReverse(true) end
    if f.cooldown.SetSwipeColor then f.cooldown:SetSwipeColor(0, 0, 0, 0.75) end
    f.cooldown:Hide()

    f.cooldownText = f:CreateFontString(nil, "OVERLAY")
    f.cooldownText:SetPoint("CENTER", f.texture, "CENTER", 0, 1)
    f.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    f.cooldownText:SetJustifyH("CENTER")
    f.cooldownText:SetJustifyV("MIDDLE")
    f.cooldownText:SetTextColor(1, 1, 1, 1)
    f.cooldownText:SetShadowColor(0, 0, 0, 1)
    f.cooldownText:SetShadowOffset(1, -1)
    f.cooldownText:SetText("")

    ResolveIndicatorAtlases(f)
    ApplyResourceBorder(f)
    ClearIndicatorCooldown(f)
    SetIndicatorEmpty(f)  -- start empty
    return f
end

---------------------------------------------------------------------------
-- Refresh atlases on all existing indicators (DK spec change)
---------------------------------------------------------------------------
local function RefreshAllIndicatorAtlases()
    for _, ind in ipairs(indicators) do
        ResolveIndicatorAtlases(ind)
    end
end

---------------------------------------------------------------------------
-- Layout for floating indicators (Blizzard / Squares styles)
---------------------------------------------------------------------------
function LegacyPRD_UpdateClassResourceLayout(barWidth, position)
    if not resourceRow then return end
    if not isVisible then
        resourceRow:Hide()
        return
    end

    local style = GetResourceStyle()
    if style == "bar" then
        resourceRow:Hide()
        return
    end

    local max = GetMax()
    if max <= 0 then
        resourceRow:Hide()
        return
    end

    local iconW, iconH = GetScaledIconDimensions()
    local gap = (LegacyPRDDB and LegacyPRDDB.resourceIconSpacing) or INDICATOR_GAP

    resourceRow:ClearAllPoints()
    if position == "top" then
        resourceRow:SetPoint("BOTTOMLEFT", ns.mainFrame, "TOPLEFT", 1, RESOURCE_GAP)
    else
        resourceRow:SetPoint("TOPLEFT", ns.mainFrame, "BOTTOMLEFT", 1, -RESOURCE_GAP)
    end

    resourceRow:SetSize(barWidth, iconH)
    resourceRow:Show()

    -- Ensure enough indicators exist
    while #indicators < max do
        indicators[#indicators + 1] = CreateIndicator(resourceRow)
    end

    -- Center the icons horizontally
    local totalW = max * iconW + (max - 1) * gap
    local xOffset = math.floor((barWidth - totalW) / 2)
    if xOffset < 0 then xOffset = 0 end

    for i = 1, max do
        local ind = indicators[i]
        ind:ClearAllPoints()
        ind:SetSize(iconW, iconH)
        if ind.cooldownText then
            local fs = math.max(6, math.floor(math.min(iconH, iconW) * 0.55))
            ind.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", fs, "OUTLINE")
            ind.cooldownText:SetWidth(math.max(iconW + 8, 18))
            if ind.cooldownText.SetWordWrap then ind.cooldownText:SetWordWrap(false) end
        end
        ApplyResourceBorder(ind)
        if i == 1 then
            ind:SetPoint("TOPLEFT", resourceRow, "TOPLEFT", xOffset, 0)
        else
            ind:SetPoint("LEFT", indicators[i - 1], "RIGHT", gap, 0)
        end
        ind:Show()
    end

    -- Hide only surplus indicators beyond max
    for i = max + 1, #indicators do
        indicators[i]:Hide()
    end

    currentMax = max
end

---------------------------------------------------------------------------
-- Layout for bar-style resources (inside main frame, sized by ApplySettings)
---------------------------------------------------------------------------
function LegacyPRD_UpdateBarResourceLayout()
    if not resourceBarFrame then return end
    if not isVisible then return end

    local max = GetMax()
    if max <= 0 then return end

    local w, h = resourceBarFrame:GetSize()
    if w <= 0 or h <= 0 then return end

    local divW = 1
    local totalDividers = max - 1
    local availW = w - totalDividers * divW
    local segW = availW / max

    while #barSegments < max do
        local seg = CreateFrame("Frame", nil, resourceBarFrame, "BackdropTemplate")
        seg.bg = seg:CreateTexture(nil, "BACKGROUND")
        seg.bg:SetAllPoints()
        seg.bg:SetTexture(EMPTY_TEXTURE)
        seg.bg:SetVertexColor(0.15, 0.15, 0.15, 0.8)

        seg.texture = seg:CreateTexture(nil, "ARTWORK")
        seg.texture:SetPoint("TOPLEFT", seg, "TOPLEFT", 0, 0)
        seg.texture:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", 0, 0)
        seg.texture:SetWidth(0)

        seg.timerText = seg:CreateFontString(nil, "OVERLAY")
        seg.timerText:SetPoint("CENTER", seg, "CENTER", 0, 0)
        seg.timerText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        seg.timerText:SetTextColor(1, 1, 1, 1)
        seg.timerText:SetShadowColor(0, 0, 0, 1)
        seg.timerText:SetShadowOffset(1, -1)
        seg.timerText:SetText("")

        ApplyResourceBorder(seg)
        barSegments[#barSegments + 1] = seg
    end

    for i = 1, max do
        local seg = barSegments[i]
        seg:ClearAllPoints()
        seg:SetSize(segW, h)
        ApplyResourceBorder(seg)
        if seg.timerText then
            local fs = math.max(6, math.floor(math.min(h, segW) * 0.55))
            seg.timerText:SetFont("Fonts\\FRIZQT__.TTF", fs, "OUTLINE")
            seg.timerText:SetWidth(segW)
            if seg.timerText.SetWordWrap then seg.timerText:SetWordWrap(false) end
        end
        local xOff = (i - 1) * (segW + divW)
        seg:SetPoint("TOPLEFT", resourceBarFrame, "TOPLEFT", xOff, 0)
        seg:Show()
    end

    for i = max + 1, #barSegments do
        barSegments[i]:Hide()
    end

    currentMax = max
end

local function SetBarSegmentFill(seg, progress, texturePath, r, g, b, a)
    if not seg or not seg.texture then return end
    if seg.bg then
        seg.bg:SetTexture(EMPTY_TEXTURE)
        seg.bg:SetVertexColor(0.15, 0.15, 0.15, 0.8)
    end

    if progress <= 0 then
        seg.texture:Hide()
        return
    end

    if progress > 1 then progress = 1 end
    seg.texture:Show()
    seg.texture:SetTexture(texturePath)
    seg.texture:SetVertexColor(r, g, b, a)
    seg.texture:ClearAllPoints()
    seg.texture:SetPoint("TOPLEFT", seg, "TOPLEFT", 0, 0)
    seg.texture:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", 0, 0)

    local w = seg:GetWidth() * progress
    if w < 2 then w = 2 end
    seg.texture:SetWidth(w)
end

local function SetBarSegmentTimerText(seg, text)
    if seg and seg.timerText then
        seg.timerText:SetText(text or "")
    end
end

---------------------------------------------------------------------------
-- Update bar segment fill states
---------------------------------------------------------------------------
UpdateBarSegments = function()
    if not resourceBarFrame or not resourceBarFrame:IsShown() then return false end
    local max = GetMax()
    local r, g, b, a = GetActiveResourceColor()
    local chargedR, chargedG, chargedB, chargedA = GetChargedResourceColor()
    local fillTexture = GetResourceFillTexture()

    if classConfig.isRunes then
        local showTracker = ShouldShowRuneRechargeTracker()
        local now = GetTime()
        local anyPending = false
        for i = 1, math.min(max, #barSegments) do
            local seg = barSegments[i]
            local runeIndex = GetRuneIndexForDisplay(i, max)
            local startTime, duration, runeReady = GetRuneCooldown(runeIndex)
            startTime, duration = NormalizeCooldownValues(startTime, duration, now)
            if runeReady then
                SetBarSegmentFill(seg, 1, fillTexture, r, g, b, a)
                SetBarSegmentTimerText(seg, "")
            else
                if showTracker and startTime and duration and duration > 0 then
                    local progress = (now - startTime) / duration
                    if progress < 0 then progress = 0 end
                    if progress > 1 then progress = 1 end

                    SetBarSegmentFill(seg, progress, fillTexture, r, g, b, a)

                    local remaining = (startTime + duration) - now
                    if remaining > 0 then
                        anyPending = true
                        SetBarSegmentTimerText(seg, FormatRemainingSeconds(remaining))
                    else
                        SetBarSegmentTimerText(seg, "")
                    end
                else
                    SetBarSegmentFill(seg, 0, fillTexture, r, g, b, a)
                    SetBarSegmentTimerText(seg, "")
                end
            end
        end
        for i = max + 1, #barSegments do
            SetBarSegmentFill(barSegments[i], 0, fillTexture, r, g, b, a)
            SetBarSegmentTimerText(barSegments[i], "")
        end
        return showTracker and anyPending
    else
        local cur = GetCurrent()
        local chargedLookup = GetChargedPointLookup()
        for i = 1, math.min(max, #barSegments) do
            local seg = barSegments[i]
            if i <= cur then
                if chargedLookup and chargedLookup[i] then
                    SetBarSegmentFill(seg, 1, fillTexture, chargedR, chargedG, chargedB, chargedA)
                else
                    SetBarSegmentFill(seg, 1, fillTexture, r, g, b, a)
                end
            else
                if chargedLookup and chargedLookup[i] then
                    SetBarSegmentFill(seg, 1, fillTexture, chargedR * 0.45, chargedG * 0.45, chargedB * 0.45, 0.85)
                else
                    SetBarSegmentFill(seg, 0, fillTexture, r, g, b, a)
                end
            end
            SetBarSegmentTimerText(seg, "")
        end
        for i = max + 1, #barSegments do
            SetBarSegmentFill(barSegments[i], 0, fillTexture, r, g, b, a)
            SetBarSegmentTimerText(barSegments[i], "")
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Update fill states
---------------------------------------------------------------------------
function LegacyPRD_UpdateClassResources()
    local shouldShow = ShouldShowResources()
    local visibilityChanged = (shouldShow ~= isVisible)
    isVisible = shouldShow

    if visibilityChanged or (isVisible and not resourceRow) then
        if LegacyPRD_ApplySettings then
            LegacyPRD_ApplySettings()
        end
        if not isVisible then
            if classConfig.isRunes then
                StopRuneTextUpdates()
                for i = 1, #indicators do
                    ClearIndicatorCooldown(indicators[i])
                end
            end
            return
        end
    end

    if not isVisible then
        if classConfig.isRunes then
            StopRuneTextUpdates()
            for i = 1, #indicators do
                ClearIndicatorCooldown(indicators[i])
            end
        end
        return
    end

    local max = GetMax()

    if max ~= currentMax then
        if LegacyPRD_ApplySettings then
            LegacyPRD_ApplySettings()
        end
    end

    local style = GetResourceStyle()

    if style == "bar" then
        local pending = UpdateBarSegments()
        if classConfig.isRunes then
            if pending then
                StartRuneTextUpdates()
            else
                StopRuneTextUpdates()
            end
            for i = 1, #indicators do
                ClearIndicatorCooldown(indicators[i])
            end
        end
    else
        -- Blizzard / Squares: update floating indicators
        if not resourceRow then return end
        if classConfig.isRunes then
            for i = 1, math.min(max, #indicators) do
                local runeIndex = GetRuneIndexForDisplay(i, max)
                local _, _, runeReady = GetRuneCooldown(runeIndex)
                if runeReady then
                    SetIndicatorFilled(indicators[i])
                else
                    SetIndicatorEmpty(indicators[i])
                end
            end
            if UpdateRuneCooldownVisuals() then
                StartRuneTextUpdates()
            else
                StopRuneTextUpdates()
            end
        else
            StopRuneTextUpdates()
            local cur = GetCurrent()
            local chargedLookup = GetChargedPointLookup()
            for i = 1, math.min(max, #indicators) do
                local isCharged = chargedLookup and chargedLookup[i]
                if i <= cur then
                    SetIndicatorFilled(indicators[i], isCharged)
                else
                    SetIndicatorEmpty(indicators[i], isCharged)
                end
            end
            for i = 1, #indicators do
                ClearIndicatorCooldown(indicators[i])
            end
        end
    end
end

---------------------------------------------------------------------------
-- Visibility check for ApplySettings
---------------------------------------------------------------------------
function LegacyPRD_ClassResourcesVisible()
    return isVisible
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function LegacyPRD_InitClassResources()
    if not classConfig then return end
    if not ns.powerBar then return end

    -- Floating row for Blizzard/Squares styles
    resourceRow = CreateFrame("Frame", nil, ns.mainFrame)
    resourceRow:Hide()
    ns.classResourceRow = resourceRow

    -- Bar-style resource display (inside main frame)
    resourceBarFrame = CreateFrame("Frame", nil, ns.mainFrame)
    resourceBarFrame.bg = resourceBarFrame:CreateTexture(nil, "BACKGROUND")
    resourceBarFrame.bg:SetAllPoints()
    resourceBarFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    resourceBarFrame:Hide()
    ns.classResourceBar = resourceBarFrame

    eventFrame = CreateFrame("Frame")

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    if IsComboPointResource() then
        eventFrame:RegisterEvent("UNIT_POWER_POINT_CHARGE")
    end

    if classConfig.requiresSpec then
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    end
    if classConfig.requiresForm then
        eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    end
    if classConfig.isRunes then
        eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        currentDKSpec = GetSpecialization()
    end

    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_POWER_POINT_CHARGE" then
            if arg1 ~= "player" then return end
        end

        if classConfig.isRunes and event == "PLAYER_SPECIALIZATION_CHANGED" then
            local newSpec = GetSpecialization()
            if newSpec ~= currentDKSpec then
                currentDKSpec = newSpec
                RefreshAllIndicatorAtlases()
            end
        end

        LegacyPRD_UpdateClassResources()
    end)

    isVisible = ShouldShowResources()
    LegacyPRD_UpdateClassResources()
end
