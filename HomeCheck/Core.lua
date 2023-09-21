HomeCheck = CreateFrame("Frame")

HomeCheck.LibGroupTalents = LibStub("LibGroupTalents-1.0")
HomeCheck.LibSharedMedia = LibStub("LibSharedMedia-3.0")
HomeCheck.LibRangeCheck = LibStub("LibRangeCheck-2.0")

LibStub("AceTimer-3.0"):Embed(HomeCheck)
LibStub("AceComm-3.0"):Embed(HomeCheck)
LibStub("AceSerializer-3.0"):Embed(HomeCheck)

HomeCheck.groups = {}
HomeCheck.localizedSpellNames = {}
HomeCheck.deadUnits = {}
HomeCheck.RebirthTargets = {}
HomeCheck.db_ver = 2

HomeCheck.comms = {
    oRA = "oRA",
    oRA3 = "oRA3",
    BLT = "BLT Raid Cooldowns",
    CTRA = "CTRA",
    RCD2 = "RaidCooldowns",
    FRCD3 = "FatCooldowns",
    FRCD3S = "FatCooldowns (single report)",
    HomeCheck = "HomeCheck",
}

local playerInRaid = UnitInRaid("player")

local updateRaidRosterCooldown = 2
local updateRaidRosterTimestamp
local updateRaidRosterScheduleTimer

local ReadinessTimestamp = {}

local childSpells = {}

local groups = 10

local date, floor, GetTime, min, pairs, select, string, strsplit, table, time, tonumber, tostring, type, unpack = date, floor, GetTime, min, pairs, select, {
    find = string.find,
    gmatch = string.gmatch
}, strsplit, {
    insert = table.insert,
    remove = table.remove,
    wipe = table.wipe
}, time, tonumber, tostring, type, unpack

HomeCheck:RegisterEvent("ADDON_LOADED")

function HomeCheck:LibGroupTalents_Update(...)
    self:refreshPlayerCooldowns((UnitName((select(3, ...)))))
    self:repositionFrames()
end

HomeCheck:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, combatEvent, _, playerName, _, _, targetName, _, spellID, spellName = ...
        if combatEvent == "SPELL_CAST_SUCCESS" or combatEvent == "SPELL_RESURRECT" or combatEvent == "SPELL_AURA_APPLIED" then
            if not UnitInRaid(playerName) and not UnitInParty(playerName) then
                return
            end

            if not self.spells[spellID] then
                spellID = self.localizedSpellNames[spellName]
            end

            if combatEvent == "SPELL_AURA_APPLIED" then
                targetName = nil
            end

            self:setCooldown(spellID, playerName, true, targetName)
        elseif combatEvent == "SPELL_HEAL" and spellID == 48153 then
            -- Guardian Spirit proced
            self:setCooldown(48153, playerName)
        elseif combatEvent == "UNIT_DIED" then
            if UnitInRaid(playerName) or UnitInParty(playerName) then
                self.deadUnits[playerName] = true
            end
        end

        -- UNIT_SPELLCAST events are used to detect double Rebirth only
    elseif event == "UNIT_SPELLCAST_SENT"
            or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, spellName, _, targetName = ...
        local spellID = self.localizedSpellNames[spellName]
        if spellID == 48477 then
            self:Rebirth(event, (UnitName(unit)), targetName)
        end
    elseif event == "RAID_ROSTER_UPDATE" then
        local instant
        if playerInRaid ~= UnitInRaid("player") then
            -- current player joined/left raid
            if playerInRaid then
                -- player WAS in raid
                self:RegisterEvent("PARTY_MEMBERS_CHANGED")
            else
                self:UnregisterEvent("PARTY_MEMBERS_CHANGED")
                instant = true
            end
            -- updating raid status
            playerInRaid = UnitInRaid("player")
        end
        if playerInRaid then
            self:updateRaidRoster(instant)
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        self:updateRaidRoster()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:cacheLocalizedSpellNames()
        self:ScheduleTimer(function()
            self:updateRaidCooldowns()
        end, 2)
        self:ScheduleTimer(function()
            self:updateRaidCooldowns()
        end, 10)
        self:ScheduleTimer(function()
            self:updateRaidCooldowns()
        end, 30)
    elseif event == "ADDON_LOADED" then
        if (...) ~= "HomeCheck" then
            return
        end
        self.db = LibStub("AceDB-3.0"):New("HomeCheck_DB", self.defaults, true)

        if self.db.global.db_ver ~= self.db_ver then
            if self.db.global.db_ver == 1 and self.db_ver == 2 then
                -- upgrading db

                local function tablecopy(t, copyto)
                    for k, v in pairs(t) do
                        if type(v) == "table" then
                            copyto[k] = tablecopy(v, copyto[k])
                        else
                            copyto[k] = v
                        end
                    end
                    return copyto
                end

                for k, v in pairs(self.db.global) do
                    if k ~= "db_ver" and k ~= "CDs" and k ~= "comms" then
                        self.db.profile[k], self.db.global[k] = tablecopy(v, self.db.profile[k]), nil
                    end
                end
            else
                -- unknown db version, resetting db to defaults
                self.db:ResetDB("Default")
            end
            self.db.global.db_ver = self.db_ver
        end

        for playerName, spells in pairs(self.db.global.CDs) do
            for spellID, cd in pairs(spells) do
                if not cd.timestamp or cd.timestamp < time() then
                    table.wipe(self.db.global.CDs[playerName][spellID])
                end
            end
        end

        for childSpellID, childSpellConfig in pairs(self.spells) do
            if childSpellConfig.parent then
                childSpells[childSpellConfig.parent] = childSpellID
            end
        end

        for i = 1, groups do
            self:getGroup(i)
        end

        self.db.RegisterCallback(self, "OnProfileChanged", "loadProfile")
        self.db.RegisterCallback(self, "OnProfileCopied", "loadProfile")
        self.db.RegisterCallback(self, "OnProfileReset", "loadProfile")

        self:OptionsPanel()

        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:RegisterEvent("UNIT_SPELLCAST_SENT")
        self:RegisterEvent("UNIT_SPELLCAST_FAILED")
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterEvent("RAID_ROSTER_UPDATE")
        if not playerInRaid then
            self:RegisterEvent("PARTY_MEMBERS_CHANGED")
        end
        self:RegisterEvent("PLAYER_ENTERING_WORLD")

        self.LibGroupTalents.RegisterCallback(self, "LibGroupTalents_Update")

        for k, _ in pairs(self.comms) do
            if self.db.global.comms[k] then
                self:RegisterComm(k)
            end
        end

        self:ScheduleRepeatingTimer(function()
            for playerName, _ in pairs(self.deadUnits) do
                if not UnitIsDeadOrGhost(playerName) or (not UnitInRaid(playerName) and not UnitInParty(playerName)) then
                    self.deadUnits[playerName] = nil
                end
            end

            for i = 1, #self.groups do
                for j = 1, #self.groups[i].CooldownFrames do
                    self:setTimerColor(self.groups[i].CooldownFrames[j])
                    self:updateRange(self.groups[i].CooldownFrames[j])
                end
            end
        end, 1)
    end
