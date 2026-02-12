local addonName, ns = ...

---------------------------------------------------------------------------
-- Defaults for buff/aura tracking (existing LegacyPRD_DB)
---------------------------------------------------------------------------
ns.defaults = {
    enabled = true,
    locked = false,
    scale = 1.0,
    iconSize = 32,
    spacing = 2,
    growDirection = "RIGHT",
    showTimers = true,
    showTooltips = true,
    trackedBuffs = {},
    playerFrameEnabled = true,
}

---------------------------------------------------------------------------
-- Defaults for PRD frame settings (LegacyPRDDB)
---------------------------------------------------------------------------
local PRD_DEFAULTS = {
    posX   = 0,
    posY   = -140,
    scale  = 100,
    width  = 100,
    height = 100,
    locked = true,
    healthColorMode   = "class",
    healthCustomColor = { r = 1, g = 0, b = 0 },
    powerColorMode    = "default",
    powerCustomColor  = { r = 0, g = 0.5, b = 1 },
    showHealthBar         = true,
    showPowerBar          = true,
    showCastBar           = false,
    castBarPosition       = "bottom",
    castBarVisibility     = "casting",
    castBarHeight         = 100,
    showClassResources    = true,
    resourceStyle         = "blizzard",
    classResourcePosition = "bottom",
    resourceIconSize      = 100,
    resourceIconSpacing   = 2,
    resourceColorMode     = "default",
    resourceCustomColor   = { r = 1, g = 1, b = 1 },
}

ns.DB = nil
ns.settingsCategory = nil

---------------------------------------------------------------------------
-- Helper: shallow-copy a value (copies one-level tables)
---------------------------------------------------------------------------
local function CopyDefault(v)
    if type(v) == "table" then
        local t = {}
        for kk, vv in pairs(v) do t[kk] = vv end
        return t
    end
    return v
end

---------------------------------------------------------------------------
-- Database initialization
---------------------------------------------------------------------------
function ns:InitDB()
    if not LegacyPRD_DB then
        LegacyPRD_DB = {}
    end
    for k, v in pairs(self.defaults) do
        if LegacyPRD_DB[k] == nil then
            LegacyPRD_DB[k] = v
        end
    end
    self.DB = LegacyPRD_DB

    if not LegacyPRDDB then
        LegacyPRDDB = {}
    end
    for k, v in pairs(PRD_DEFAULTS) do
        if LegacyPRDDB[k] == nil then
            LegacyPRDDB[k] = CopyDefault(v)
        end
    end

    -- Migrate old decimal scale (0.5-3.0) to new integer scale (1-200)
    if LegacyPRDDB.scale and LegacyPRDDB.scale < 10 then
        LegacyPRDDB.scale = math.floor(LegacyPRDDB.scale * 100 + 0.5)
    end
end

function ns:GetOption(key)
    return self.DB and self.DB[key]
end

function ns:SetOption(key, value)
    if self.DB then
        self.DB[key] = value
    end
end

function ns:ResetDefaults()
    LegacyPRD_DB = {}
    for k, v in pairs(self.defaults) do
        LegacyPRD_DB[k] = v
    end
    self.DB = LegacyPRD_DB

    LegacyPRDDB = {}
    for k, v in pairs(PRD_DEFAULTS) do
        LegacyPRDDB[k] = CopyDefault(v)
    end
end

---------------------------------------------------------------------------
-- Move handle overlay (created once, toggled by lock state)
---------------------------------------------------------------------------
local moveHandle

local function CreateMoveHandle(parent)
    if moveHandle then return moveHandle end

    moveHandle = CreateFrame("Frame", nil, parent)
    moveHandle:SetAllPoints()
    moveHandle:SetFrameLevel(parent:GetFrameLevel() + 10)

    moveHandle.bg = moveHandle:CreateTexture(nil, "OVERLAY")
    moveHandle.bg:SetAllPoints()
    moveHandle.bg:SetColorTexture(0.5, 0.5, 0.5, 0.4)

    moveHandle.text = moveHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    moveHandle.text:SetPoint("CENTER")
    moveHandle.text:SetText("Drag to move")
    moveHandle.text:SetTextColor(1, 1, 1, 1)

    moveHandle:EnableMouse(true)
    moveHandle:RegisterForDrag("LeftButton")

    moveHandle:SetScript("OnDragStart", function()
        ns.prdAnchor:StartMoving()
    end)

    moveHandle:SetScript("OnDragStop", function()
        ns.prdAnchor:StopMovingOrSizing()
        ns.prdAnchor:SetUserPlaced(false)

        local _, _, _, x, y = ns.prdAnchor:GetPoint()

        if LegacyPRDDB then
            LegacyPRDDB.posX = x
            LegacyPRDDB.posY = y
        end
    end)

    moveHandle:Hide()
    return moveHandle
end

---------------------------------------------------------------------------
-- Apply lock / unlock state to the PRD frame
---------------------------------------------------------------------------
local function ApplyLockState()
    local frame = ns.mainFrame
    local anchor = ns.prdAnchor
    if not frame or not anchor then return end

    CreateMoveHandle(frame)

    if LegacyPRDDB and LegacyPRDDB.locked then
        anchor:SetMovable(false)
        if moveHandle then moveHandle:Hide() end
    else
        anchor:SetMovable(true)
        if moveHandle then moveHandle:Show() end
    end
end

---------------------------------------------------------------------------
-- Position helper
---------------------------------------------------------------------------
function LegacyPRD_SetPosition()
    local anchor = ns.prdAnchor
    if not anchor then return end
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "CENTER", LegacyPRDDB and LegacyPRDDB.posX or 0, LegacyPRDDB and LegacyPRDDB.posY or -140)
end

---------------------------------------------------------------------------
-- Color update functions
---------------------------------------------------------------------------
function LegacyPRD_UpdateHealthColor()
    local bar = ns.healthBar
    if not bar or not LegacyPRDDB then return end
    local mode = LegacyPRDDB.healthColorMode or "class"
    if mode == "class" then
        local _, playerClass = UnitClass("player")
        local cc = RAID_CLASS_COLORS[playerClass]
        if cc then
            bar:SetStatusBarColor(cc.r, cc.g, cc.b)
        else
            bar:SetStatusBarColor(0, 1, 0)
        end
    elseif mode == "green" then
        bar:SetStatusBarColor(0, 0.8, 0, 1)
    elseif mode == "custom" then
        local c = LegacyPRDDB.healthCustomColor or { r = 1, g = 0, b = 0 }
        bar:SetStatusBarColor(c.r, c.g, c.b)
    end
end

function LegacyPRD_UpdatePowerColor()
    local bar = ns.powerBar
    if not bar or not LegacyPRDDB then return end
    local mode = LegacyPRDDB.powerColorMode or "default"
    if mode == "default" then
        local powerType = UnitPowerType("player")
        local color = PowerBarColor[powerType]
        if color then
            bar:SetStatusBarColor(color.r, color.g, color.b)
        else
            bar:SetStatusBarColor(0, 0, 1)
        end
    elseif mode == "custom" then
        local c = LegacyPRDDB.powerCustomColor or { r = 0, g = 0.5, b = 1 }
        bar:SetStatusBarColor(c.r, c.g, c.b)
    end
end

---------------------------------------------------------------------------
-- Layout rebuild (called by ApplySettings and when cast state changes)
---------------------------------------------------------------------------
function LegacyPRD_UpdateLayout()
    local db = LegacyPRDDB
    if not db or not ns.mainFrame then return end

    local frame = ns.mainFrame
    local w = ns.barWidth or (((db.width or 100) / 100) * 140)
    local sepH = 2

    local showHealth = db.showHealthBar ~= false
    local showPower  = db.showPowerBar  ~= false
    local alwaysShow = (db.castBarVisibility or "casting") == "always"
    local showCast   = ns.castBarEnabled and (ns.castBarActive == true or alwaysShow)
    local castPos    = db.castBarPosition or "bottom"

    local resourceStyle = db.resourceStyle or "blizzard"
    local showResources = LegacyPRD_ClassResourcesVisible and LegacyPRD_ClassResourcesVisible()
    local resourceIsBar = (resourceStyle == "bar") and showResources
    local resourcePos   = db.classResourcePosition or "bottom"

    -- Build ordered bars list (cast bar at top or bottom)
    local bars = {}
    if showCast and castPos == "top" and ns.castBar then
        bars[#bars + 1] = ns.castBar
    end

    if showHealth and ns.healthBar then
        bars[#bars + 1] = ns.healthBar
    end

    if showPower and ns.powerBar then
        bars[#bars + 1] = ns.powerBar
    end

    if resourceIsBar and ns.classResourceBar then
        bars[#bars + 1] = ns.classResourceBar
    end

    if showCast and castPos == "bottom" and ns.castBar then
        bars[#bars + 1] = ns.castBar
    end

    -- Show bars in layout, hide others
    local inLayout = {}
    for _, bar in ipairs(bars) do inLayout[bar] = true end
    for _, bar in ipairs({ ns.healthBar, ns.powerBar, ns.castBar, ns.classResourceBar }) do
        if bar then
            if inLayout[bar] then bar:Show() else bar:Hide() end
        end
    end

    -- Separator pool
    local separators = ns.separatorPool or {}
    local sepIdx = 0

    -- Build layout: interleave bars with separators
    local layout = {}
    for i, bar in ipairs(bars) do
        layout[#layout + 1] = { frame = bar, h = bar:GetHeight(), isSep = false }
        if i < #bars then
            sepIdx = sepIdx + 1
            local sep = separators[sepIdx]
            if sep then
                sep:SetHeight(sepH)
                sep:Show()
                layout[#layout + 1] = { frame = sep, h = sepH, isSep = true }
            end
        end
    end

    -- Hide unused separators
    for i = sepIdx + 1, #separators do
        if separators[i] then separators[i]:Hide() end
    end

    -- Anchor everything top-to-bottom inside the frame (two-point for width)
    local totalH = 0
    for i, item in ipairs(layout) do
        item.frame:ClearAllPoints()
        if i == 1 then
            item.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
            item.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        else
            item.frame:SetPoint("TOPLEFT", layout[i - 1].frame, "BOTTOMLEFT", 0, 0)
            item.frame:SetPoint("TOPRIGHT", layout[i - 1].frame, "BOTTOMRIGHT", 0, 0)
        end
        totalH = totalH + item.h
    end

    if totalH < 2 then totalH = 2 end
    frame:SetSize(w + 2, totalH + 2)

    -- Update bar-style resource segments after sizing
    if resourceIsBar and LegacyPRD_UpdateBarResourceLayout then
        LegacyPRD_UpdateBarResourceLayout()
    end

    -- Floating class resources (Blizzard / Squares styles)
    if showResources and not resourceIsBar then
        if LegacyPRD_UpdateClassResourceLayout then
            LegacyPRD_UpdateClassResourceLayout(w, resourcePos)
        end
    elseif ns.classResourceRow then
        ns.classResourceRow:Hide()
    end
end

---------------------------------------------------------------------------
-- Apply all saved settings from LegacyPRDDB to the PRD frame
---------------------------------------------------------------------------
function LegacyPRD_ApplySettings()
    local db = LegacyPRDDB
    if not db then return end

    local frame = ns.mainFrame
    if not frame then return end

    local widthPct  = (db.width  or 100) / 100
    local heightPct = (db.height or 100) / 100

    local w    = widthPct * 140
    local hh   = heightPct * 10
    local ph   = math.floor(hh * 0.8)
    local cbHPct = (db.castBarHeight or 100) / 100
    local cbH  = math.max(math.floor(hh * 0.6 * cbHPct + 0.5), 4)
    local rbH  = math.max(math.floor(hh * 0.5 + 0.5), 4)

    -- Store dimensions for UpdateLayout
    ns.barWidth = w

    -- Set bar sizes (height only for castBar — width from two-point anchoring)
    if ns.healthBar then ns.healthBar:SetSize(w, hh) end
    if ns.powerBar  then ns.powerBar:SetSize(w, ph) end
    if ns.castBar   then ns.castBar:SetHeight(cbH) end
    if ns.classResourceBar then ns.classResourceBar:SetSize(w, rbH) end

    -- Cast bar font
    if LegacyPRD_UpdateCastBarFont then
        LegacyPRD_UpdateCastBarFont(cbH)
    end

    -- Cast bar enabled flag
    ns.castBarEnabled = (db.showCastBar == true)

    -- Position (moves the scale-1.0 anchor)
    LegacyPRD_SetPosition()

    -- Scale (applied only to the visual frame, not the anchor)
    frame:SetScale((db.scale or 100) / 100)

    -- Lock state
    ApplyLockState()

    -- Colors
    LegacyPRD_UpdateHealthColor()
    LegacyPRD_UpdatePowerColor()

    -- Rebuild layout
    LegacyPRD_UpdateLayout()
end

ns.ApplyPRDSettings = LegacyPRD_ApplySettings

---------------------------------------------------------------------------
-- Settings panel: widget factory functions
---------------------------------------------------------------------------
local function MakeSlider(parent, name, label, minVal, maxVal, step)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(300, 36)

    local lbl = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(label)

    local sl = CreateFrame("Slider", "LegacyPRD_" .. name, box, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
    sl:SetWidth(200)
    sl:SetMinMaxValues(minVal, maxVal)
    sl:SetValueStep(step)
    sl:SetObeyStepOnDrag(true)
    if sl.Low  then sl.Low:SetText("")  end
    if sl.High then sl.High:SetText("") end
    if sl.Text then sl.Text:SetText("") end

    local val = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    val:SetPoint("LEFT", sl, "RIGHT", 8, 0)

    box.slider = sl
    box.val    = val
    box.lbl    = lbl
    return box
end

local function MakeCheck(parent, name, label)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(300, 24)

    local cb = CreateFrame("CheckButton", "LegacyPRD_" .. name, box, "UICheckButtonTemplate")
    cb:SetPoint("LEFT", 0, 0)

    local lbl = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    lbl:SetText(label)

    box.check = cb
    return box
end

local function MakeDropdown(parent, name, label)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(300, 44)

    local lbl = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(label)

    local dd = CreateFrame("Frame", "LegacyPRD_" .. name, box, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(dd, 150)

    box.dropdown = dd
    box.lbl      = lbl
    return box
end

local function MakeHeader(parent, text)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(300, 16)

    local fs = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 0, 0)
    fs:SetText("|cffffd100" .. text .. "|r")

    box.text = fs
    return box
end

local function MakeColorPicker(parent, label, getColor, setColor, onConfirm)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(260, 26)

    local border = box:CreateTexture(nil, "BORDER")
    border:SetSize(22, 22)
    border:SetPoint("LEFT", 2, 0)
    border:SetColorTexture(0, 0, 0, 1)

    local swatch = box:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(18, 18)
    swatch:SetPoint("CENTER", border, "CENTER")
    local c = getColor()
    swatch:SetColorTexture(c.r, c.g, c.b)

    local btn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    btn:SetSize(160, 22)
    btn:SetPoint("LEFT", border, "RIGHT", 6, 0)
    btn:SetText(label)

    btn:SetScript("OnClick", function()
        local cur = getColor()
        local pR, pG, pB = cur.r, cur.g, cur.b
        ColorPickerFrame:SetupColorPickerAndShow({
            r = pR, g = pG, b = pB,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                setColor(r, g, b)
                swatch:SetColorTexture(r, g, b)
                if onConfirm then onConfirm() end
            end,
            cancelFunc = function()
                setColor(pR, pG, pB)
                swatch:SetColorTexture(pR, pG, pB)
                if onConfirm then onConfirm() end
            end,
        })
    end)

    box.swatch = swatch
    return box
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------
function ns:CreateSettingsPanel()
    local canvas = CreateFrame("Frame", "LegacyPRDSettingsPanel")
    canvas:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)

    local content = CreateFrame("Frame")
    content:SetWidth(600)
    content:SetHeight(1200)
    scrollFrame:SetScrollChild(content)

    --------------- layout engine ---------------
    local items = {}
    local refreshing = false

    local function Add(frame, height, opts)
        items[#items + 1] = {
            frame   = frame,
            height  = height,
            indent  = opts and opts.indent or 0,
            isHead  = opts and opts.isHead or false,
            visFn   = opts and opts.visFn  or nil,
        }
    end

    local function LayoutAll()
        local cw = canvas:GetWidth()
        if cw and cw > 50 then content:SetWidth(cw - 30) end

        local y = -16
        for _, it in ipairs(items) do
            local vis = true
            if it.visFn then vis = it.visFn() end
            if vis then
                it.frame:Show()
                it.frame:ClearAllPoints()
                if it.isHead then y = y - 12 end
                it.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 16 + it.indent, y)
                y = y - it.height - 8
            else
                it.frame:Hide()
            end
        end
        content:SetHeight(math.abs(y) + 40)
    end

    --------------- widgets ---------------

    -- Title
    local titleBox = CreateFrame("Frame", nil, content)
    titleBox:SetSize(400, 20)
    local titleFS = titleBox:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleFS:SetPoint("TOPLEFT", 0, 0)
    titleFS:SetText("LegacyPRD - Personal Resource Display")
    Add(titleBox, 20)

    -- Subtitle
    local subBox = CreateFrame("Frame", nil, content)
    subBox:SetSize(400, 14)
    local subFS = subBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subFS:SetPoint("TOPLEFT", 0, 0)
    subFS:SetText("Restore the Legacy Personal Resource Display anchored to your character.")
    Add(subBox, 14)

    -- Reset button
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetSize(130, 24)
    resetBtn:SetText("Reset to Default")
    local resetMsg = content:CreateFontString(nil, "ARTWORK", "GameFontGreen")
    resetMsg:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    resetMsg:SetText("Settings reset!")
    resetMsg:Hide()
    Add(resetBtn, 24)

    ---------------------------------------------------------------
    -- Position & Size
    ---------------------------------------------------------------
    Add(MakeHeader(content, "Position & Size"), 16, {isHead = true})

    local lockW = MakeCheck(content, "Lock", "Lock Frame Position")
    lockW.check:SetScript("OnClick", function(self)
        if LegacyPRDDB then LegacyPRDDB.locked = self:GetChecked(); ApplyLockState() end
    end)
    Add(lockW, 24)

    local scaleW = MakeSlider(content, "Scale", "Scale (%)", 1, 200, 1)
    scaleW.slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5); scaleW.val:SetText(v .. "%")
        if refreshing then return end
        if LegacyPRDDB then
            LegacyPRDDB.scale = v
            if ns.mainFrame then ns.mainFrame:SetScale(v / 100) end
        end
    end)
    Add(scaleW, 36)

    local widthW = MakeSlider(content, "Width", "Width (%)", 1, 200, 1)
    widthW.slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5); widthW.val:SetText(v .. "%")
        if refreshing then return end
        if LegacyPRDDB then LegacyPRDDB.width = v; LegacyPRD_ApplySettings() end
    end)
    Add(widthW, 36)

    local heightW = MakeSlider(content, "Height", "Height (%)", 1, 200, 1)
    heightW.slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5); heightW.val:SetText(v .. "%")
        if refreshing then return end
        if LegacyPRDDB then LegacyPRDDB.height = v; LegacyPRD_ApplySettings() end
    end)
    Add(heightW, 36)

    ---------------------------------------------------------------
    -- Visibility
    ---------------------------------------------------------------
    Add(MakeHeader(content, "Visibility"), 16, {isHead = true})

    local showHealthW = MakeCheck(content, "ShowHP", "Show Health Bar")
    showHealthW.check:SetScript("OnClick", function(self)
        if LegacyPRDDB then LegacyPRDDB.showHealthBar = self:GetChecked(); LegacyPRD_ApplySettings() end
    end)
    Add(showHealthW, 24)

    local showPowerW = MakeCheck(content, "ShowPow", "Show Power Bar")
    showPowerW.check:SetScript("OnClick", function(self)
        if LegacyPRDDB then LegacyPRDDB.showPowerBar = self:GetChecked(); LegacyPRD_ApplySettings() end
    end)
    Add(showPowerW, 24)

    ---------------------------------------------------------------
    -- Colors
    ---------------------------------------------------------------
    Add(MakeHeader(content, "Colors"), 16, {isHead = true})

    -- Health color dropdown
    local HEALTH_OPTS = {
        { text = "Class Color",  value = "class" },
        { text = "Green",        value = "green" },
        { text = "Custom Color", value = "custom" },
    }
    local healthDDW = MakeDropdown(content, "HealthDD", "Health Bar Color")
    UIDropDownMenu_Initialize(healthDDW.dropdown, function()
        for _, o in ipairs(HEALTH_OPTS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text; info.value = o.value
            info.checked = (LegacyPRDDB and LegacyPRDDB.healthColorMode == o.value)
            info.func = function(btn)
                LegacyPRDDB.healthColorMode = btn.value
                UIDropDownMenu_SetText(healthDDW.dropdown, btn:GetText())
                CloseDropDownMenus()
                LegacyPRD_UpdateHealthColor()
                LayoutAll()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    Add(healthDDW, 44)

    -- Health custom picker
    local healthPicker = MakeColorPicker(content, "Custom Health Color",
        function() return LegacyPRDDB and LegacyPRDDB.healthCustomColor or {r=1,g=0,b=0} end,
        function(r,g,b) if LegacyPRDDB then LegacyPRDDB.healthCustomColor = {r=r,g=g,b=b} end end,
        function() LegacyPRD_UpdateHealthColor() end)
    Add(healthPicker, 26, {indent = 16, visFn = function()
        return LegacyPRDDB and LegacyPRDDB.healthColorMode == "custom"
    end})

    -- Power color dropdown
    local POWER_OPTS = {
        { text = "Default",      value = "default" },
        { text = "Custom Color", value = "custom" },
    }
    local powerDDW = MakeDropdown(content, "PowerDD", "Power Bar Color")
    UIDropDownMenu_Initialize(powerDDW.dropdown, function()
        for _, o in ipairs(POWER_OPTS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text; info.value = o.value
            info.checked = (LegacyPRDDB and LegacyPRDDB.powerColorMode == o.value)
            info.func = function(btn)
                LegacyPRDDB.powerColorMode = btn.value
                UIDropDownMenu_SetText(powerDDW.dropdown, btn:GetText())
                CloseDropDownMenus()
                LegacyPRD_UpdatePowerColor()
                LayoutAll()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    Add(powerDDW, 44)

    -- Power custom picker
    local powerPicker = MakeColorPicker(content, "Custom Power Color",
        function() return LegacyPRDDB and LegacyPRDDB.powerCustomColor or {r=0,g=0.5,b=1} end,
        function(r,g,b) if LegacyPRDDB then LegacyPRDDB.powerCustomColor = {r=r,g=g,b=b} end end,
        function() LegacyPRD_UpdatePowerColor() end)
    Add(powerPicker, 26, {indent = 16, visFn = function()
        return LegacyPRDDB and LegacyPRDDB.powerColorMode == "custom"
    end})

    ---------------------------------------------------------------
    -- Class Resources
    ---------------------------------------------------------------
    Add(MakeHeader(content, "Class Resources"), 16, {isHead = true})

    local classResW = MakeCheck(content, "ClassRes", "Show Class Resources")
    classResW.check:SetScript("OnClick", function(self)
        if LegacyPRDDB then
            LegacyPRDDB.showClassResources = self:GetChecked()
            if LegacyPRD_UpdateClassResources then LegacyPRD_UpdateClassResources() end
            LayoutAll()
        end
    end)
    Add(classResW, 24)

    -- Resource Style dropdown
    local RES_STYLE_OPTS = {
        { text = "Blizzard", value = "blizzard" },
        { text = "Bar",      value = "bar" },
        { text = "Squares",  value = "squares" },
    }
    local resStyleW = MakeDropdown(content, "ResStyle", "Resource Style")
    UIDropDownMenu_Initialize(resStyleW.dropdown, function()
        for _, o in ipairs(RES_STYLE_OPTS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text; info.value = o.value
            info.checked = (LegacyPRDDB and LegacyPRDDB.resourceStyle == o.value)
            info.func = function(btn)
                LegacyPRDDB.resourceStyle = btn.value
                UIDropDownMenu_SetText(resStyleW.dropdown, btn:GetText())
                CloseDropDownMenus()
                LegacyPRD_ApplySettings()
                if LegacyPRD_UpdateClassResources then LegacyPRD_UpdateClassResources() end
                LayoutAll()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    Add(resStyleW, 44, {indent = 16, visFn = function()
        return LegacyPRDDB and LegacyPRDDB.showClassResources
    end})

    -- Resource Position dropdown
    local RES_POS_OPTS = {
        { text = "Bottom", value = "bottom" },
        { text = "Top",    value = "top" },
    }
    local resPosW = MakeDropdown(content, "ResPos", "Resource Position")
    UIDropDownMenu_Initialize(resPosW.dropdown, function()
        for _, o in ipairs(RES_POS_OPTS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text; info.value = o.value
            info.checked = (LegacyPRDDB and LegacyPRDDB.classResourcePosition == o.value)
            info.func = function(btn)
                LegacyPRDDB.classResourcePosition = btn.value
                UIDropDownMenu_SetText(resPosW.dropdown, btn:GetText())
                CloseDropDownMenus()
                LegacyPRD_ApplySettings()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    Add(resPosW, 44, {indent = 16, visFn = function()
        return LegacyPRDDB and LegacyPRDDB.showClassResources
    end})

    -- Resource Color dropdown
    local RES_COLOR_OPTS = {
        { text = "Class Default", value = "default" },
        { text = "Class Color",   value = "class" },
        { text = "Custom",        value = "custom" },
    }
    local resColorW = MakeDropdown(content, "ResColor", "Resource Color")
    UIDropDownMenu_Initialize(resColorW.dropdown, function()
        for _, o in ipairs(RES_COLOR_OPTS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text; info.value = o.value
            info.checked = (LegacyPRDDB and LegacyPRDDB.resourceColorMode == o.value)
            info.func = function(btn)
                LegacyPRDDB.resourceColorMode = btn.value
                UIDropDownMenu_SetText(resColorW.dropdown, btn:GetText())
                CloseDropDownMenus()
                LegacyPRD_ApplySettings()
                if LegacyPRD_UpdateClassResources then LegacyPRD_UpdateClassResources() end
                LayoutAll()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    Add(resColorW, 44, {indent = 16, visFn = function()
        if not LegacyPRDDB or not LegacyPRDDB.showClassResources then return false end
        return (LegacyPRDDB.resourceStyle or "blizzard") ~= "blizzard"
    end})

    -- Custom Resource Color picker
    local resColorPicker = MakeColorPicker(content, "Custom Resource Color",
        function() return LegacyPRDDB and LegacyPRDDB.resourceCustomColor or {r=1,g=1,b=1} end,
        function(r,g,b) if LegacyPRDDB then LegacyPRDDB.resourceCustomColor = {r=r,g=g,b=b} end end,
        function()
            LegacyPRD_ApplySettings()
            if LegacyPRD_UpdateClassResources then LegacyPRD_UpdateClassResources() end
        end)
    Add(resColorPicker, 26, {indent = 32, visFn = function()
        if not LegacyPRDDB or not LegacyPRDDB.showClassResources then return false end
        if (LegacyPRDDB.resourceStyle or "blizzard") == "blizzard" then return false end
        return LegacyPRDDB.resourceColorMode == "custom"
    end})

    -- Icon Size slider
    local iconSizeW = MakeSlider(content, "IconSize", "Resource Icon Size (%)", 50, 200, 1)
    iconSizeW.slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5); iconSizeW.val:SetText(v .. "%")
        if refreshing then return end
        if LegacyPRDDB then LegacyPRDDB.resourceIconSize = v; LegacyPRD_ApplySettings() end
    end)
    Add(iconSizeW, 36, {indent = 16, visFn = function()
        if not LegacyPRDDB or not LegacyPRDDB.showClassResources then return false end
        return (LegacyPRDDB.resourceStyle or "blizzard") ~= "bar"
    end})

    -- Icon Spacing slider
    local iconSpaceW = MakeSlider(content, "IconSpace", "Resource Icon Spacing (px)", 0, 50, 1)
    iconSpaceW.slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5); iconSpaceW.val:SetText(v .. "px")
        if refreshing then return end
        if LegacyPRDDB then LegacyPRDDB.resourceIconSpacing = v; LegacyPRD_ApplySettings() end
    end)
    Add(iconSpaceW, 36, {indent = 16, visFn = function()
        if not LegacyPRDDB or not LegacyPRDDB.showClassResources then return false end
        return (LegacyPRDDB.resourceStyle or "blizzard") ~= "bar"
    end})

    ---------------------------------------------------------------
    -- Cast Bar
    ---------------------------------------------------------------
    Add(MakeHeader(content, "Cast Bar"), 16, {isHead = true})

    local showCastW = MakeCheck(content, "ShowCast", "Show Cast Bar")
    showCastW.check:SetScript("OnClick", function(self)
        if LegacyPRDDB then
            LegacyPRDDB.showCastBar = self:GetChecked()
            LegacyPRD_ApplySettings()
            LayoutAll()
        end
    end)
    Add(showCastW, 24)

    -- Cast Bar Position dropdown
    local CAST_POS_OPTS = {
        { text = "Bottom", value = "bottom" },
        { text = "Top",    value = "top" },
    }
    local castPosW = MakeDropdown(content, "CastPos", "Cast Bar Position")
    UIDropDownMenu_Initialize(castPosW.dropdown, function()
        for _, o in ipairs(CAST_POS_OPTS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text; info.value = o.value
            info.checked = (LegacyPRDDB and LegacyPRDDB.castBarPosition == o.value)
            info.func = function(btn)
                LegacyPRDDB.castBarPosition = btn.value
                UIDropDownMenu_SetText(castPosW.dropdown, btn:GetText())
                CloseDropDownMenus()
                LegacyPRD_ApplySettings()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    Add(castPosW, 44, {indent = 16, visFn = function()
        return LegacyPRDDB and LegacyPRDDB.showCastBar == true
    end})

    -- Cast Bar Visibility dropdown
    local CAST_VIS_OPTS = {
        { text = "Only When Casting", value = "casting" },
        { text = "Always Show",       value = "always" },
    }
    local castVisW = MakeDropdown(content, "CastVis", "Cast Bar Visibility")
    UIDropDownMenu_Initialize(castVisW.dropdown, function()
        for _, o in ipairs(CAST_VIS_OPTS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text; info.value = o.value
            info.checked = (LegacyPRDDB and (LegacyPRDDB.castBarVisibility or "casting") == o.value)
            info.func = function(btn)
                LegacyPRDDB.castBarVisibility = btn.value
                UIDropDownMenu_SetText(castVisW.dropdown, btn:GetText())
                CloseDropDownMenus()
                LegacyPRD_UpdateLayout()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    Add(castVisW, 44, {indent = 16, visFn = function()
        return LegacyPRDDB and LegacyPRDDB.showCastBar == true
    end})

    -- Cast Bar Height slider
    local castHtW = MakeSlider(content, "CastHt", "Cast Bar Height (%)", 50, 200, 1)
    castHtW.slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5); castHtW.val:SetText(v .. "%")
        if refreshing then return end
        if LegacyPRDDB then LegacyPRDDB.castBarHeight = v; LegacyPRD_ApplySettings() end
    end)
    Add(castHtW, 36, {indent = 16, visFn = function()
        return LegacyPRDDB and LegacyPRDDB.showCastBar == true
    end})

    ---------------------------------------------------------------
    -- Refresh all controls
    ---------------------------------------------------------------
    local function SetDropdownText(dd, opts, val)
        for _, o in ipairs(opts) do
            if o.value == val then UIDropDownMenu_SetText(dd, o.text); return end
        end
    end

    local function RefreshPanel()
        if not LegacyPRDDB then return end
        refreshing = true

        lockW.check:SetChecked(LegacyPRDDB.locked)
        scaleW.slider:SetValue(LegacyPRDDB.scale  or 100)
        widthW.slider:SetValue(LegacyPRDDB.width  or 100)
        heightW.slider:SetValue(LegacyPRDDB.height or 100)

        showHealthW.check:SetChecked(LegacyPRDDB.showHealthBar ~= false)
        showPowerW.check:SetChecked(LegacyPRDDB.showPowerBar ~= false)

        SetDropdownText(healthDDW.dropdown, HEALTH_OPTS, LegacyPRDDB.healthColorMode or "class")
        if healthPicker.swatch then
            local hc = LegacyPRDDB.healthCustomColor or {r=1,g=0,b=0}
            healthPicker.swatch:SetColorTexture(hc.r, hc.g, hc.b)
        end
        SetDropdownText(powerDDW.dropdown, POWER_OPTS, LegacyPRDDB.powerColorMode or "default")
        if powerPicker.swatch then
            local pc = LegacyPRDDB.powerCustomColor or {r=0,g=0.5,b=1}
            powerPicker.swatch:SetColorTexture(pc.r, pc.g, pc.b)
        end

        classResW.check:SetChecked(LegacyPRDDB.showClassResources)
        SetDropdownText(resStyleW.dropdown, RES_STYLE_OPTS, LegacyPRDDB.resourceStyle or "blizzard")
        SetDropdownText(resPosW.dropdown, RES_POS_OPTS, LegacyPRDDB.classResourcePosition or "bottom")
        iconSizeW.slider:SetValue(LegacyPRDDB.resourceIconSize or 100)
        iconSpaceW.slider:SetValue(LegacyPRDDB.resourceIconSpacing or 2)

        SetDropdownText(resColorW.dropdown, RES_COLOR_OPTS, LegacyPRDDB.resourceColorMode or "default")
        if resColorPicker.swatch then
            local rc = LegacyPRDDB.resourceCustomColor or {r=1,g=1,b=1}
            resColorPicker.swatch:SetColorTexture(rc.r, rc.g, rc.b)
        end

        showCastW.check:SetChecked(LegacyPRDDB.showCastBar == true)
        SetDropdownText(castPosW.dropdown, CAST_POS_OPTS, LegacyPRDDB.castBarPosition or "bottom")
        SetDropdownText(castVisW.dropdown, CAST_VIS_OPTS, LegacyPRDDB.castBarVisibility or "casting")
        castHtW.slider:SetValue(LegacyPRDDB.castBarHeight or 100)

        refreshing = false
        LayoutAll()
    end

    ---------------------------------------------------------------
    -- Reset button handler
    ---------------------------------------------------------------
    resetBtn:SetScript("OnClick", function()
        LegacyPRDDB = {}
        for k, v in pairs(PRD_DEFAULTS) do LegacyPRDDB[k] = CopyDefault(v) end
        LegacyPRD_ApplySettings()
        if LegacyPRD_UpdateClassResources then LegacyPRD_UpdateClassResources() end
        RefreshPanel()
        resetMsg:SetAlpha(1); resetMsg:Show()
        C_Timer.After(2, function()
            if resetMsg:IsShown() then
                UIFrameFadeOut(resetMsg, 0.5, 1, 0)
                C_Timer.After(0.5, function() resetMsg:Hide() end)
            end
        end)
    end)

    ---------------------------------------------------------------
    -- Register & refresh on show
    ---------------------------------------------------------------
    local category = Settings.RegisterCanvasLayoutCategory(canvas, "LegacyPRD")
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category

    canvas:SetScript("OnShow", RefreshPanel)
end

---------------------------------------------------------------------------
-- Slash command handler
---------------------------------------------------------------------------
function ns:HandleConfigCommand(args)
    if args == "" or args == "options" or args == "config" or args == "settings" then
        if ns.settingsCategory then
            Settings.OpenToCategory(ns.settingsCategory:GetID())
        end
        return
    end

    if args == "reset" then
        self:ResetDefaults()
        LegacyPRD_ApplySettings()
        if LegacyPRD_UpdateClassResources then LegacyPRD_UpdateClassResources() end
        print("|cff00ccffLegacyPRD|r: Settings reset to defaults.")
        return
    end

    if args == "lock" then
        if LegacyPRDDB then LegacyPRDDB.locked = true end
        ApplyLockState()
        print("|cff00ccffLegacyPRD|r: Frame locked.")
        return
    end

    if args == "unlock" then
        if LegacyPRDDB then LegacyPRDDB.locked = false end
        ApplyLockState()
        print("|cff00ccffLegacyPRD|r: Frame unlocked.")
        return
    end

    if args == "toggle" then
        local enabled = not self:GetOption("enabled")
        self:SetOption("enabled", enabled)
        print("|cff00ccffLegacyPRD|r: " .. (enabled and "Enabled" or "Disabled") .. ".")
        return
    end

    local key, value = strsplit(" ", args, 2)
    if key == "scale" and tonumber(value) then
        local s = tonumber(value)
        if s < 10 then s = math.floor(s * 100 + 0.5) end
        if LegacyPRDDB then LegacyPRDDB.scale = s end
        LegacyPRD_ApplySettings()
        print("|cff00ccffLegacyPRD|r: Scale set to " .. s .. "%.")
        return
    end

    if key == "iconsize" and tonumber(value) then
        self:SetOption("iconSize", tonumber(value))
        print("|cff00ccffLegacyPRD|r: Icon size set to " .. value .. ".")
        if ns.ApplyLayout then ns:ApplyLayout() end
        return
    end

    if key == "bars" then
        local on = not self:GetOption("playerFrameEnabled")
        self:SetOption("playerFrameEnabled", on)
        if ns.mainFrame then
            if on then ns.mainFrame:Show() else ns.mainFrame:Hide() end
        end
        print("|cff00ccffLegacyPRD|r: Player bars " .. (on and "enabled" or "disabled") .. ".")
        return
    end

    print("|cff00ccffLegacyPRD|r commands:")
    print("  /lprd - Open settings panel")
    print("  /lprd toggle - Enable/disable addon")
    print("  /lprd lock - Lock frame position")
    print("  /lprd unlock - Unlock frame position")
    print("  /lprd scale <1-200> - Set scale percentage")
    print("  /lprd iconsize <number> - Set icon size")
    print("  /lprd bars - Toggle player health/power bars")
    print("  /lprd reset - Reset to defaults")
end
