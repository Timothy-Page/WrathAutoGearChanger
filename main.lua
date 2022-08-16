local addonName, WrathAutoGearChanger = ...

SLASH_WAGC1 = "/WAGC"
local inDebugMode = false
local inDeepDebugMode = false

local isSkinner = false
local isHerber = false
local isMinner = false
local isFishing = false

local skinningRank = 0
local herbingRank = 0
local minningRank = 0
local fishingRank = 0

local skinningLine = 0
local herbingLine = 0
local minningLine = 0
local fishingLine = 0

local getProfHasRun = false

local isCasting = false

local SkillLevelGap = 10

local mounted = IsMounted()
local isFlightForm = false
local inCombat = InCombatLockdown()

local currentSet = "None"
local currentWantedSet = "None"
--local currentBaseSet = "None"

local flightFormBuffs = {
    ["Swift Flight Form"] = true,
    ["Flight Form"] = true
}

--Create delay function
local waitTable = {}
local waitFrame = nil

function wagc_wait(delay, func, ...)
  if(type(delay) ~= "number" or type(func) ~= "function") then
    return false
  end
  if not waitFrame then
    waitFrame = CreateFrame("Frame", nil, UIParent)
    waitFrame:SetScript("OnUpdate", function (self, elapse)
      for i = 1, #waitTable do
        local waitRecord = tremove(waitTable, i)
        local d = tremove(waitRecord, 1)
        local f = tremove(waitRecord, 1)
        local p = tremove(waitRecord, 1)
        if d > elapse then
          tinsert(waitTable, i, {d - elapse, f, p})
          i = i + 1
        else
          i = i - 1
          f(unpack(p))
        end
      end
    end)
  end
  tinsert(waitTable, {delay, func, {...}})
  return true
end

local function checkIfFlightForm()
    value = false

    for buff in pairs(flightFormBuffs) do
        if AuraUtil.FindAuraByName(buff, "player") then
            value = true
        end
    end

    return value
end

--Keep Track of Tooltip text to check if it has updated
local GameTooltipLine1 = nil
local GameTooltipLine2 = nil
local GameTooltipLine3 = nil

local function PrintSkill(skill)
    if skill == "Skinning" then
        print("Skinning: " .. tostring(isSkinner) .. ", Rank: " .. skinningRank)
    elseif skill == "Herbalism" then
        print("Herbalism: " .. tostring(isHerber) .. ", Rank: " .. herbingRank)
    elseif skill == "Mining" then
        print("Mining: " .. tostring(isMinner) .. ", Rank: " .. minningRank)
    elseif skill == "Fishing" then
        print("Fishing: " .. tostring(isFishing) .. ", Rank: " .. fishingRank)
    else
        print(skill .. " is not a recgonised skill. Please use Skinning, Herbalism, Fishing or Mining")
    end
end

local function GetProf()
    local numSkills = GetNumSkillLines()
    for i = 1, numSkills do
        local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType, skillDescription = GetSkillLineInfo(i)
            if (skillName == "Skinning") then
                isSkinner = true
                skinningRank = skillRank
                skinningLine = i
            end
            if (skillName == "Herbalism") then
                isHerber = true
                herbingRank = skillRank
                herbingLine = i
            end
            if (skillName == "Mining") then
                isMinner = true
                minningRank = skillRank
                minningLine = i
            end
            if (skillName == "Fishing") then
                isFishing = true
                fishingRank = skillRank
                fishingLine = i
            end
            if (string.len(skillName) > 0 and inDeepDebugMode) then
                print(skillName)
            end
    end

    if inDebugMode then
        PrintSkill("Skinning")
        PrintSkill("Herbalism")
        PrintSkill("Mining")
        PrintSkill("Fishing")
    end

    getProfHasRun = true
end

local function UpdateSkill(skill)
    if skill == "Skinning" and isSkinner then
        local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType, skillDescription = GetSkillLineInfo(skinningLine)
        skinningRank = skillRank
    elseif skill == "Herbalism" and isHerber then
        local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType, skillDescription = GetSkillLineInfo(herbingLine)
        herbingRank = skillRank
    elseif skill == "Mining" and isMinner then
        local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType, skillDescription = GetSkillLineInfo(minningLine)
        miningRank = skillRank
    elseif skill == "Fishing" and isFishing then
        local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType, skillDescription = GetSkillLineInfo(fishingLine)
        fishingRank = skillRank
    end
end

local function WAGCHandler(parameter)

    local setName

    if(string.len(parameter) > 0) then
        if (parameter == "GetProf") then
            GetProf()
        elseif (parameter == "FlightForm") then
            print("FlightForm: " .. tostring(checkIfFlightForm()))
        elseif (parameter == "test") then
            GetSetID("FlightForm")
        else
            UpdateSkill(parameter)
            PrintSkill(parameter)
        end
    else
        print("No Set Name was Specified")
        print(EquipedSet())
    end

    if (inDebugMode) then
        print("The Parameter was: " .. parameter)
    end
