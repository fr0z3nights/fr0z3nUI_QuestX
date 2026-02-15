local function InitSV()
    fr0z3nUI_QuestX_Acc = fr0z3nUI_QuestX_Acc or {}
    fr0z3nUI_QuestX_Char = fr0z3nUI_QuestX_Char or {}
    fr0z3nUI_QuestX_Settings = fr0z3nUI_QuestX_Settings or { disabled = {} }
    fr0z3nUI_QuestX_CharSettings = fr0z3nUI_QuestX_CharSettings or { disabled = {} }

    fr0z3nUI_QuestY_Acc = fr0z3nUI_QuestY_Acc or {}
    fr0z3nUI_QuestY_Char = fr0z3nUI_QuestY_Char or {}
    fr0z3nUI_QuestY_Settings = fr0z3nUI_QuestY_Settings or { disabled = {} }
    fr0z3nUI_QuestY_CharSettings = fr0z3nUI_QuestY_CharSettings or { disabled = {} }

    if type(fr0z3nUI_QuestX_Settings.disabled) ~= "table" then
        fr0z3nUI_QuestX_Settings.disabled = {}
    end
    if type(fr0z3nUI_QuestX_CharSettings.disabled) ~= "table" then
        fr0z3nUI_QuestX_CharSettings.disabled = {}
    end

    if type(fr0z3nUI_QuestY_Settings.disabled) ~= "table" then
        fr0z3nUI_QuestY_Settings.disabled = {}
    end
    if type(fr0z3nUI_QuestY_CharSettings.disabled) ~= "table" then
        fr0z3nUI_QuestY_CharSettings.disabled = {}
    end

    if fr0z3nUI_QuestX_Settings.scopeMode == nil then
        -- Default: RESTING (reduces auto-run while out questing)
        fr0z3nUI_QuestX_Settings.scopeMode = "RESTING"
    else
        fr0z3nUI_QuestX_Settings.scopeMode = tostring(fr0z3nUI_QuestX_Settings.scopeMode):upper()
        if fr0z3nUI_QuestX_Settings.scopeMode ~= "MAP" and fr0z3nUI_QuestX_Settings.scopeMode ~= "RESTING" then
            fr0z3nUI_QuestX_Settings.scopeMode = "RESTING"
        end
    end

    local function NormalizeMapLists(tbl)
        for mapID, list in pairs(tbl) do
            if type(list) == "table" then
                -- Migrate old array format (table.insert) to set format: [questID]=true
                if list[1] ~= nil then
                    local set = {}
                    for _, qid in ipairs(list) do
                        qid = tonumber(qid)
                        if qid then set[qid] = true end
                    end
                    tbl[mapID] = set
                end
            end
        end
    end

    NormalizeMapLists(fr0z3nUI_QuestX_Acc)
    NormalizeMapLists(fr0z3nUI_QuestX_Char)
    NormalizeMapLists(fr0z3nUI_QuestY_Acc)
    NormalizeMapLists(fr0z3nUI_QuestY_Char)
end

local function GetQuestTitleSafe(qid)
    if not qid then return nil end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        return C_QuestLog.GetTitleForQuestID(qid)
    end
    return nil
end

local function GetBestMapIDSafe()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function GetScopeMode()
    InitSV()
    return tostring(fr0z3nUI_QuestX_Settings.scopeMode or "RESTING"):upper()
end

local function GetScopeKey()
    local mode = GetScopeMode()
    if mode == "RESTING" then
        return "RESTING"
    end
    return GetBestMapIDSafe()
end

local function ShouldTryAbandonNow()
    if GetScopeMode() == "RESTING" then
        if IsResting and not IsResting() then
            return false
        end
    end
    return true
end

local function Print(msg)
    print("|cff00ccff[FQX]|r " .. tostring(msg or ""))
end

local function GetActiveQuestOfferIDSafe()
    if type(_G) == "table" then
        local f1 = rawget(_G, "GetQuestID")
        if type(f1) == "function" then
            local ok, v = pcall(f1)
            if ok and type(v) == "number" and v > 0 then return v end
        end
        local f2 = rawget(_G, "QuestGetQuestID")
        if type(f2) == "function" then
            local ok, v = pcall(f2)
            if ok and type(v) == "number" and v > 0 then return v end
        end
    end
    return nil
