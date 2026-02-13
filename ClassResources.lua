local addonName, ns = ...

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local BASE_ICON_HEIGHT = 12
local RESOURCE_GAP     = 3
local INDICATOR_GAP    = 2

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

local function GetMax()
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
local function SetIndicatorFilled(ind)
    local style = GetResourceStyle()
    if style ~= "squares" and ind.filledAtlas then
        ind.texture:SetAtlas(ind.filledAtlas, false)
        ind.texture:SetVertexColor(1, 1, 1, 1)
    else
        ind.texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        local r, g, b, a = GetActiveResourceColor()
        ind.texture:SetVertexColor(r, g, b, a)
    end
    ind.texture:SetDesaturated(false)
    ind.texture:SetAlpha(1.0)
    ind:Show()
end

local function SetIndicatorEmpty(ind)
    local style = GetResourceStyle()
    if style ~= "squares" and ind.emptyAtlas then
        ind.texture:SetAtlas(ind.emptyAtlas, false)
        ind.texture:SetVertexColor(1, 1, 1, 1)
        ind.texture:SetDesaturated(false)
        ind.texture:SetAlpha(1.0)
    elseif style ~= "squares" and ind.filledAtlas then
        ind.texture:SetAtlas(ind.filledAtlas, false)
        ind.texture:SetVertexColor(1, 1, 1, 1)
        ind.texture:SetDesaturated(true)
        ind.texture:SetAlpha(0.35)
    else
        ind.texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        ind.texture:SetVertexColor(0.15, 0.15, 0.15, 0.8)
        ind.texture:SetDesaturated(false)
        ind.texture:SetAlpha(1.0)
    end
    ind:Show()
end

---------------------------------------------------------------------------
-- Indicator creation — plain Frame, single texture, NO backdrop/border
---------------------------------------------------------------------------
local function CreateIndicator(parent)
    local f = CreateFrame("Frame", nil, parent)  -- NO template
    f.texture = f:CreateTexture(nil, "ARTWORK")
    f.texture:SetAllPoints()

    ResolveIndicatorAtlases(f)
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
        local seg = CreateFrame("Frame", nil, resourceBarFrame)
        seg.texture = seg:CreateTexture(nil, "ARTWORK")
        seg.texture:SetAllPoints()
        barSegments[#barSegments + 1] = seg
    end

    for i = 1, max do
        local seg = barSegments[i]
        seg:ClearAllPoints()
        seg:SetSize(segW, h)
        local xOff = (i - 1) * (segW + divW)
        seg:SetPoint("TOPLEFT", resourceBarFrame, "TOPLEFT", xOff, 0)
        seg:Show()
    end

    for i = max + 1, #barSegments do
        barSegments[i]:Hide()
    end

    currentMax = max
end

---------------------------------------------------------------------------
-- Update bar segment fill states
---------------------------------------------------------------------------
local function UpdateBarSegments()
    if not resourceBarFrame or not resourceBarFrame:IsShown() then return end
    local max = GetMax()
    local r, g, b, a = GetActiveResourceColor()

    if classConfig.isRunes then
        for i = 1, math.min(max, #barSegments) do
            local _, _, runeReady = GetRuneCooldown(i)
            if runeReady then
                barSegments[i].texture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
                barSegments[i].texture:SetVertexColor(r, g, b, a)
            else
                barSegments[i].texture:SetTexture("Interface\\Buttons\\WHITE8x8")
                barSegments[i].texture:SetVertexColor(0.15, 0.15, 0.15, 0.8)
            end
        end
    else
        local cur = GetCurrent()
        for i = 1, math.min(max, #barSegments) do
            if i <= cur then
                barSegments[i].texture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
                barSegments[i].texture:SetVertexColor(r, g, b, a)
            else
                barSegments[i].texture:SetTexture("Interface\\Buttons\\WHITE8x8")
                barSegments[i].texture:SetVertexColor(0.15, 0.15, 0.15, 0.8)
            end
        end
    end
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
        if not isVisible then return end
    end

    if not isVisible then return end

    local max = GetMax()

    if max ~= currentMax then
        if LegacyPRD_ApplySettings then
            LegacyPRD_ApplySettings()
        end
    end

    local style = GetResourceStyle()

    if style == "bar" then
        UpdateBarSegments()
    else
        -- Blizzard / Squares: update floating indicators
        if not resourceRow then return end
        if classConfig.isRunes then
            for i = 1, math.min(max, #indicators) do
                local _, _, runeReady = GetRuneCooldown(i)
                if runeReady then
                    SetIndicatorFilled(indicators[i])
                else
                    SetIndicatorEmpty(indicators[i])
                end
            end
        else
            local cur = GetCurrent()
            for i = 1, math.min(max, #indicators) do
                if i <= cur then
                    SetIndicatorFilled(indicators[i])
                else
                    SetIndicatorEmpty(indicators[i])
                end
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

    local ef = CreateFrame("Frame")

    ef:RegisterEvent("PLAYER_ENTERING_WORLD")
    ef:RegisterEvent("UNIT_POWER_FREQUENT")
    ef:RegisterEvent("UNIT_MAXPOWER")

    if classConfig.requiresSpec then
        ef:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    end
    if classConfig.requiresForm then
        ef:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    end
    if classConfig.isRunes then
        ef:RegisterEvent("RUNE_POWER_UPDATE")
        ef:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        currentDKSpec = GetSpecialization()
    end

    ef:SetScript("OnEvent", function(self, event, arg1)
        if event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
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
