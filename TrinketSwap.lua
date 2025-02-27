local TrinketSwapFrame = CreateFrame("Frame")
local AceTimer = LibStub("AceTimer-3.0")

local CHICKEN_ID = 10725  -- Gnomish Battle Chicken
local TRINKET_SLOT = 13
local originalTrinket = nil
local isEquipped = false  -- Track if the chicken trinket is equipped
local cooldownTimer = nil  -- Timer for updating cooldown text
local pulseTimer = nil  -- Timer for pulsing the icon
local pulseDirection = 1  -- Direction of pulsing (1 for increasing alpha, -1 for decreasing alpha)

local function IsTrinketEquipped()
    local itemID = GetInventoryItemID("player", TRINKET_SLOT)
    return itemID == CHICKEN_ID
end

local function HasChickenTrinket()
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemID = GetContainerItemID(bag, slot)
            if itemID == CHICKEN_ID then
                return true
            end
        end
    end
    return IsTrinketEquipped()
end

local function FormatCooldown(remaining)
    if remaining >= 60 then
        return string.format("%dm", math.ceil(remaining / 60))
    else
        return tostring(remaining)
    end
end

local function PulseIcon()
    local alpha = TrinketSwapIconFrame:GetAlpha()
    alpha = alpha + (pulseDirection * 0.05)
    if alpha >= 1 then
        alpha = 1
        pulseDirection = -1
    elseif alpha <= 0.5 then
        alpha = 0.5
        pulseDirection = 1
    end
    TrinketSwapIconFrame:SetAlpha(alpha)
end

local function StartPulsing()
    if not pulseTimer then
        pulseTimer = AceTimer:ScheduleRepeatingTimer(PulseIcon, 0.05)
    end
end

local function StopPulsing()
    if pulseTimer then
        AceTimer:CancelTimer(pulseTimer)
        pulseTimer = nil
        TrinketSwapIconFrame:SetAlpha(1)
    end
end

local function EquipChicken()
    -- Save the current trinket and equip the chicken
    originalTrinket = GetInventoryItemID("player", TRINKET_SLOT)
    EquipItemByName(CHICKEN_ID, TRINKET_SLOT)
    isEquipped = true
    TrinketSwapUseText:Show()
    if TrinketSwapCooldown then
        TrinketSwapCooldown:SetCooldown(GetTime(), 30)  -- Start the 30-second cooldown
        TrinketSwapCooldownText:SetText("30")
        cooldownTimer = AceTimer:ScheduleRepeatingTimer(function()
            local start, duration = GetInventoryItemCooldown("player", TRINKET_SLOT)
            local remaining = math.ceil(duration - (GetTime() - start))
            TrinketSwapCooldownText:SetText(remaining > 0 and FormatCooldown(remaining) or "")
            if remaining > 32 then
                RevertTrinket()
            end
            if remaining <= 0 then
                AceTimer:CancelTimer(cooldownTimer)
            end
        end, 1)
    end
end

local function RevertTrinket()
    -- Swap back to original trinket
    EquipItemByName(originalTrinket, TRINKET_SLOT)
    isEquipped = false
    TrinketSwapUseText:Hide()
    TrinketSwapCooldownText:SetText("")
    if cooldownTimer then
        AceTimer:CancelTimer(cooldownTimer)
        cooldownTimer = nil
    end
    StopPulsing()
end

function TrinketSwap_UpdateIcon()
    local itemID = GetInventoryItemID("player", TRINKET_SLOT)
    if itemID then
        local icon = GetItemIcon(itemID)
        TrinketSwapIconTexture:SetTexture(icon)
    else
        TrinketSwapIconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
end

function TrinketSwap_UpdateCooldown()
    local start, duration, enable = GetInventoryItemCooldown("player", TRINKET_SLOT)
    if TrinketSwapCooldown then
        TrinketSwapCooldown:SetCooldown(start, duration)
        local remaining = math.ceil(duration - (GetTime() - start))
        TrinketSwapCooldownText:SetText(remaining > 0 and FormatCooldown(remaining) or "")
    end
end

TrinketSwapFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
TrinketSwapFrame:RegisterEvent("PLAYER_LOGIN")
TrinketSwapFrame:RegisterEvent("BAG_UPDATE")
TrinketSwapFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" and isEquipped then
        RevertTrinket()
    elseif event == "PLAYER_LOGIN" or event == "BAG_UPDATE" then
        if HasChickenTrinket() then
            TrinketSwapIconFrame:Show()
        else
            TrinketSwapIconFrame:Hide()
        end
        TrinketSwap_UpdateIcon()
        TrinketSwap_UpdateCooldown()
        TrinketSwapUseText:Hide()
    end
end)

SLASH_REVERT1 = "/revert"
SlashCmdList["REVERT"] = RevertTrinket

TrinketSwapIconFrame:SetScript("OnMouseUp", function(self, button)
    if IsShiftKeyDown() then
        self:StopMovingOrSizing()
    else
        if not isEquipped and GetInventoryItemCooldown("player", TRINKET_SLOT) == 0 then
            EquipChicken()
        end
    end
end)

TrinketSwapFrame:SetScript("OnUpdate", function(self, elapsed)
    local start, duration = GetInventoryItemCooldown("player", TRINKET_SLOT)
    local remaining = math.ceil(duration - (GetTime() - start))
    TrinketSwapCooldownText:SetText(remaining > 0 and FormatCooldown(remaining) or "")
    if isEquipped and remaining > 32 then
        RevertTrinket()
    end
    if IsTrinketEquipped() and remaining <= 0 then
        StartPulsing()
    else
        StopPulsing()
    end
end)