end

-- 1. Create UI Frame
local f = CreateFrame("Frame", "fr0z3nUIQuestXFrame", UIParent, "BasicFrameTemplateWithInset")

do
    -- Unify styling: borderless + darker background (like FGO/FQT).
    if f.NineSlice and f.NineSlice.Hide then f.NineSlice:Hide() end
    if f.Bg and f.Bg.Hide then f.Bg:Hide() end
    if f.TitleBg and f.TitleBg.Hide then f.TitleBg:Hide() end
    if f.InsetBg and f.InsetBg.Hide then f.InsetBg:Hide() end
    if f.Inset and f.Inset.Hide then f.Inset:Hide() end

    local bg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bg:SetAllPoints(f)
    bg:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    bg:SetBackdropColor(0, 0, 0, 0.85)
    bg:SetFrameLevel((f.GetFrameLevel and f:GetFrameLevel() or 0))
    f._unifiedBG = bg

    local tabBarBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
    tabBarBG:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    tabBarBG:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    tabBarBG:SetHeight(26)
    tabBarBG:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    tabBarBG:SetBackdropColor(0, 0, 0, 0.92)
    tabBarBG:SetFrameLevel((f.GetFrameLevel and f:GetFrameLevel() or 0) + 1)
    f._tabBarBG = tabBarBG

    local closeBtn = f.CloseButton
    if not closeBtn then
        closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    end
    if closeBtn and closeBtn.ClearAllPoints and closeBtn.SetPoint then
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
        if closeBtn.SetFrameLevel then
            closeBtn:SetFrameLevel((f.GetFrameLevel and f:GetFrameLevel() or 0) + 20)
        end
        closeBtn:SetScript("OnClick", function() if f and f.Hide then f:Hide() end end)
    end

    f._closeBtn = closeBtn
end

-- Allow closing with Escape.
do
    local special = _G and _G["UISpecialFrames"]
    if type(special) == "table" then
        local name = "fr0z3nUIQuestXFrame"
        local exists = false
        for i = 1, #special do
            if special[i] == name then exists = true break end
        end
        if not exists and table and table.insert then table.insert(special, name) end
    end
end

local editBox
local DoValidate

f:SetSize(300, 190)
f:SetPoint("CENTER")
f:Hide()
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

do
    local t = f.TitleText
    if not t then
        t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetJustifyH("RIGHT")
    end

    if t.SetParent and f._tabBarBG then
        t:SetParent(f._tabBarBG)
    end
    if t.ClearAllPoints and t.SetPoint then
        t:ClearAllPoints()
        local closeBtn = f._closeBtn or f.CloseButton
        if closeBtn then
            t:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
        else
            t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -6)
        end
    end
    if t.SetText then
        -- Title is just the addon prefix; the active tab label is shown in the body.
        t:SetText("|cff00ccff[FQX]|r")
    end
    do
        local fontPath, fontSize, fontFlags = t:GetFont()
        if fontPath and fontSize then
            t:SetFont(fontPath, fontSize + 2, fontFlags)
        end
    end
    f.title = t
end

-- Active module label (top-left body).
local modeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
modeLabel:SetPoint("TOPLEFT", 12, -34)
modeLabel:SetJustifyH("LEFT")
modeLabel:SetText("QuestX")
f.modeLabel = modeLabel

-- Tab content panels (QuestX/QuestY). Most controls are shared, but some are tab-specific.
local panelQuestX = CreateFrame("Frame", nil, f)
panelQuestX:SetAllPoints()
f.panelQuestX = panelQuestX

local panelQuestY = CreateFrame("Frame", nil, f)
panelQuestY:SetAllPoints()
panelQuestY:Hide()
f.panelQuestY = panelQuestY

-- Tabs
local function StyleTab(btn, active)
    if not (btn and btn.GetFontString) then return end
    local fs = btn:GetFontString()
    if fs and fs.SetTextColor then
        if active then
            fs:SetTextColor(1.0, 0.82, 0.0, 1)
        else
            fs:SetTextColor(0.70, 0.70, 0.70, 1)
        end
    end