end

local function SkinningRankNeeded(level)
    local rankNeeded
    if (level <= 10) then
        rankNeeded = 1
    elseif (level <= 20) then
        rankNeeded = (10 * level) - 100
    else
        rankNeeded = 5 * level
    end

    return rankNeeded
end

local function HerbalismRankNeeded(herb)
    local rankNeeded = WrathAutoGearChanger.herbNodes[herb]

    if rankNeeded == nil then
        rankNeeded = WrathAutoGearChanger.herbNodes["CatchAll"]
    end

    if inDebugMode then 
        print("Herb Skill Needed to pick " .. herb .. " is: " .. tostring(rankNeeded))
    end

    return rankNeeded
end

local function MiningRankNeeded(ore)
    local rankNeeded = WrathAutoGearChanger.miningNodes[ore]

    if rankNeeded == nil then
        rankNeeded = WrathAutoGearChanger.miningNodes["CatchAll"]
    end

    if inDebugMode then 
        print("Mining Skill Needed to mine " .. ore .. " is: " .. tostring(rankNeeded))
    end

    return rankNeeded
end

local function FishingRankNeeded(pool)
    local rankNeeded = WrathAutoGearChanger.fishingNodes[pool]["garentee"]

    if inDebugMode then 
        print("Fishing Skill Needed to Fish " .. pool .. " is: " .. tostring(rankNeeded))
    end

    return rankNeeded
end

local function isFishingPool(textString)
    local isFishingPool = false

    local fishingPool = WrathAutoGearChanger.fishingNodes[textString]

    if fishingPool ~= nil then
        isFishingPool = true
    end

    return isFishingPool
end

local function SkinningHandler()
    if (isSkinner) then
        UpdateSkill("Skinning")
        if(GameTooltipLine3 == "Skinnable" and SkinningRankNeeded(UnitLevel("Mouseover")) > skinningRank - SkillLevelGap) then
            return true
        else
            return false
        end
    end
end

local function HerbalismHandler()
    if (isHerber) then
        UpdateSkill("Herbalism")
        if(GameTooltipLine2 == "Herbalism" and HerbalismRankNeeded(GameTooltipLine1) > herbingRank - SkillLevelGap) then
            return true
        else
            return false
        end
    end
end

local function MiningHandler()
    if (isMinner) then
        UpdateSkill("Mining")
        if(GameTooltipLine2 == "Mining" and MiningRankNeeded(GameTooltipLine1) > minningRank - SkillLevelGap) then
            return true
        else
            return false
        end
    end
end

local function FishingHandler(FishingType)
    if (isFishing) then
        UpdateSkill("Fishing")
        if isFishingPool(GameTooltipLine1) then
            if (FishingType == "BasicFishing" and FishingRankNeeded(GameTooltipLine1) <= fishingRank) then
                return true
            elseif (FishingType == "Fishing" and FishingRankNeeded(GameTooltipLine1) > fishingRank) then
                return true
            end
        end
    end
    
    return false
end

local function MountHandler()
    if IsMounted() and not UnitOnTaxi("player") then
        local inInstance, instanceType = IsInInstance()
        if instanceType == "arena" or instanceType == "party" or instanceType == "raid" then
            return false
        else
            return true
        end
    else
        return false
    end
end

local function FlightFormHandler()
    if checkIfFlightForm() then
        return true
    else
        return false
    end
end

local function GetSetID(setName)
    setID = C_EquipmentSet.GetEquipmentSetID(setName)
    return setID
end

local function WAGCEquipSet(setName)
    if setName ~= "None" and setName ~= nil then
        if inDebugMode then
            print("Looking for setname: " .. tostring(setName))
        end
        setID = GetSetID(setName)
        if setID ~= nil then
            setWasEquipped = C_EquipmentSet.UseEquipmentSet(setID)
        else
            print("Could not Find Set: " .. setName)
        end
    end
end

local function UpdateGear()

    local equipSkinning = SkinningHandler()
    local equipHerbalism = HerbalismHandler()
    local equipMining = MiningHandler()
    local equipBasicFishing = FishingHandler("BasicFishing")
    local equipFishing = FishingHandler("Fishing")
    local equipMount = MountHandler()
    local equipFlightForm = FlightFormHandler()

    currentWantedSet = "None"

    if equipMount then
        currentWantedSet = "Mount"
    elseif equipHerbalism then
        currentWantedSet = "Herbalism"
    elseif equipFlightForm then
        currentWantedSet = "FlightForm"
    elseif equipSkinning then
        currentWantedSet = "Skinning"
    elseif equipMining then
        currentWantedSet = "Mining"
    elseif equipBasicFishing then
        currentWantedSet = "BasicFishing"
    elseif equipFishing then
        currentWantedSet = "Fishing"
    end
    
    if currentWantedSet == "None" and currentSet ~= currentBaseSet then
        if inDebugMode then
          print("Equiping " .. currentWantedSet)
        end
        WAGCEquipSet(currentBaseSet)
    elseif currentWantedSet ~= currentSet and currentWantedSet ~= "None" then
        if inDebugMode then
          print("Equiping " .. currentWantedSet)
        end
        WAGCEquipSet(currentWantedSet)
    end

