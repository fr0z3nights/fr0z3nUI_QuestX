-- 1. Create UI Frame
local f = CreateFrame("Frame", "fr0z3nUIQuestXFrame", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(300, 130)
f:SetPoint("CENTER")
f:Hide()
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", 0, -5)
f.title:SetText("fr0z3nUI QuestX: Add Quest ID")

local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
editBox:SetSize(150, 30)
editBox:SetPoint("TOP", 0, -30)
editBox:SetAutoFocus(false)
editBox:SetNumeric(true)

-- Helper to save IDs
local function SaveID(isAccount)
    local qid = tonumber(editBox:GetText())
    local mapID = C_Map.GetBestMapForUnit("player")
    if not qid or not mapID then return end

    if isAccount then
        fr0z3nUI_QuestX_Acc[mapID] = fr0z3nUI_QuestX_Acc[mapID] or {}
        table.insert(fr0z3nUI_QuestX_Acc[mapID], qid)
        print("|cff00ccff[QuestX]|r Added " .. qid .. " to ACCOUNT list.")
    else
        fr0z3nUI_QuestX_Char[mapID] = fr0z3nUI_QuestX_Char[mapID] or {}
        table.insert(fr0z3nUI_QuestX_Char[mapID], qid)
        print("|cff00ccff[QuestX]|r Added " .. qid .. " to CHARACTER list.")
    end
    editBox:SetText("")
    f:Hide()
end

-- UI Buttons
local btnChar = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
btnChar:SetPoint("BOTTOMLEFT", 10, 10)
btnChar:SetSize(135, 25)
btnChar:SetText("Add to Character")
btnChar:SetScript("OnClick", function() SaveID(false) end)

local btnAcc = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
btnAcc:SetPoint("BOTTOMRIGHT", -10, 10)
btnAcc:SetSize(135, 25)
btnAcc:SetText("Add to Account")
btnAcc:SetScript("OnClick", function() SaveID(true) end)

-- 2. Logic: Check and Abandon
local function TryAbandon()
    -- Safety: Don't try to abandon in combat to avoid UI Taint
    if InCombatLockdown() then return end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end

    local targets = {}
    if fr0z3nUI_QuestX_Acc and fr0z3nUI_QuestX_Acc[mapID] then
        for _, id in ipairs(fr0z3nUI_QuestX_Acc[mapID]) do targets[id] = true end
    end
    if fr0z3nUI_QuestX_Char and fr0z3nUI_QuestX_Char[mapID] then
        for _, id in ipairs(fr0z3nUI_QuestX_Char[mapID]) do targets[id] = true end
    end

    -- Optimized Loop for 2026
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local qID = C_QuestLog.GetQuestIDForLogIndex(i)
        if qID and targets[qID] then
            local info = C_QuestLog.GetInfo(i)
            local qTitle = (info and info.title) or qID
            
            C_QuestLog.SetSelectedQuest(qID)
            C_QuestLog.SetAbandonQuest()
            C_QuestLog.AbandonQuest()
            
            -- Confirm the "Are you sure?" popup safely
            if StaticPopup1 and StaticPopup1.which == "ABANDON_QUEST" then
                StaticPopup_OnClick(StaticPopup1, 1)
            end
            
            print("|cff00ccff[QuestX]|r " .. qTitle .. " Abandoned")
        end
    end
end

-- 3. Slash Commands and Events
SLASH_FR0Z3NUIQX1 = "/qx"
SlashCmdList["FR0Z3NUIQX"] = function() f:Show() end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED") -- Trigger after combat ends
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("QUEST_ACCEPTED")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        fr0z3nUI_QuestX_Acc = fr0z3nUI_QuestX_Acc or {}
        fr0z3nUI_QuestX_Char = fr0z3nUI_QuestX_Char or {}
    end
    
    -- Small delay to ensure quest log sync
    C_Timer.After(0.5, TryAbandon)
end)