end

local function SizeTabToText(btn)
    if not btn then return end
    local fs = (btn.GetFontString and btn:GetFontString()) or btn.Text or btn.text
    local w = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
    w = (tonumber(w) or 0) + 24
    if w < 60 then w = 60 end
    if btn.SetSize then btn:SetSize(w, 18) end
end

local function RaiseActiveTab()
    local base = (f._tabBarBG and f._tabBarBG.GetFrameLevel and f._tabBarBG:GetFrameLevel())
        or (f.GetFrameLevel and f:GetFrameLevel())
        or 0
    base = base + 2
    if f.tab1 and f.tab1.SetFrameLevel then f.tab1:SetFrameLevel(base + ((f.activeTabID == 1) and 2 or 1)) end
    if f.tab2 and f.tab2.SetFrameLevel then f.tab2:SetFrameLevel(base + ((f.activeTabID == 2) and 2 or 1)) end
end

local function SelectTab(tabID)
    f.activeTabID = tabID

    local isQuestX = (tabID == 1)
    if f.panelQuestX then f.panelQuestX:SetShown(isQuestX) end
    if f.panelQuestY then f.panelQuestY:SetShown(not isQuestX) end
    if f.modeLabel then
        f.modeLabel:SetText(isQuestX and "QuestX" or "QuestY")
    end

    StyleTab(f.tab1, isQuestX)
    StyleTab(f.tab2, not isQuestX)
    RaiseActiveTab()

    if editBox and editBox.GetText and editBox:GetText() ~= "" then
        C_Timer.After(0, DoValidate)
    else
        if f and f._placeholder then f._placeholder:Show() end
    end
end

local tab1 = CreateFrame("Button", "$parentTab1", f, "UIPanelButtonTemplate")
tab1:SetID(1)
tab1:SetText("QuestX")
SizeTabToText(tab1)
tab1:ClearAllPoints()
tab1:SetPoint("LEFT", f._tabBarBG or f, "LEFT", 8, 0)
tab1:SetScript("OnClick", function(self) SelectTab(self:GetID()) end)
f.tab1 = tab1

local tab2 = CreateFrame("Button", "$parentTab2", f, "UIPanelButtonTemplate")
tab2:SetID(2)
tab2:SetText("QuestY")
SizeTabToText(tab2)
tab2:ClearAllPoints()
tab2:SetPoint("LEFT", tab1, "RIGHT", -8, 0)
tab2:SetScript("OnClick", function(self) SelectTab(self:GetID()) end)
f.tab2 = tab2
SelectTab(1)

local function UpdateScopeButton()
    if not f.btnScope then return end
    local mode = GetScopeMode()
    if mode == "MAP" then
        f.btnScope:SetText("MAP")
    else
        f.btnScope:SetText("RESTING")
    end
end

local btnScope = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
btnScope:SetSize(90, 22)
btnScope:SetPoint("BOTTOMLEFT", 10, 10)
btnScope:SetScript("OnClick", function()
    InitSV()
    local cur = GetScopeMode()
    fr0z3nUI_QuestX_Settings.scopeMode = (cur == "MAP") and "RESTING" or "MAP"
    UpdateScopeButton()
    if f and f.IsShown and f:IsShown() then
        C_Timer.After(0, function()
            if editBox and editBox.GetText and editBox:GetText() ~= "" then
                DoValidate()
            end
        end)
    end
end)
btnScope:SetScript("OnEnter", function()
    if GameTooltip then
        GameTooltip:SetOwner(f, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMLEFT", btnScope, "TOPLEFT", 0, 8)
        GameTooltip:SetText("Auto-Abandon Scope")
        GameTooltip:AddLine("MAP: uses current mapID; runs anywhere.", 1, 1, 1, true)
        GameTooltip:AddLine("RESTING: uses one shared list; only runs while resting.", 1, 1, 1, true)
        GameTooltip:Show()
    end
end)
btnScope:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
end)
f.btnScope = btnScope
UpdateScopeButton()

-- Scope only belongs to QuestX tab.
btnScope:SetParent(panelQuestX)

editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
editBox:SetSize(150, 30)
editBox:SetPoint("TOP", 0, -44)
editBox:SetAutoFocus(false)
editBox:SetNumeric(true)

-- Make the input look like a clean field (hide the template frame) + add a placeholder.
local function HideEditBoxFrame(box)
    if not box or not box.GetRegions then return end
    local regions = { box:GetRegions() }
    for i = 1, #regions do
        local r = regions[i]
        if r and r.GetObjectType and r:GetObjectType() == "Texture" then
            r:Hide()
        end
    end
end

HideEditBoxFrame(editBox)
editBox:SetTextInsets(6, 6, 0, 0)
editBox:SetJustifyH("CENTER")
if editBox.SetJustifyV then editBox:SetJustifyV("MIDDLE") end

local ph = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
ph:SetPoint("CENTER", editBox, "CENTER", 0, 0)
ph:SetJustifyH("CENTER")
ph:SetText("Enter QuestID")
ph:Show()
f._placeholder = ph

local function UpdateInputPlaceholder()
    if not (ph and editBox and editBox.GetText) then return end
    local txt = tostring(editBox:GetText() or "")
    local focused = (editBox.HasFocus and editBox:HasFocus()) and true or false
    if txt == "" and not focused then
        ph:Show()
    else
        ph:Hide()
    end
end

editBox:HookScript("OnEditFocusGained", function() UpdateInputPlaceholder() end)
editBox:HookScript("OnEditFocusLost", function() UpdateInputPlaceholder() end)
editBox:HookScript("OnShow", function() UpdateInputPlaceholder() end)

local nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
nameLabel:SetPoint("TOP", editBox, "BOTTOM", 0, -8)
nameLabel:SetWidth(f:GetWidth() - 20)
nameLabel:SetJustifyH("CENTER")
nameLabel:SetWordWrap(true)
nameLabel:SetText("")
f.nameLabel = nameLabel

local existsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
existsLabel:SetPoint("TOP", nameLabel, "BOTTOM", 0, -2)
existsLabel:SetWidth(f:GetWidth() - 20)
existsLabel:SetJustifyH("CENTER")
existsLabel:SetWordWrap(true)
existsLabel:SetText("")
f.existsLabel = existsLabel

local reasonLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
reasonLabel:SetPoint("TOP", existsLabel, "BOTTOM", 0, -2)
reasonLabel:SetWidth(f:GetWidth() - 20)
reasonLabel:SetJustifyH("CENTER")
reasonLabel:SetWordWrap(true)
reasonLabel:SetText("")
f.reasonLabel = reasonLabel

-- Helper to save IDs
local function EnsureQuestSets(mode, mapID)
    if not (mode and mapID) then return end
    if mode == "Y" then
        fr0z3nUI_QuestY_Acc[mapID] = fr0z3nUI_QuestY_Acc[mapID] or {}
        fr0z3nUI_QuestY_Char[mapID] = fr0z3nUI_QuestY_Char[mapID] or {}

        if fr0z3nUI_QuestY_Acc[mapID][1] ~= nil then
            local set = {}
            for _, qid in ipairs(fr0z3nUI_QuestY_Acc[mapID]) do
                qid = tonumber(qid)
                if qid then set[qid] = true end
            end
            fr0z3nUI_QuestY_Acc[mapID] = set
        end
        if fr0z3nUI_QuestY_Char[mapID][1] ~= nil then
            local set = {}
            for _, qid in ipairs(fr0z3nUI_QuestY_Char[mapID]) do
                qid = tonumber(qid)
                if qid then set[qid] = true end
            end
            fr0z3nUI_QuestY_Char[mapID] = set
        end
        return
    end

    fr0z3nUI_QuestX_Acc[mapID] = fr0z3nUI_QuestX_Acc[mapID] or {}
    fr0z3nUI_QuestX_Char[mapID] = fr0z3nUI_QuestX_Char[mapID] or {}

    if fr0z3nUI_QuestX_Acc[mapID][1] ~= nil then
        local set = {}
        for _, qid in ipairs(fr0z3nUI_QuestX_Acc[mapID]) do
            qid = tonumber(qid)
            if qid then set[qid] = true end
        end
        fr0z3nUI_QuestX_Acc[mapID] = set
    end
    if fr0z3nUI_QuestX_Char[mapID][1] ~= nil then
        local set = {}
        for _, qid in ipairs(fr0z3nUI_QuestX_Char[mapID]) do
            qid = tonumber(qid)
            if qid then set[qid] = true end
        end
        fr0z3nUI_QuestX_Char[mapID] = set
    end