end)

function HomeCheck:OnCommReceived(...)
    local prefix, message, _, sender = ...

    if not self.db.global.comms[prefix] then
        return
    end

    if sender == (UnitName("player")) then
        return
    end

    local success, messageType, spellID, spellName, playerName, CDLeft, target
    if prefix == "oRA3" then
        success, messageType, spellID, CDLeft, target = self:Deserialize(message)

        if not success then
            return
        end

        if type(messageType) ~= "string" or messageType ~= "Cooldown" then
            return
        end
    elseif prefix == "BLT" then
        if not string.find(message, ":") then
            return
        end

        messageType, message = strsplit(":", message)
        if messageType ~= "CD" then
            return
        end

        if not string.find(message, ";") then
            return
        end

        playerName, spellName, spellID, target = strsplit(";", message)
    elseif prefix == "oRA" or prefix == "CTRA" then
        spellID, CDLeft = select(3, message:find("CD (%d) (%d+)"))
    elseif prefix == "RCD2" then
        spellID, CDLeft = select(3, message:find("(%d+) (%d+)"))
    elseif prefix == "FRCD3S" then
        spellID, playerName, CDLeft, target = select(3, message:find("(%d+)(%a+)(%d+)(%a*)"))
    elseif prefix == "FRCD3" then
        playerName = tostring(sender)
        if not UnitInRaid(playerName) and not UnitInParty(playerName) then
            return
        end

        for w in string.gmatch(message, "([^,]*),") do
            spellID, CDLeft = select(3, w:find("(%d+)-(%d+)"))
            spellID = tonumber(spellID)
            CDLeft = tonumber(CDLeft)

            if not spellID or not CDLeft then
                return
            end

            if not self.spells[spellID] then
                local spellName = GetSpellInfo(spellID)
                if spellName then
                    spellID = self.localizedSpellNames[spellName]
                end
            end

            self:setCooldown(spellID, playerName, CDLeft, nil, true)
        end
        return
    elseif prefix == "HomeCheck" then
        success, spellID, playerName, target = self:Deserialize(message)
        if not success then
            return
        end
    end

    if not spellID then
        return
    end

    playerName = playerName and tostring(playerName) or sender

    if not UnitInRaid(playerName) and not UnitInParty(playerName) then
        return
    end

    spellID = tonumber(spellID)

    CDLeft = CDLeft and tonumber(CDLeft)

    if not CDLeft then
        CDLeft = true
    elseif CDLeft <= 0 and not self:getSpellAlwaysShow(spellID) then
        return
    end

    if prefix == "oRA" then
        if spellID == 1 then
            spellID = 48477 -- Rebirth
        elseif spellID == 2 then
            spellID = 21169 -- Reincarnation
        elseif spellID == 3 then
            spellID = 47883 -- Soulstone Resurrection
        elseif spellID == 4 then
            spellID = 19752 -- Divine Intervention
        end
    elseif prefix == "BLT" then
        if spellID == 57934 then
            spellID = 59628
        elseif spellID == 34477 then
            spellID = 35079
        end
    end

    if not self.spells[spellID] then
        if not spellName then
            spellName = GetSpellInfo(spellID)
        end
        if spellName then
            spellID = self.localizedSpellNames[spellName]
        end
    end

    if prefix == "RCD2" and CDLeft == 0 and not self:UnitHasAbility(playerName, spellID) then
        return
    end

    if target then
        if target == "" then
            target = nil
        else
            target = tostring(target)
        end
    end

    self:setCooldown(spellID, playerName, CDLeft, target, true)
end

---@param spellID number
---@param playerName string
---@param CDLeft number|boolean|nil
---@param target string|nil
---@param isRemote boolean|nil
function HomeCheck:setCooldown(spellID, playerName, CDLeft, target, isRemote)
    if spellID == 23989 then
        -- Readiness
        self:Readiness(playerName)
    elseif spellID == 48153 then
        -- Guardian Spirit heal
        self:GSProc(playerName, target, isRemote)
    end

    if not spellID or not self.spells[spellID] then
        return
    end

    if not isRemote and CDLeft == true then
        self:SendCommMessage("HomeCheck", self:Serialize(spellID, playerName, target), "RAID")
    end

    if not self:isSpellEnabled(spellID) then
        return
    end

    if self.spells[spellID].parent then
        local frame = self:getCooldownFrame(playerName, self.spells[spellID].parent)
        if frame then
            if frame.CDLeft ~= 0 then
                self:setTarget(frame, target)
                return
            else
                self:removeCooldownFrames(playerName, self.spells[spellID].parent)
            end
        end
    end

    local frame = self:createCooldownFrame(playerName, spellID)

    if CDLeft == true then
        CDLeft = self:getSpellCooldown(frame)
    end

    if not CDLeft and frame.CDLeft == 0 and self.db.global.CDs[playerName][spellID].timestamp and self.db.global.CDs[playerName][spellID].timestamp > time() then
        -- restoring CD info from SV
        CDLeft = self.db.global.CDs[playerName][spellID].timestamp - time()
        target = self.db.global.CDs[playerName][spellID].target
        -- unknown data source and reliability, treat is as remote
        isRemote = true
    end

    target = self:setTarget(frame, target)

    if CDLeft then
        if not frame.isRemote and isRemote then
            if frame.CDLeft > 5 then
                return
            end
            if CDLeft >= frame.CDLeft and CDLeft - frame.CDLeft < 5 then
                return
            end
        end

        if not frame.isRemote and not isRemote then
            if CDLeft >= frame.CDLeft and CDLeft - frame.CDLeft < 2 then
                return
            end
        end

        if frame.isRemote and isRemote then
            if frame.CDLeft > 5 then
                if CDLeft >= frame.CDLeft and CDLeft - frame.CDLeft < 5 then
                    return
                end
            end
        end

        frame.CDLeft = CDLeft
    else
        if frame.initialized then
            return
        end
    end

    if childSpells[spellID] then
        if not target then
            self:setTarget(frame, self:getTarget(playerName, childSpells[spellID]))
        end
        self:removeCooldownFrames(playerName, childSpells[spellID])
    end

    frame.CDLeft = CDLeft or frame.CDLeft
    frame.isRemote = isRemote
    frame.CD = self:getSpellCooldown(frame)

    if frame.CDLeft > 0 then
        self.db.global.CDs[playerName][spellID].timestamp = time() + frame.CDLeft
        frame.CDReady = GetTime() + frame.CDLeft

        frame.timerFontString:SetText(date("!%M:%S", frame.CDLeft):gsub('^0+:?0?', ''))

        if not frame.CDtimer then
            local tick = 0.1
            frame.CDtimer = self:ScheduleRepeatingTimer(function(frame)
                frame.CDLeft = frame.CDReady - GetTime()
                frame.CDLeft = tonumber((("%%.%df"):format(1)):format(frame.CDLeft))

                self:updateCooldownBarProgress(frame)

                if frame.CDLeft <= 0 then
                    self:CancelTimer(frame.CDtimer)
                    frame.CDtimer = nil
                    if not self:getSpellAlwaysShow(spellID) then
                        self:removeCooldownFrames(playerName, spellID)
                        self:repositionFrames(self:getSpellGroup(spellID))
                    else
                        frame.timerFontString:SetText("R")
                        self:setTimerColor(frame)
                    end
                    table.wipe(self.db.global.CDs[playerName][spellID])
                elseif frame.timerText ~= floor(frame.CDLeft) then
                    frame.timerText = floor(frame.CDLeft)
                    frame.timerFontString:SetText(date("!%M:%S", frame.CDLeft):gsub('^0+:?0?', ''))
                    self:setTimerColor(frame)
                end
            end, tick, frame)
        end
    elseif not self:getSpellAlwaysShow(spellID) then
        self:removeCooldownFrames(playerName, spellID, true)
        self:repositionFrames(self:getSpellGroup(spellID))
        return
    else
        frame.timerFontString:SetText("R")
    end

    self:updateCooldownBarProgress(frame)

    self:sortFrames(self:getSpellGroup(spellID))

    self:setTimerColor(frame)

    frame.initialized = true
end

function HomeCheck:getCooldownFrame(playerName, spellID)
    local group = self:getGroup(self:getSpellGroup(spellID))
    for i = 1, #group.CooldownFrames do
        if group.CooldownFrames[i].playerName == playerName and group.CooldownFrames[i].spellID == spellID then
            return group.CooldownFrames[i]
        end
    end
end

function HomeCheck:createCooldownFrame(playerName, spellID)
    local frame = self:getCooldownFrame(playerName, spellID)

    if frame then
        return frame
    end

    local group = self:getGroup(self:getSpellGroup(spellID))
    frame = CreateFrame("Frame", nil, group)

    frame.playerName = playerName
    frame.spellID = spellID
    frame.CDLeft = 0
    frame.class = select(2, UnitClass(playerName))

    frame.iconFrame = CreateFrame("Frame", nil, frame)
    frame.iconFrame:SetPoint("LEFT")
    local icon = select(3, GetSpellInfo(spellID))
    if icon then
        frame.iconFrame.texture = frame.iconFrame:CreateTexture(nil, "OVERLAY")
        frame.iconFrame.texture:SetTexture(icon)
        frame.iconFrame.texture:SetAllPoints()
        frame.iconFrame.texture:SetPoint("CENTER")
    end

    frame.bar = CreateFrame("Frame", nil, frame)
    frame.bar:SetPoint("LEFT", frame.iconFrame, "RIGHT")
    frame.bar.texture = frame.bar:CreateTexture(nil, "ARTWORK")
    frame.bar.texture:SetAllPoints()
    self:updateRange(frame)

    frame.inactiveBar = CreateFrame("Frame", nil, frame)
    frame.inactiveBar.texture = frame.inactiveBar:CreateTexture(nil, "BACKGROUND")
    frame.inactiveBar.texture:SetAllPoints()
    frame.inactiveBar:SetPoint("BOTTOMRIGHT")

    frame.playerNameFontString = frame.bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.playerNameFontString:SetText(frame.playerName)
    frame.playerNameFontString:SetTextColor(1, 1, 1, 1)

    frame.targetFontString = frame.bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.targetFontString:SetPoint("LEFT", frame.playerNameFontString, "RIGHT", 1, 0)

    frame.timerFontString = frame.bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    self:applyGroupSettings(frame)

    if self.db.global.link then
        frame:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and IsShiftKeyDown() then
                local message = frame.playerName .. " " .. (GetSpellLink(frame.spellID)) .. " " .. (frame.CDLeft == 0 and "READY" or date("!%M:%S", frame.CDLeft))
                ChatThrottleLib:SendChatMessage("NORMAL", "HomeCheck", message, playerInRaid and "RAID" or "PARTY")
            end
        end)
        frame:EnableMouse(true)
    end

    table.insert(group.CooldownFrames, frame)
    return frame
end

function HomeCheck:repositionFrames(groupIndex)
    if not groupIndex then
        for i = 1, #self.groups do
            self:repositionFrames(i)
        end
        return
    end
    for j = 1, #self.groups[groupIndex].CooldownFrames do
        self.groups[groupIndex].CooldownFrames[j]:SetPoint("TOPLEFT", 0, -(self.db.profile[self.db.profile[groupIndex].inherit or groupIndex].iconSize + self.db.profile[self.db.profile[groupIndex].inherit or groupIndex].padding) * (j - 1))
    end
end

function HomeCheck:loadProfile()
    for i = 1, #self.groups do
        self.groups[i]:ClearAllPoints()
        self.groups[i]:SetPoint(self.db.profile[i].pos.point, self.db.profile[i].pos.relativeTo, self.db.profile[i].pos.relativePoint, self.db.profile[i].pos.xOfs, self.db.profile[i].pos.yOfs)
    end
    self:updateRaidCooldowns()
end

function HomeCheck:removeCooldownFrames(playerName, spellID, onlyWhenReady, startGroup, startIndex)
    if spellID then
        startGroup = self:getSpellGroup(spellID)
    end
    for i = startGroup or 1, #self.groups do
        for j = startIndex or 1, #self.groups[i].CooldownFrames do
            if self.groups[i].CooldownFrames[j].playerName == playerName and (not spellID or self.groups[i].CooldownFrames[j].spellID == spellID) and (not onlyWhenReady or self.groups[i].CooldownFrames[j].CDLeft <= 0) then
                self.groups[i].CooldownFrames[j]:Hide()
                if self.groups[i].CooldownFrames[j].CDtimer then
                    self:CancelTimer(self.groups[i].CooldownFrames[j].CDtimer)
                end
                table.remove(self.groups[i].CooldownFrames, j)
                if spellID then
                    break
                end
                return self:removeCooldownFrames(playerName, spellID, onlyWhenReady, i, j)
            end
        end
    end
end

function HomeCheck:updateRaidRoster(instant, startGroup, startIndex)
    if not instant then
        if updateRaidRosterScheduleTimer then
            -- update is scheduled
            return
        end

        if updateRaidRosterTimestamp and time() - updateRaidRosterTimestamp < updateRaidRosterCooldown then
            -- update is on cooldown
            updateRaidRosterScheduleTimer = self:ScheduleTimer(function()
                updateRaidRosterScheduleTimer = nil
                self:updateRaidRoster()
            end, updateRaidRosterCooldown)
            return
        end
    end

    for i = startGroup or 1, #self.groups do
        for j = startIndex or 1, #self.groups[i].CooldownFrames do
            if not UnitInRaid(self.groups[i].CooldownFrames[j].playerName) and not UnitInParty(self.groups[i].CooldownFrames[j].playerName) or not UnitIsConnected(self.groups[i].CooldownFrames[j].playerName) then
                self:removeCooldownFrames(self.groups[i].CooldownFrames[j].playerName)
                return self:updateRaidRoster(true, i, j)
            end
        end
    end
    self:updateRaidCooldowns()
    updateRaidRosterTimestamp = time()