end

local function GameTooltipChangeHandler(forceRunHandler, debugString)

    -- do nothing if profession data has not been set
    if not getProfHasRun then
        return
    end
    
    if not (inCombat == InCombatLockdown()) or not (isFlightForm == checkIfFlightForm()) or not (mounted == IsMounted()) or (not (GameTooltipLine1 == GameTooltipTextLeft1:GetText() and GameTooltipLine2 == GameTooltipTextLeft2:GetText() and GameTooltipLine3 == GameTooltipTextLeft3:GetText()) or forceRunHandler) then
        if (inDebugMode) then
            DEFAULT_CHAT_FRAME:AddMessage(debugString)
        end
        
        mounted = IsMounted()
        inCombat = InCombatLockdown()
        isFlightForm = checkIfFlightForm()

        -- update local variables for tooltiptext
        GameTooltipLine1 = GameTooltipTextLeft1:GetText()
        GameTooltipLine2 = GameTooltipTextLeft2:GetText()
        GameTooltipLine3 = GameTooltipTextLeft3:GetText()

        if not isCasting and not inCombat then
            -- Call the Handlers for each Profession
            UpdateGear()
        end
    end
end

-- CreateEvent when GameToolTip Shows
local function ToolTipOnShow()
    GameTooltipChangeHandler(false, "Tooltip OnShow Event fired!")
end

GameTooltip:HookScript("OnShow", ToolTipOnShow)

-- CreateEvent when GameToolTip Hides
local function ToolTipOnHide()
    GameTooltipChangeHandler(false, "Tooltip OnHide Event fired!")
end

GameTooltip:HookScript("OnHide", ToolTipOnHide)


-- CreateEvent when GameToolTip Update
local function ToolTipOnUpdate()
    GameTooltipChangeHandler(false, "Tooltip OnUpdate Event fired!")
end

GameTooltip:HookScript("OnUpdate", ToolTipOnUpdate)

-- Delay lookup of Profession values for 1.5s to allow ItemRack to Load
local function initialiseProfessions()
    wagc_wait(1.5, GetProf)
end

local EnterWorldFrame = CreateFrame("Frame")
EnterWorldFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EnterWorldFrame:SetScript("OnEvent", initialiseProfessions)

-- Check gear set when cast finishes
local function StopCastingHandler(self, event, ...)
    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        unitTarget = ...
        if unitTarget == "player" then
            isCasting = false
            GameTooltipChangeHandler(true, "Cast Stopped")
        end
    end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        unitTarget = ...
        if unitTarget == "player" then
            isCasting = true
        end
    end
end

local ChangeCastingFrame = CreateFrame("Frame")
ChangeCastingFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
ChangeCastingFrame:RegisterEvent("UNIT_SPELLCAST_START")
ChangeCastingFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
ChangeCastingFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
ChangeCastingFrame:SetScript("OnEvent", StopCastingHandler)

-- update which gearset is equiped
local function SetChangedHandler(self, event, result, setID, ...)
    if event == "EQUIPMENT_SWAP_FINISHED" then
        name, iconFileID, setID, isEquipped, numItems, numEquipped, numInInventory, numLost, numIgnored = C_EquipmentSet.GetEquipmentSetInfo(setID)

        currentSet = name
        if inDebugMode then
            print ("Equipment Set was equiped: " .. tostring(currentSet))
        end

        if currentSet ~= currentWantedSet and currentSet ~= currentBaseSet then
            if inDebugMode then
              print("Changing Base set from " .. tostring(currentBaseSet) .. " to " .. currentSet)
            end
              currentBaseSet = currentSet
        end
    end
end

local SetChangedFrame = CreateFrame("Frame")
SetChangedFrame:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
SetChangedFrame:RegisterEvent("EQUIPMENT_SWAP_PENDING")
SetChangedFrame:SetScript("OnEvent", SetChangedHandler)

local function loopCheck()
    if not (mounted == IsMounted()) then
        GameTooltipChangeHandler(false, "Mount Status Change")
    end
    if not (inCombat == InCombatLockdown()) then
        GameTooltipChangeHandler(false, "Combat Status Changed")
    end
    if not (isFlightForm == checkIfFlightForm()) then
        GameTooltipChangeHandler(false, "Flight Form Changed")
    end
end
local LoopFrame = CreateFrame("Frame")
LoopFrame:SetScript("OnUpdate", loopCheck)

-- Register slash commands
SlashCmdList["WAGC"] = WAGCHandler;


-- PLAYER_EQUIPMENT_CHANGED, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED
