local function InitSV()
    fr0z3nUI_QuestX_Acc = fr0z3nUI_QuestX_Acc or {}
    fr0z3nUI_QuestX_Char = fr0z3nUI_QuestX_Char or {}

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

local function Print(msg)
    print("|cff00ccff[FQX]|r " .. tostring(msg or ""))
end

-- 1. Create UI Frame
local f = CreateFrame("Frame", "fr0z3nUIQuestXFrame", UIParent, "BasicFrameTemplateWithInset")

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
        t:SetPoint("TOPLEFT", 12, -10)
        t:SetJustifyH("LEFT")
    end
    if t.SetText then
        t:SetText("|cff00ccff[FQX]|r QuestX")
    end
    f.title = t
end

local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
editBox:SetSize(150, 30)
editBox:SetPoint("TOP", 0, -30)
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

-- Helper to save IDs
local function EnsureMapSets(mapID)
    fr0z3nUI_QuestX_Acc[mapID] = fr0z3nUI_QuestX_Acc[mapID] or {}
    fr0z3nUI_QuestX_Char[mapID] = fr0z3nUI_QuestX_Char[mapID] or {}

    -- If an older array slipped through, migrate it now.
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

local function SaveID(isAccount)
    InitSV()
    local qid = f.validQID or tonumber(editBox:GetText())
    local mapID = GetBestMapIDSafe()
    if not qid or not mapID then return end

    EnsureMapSets(mapID)
    local acc = fr0z3nUI_QuestX_Acc[mapID]
    local chr = fr0z3nUI_QuestX_Char[mapID]
    local title = GetQuestTitleSafe(qid) or tostring(qid)

    if isAccount then
        if acc[qid] then
            Print("Already in ACCOUNT list: " .. title)
            return
        end

        if chr[qid] then
            chr[qid] = nil
            acc[qid] = true
            Print("Moved " .. title .. " to ACCOUNT list.")
        else
            acc[qid] = true
            Print("Added " .. title .. " to ACCOUNT list.")
        end
    else
        if chr[qid] then
            Print("Already in CHARACTER list: " .. title)
            return
        end

        if acc[qid] then
            acc[qid] = nil
            chr[qid] = true
            Print("Moved " .. title .. " to CHARACTER list.")
        else
            chr[qid] = true
            Print("Added " .. title .. " to CHARACTER list.")
        end
    end

    editBox:SetText("")
    f.validQID = nil
    if f.nameLabel then f.nameLabel:SetText("") end
    if f.existsLabel then f.existsLabel:SetText("") end
    if f.btnChar then f.btnChar:Disable() end
    if f.btnAcc then f.btnAcc:Disable() end
    f:Hide()
end

-- UI Buttons
local btnChar = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
btnChar:SetPoint("BOTTOMLEFT", 10, 10)
btnChar:SetSize(135, 25)
btnChar:SetText("Add to Character")
btnChar:SetScript("OnClick", function() SaveID(false) end)
btnChar:Disable()
f.btnChar = btnChar

local btnAcc = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
btnAcc:SetPoint("BOTTOMRIGHT", -10, 10)
btnAcc:SetSize(135, 25)
btnAcc:SetText("Add to Account")
btnAcc:SetScript("OnClick", function() SaveID(true) end)
btnAcc:Disable()
f.btnAcc = btnAcc

local function ClearValidationUI()
    f.validQID = nil
    if f.nameLabel then f.nameLabel:SetText("") end
    if f.existsLabel then f.existsLabel:SetText("") end
    if f.btnChar then f.btnChar:Disable() end
    if f.btnAcc then f.btnAcc:Disable() end
end

local function DoValidate()
    InitSV()
    local mapID = GetBestMapIDSafe()
    local text = (editBox:GetText() or "")
    if text == "" then
        ClearValidationUI()
        return
    end

    local qid = tonumber(text)
    if not qid or not mapID then
        ClearValidationUI()
        if f.nameLabel then f.nameLabel:SetText("|cffff0000Invalid ID|r") end
        return
    end

    EnsureMapSets(mapID)
    local acc = fr0z3nUI_QuestX_Acc[mapID]
    local chr = fr0z3nUI_QuestX_Char[mapID]
    local title = GetQuestTitleSafe(qid)
    if title then
        if f.nameLabel then f.nameLabel:SetText("|cffffff00" .. title .. "|r") end
    else
        if f.nameLabel then f.nameLabel:SetText("|cffff9900Quest not found (may need cache)|r") end
    end

    local inAcc = (acc and acc[qid]) and true or false
    local inChr = (chr and chr[qid]) and true or false

    if f.existsLabel then
        local a = inAcc and "|cff00ff00YES|r" or "|cffff0000NO|r"
        local c = inChr and "|cff00ff00YES|r" or "|cffff0000NO|r"
        f.existsLabel:SetText("Account: " .. a .. "   Character: " .. c)
    end

    f.validQID = qid
    if f.btnAcc then
        if inAcc then f.btnAcc:Disable() else f.btnAcc:Enable() end
    end
    if f.btnChar then
        if inChr then f.btnChar:Disable() else f.btnChar:Enable() end
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

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end

    local targets = {}
    InitSV()

    if fr0z3nUI_QuestX_Acc and fr0z3nUI_QuestX_Acc[mapID] then
        for id in pairs(fr0z3nUI_QuestX_Acc[mapID]) do targets[id] = true end
    end
    if fr0z3nUI_QuestX_Char and fr0z3nUI_QuestX_Char[mapID] then
        for id in pairs(fr0z3nUI_QuestX_Char[mapID]) do targets[id] = true end
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
f:RegisterEvent("PLAYER_REGEN_ENABLED") -- Trigger after combat ends
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("QUEST_ACCEPTED")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        InitSV()
    end
    
    -- Small delay to ensure quest log sync
    C_Timer.After(0.5, TryAbandon)
end)