end

local function EnsureQuestDisabledSets(mode, mapID)
    InitSV()
    if mode == "Y" then
        fr0z3nUI_QuestY_Settings.disabled[mapID] = fr0z3nUI_QuestY_Settings.disabled[mapID] or {}
        fr0z3nUI_QuestY_CharSettings.disabled[mapID] = fr0z3nUI_QuestY_CharSettings.disabled[mapID] or {}
        return
    end
    fr0z3nUI_QuestX_Settings.disabled[mapID] = fr0z3nUI_QuestX_Settings.disabled[mapID] or {}
    fr0z3nUI_QuestX_CharSettings.disabled[mapID] = fr0z3nUI_QuestX_CharSettings.disabled[mapID] or {}
end

local function GetActiveModeKey()
    return (f.activeTabID == 2) and "Y" or "X"
end

local function GetActiveScopeKeyForUI()
    if GetActiveModeKey() == "Y" then
        return GetBestMapIDSafe()
    end
    return GetScopeKey()
end

local function GetActiveTablesForUI(scopeKey)
    if GetActiveModeKey() == "Y" then
        EnsureQuestSets("Y", scopeKey)
        EnsureQuestDisabledSets("Y", scopeKey)
        return fr0z3nUI_QuestY_Acc[scopeKey], fr0z3nUI_QuestY_Char[scopeKey], fr0z3nUI_QuestY_Settings.disabled[scopeKey], fr0z3nUI_QuestY_CharSettings.disabled[scopeKey]
    end
    EnsureQuestSets("X", scopeKey)
    EnsureQuestDisabledSets("X", scopeKey)
    return fr0z3nUI_QuestX_Acc[scopeKey], fr0z3nUI_QuestX_Char[scopeKey], fr0z3nUI_QuestX_Settings.disabled[scopeKey], fr0z3nUI_QuestX_CharSettings.disabled[scopeKey]
end

local function SetButtonState(btn, label, isDisabled)
    if not btn then return end
    if isDisabled then
        btn:SetText("|cffffff00" .. label .. "|r") -- yellow = re-enable
    else
        btn:SetText("|cffff0000" .. label .. "|r") -- red = disable
    end
end

local function SetButtonColor(btn, label, state)
    if not btn then return end
    if state == "inactive" then
        btn:SetText("|cffffff00" .. label .. "|r") -- yellow
        return
    end
    if state == "active" then
        btn:SetText("|cff00ff00" .. label .. "|r") -- green
        return
    end
    if state == "disabled" then
        btn:SetText("|cffff9900" .. label .. "|r") -- orange
        return
    end
    btn:SetText(label)
end