end

function HomeCheck:updateRaidCooldowns()
    if GetNumRaidMembers() > 0 then
        for i = 1, 40 do
            local playerName, _, _, _, _, class, _, online, isDead = GetRaidRosterInfo(i)
            if isDead then
                self.deadUnits[playerName] = true
            end
            if playerName and online then
                self:refreshPlayerCooldowns(playerName, class)
            end
        end
    else
        self:refreshPlayerCooldowns((UnitName("player")))
        for i = 1, GetNumPartyMembers() do
            self:refreshPlayerCooldowns((UnitName("party" .. i)))
        end
    end
    self:repositionFrames()
end

function HomeCheck:refreshPlayerCooldowns(playerName, class)
    if not class then
        class = select(2, UnitClass(playerName))
    end

    for spellID, spellConfig in pairs(self.spells) do
        if not spellConfig.parent then
            if not spellConfig.class or spellConfig.class == class then
                if self.db.profile.spells[spellID] and self:isSpellEnabled(spellID) and self:UnitHasAbility(playerName, spellID) then
                    self:setCooldown(spellID, playerName)
                else
                    self:removeCooldownFrames(playerName, spellID)
                end
            end
        end
    end
end

function HomeCheck:UnitHasAbility(playerName, spellID)
    return not self.spells[spellID].talentTab or not self.spells[spellID].talentIndex or self.LibGroupTalents:UnitHasTalent(playerName, (GetSpellInfo(spellID)))
end

function HomeCheck:saveFramePosition(groupIndex)
    local point, relativeTo, relativePoint, xOfs, yOfs = self.groups[groupIndex].anchor:GetPoint(0)
    self.db.profile[groupIndex].pos = {
        point = point,
        relativeTo = relativeTo and relativeTo:GetName(),
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs
    }
end

function HomeCheck:Readiness(hunterName)
    if ReadinessTimestamp[hunterName] and time() - ReadinessTimestamp[hunterName] < 100 then
        return
    end

    for i = 1, #self.groups do
        for j = 1, #self.groups[i].CooldownFrames do
            if self.groups[i].CooldownFrames[j].playerName == hunterName and self.groups[i].CooldownFrames[j].spellID ~= 34477 then
                self.groups[i].CooldownFrames[j].CDLeft = 0
            end
        end
    end

    ReadinessTimestamp[hunterName] = time()
end

function HomeCheck:GSProc(playerName, target, isRemote)
    local frame = self:getCooldownFrame(playerName, 47788)
    if not frame or frame.CDLeft <= 0 then
        -- cooldown not set or expired
        self:setCooldown(47788, playerName, 110, target, isRemote)
        return
    end

    if frame.CD == 180 then
        -- GS proc already processed
        return
    end

    frame.CD = 180
    self:setCooldown(47788, playerName, frame.CD, target, isRemote)
end

function HomeCheck:sortFrames(groupIndex)
    if not groupIndex then
        for i = 1, #self.groups do
            self:sortFrames(i)
        end
        return
    end

    for j = 1, #self.groups[groupIndex].CooldownFrames - 1 do
        for k = j + 1, #self.groups[groupIndex].CooldownFrames do
            if self:cooldownSorter(self.groups[groupIndex].CooldownFrames[j], self.groups[groupIndex].CooldownFrames[k]) then
                self.groups[groupIndex].CooldownFrames[j], self.groups[groupIndex].CooldownFrames[k] = self.groups[groupIndex].CooldownFrames[k], self.groups[groupIndex].CooldownFrames[j]
            end
        end
    end
    self:repositionFrames(groupIndex)
end

---cooldownSorter
---@param frame1 table cooldown frame to be moved
---@param frame2 table cooldown frame to compare against
---@return boolean true if frame1 should be below frame2
function HomeCheck:cooldownSorter(frame1, frame2)
    local groupIndex = self:getSpellGroup(frame1.spellID)
    if frame1.inRange < frame2.inRange then
        if self.db.profile[self.db.profile[groupIndex].inherit or groupIndex].rangeUngroup then
            return true
        elseif frame1.spellID == frame2.spellID and self.db.profile[self.db.profile[groupIndex].inherit or groupIndex].rangeDimout then
            return true
        end
    elseif frame1.inRange > frame2.inRange then
        if self.db.profile[self.db.profile[groupIndex].inherit or groupIndex].rangeUngroup or frame1.spellID == frame2.spellID then
            return
        end
    end

    if self.db.profile.spells[frame1.spellID].priority < self.db.profile.spells[frame2.spellID].priority then
        return true
    elseif frame1.spellID == frame2.spellID then
        if frame1.CDLeft > frame2.CDLeft then
            return true
        end
    elseif self.db.profile.spells[frame1.spellID].priority == self.db.profile.spells[frame2.spellID].priority and frame1.spellID < frame2.spellID then
        -- attempt to group spells by ID
        return true
    end
end

function HomeCheck:getGroup(i)
    i = i or 1
    if self.groups[i] then
        return self.groups[i]
    end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:ClearAllPoints()

    frame.anchor = CreateFrame("Frame")
    frame.anchor:SetClampedToScreen(true)
    frame.anchor:SetSize(20, 20)
    frame.anchor:SetPoint(self.db.profile[i].pos.point, self.db.profile[i].pos.relativeTo, self.db.profile[i].pos.relativePoint, self.db.profile[i].pos.xOfs, self.db.profile[i].pos.yOfs)
    frame.anchor:SetFrameStrata("HIGH")
    frame.anchor:EnableMouse(true)
    frame.anchor:SetMovable(true)
    frame.anchor:RegisterForDrag("LeftButton")
    frame.anchor:SetScript("OnDragStart", function(s)
        s:StartMoving()
    end)
    frame.anchor:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        self:saveFramePosition(i)
    end)

    frame:SetAllPoints(frame.anchor)

    frame.CooldownFrames = {}

    table.insert(self.groups, frame)
    return frame
end

---@param playerName string
---@param spellID number
function HomeCheck:getCDLeft(playerName, spellID)
    for i = 1, #self.groups[self:getSpellGroup(spellID)].CooldownFrames do
        if playerName == self.groups[self:getSpellGroup(spellID)].CooldownFrames[i].playerName
                and spellID == self.groups[self:getSpellGroup(spellID)].CooldownFrames[i].spellID then
            return self.groups[self:getSpellGroup(spellID)].CooldownFrames[i].CDLeft
        end
    end
    return 0
end

function HomeCheck:getTarget(playerName, spellID)
    for i = 1, #self.groups[self:getSpellGroup(spellID)].CooldownFrames do
        if playerName == self.groups[self:getSpellGroup(spellID)].CooldownFrames[i].playerName
                and spellID == self.groups[self:getSpellGroup(spellID)].CooldownFrames[i].spellID then
            return self.groups[self:getSpellGroup(spellID)].CooldownFrames[i].target
        end
    end
end

function HomeCheck:setTarget(frame, target)
    if not target or target == frame.target or self.spells[frame.spellID].notarget then
        return
    end
    if self.spells[frame.spellID].noself and target == frame.playerName then
        return
    end
    frame.target = target
    self.db.global.CDs[frame.playerName][frame.spellID].target = target
    frame.targetFontString:SetText(target)
    local class = select(2, UnitClass(target))
    if class then
        local targetClassColor = RAID_CLASS_COLORS[class]
        frame.targetFontString:SetTextColor(targetClassColor.r, targetClassColor.g, targetClassColor.b, 1)
    end
    return target
end

function HomeCheck:updateRange(frame)
    if not frame.inRange then
        frame.inRange = self:UnitInRange(frame.playerName) and 1 or 0
        self:setBarColor(frame)
        self:sortFrames()
    elseif frame.inRange == 1 then
        if not self:UnitInRange(frame.playerName) then
            frame.inRange = 0
            if self.db.profile[self.db.profile[self:getSpellGroup(frame.spellID)].inherit or self:getSpellGroup(frame.spellID)].rangeDimout then
                self:setBarColor(frame)
            end
            self:sortFrames()
        end
    elseif self:UnitInRange(frame.playerName) then
        frame.inRange = 1
        if self.db.profile[self.db.profile[self:getSpellGroup(frame.spellID)].inherit or self:getSpellGroup(frame.spellID)].rangeDimout then
            self:setBarColor(frame)
        end
        self:sortFrames()
    end
end

---@param frame table
function HomeCheck:setBarColor(frame)
    if frame.inRange == 1 or not self.db.profile[self.db.profile[self:getSpellGroup(frame.spellID)].inherit or self:getSpellGroup(frame.spellID)].rangeDimout then
        local playerClassColor = RAID_CLASS_COLORS[frame.class]
        frame.bar.texture:SetVertexColor(playerClassColor.r, playerClassColor.g, playerClassColor.b, self.db.profile[self:getSpellGroup(frame.spellID)].opacity)
    else
        frame.bar.texture:SetVertexColor(0.5, 0.5, 0.5, self.db.profile[self:getSpellGroup(frame.spellID)].opacity)
    end
end

function HomeCheck:setTimerColor(frame)
    if self.deadUnits[frame.playerName] then
        frame.timerFontString:SetTextColor(1, 0, 0, 1)
    elseif frame.CDLeft <= 0 then
        if self.db.profile.spells[frame.spellID].alwaysShow then
            frame.timerFontString:SetTextColor(0, 1, 0, 1)
        end
    else
        frame.timerFontString:SetTextColor(0.9, 0.7, 0, 1)
    end
end

