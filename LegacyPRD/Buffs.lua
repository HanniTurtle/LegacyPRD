local addonName, ns = ...

ns.activeBuffs = {}
ns.buffFrames = {}

local MAX_BUFFS = 40

function ns:ScanBuffs()
    wipe(self.activeBuffs)

    for i = 1, MAX_BUFFS do
        local name, icon, count, debuffType, duration, expirationTime, source, isStealable,
              nameplateShowPersonal, spellId = UnitBuff("player", i)

        if not name then break end

        self.activeBuffs[#self.activeBuffs + 1] = {
            name = name,
            icon = icon,
            count = count,
            debuffType = debuffType,
            duration = duration,
            expirationTime = expirationTime,
            source = source,
            spellId = spellId,
            index = i,
        }
    end

    return self.activeBuffs
end

function ns:CreateBuffFrame(parent, index)
    local size = self:GetOption("iconSize") or 32

    local frame = CreateFrame("Frame", "LegacyPRD_Buff" .. index, parent)
    frame:SetSize(size, size)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()

    frame.count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    frame.count:SetPoint("BOTTOMRIGHT", -1, 1)

    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()
    frame.cooldown:SetDrawEdge(false)
    frame.cooldown:SetDrawSwipe(true)

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if ns:GetOption("showTooltips") and self.buffIndex then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetUnitBuff("player", self.buffIndex)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame:Hide()
    return frame
end

function ns:UpdateBuffFrame(frame, buffData)
    if not buffData then
        frame:Hide()
        return
    end

    frame.icon:SetTexture(buffData.icon)
    frame.buffIndex = buffData.index

    if buffData.count and buffData.count > 1 then
        frame.count:SetText(buffData.count)
        frame.count:Show()
    else
        frame.count:Hide()
    end

    if self:GetOption("showTimers") and buffData.duration and buffData.duration > 0 then
        frame.cooldown:SetCooldown(buffData.expirationTime - buffData.duration, buffData.duration)
        frame.cooldown:Show()
    else
        frame.cooldown:Hide()
    end

    frame:Show()
end

function ns:RefreshAllBuffs()
    if not self:GetOption("enabled") then
        for _, frame in ipairs(self.buffFrames) do
            frame:Hide()
        end
        return
    end

    local buffs = self:ScanBuffs()

    -- Create frames as needed
    while #self.buffFrames < #buffs do
        local index = #self.buffFrames + 1
        self.buffFrames[index] = self:CreateBuffFrame(self.anchor, index)
    end

    -- Update visible frames
    for i, buffData in ipairs(buffs) do
        self:UpdateBuffFrame(self.buffFrames[i], buffData)
    end

    -- Hide unused frames
    for i = #buffs + 1, #self.buffFrames do
        self.buffFrames[i]:Hide()
    end

    self:ApplyLayout()
end

function ns:ApplyLayout()
    if not self.anchor then return end

    local size = self:GetOption("iconSize") or 32
    local spacing = self:GetOption("spacing") or 2
    local scale = self:GetOption("scale") or 1.0
    local direction = self:GetOption("growDirection") or "RIGHT"

    self.anchor:SetScale(scale)

    for i, frame in ipairs(self.buffFrames) do
        if frame:IsShown() then
            frame:SetSize(size, size)
            frame:ClearAllPoints()

            if i == 1 then
                frame:SetPoint("TOPLEFT", self.anchor, "TOPLEFT", 0, 0)
            else
                if direction == "RIGHT" then
                    frame:SetPoint("LEFT", self.buffFrames[i - 1], "RIGHT", spacing, 0)
                elseif direction == "LEFT" then
                    frame:SetPoint("RIGHT", self.buffFrames[i - 1], "LEFT", -spacing, 0)
                elseif direction == "DOWN" then
                    frame:SetPoint("TOP", self.buffFrames[i - 1], "BOTTOM", 0, -spacing)
                elseif direction == "UP" then
                    frame:SetPoint("BOTTOM", self.buffFrames[i - 1], "TOP", 0, spacing)
                end
            end
        end
    end
end
