local addonName, ns = ...

---------------------------------------------------------------------------
-- Local references for performance (cached upvalues for future OnUpdate)
---------------------------------------------------------------------------
local UnitHealth        = UnitHealth
local UnitHealthMax     = UnitHealthMax
local UnitPower         = UnitPower
local UnitPowerMax      = UnitPowerMax
local UnitPowerType     = UnitPowerType
local UnitClass         = UnitClass
local InCombatLockdown  = InCombatLockdown
local SetCVar           = SetCVar

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local BAR_WIDTH      = 140
local HEALTH_HEIGHT  = 10
local POWER_HEIGHT   = 8
local SEP_HEIGHT     = 2

local ALPHA_COMBAT   = 1.0
local ALPHA_OOC      = 0.6

---------------------------------------------------------------------------
-- Text formatting
---------------------------------------------------------------------------
local function SafeToString(v)
    local ok, s = pcall(tostring, v)
    if ok and s then return s end
    return "?"
end

local function SafeNumber(v)
    if v == nil then return nil end
    if type(v) ~= "number" then
        local ok, n = pcall(tonumber, v)
        if ok then return n end
        return nil
    end
    local ok = pcall(function()
        local _ = v + 0
    end)
    if ok then return v end
    return nil
end

local function FormatShortNumber(n)
    if n >= 1000000 then
        local out = string.format("%.1fm", n / 1000000)
        return out:gsub("%.0m", "m")
    elseif n >= 1000 then
        local out = string.format("%.1fk", n / 1000)
        return out:gsub("%.0k", "k")
    end
    return tostring(n)
end

local function FormatFullNumber(n)
    if type(BreakUpLargeNumbers) == "function" then
        local ok, out = pcall(BreakUpLargeNumbers, n)
        if ok and out then return out end
    end
    return tostring(n)
end

local function CleanNumber(v)
    if v == nil then return nil end
    local ok, s = pcall(tostring, v)
    if not ok or not s then return nil end
    local ok2, n = pcall(tonumber, s)
    if ok2 then return n end
    return nil
end

local function BuildStatusText(cur, max, mode)
    if mode == "OFF" then return "" end

    local curN = SafeNumber(cur)
    local maxN = SafeNumber(max)
    local canMath = (curN ~= nil and maxN ~= nil and maxN > 0)

    local curText
    local maxText
    if curN ~= nil and maxN ~= nil then
        curText = FormatShortNumber(curN)
        maxText = FormatShortNumber(maxN)
    else
        curText = SafeToString(cur)
        maxText = SafeToString(max)
    end

    if mode == "CURRENT" then
        return curText
    end

    return curText .. "/" .. maxText
end

---------------------------------------------------------------------------
-- Frame references (assigned in CreateBars)
---------------------------------------------------------------------------
local prdAnchor   -- LegacyPRDAnchor (invisible scale-1.0 position anchor)
local mainFrame   -- LegacyPRDFrame
local healthBar   -- LegacyPRDHealthBar
local separator   -- black divider between health and power
local powerBar    -- LegacyPRDPowerBar
local castSep     -- black divider between power and cast bar
local castBar     -- LegacyPRDCastBar

---------------------------------------------------------------------------
-- Shared backdrop definition: 1px solid black border, no fill
---------------------------------------------------------------------------
local BORDER_BACKDROP = {
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets   = { left = 0, right = 0, top = 0, bottom = 0 },
}

---------------------------------------------------------------------------
-- Bar creation
---------------------------------------------------------------------------
local function CreateBars()
    -----------------------------------------------------------------------
    -- 1a) Invisible anchor frame — always scale 1.0, handles position only
    -----------------------------------------------------------------------
    prdAnchor = CreateFrame("Frame", "LegacyPRDAnchor", UIParent)
    prdAnchor:SetSize(1, 1)
    prdAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
    prdAnchor:SetClampedToScreen(true)

    -----------------------------------------------------------------------
    -- 1b) Visual frame — parented to anchor, handles scale only
    -----------------------------------------------------------------------
    mainFrame = CreateFrame("Frame", "LegacyPRDFrame", prdAnchor, "BackdropTemplate")
    mainFrame:SetSize(BAR_WIDTH + 2, HEALTH_HEIGHT + SEP_HEIGHT + POWER_HEIGHT + 2)
    mainFrame:SetPoint("CENTER", prdAnchor, "CENTER", 0, 0)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(10)
    mainFrame:SetClampedToScreen(true)

    -- 1px black outline border wrapping all child elements
    mainFrame:SetBackdrop(BORDER_BACKDROP)
    mainFrame:SetBackdropBorderColor(0, 0, 0, 1)

    -----------------------------------------------------------------------
    -- 2) Health bar
    -----------------------------------------------------------------------
    healthBar = CreateFrame("StatusBar", "LegacyPRDHealthBar", mainFrame)
    healthBar:SetSize(BAR_WIDTH, HEALTH_HEIGHT)
    healthBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 1, -1)
    healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    healthBar:SetMinMaxValues(0, 1)
    healthBar:SetValue(1)

    healthBar.valueText = healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthBar.valueText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    healthBar.valueText:SetTextColor(1, 1, 1, 1)
    healthBar.valueText:SetShadowColor(0, 0, 0, 1)
    healthBar.valueText:SetShadowOffset(1, -1)

    -- Dark background visible behind the unfilled portion
    healthBar.bg = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBar.bg:SetAllPoints()
    healthBar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Class color (safe to call here; class data exists by ADDON_LOADED)
    local _, playerClass = UnitClass("player")
    local cc = RAID_CLASS_COLORS[playerClass]
    if cc then
        healthBar:SetStatusBarColor(cc.r, cc.g, cc.b)
    else
        healthBar:SetStatusBarColor(0, 1, 0)
    end

    -----------------------------------------------------------------------
    -- 3) Separator between health and power
    -----------------------------------------------------------------------
    separator = CreateFrame("Frame", nil, mainFrame)
    separator:SetHeight(SEP_HEIGHT)
    separator:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, 0)
    separator:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)

    separator.bg = separator:CreateTexture(nil, "BACKGROUND")
    separator.bg:SetAllPoints()
    separator.bg:SetColorTexture(0, 0, 0, 1)

    -----------------------------------------------------------------------
    -- 4) Power / resource bar
    -----------------------------------------------------------------------
    powerBar = CreateFrame("StatusBar", "LegacyPRDPowerBar", mainFrame)
    powerBar:SetSize(BAR_WIDTH, POWER_HEIGHT)
    powerBar:SetPoint("TOP", separator, "BOTTOM", 0, 0)
    powerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    powerBar:SetMinMaxValues(0, 1)
    powerBar:SetValue(1)

    powerBar.valueText = powerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    powerBar.valueText:SetPoint("CENTER", powerBar, "CENTER", 0, 0)
    powerBar.valueText:SetTextColor(1, 1, 1, 1)
    powerBar.valueText:SetShadowColor(0, 0, 0, 1)
    powerBar.valueText:SetShadowOffset(1, -1)

    powerBar.bg = powerBar:CreateTexture(nil, "BACKGROUND")
    powerBar.bg:SetAllPoints()
    powerBar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -----------------------------------------------------------------------
    -- 5) Second separator (reusable in separator pool)
    -----------------------------------------------------------------------
    castSep = CreateFrame("Frame", nil, mainFrame)
    castSep:SetHeight(SEP_HEIGHT)
    castSep.bg = castSep:CreateTexture(nil, "BACKGROUND")
    castSep.bg:SetAllPoints()
    castSep.bg:SetColorTexture(0, 0, 0, 1)
    castSep:Hide()

    -----------------------------------------------------------------------
    -- 6) Cast bar (inside main frame, shown during casts)
    -----------------------------------------------------------------------
    castBar = CreateFrame("StatusBar", "LegacyPRDCastBar", mainFrame)
    castBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)
    castBar:SetStatusBarColor(1.0, 0.7, 0.0)

    castBar.bg = castBar:CreateTexture(nil, "BACKGROUND")
    castBar.bg:SetAllPoints()
    castBar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    castBar:Hide()

    -----------------------------------------------------------------------
    -- 7) Third separator (for separator pool)
    -----------------------------------------------------------------------
    local sep3 = CreateFrame("Frame", nil, mainFrame)
    sep3:SetHeight(SEP_HEIGHT)
    sep3.bg = sep3:CreateTexture(nil, "BACKGROUND")
    sep3.bg:SetAllPoints()
    sep3.bg:SetColorTexture(0, 0, 0, 1)
    sep3:Hide()

    -----------------------------------------------------------------------
    -- Initial alpha based on current combat state
    -----------------------------------------------------------------------
    mainFrame:SetAlpha(InCombatLockdown() and ALPHA_COMBAT or ALPHA_OOC)

    -- Expose on namespace for Config / other modules
    ns.prdAnchor  = prdAnchor
    ns.mainFrame  = mainFrame
    ns.healthBar  = healthBar
    ns.separator  = separator
    ns.powerBar   = powerBar
    ns.castBar    = castBar
    ns.castSep    = castSep
    ns.separatorPool = { separator, castSep, sep3 }

    mainFrame:Show()
end