function HomeCheck:getSpellCooldown(frame)
    local CDmodifier = 0
    if frame.spellID == 498 or frame.spellID == 642 then
        -- Divine Shield and Divine Protection
        CDmodifier = -30 * (select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 2, 14)) or 0)
    elseif frame.spellID == 10278 then
        -- HoP
        CDmodifier = -60 * (select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 2, 4)) or 0)
    elseif frame.spellID == 48788 then
        -- Lay on Hands
        CDmodifier = -120 * (select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 1, 8)) or 0)
        if self.LibGroupTalents:UnitHasGlyph(frame.playerName, 57955) then
            CDmodifier = CDmodifier - 300
        end
    elseif frame.spellID == 20608 then
        -- Reincarnation
        local talentPoints = select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 3, 3))
        if talentPoints == 1 then
            CDmodifier = -420
        elseif talentPoints == 2 then
            CDmodifier = -900
        end
    elseif frame.spellID == 871 then
        -- Shield Wall
        -- TODO verify spell and glyph ID
        CDmodifier = -30 * (select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 3, 13)) or 0)
        if self.LibGroupTalents:UnitHasGlyph(frame.playerName, 63329) then
            CDmodifier = CDmodifier - 120
        end
    elseif frame.spellID == 12975 then
        -- Last Stand
        -- TODO verify spell and glyph IDs
        if self.LibGroupTalents:UnitHasGlyph(frame.playerName, 58376) then
            CDmodifier = CDmodifier - 60
        end
    elseif frame.spellID == 48447 then
        -- Tranquility
        local talentPoints = select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 3, 14))
        if talentPoints == 1 then
            CDmodifier = -(self.spells[frame.spellID] and self.spells[frame.spellID].cd or 0) * 0.3
        elseif talentPoints == 2 then
            CDmodifier = -(self.spells[frame.spellID] and self.spells[frame.spellID].cd or 0) * 0.5
        end
    elseif frame.spellID == 47585 then
        -- Dispersion
        if self.LibGroupTalents:UnitHasGlyph(frame.playerName, 63229) then
            CDmodifier = CDmodifier - 45
        end
    elseif frame.spellID == 45438 then
        -- Ice Block
        local talentPoints = select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 3, 3))
        if talentPoints == 1 then
            CDmodifier = -(self.spells[frame.spellID] and self.spells[frame.spellID].cd or 0) * 0.07
        elseif talentPoints == 2 then
            CDmodifier = -(self.spells[frame.spellID] and self.spells[frame.spellID].cd or 0) * 0.14
        elseif talentPoints == 3 then
            CDmodifier = -(self.spells[frame.spellID] and self.spells[frame.spellID].cd or 0) * 0.2
        end
    elseif frame.spellID == 66 or frame.spellID == 12051 then
        -- Invisibility or Evocation
        CDmodifier = -(self.spells[frame.spellID] and self.spells[frame.spellID].cd or 0) * 0.15 * (select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 1, 24)) or 0)
    elseif frame.spellID == 12292 then
        -- Death Wish
        CDmodifier = -(self.spells[frame.spellID] and self.spells[frame.spellID].cd or 0) * 0.11 * (select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 2, 18)) or 0)
    elseif frame.spellID == 10060 or frame.spellID == 33206 then
        -- Power Infusion and Pain Suppression
        CDmodifier = -(self.spells[frame.spellID] and self.spells[frame.spellID].cd or 0) * 0.1 * (select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 1, 23)) or 0)
    elseif frame.spellID == 47788 then
        -- Guardian spirit
        if frame.CDLeft > self.spells[frame.spellID].cd then
            CDmodifier = 110
        end
    elseif frame.spellID == 42650 then
        -- Army of the Dead
        CDmodifier = -120 * (select(5, self.LibGroupTalents:GetTalentInfo(frame.playerName, 3, 13)) or 0)
    end

    return self.spells[frame.spellID].cd + CDmodifier
end

function HomeCheck:cacheLocalizedSpellNames()
    for spellID, _ in pairs(self.spells) do
        local spellName = GetSpellInfo(spellID)
        self.localizedSpellNames[spellName] = spellID
    end
end

function HomeCheck:getSpellGroup(spellID)
    return self.spells[spellID].parent and self.db.profile.spells[self.spells[spellID].parent].group or self.db.profile.spells[spellID].group
end

function HomeCheck:applyGroupSettings(frame, groupIndex)
    groupIndex = groupIndex or self:getSpellGroup(frame.spellID)

    frame:SetParent(self:getGroup(groupIndex))

    groupIndex = self.db.profile[groupIndex].inherit or groupIndex
    frame:SetSize(self.db.profile[groupIndex].frameWidth, self.db.profile[groupIndex].iconSize)
    frame.iconFrame:SetSize(self.db.profile[groupIndex].iconSize, self.db.profile[groupIndex].iconSize)
    frame.playerNameFontString:SetFont(self.LibSharedMedia:Fetch("font", self.db.profile[groupIndex].fontPlayer), self.db.profile[groupIndex].fontSize)
    frame.targetFontString:SetFont(self.LibSharedMedia:Fetch("font", self.db.profile[groupIndex].fontTarget), self.db.profile[groupIndex].fontSizeTarget)
    frame.targetFontString:SetJustifyH(self.db.profile[groupIndex].targetJustify == "l" and "LEFT" or "RIGHT")
    frame.bar:SetSize(self.db.profile[groupIndex].frameWidth - self.db.profile[groupIndex].iconSize, self.db.profile[groupIndex].iconSize)
    frame.bar.texture:SetTexture(self.LibSharedMedia:Fetch("statusbar", self.db.profile[groupIndex].statusbar))
    frame.inactiveBar.texture:SetTexture(self.LibSharedMedia:Fetch("statusbar", self.db.profile[groupIndex].statusbar))
    frame.inactiveBar.texture:SetVertexColor(unpack(self.db.profile[groupIndex].background))
    frame.timerFontString:SetFont(self.LibSharedMedia:Fetch("font", self.db.profile[groupIndex].fontTimer), self.db.profile[groupIndex].fontSizeTimer)

    self:setTimerPosition(frame)