local function SetDynamicTip(btn, getLines)
    if not (btn and btn.SetScript and getLines) then return end
    btn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local title, l1, l2, l3 = getLines()
        if not title then return end
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOP", self, "BOTTOM", 0, -6)
        GameTooltip:SetText(title)
        if l1 then GameTooltip:AddLine(l1, 1, 1, 1, true) end
        if l2 then GameTooltip:AddLine(l2, 1, 1, 1, true) end
        if l3 then GameTooltip:AddLine(l3, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function SaveID(isAccount)
    InitSV()
    local qid = f.validQID or tonumber(editBox:GetText())
    local scopeKey = GetActiveScopeKeyForUI()
    if not qid or not scopeKey then return end

    local acc, chr, accDis, chrDis = GetActiveTablesForUI(scopeKey)
    local title = GetQuestTitleSafe(qid) or tostring(qid)

    if isAccount then
        if acc[qid] then
            Print("Already in ACCOUNT list: " .. title)
            return
        end

        if chr[qid] then
            chr[qid] = nil
            chrDis[qid] = nil
            acc[qid] = true
            accDis[qid] = nil
            Print("Moved " .. title .. " to ACCOUNT list.")
        else
            acc[qid] = true
            accDis[qid] = nil
            Print("Added " .. title .. " to ACCOUNT list.")
        end
    else
        if chr[qid] then
            Print("Already in CHARACTER list: " .. title)
            return
        end

        if acc[qid] then
            acc[qid] = nil
            accDis[qid] = nil
            chr[qid] = true
            chrDis[qid] = nil
            Print("Moved " .. title .. " to CHARACTER list.")
        else
            chr[qid] = true
            chrDis[qid] = nil
            Print("Added " .. title .. " to CHARACTER list.")
        end
    end

    editBox:SetText("")
    f.validQID = nil
    if f.nameLabel then f.nameLabel:SetText("") end
    if f.existsLabel then f.existsLabel:SetText("") end
    if f.reasonLabel then f.reasonLabel:SetText("") end
    if f.btnChar then f.btnChar:Disable() end
    if f.btnAcc then f.btnAcc:Disable() end
    f:Hide()
end

-- UI Buttons
local btnChar = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
btnChar:SetPoint("BOTTOMLEFT", 10, 42)
btnChar:SetSize(135, 25)
btnChar:SetText("Add to Character")
btnChar:SetScript("OnClick", function() SaveID(false) end)
if btnChar.RegisterForClicks then btnChar:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
btnChar:Disable()
f.btnChar = btnChar

local btnAcc = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
btnAcc:SetPoint("BOTTOMRIGHT", -10, 42)
btnAcc:SetSize(135, 25)
btnAcc:SetText("Add to Account")
btnAcc:SetScript("OnClick", function() SaveID(true) end)
if btnAcc.RegisterForClicks then btnAcc:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
btnAcc:Disable()
f.btnAcc = btnAcc

local reloadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
reloadBtn:SetSize(90, 22)
reloadBtn:SetPoint("BOTTOMRIGHT", -10, 10)
reloadBtn:SetText("Reload UI")
reloadBtn:SetScript("OnClick", function()
    local r = _G and _G["ReloadUI"]
    if r then r() end
end)
f._reloadBtn = reloadBtn

local function ClearValidationUI()
    f.validQID = nil
    if f.nameLabel then f.nameLabel:SetText("") end
    if f.existsLabel then f.existsLabel:SetText("") end
    if f.reasonLabel then f.reasonLabel:SetText("") end
    if f.btnChar then f.btnChar:Disable() end
    if f.btnAcc then f.btnAcc:Disable() end
end

DoValidate = function()
    InitSV()
    local scopeKey = GetActiveScopeKeyForUI()
    local text = (editBox:GetText() or "")
    if text == "" then
        ClearValidationUI()
        return
    end

    local qid = tonumber(text)
    if not qid or not scopeKey then
        ClearValidationUI()
        if f.nameLabel then f.nameLabel:SetText("|cffff0000Invalid ID|r") end
        return
    end

    local acc, chr, accDis, chrDis = GetActiveTablesForUI(scopeKey)
    local title = GetQuestTitleSafe(qid)
    if title then
        if f.nameLabel then f.nameLabel:SetText("|cffffff00" .. title .. "|r") end
    else
        if f.nameLabel then f.nameLabel:SetText("|cffff9900Quest not found (may need cache)|r") end
    end

    local inAcc = (acc and acc[qid]) and true or false
    local inChr = (chr and chr[qid]) and true or false

    local disAcc = (inAcc and accDis and accDis[qid]) and true or false
    local disChr = (inChr and chrDis and chrDis[qid]) and true or false

    if f.existsLabel then
        local a = inAcc and "|cff00ff00YES|r" or "|cffff0000NO|r"
        local c = inChr and "|cff00ff00YES|r" or "|cffff0000NO|r"
        f.existsLabel:SetText("Account: " .. a .. "   Character: " .. c)
    end

    if f.reasonLabel then f.reasonLabel:SetText("") end

    f.validQID = qid
    if f.btnAcc then
        f.btnAcc:Enable()
        SetButtonColor(f.btnAcc, "Account", (not inAcc) and "inactive" or (disAcc and "disabled" or "active"))
        f.btnAcc:SetScript("OnClick", function(_, mouseButton)
            if not inAcc then
                if mouseButton == "RightButton" then return end
                SaveID(true)
                return
            end

            InitSV()
            local key = GetActiveScopeKeyForUI()
            if not key then return end
            local acc2, _, accDis2 = GetActiveTablesForUI(key)
            local title2 = GetQuestTitleSafe(qid) or tostring(qid)

            if mouseButton == "RightButton" then
                acc2[qid] = nil
                accDis2[qid] = nil
                Print("Removed from ACCOUNT list: " .. title2)
                DoValidate()
                return
            end

            if accDis2[qid] then
                accDis2[qid] = nil
                Print("'" .. title2 .. "' will now abandon (ACCOUNT)")
            else
                accDis2[qid] = true
                Print("'" .. title2 .. "' will NOT abandon (ACCOUNT)")
            end
            DoValidate()
        end)

        SetDynamicTip(f.btnAcc, function()
            if not qid then return "Account", "Enter a QuestID first." end
            if not inAcc then
                if inChr then
                    return "Account (Inactive)", "Left-click: move to Account list", "(Removes from Character list)"
                end
                return "Account (Inactive)", "Left-click: add to Account list"
            end
            if disAcc then
                return "Account (Disabled)", "Left-click: re-enable auto-abandon (Account)", "Right-click: remove from Account list"
            end
            return "Account (Active)", "Left-click: disable auto-abandon (Account)", "Right-click: remove from Account list"
        end)
    end

    if f.btnChar then
        f.btnChar:Enable()
        SetButtonColor(f.btnChar, "Character", (not inChr) and "inactive" or (disChr and "disabled" or "active"))
        f.btnChar:SetScript("OnClick", function(_, mouseButton)
            if not inChr then
                if mouseButton == "RightButton" then return end
                SaveID(false)
                return
            end

            InitSV()
            local key = GetActiveScopeKeyForUI()
            if not key then return end
            local _, chr2, _, chrDis2 = GetActiveTablesForUI(key)
            local title2 = GetQuestTitleSafe(qid) or tostring(qid)

            if mouseButton == "RightButton" then
                chr2[qid] = nil
                chrDis2[qid] = nil
                Print("Removed from CHARACTER list: " .. title2)
                DoValidate()
                return
            end

            if chrDis2[qid] then
                chrDis2[qid] = nil
                Print("'" .. title2 .. "' will now abandon (CHARACTER)")
            else
                chrDis2[qid] = true
                Print("'" .. title2 .. "' will NOT abandon (CHARACTER)")
            end
            DoValidate()
        end)

        SetDynamicTip(f.btnChar, function()
            if not qid then return "Character", "Enter a QuestID first." end
            if not inChr then
                if inAcc then
                    return "Character (Inactive)", "Left-click: move to Character list", "(Removes from Account list)"
                end
                return "Character (Inactive)", "Left-click: add to Character list"
            end
            if disChr then
                return "Character (Disabled)", "Left-click: re-enable auto-abandon (Character)", "Right-click: remove from Character list"
            end
            return "Character (Active)", "Left-click: disable auto-abandon (Character)", "Right-click: remove from Character list"
        end)
    end
end

-- QuestY: auto-accept quests in its DB (map-based).
local function TryAutoAcceptQuestY()
    InitSV()
    local mapID = GetBestMapIDSafe()
    if not mapID then return end

    EnsureQuestSets("Y", mapID)
    EnsureQuestDisabledSets("Y", mapID)

    local qid = GetActiveQuestOfferIDSafe()
    if not qid then return end

    local acc = fr0z3nUI_QuestY_Acc[mapID]
    local chr = fr0z3nUI_QuestY_Char[mapID]
    local accDis = fr0z3nUI_QuestY_Settings.disabled[mapID]
    local chrDis = fr0z3nUI_QuestY_CharSettings.disabled[mapID]

    local allow = false
    if acc and acc[qid] and not (accDis and accDis[qid]) then allow = true end
    if chr and chr[qid] and not (chrDis and chrDis[qid]) then allow = true end
    if not allow then return end

    local acceptFunc = _G and _G["AcceptQuest"]
    if type(acceptFunc) ~= "function" then return end

    local title = GetQuestTitleSafe(qid) or tostring(qid)
    local ok = pcall(acceptFunc)
    if ok then
        Print("Auto-accepted: " .. title)
    end
end

editBox:SetScript("OnTextChanged", function(self, userInput)
    local txt = self:GetText() or ""

    if userInput then
        local cleaned = txt:gsub("%D", "")
        if txt ~= cleaned then
            self:SetText(cleaned)
            if self.SetCursorPosition then self:SetCursorPosition(#cleaned) end
            txt = cleaned
        end
    end

    ClearValidationUI()
    if f and f._placeholder then
        local focused = (self.HasFocus and self:HasFocus()) and true or false
        if txt == "" and not focused then f._placeholder:Show() else f._placeholder:Hide() end
    end
    if userInput then
        if f._validateTimer then f._validateTimer:Cancel() end
        f._validateTimer = C_Timer.NewTimer(0.7, DoValidate)
    end
end)

-- 2. Logic: Check and Abandon
local function TryAbandon()
    -- Safety: Don't try to abandon in combat to avoid UI Taint
    if InCombatLockdown() then return end

    if not ShouldTryAbandonNow() then return end

    local scopeKey = GetScopeKey()
    if not scopeKey then return end

    local targets = {}
    InitSV()

    local accDisabled = (fr0z3nUI_QuestX_Settings and fr0z3nUI_QuestX_Settings.disabled and fr0z3nUI_QuestX_Settings.disabled[scopeKey]) or nil
    local chrDisabled = (fr0z3nUI_QuestX_CharSettings and fr0z3nUI_QuestX_CharSettings.disabled and fr0z3nUI_QuestX_CharSettings.disabled[scopeKey]) or nil

    if fr0z3nUI_QuestX_Acc and fr0z3nUI_QuestX_Acc[scopeKey] then
        for id in pairs(fr0z3nUI_QuestX_Acc[scopeKey]) do
            if not (accDisabled and accDisabled[id]) then
                targets[id] = true
            end
        end
    end
    if fr0z3nUI_QuestX_Char and fr0z3nUI_QuestX_Char[scopeKey] then
        for id in pairs(fr0z3nUI_QuestX_Char[scopeKey]) do
            if not (chrDisabled and chrDisabled[id]) then
                targets[id] = true
            end
        end
    end

    -- Optimized Loop for 2026
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local qID = C_QuestLog.GetQuestIDForLogIndex(i)
        if qID and targets[qID] then
            local info = C_QuestLog.GetInfo(i)
            local qTitle = (info and info.title) or qID
            
            -- SetSelectedQuest expects a quest log index
            C_QuestLog.SetSelectedQuest(i)
            C_QuestLog.SetAbandonQuest()
            C_QuestLog.AbandonQuest()
            
            -- Confirm the "Are you sure?" popup safely
            if StaticPopup1 and StaticPopup1.which == "ABANDON_QUEST" then
                StaticPopup_OnClick(StaticPopup1, 1)
            end
            
            Print(tostring(qTitle) .. " Abandoned")
        end
    end
end

-- 3. Slash Commands and Events
SLASH_FR0Z3NUIQX1 = "/fqx"
SlashCmdList["FR0Z3NUIQX"] = function()
    f:Show()
    if editBox and editBox.SetFocus then editBox:SetFocus() end
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED") -- Trigger after combat ends
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_DETAIL")

local function QueueTryAbandon()
    if not ShouldTryAbandonNow() then return end
    if f._abandonTimer then
        f._abandonTimer:Cancel()
        f._abandonTimer = nil
    end
    f._abandonTimer = C_Timer.NewTimer(0.5, TryAbandon)
end

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        InitSV()
        UpdateScopeButton()
    end

    if event == "QUEST_DETAIL" then
        -- QuestY runs regardless of which tab is open.
        C_Timer.After(0, TryAutoAcceptQuestY)
    end

    QueueTryAbandon()
end)