---------------------------------------------------------------------------
-- Health bar update
---------------------------------------------------------------------------
local function UpdateHealthBar()
    if not healthBar then return end
    local curRaw = UnitHealth("player")
    local maxRaw = UnitHealthMax("player")
    local curN = CleanNumber(curRaw)
    local maxN = CleanNumber(maxRaw)

    local maxSet = maxN or maxRaw or 1
    local curSet = curN or curRaw or 0

    healthBar:SetMinMaxValues(0, maxSet)
    healthBar:SetValue(curSet)
    if healthBar.valueText then
        local mode = (LegacyPRDDB and LegacyPRDDB.healthTextMode) or "OFF"
        if mode == "OFF" then
            healthBar.valueText:SetText("")
        else
            local textCur = curN or curRaw
            local textMax = maxN or maxRaw
            healthBar.valueText:SetText(BuildStatusText(textCur, textMax, mode))
        end
    end
end

---------------------------------------------------------------------------
-- Power bar value update
---------------------------------------------------------------------------
local function UpdatePowerBar()
    if not powerBar then return end
    local powerType = UnitPowerType("player")
    local curRaw = UnitPower("player", powerType)
    local maxRaw = UnitPowerMax("player", powerType)
    local curN = CleanNumber(curRaw)
    local maxN = CleanNumber(maxRaw)

    local maxSet = maxN or maxRaw or 1
    local curSet = curN or curRaw or 0

    powerBar:SetMinMaxValues(0, maxSet)
    powerBar:SetValue(curSet)
    if powerBar.valueText then
        local mode = (LegacyPRDDB and LegacyPRDDB.powerTextMode) or "OFF"
        if mode == "OFF" then
            powerBar.valueText:SetText("")
        else
            local textCur = curN or curRaw
            local textMax = maxN or maxRaw
            powerBar.valueText:SetText(BuildStatusText(textCur, textMax, mode))
        end
    end
end

---------------------------------------------------------------------------
-- External refresh hook for text updates
---------------------------------------------------------------------------
function LegacyPRD_UpdateStatusText()
    UpdateHealthBar()
    UpdatePowerBar()
end

---------------------------------------------------------------------------
-- Full refresh: both bars + colors
---------------------------------------------------------------------------
local function FullRefresh()
    UpdateHealthBar()
    UpdatePowerBar()
    LegacyPRD_UpdateHealthColor()
    LegacyPRD_UpdatePowerColor()
end

---------------------------------------------------------------------------
-- Event driver
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "LegacyPRD_EventDriver")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

local function OnEvent(self, event, arg1)
    ------------------------------------------------------------------
    -- Initialization
    ------------------------------------------------------------------
    if event == "ADDON_LOADED" and arg1 == addonName then
        ns:InitDB()
        CreateBars()
        FullRefresh()

        -- Hide the default Blizzard personal resource display
        SetCVar("nameplateShowSelf", "0")

        -- Create settings panel and apply saved PRD settings
        ns:CreateSettingsPanel()
        LegacyPRD_ApplySettings()

        if LegacyPRD_InitClassResources then
            LegacyPRD_InitClassResources()
        end
        if LegacyPRD_InitCastBar then
            LegacyPRD_InitCastBar()
        end

        print("|cff00ccffLegacyPRD|r v1.0.2 loaded. Type |cff00ccff/lprd|r for options.")
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        SetCVar("nameplateShowSelf", "0")
        FullRefresh()
        LegacyPRD_ApplySettings()
        if LegacyPRD_UpdateClassResources then
            LegacyPRD_UpdateClassResources()
        end

        -- Re-apply combat alpha (world transitions can reset state)
        if mainFrame then
            mainFrame:SetAlpha(InCombatLockdown() and ALPHA_COMBAT or ALPHA_OOC)
        end

    ------------------------------------------------------------------
    -- Health events
    ------------------------------------------------------------------
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if arg1 == "player" then
            UpdateHealthBar()
        end

    ------------------------------------------------------------------
    -- Power events
    ------------------------------------------------------------------
    elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        if arg1 == "player" then
            UpdatePowerBar()
        end

    elseif event == "UNIT_DISPLAYPOWER" then
        -- Power type changed (e.g. druid shapeshift): refresh value + color
        if arg1 == "player" then
            UpdatePowerBar()
            LegacyPRD_UpdatePowerColor()
        end

    ------------------------------------------------------------------
    -- Combat alpha fade
    ------------------------------------------------------------------
    elseif event == "PLAYER_REGEN_DISABLED" then
        if mainFrame then mainFrame:SetAlpha(ALPHA_COMBAT) end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if mainFrame then mainFrame:SetAlpha(ALPHA_OOC) end

    end
end


eventFrame:SetScript("OnEvent", OnEvent)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_LEGACYPRD1 = "/lprd"
SLASH_LEGACYPRD2 = "/legacyprd"
SlashCmdList["LEGACYPRD"] = function(msg)
    local args = strtrim(msg):lower()
    ns:HandleConfigCommand(args)
end