end

function HomeCheck:setSpellGroupIndex(spellID, groupIndex, startIndex)
    if self.db.profile.spells[spellID].group == groupIndex then
        return
    end
    for i = startIndex or 1, #self.groups[self.db.profile.spells[spellID].group].CooldownFrames do
        if spellID == self.groups[self.db.profile.spells[spellID].group].CooldownFrames[i].spellID then
            local frame = table.remove(self.groups[self.db.profile.spells[spellID].group].CooldownFrames, i)
            self:applyGroupSettings(frame, groupIndex)
            table.insert(self.groups[groupIndex].CooldownFrames, frame)
            return self:setSpellGroupIndex(spellID, groupIndex, i)
        end
    end
    self:sortFrames(self.db.profile.spells[spellID].group)
    self:sortFrames(groupIndex)
    self.db.profile.spells[spellID].group = groupIndex
end

function HomeCheck:UnitInRange(unit)
    return select(2, self.LibRangeCheck:GetRange(unit))
end

function HomeCheck:updateCooldownBarProgress(frame)
    local pct = min(frame.CDLeft / frame.CD, 1)
    if self.db.profile[self.db.profile[self:getSpellGroup(frame.spellID)].inherit or self:getSpellGroup(frame.spellID)].invertColors then
        if pct ~= 0 then
            if not frame.bar.texture:IsShown() then
                frame.bar.texture:Show()
                frame.inactiveBar:SetPoint("TOPLEFT", frame.bar, "TOPRIGHT")
            end
            frame.bar:SetWidth((self.db.profile[self.db.profile[self:getSpellGroup(frame.spellID)].inherit or self:getSpellGroup(frame.spellID)].frameWidth - self.db.profile[self.db.profile[self:getSpellGroup(frame.spellID)].inherit or self:getSpellGroup(frame.spellID)].iconSize) * pct)
        elseif frame.bar.texture:IsShown() then
            frame.bar.texture:Hide()
            frame.inactiveBar:SetPoint("TOPLEFT", frame.iconFrame, "TOPRIGHT")
        end
    else
        if pct ~= 1 then
            if not frame.bar.texture:IsShown() then
                frame.bar.texture:Show()
                frame.inactiveBar:SetPoint("TOPLEFT", frame.bar, "TOPRIGHT")
            end
            frame.bar:SetWidth((self.db.profile[self.db.profile[self:getSpellGroup(frame.spellID)].inherit or self:getSpellGroup(frame.spellID)].frameWidth - self.db.profile[self.db.profile[self:getSpellGroup(frame.spellID)].inherit or self:getSpellGroup(frame.spellID)].iconSize) * (1 - pct))
        elseif frame.bar.texture:IsShown() then
            frame.bar.texture:Hide()
            frame.inactiveBar:SetPoint("TOPLEFT", frame.iconFrame, "TOPRIGHT")
        end
    end
end

function HomeCheck:setTimerPosition(frame)
    frame.timerFontString:ClearAllPoints()
    if self.db.profile[self.db.profile[self:getSpellGroup(frame.spellID)].inherit or self:getSpellGroup(frame.spellID)].timerPosition == "l" then
        frame.timerFontString:SetPoint("LEFT", frame.iconFrame, "RIGHT", 1, 0)
        frame.playerNameFontString:SetPoint("LEFT", frame.timerFontString, "RIGHT", 2, 0)
        frame.targetFontString:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    else
        frame.timerFontString:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
        frame.playerNameFontString:SetPoint("LEFT", frame.iconFrame, "RIGHT", 1, 0)
        frame.targetFontString:SetPoint("RIGHT", frame.timerFontString, "LEFT", -1, 0)
    end
end

function HomeCheck:getSpellAlwaysShow(spellID)
    return self.spells[spellID]
            and self.spells[spellID].parent
            and self.db.profile.spells[self.spells[spellID].parent].alwaysShow
            or self.db.profile.spells[spellID].alwaysShow
end

function HomeCheck:isSpellEnabled(spellID)
    return self.spells[spellID].parent and self.db.profile.spells[self.spells[spellID].parent].enable or self.db.profile.spells[spellID].enable
end

function HomeCheck:Rebirth(event, playerName, target)
    if event == "UNIT_SPELLCAST_SENT" then
        self.RebirthTargets[playerName] = target
    elseif event == "UNIT_SPELLCAST_FAILED" then
        self.RebirthTargets[playerName] = nil
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        self:setCooldown(48477, playerName, true, self.RebirthTargets[playerName])
        self.RebirthTargets[playerName] = nil
    end
end