-- Provides voice callouts for incoming missiles, to confirm kills,
-- and can be used in conjunction with the ammo script to give voice
-- callouts for ammo status.
AceEagleEye = {}

AceEagleEye.ReportKillDelay = 1.5
AceEagleEye.ReportHitDelay = 1.5

--------------------------
-- Debug
--------------------------

local SHOW_DEBUG = false
local SHOW_ERROR = true

local function printDebug(source, message)
  if SHOW_DEBUG then
    local output = "AceEagleEye (" .. source .. "): " .. message
    trigger.action.outText(output, 5, false)
  end
end

local function printError(source, message)
  if SHOW_ERROR then
    local output = "AceEagleEye ERROR (" .. source .. "): " .. message
    trigger.action.outText(output, 5, false)
  end
end

--------------------------
-- Sound clip paths
--------------------------

local MINUTES_REMAINING = {
  [15] = "EagleEye/MinutesRemaining/15.wav",
  [10] = "EagleEye/MinutesRemaining/10.wav",
  [5] = "EagleEye/MinutesRemaining/5.wav",
  [4] = "EagleEye/MinutesRemaining/4.wav",
  [3] = "EagleEye/MinutesRemaining/3.wav",
  [2] = "EagleEye/MinutesRemaining/2.wav",
  [1] = "EagleEye/MinutesRemaining/1.wav",
}

local MISSILE_INCOMING = {
  "EagleEye/MissileIncoming/1.wav",
  "EagleEye/MissileIncoming/2.wav",
  "EagleEye/MissileIncoming/3.wav",
}

local MISSILE_HIT = {
  "EagleEye/MissileHit/1.wav",
  "EagleEye/MissileHit/2.wav",
  "EagleEye/MissileHit/3.wav",
}

local MISSILE_LOW = {
  "EagleEye/MissileAmmo/Low1.wav",
  "EagleEye/MissileAmmo/Low2.wav",
}

local MISSILE_EMPTY = {
  "EagleEye/MissileAmmo/Empty1.wav",
  "EagleEye/MissileAmmo/Empty2.wav",
}

local SP_WEAPON_LOW = {
  "EagleEye/SPWeaponAmmo/Low1.wav",
  "EagleEye/SPWeaponAmmo/Low2.wav",
}

local SP_WEAPON_EMPTY = {
  "EagleEye/SPWeaponAmmo/Empty1.wav",
  "EagleEye/SPWeaponAmmo/Empty2.wav",
  "EagleEye/SPWeaponAmmo/Empty3.wav",
}

local FRIENDLY_HIT = {
  "EagleEye/FriendlyHit/1.wav",
  "EagleEye/FriendlyHit/2.wav",
}

local KILL_PLANE = {
  "EagleEye/PlaneKill/1.wav",
  "EagleEye/PlaneKill/2.wav",
  "EagleEye/PlaneKill/3.wav",
  "EagleEye/PlaneKill/4.wav",
  "EagleEye/PlaneKill/5.wav",
  "EagleEye/PlaneKill/6.wav",
  "EagleEye/PlaneKill/7.wav",
  "EagleEye/PlaneKill/8.wav",
  "EagleEye/PlaneKill/9.wav",
  "EagleEye/PlaneKill/10.wav",
}

local KILL_AAA = {
  "EagleEye/AAAKill/1.wav",
  "EagleEye/AAAKill/2.wav",
  "EagleEye/AAAKill/3.wav",
  "EagleEye/AAAKill/4.wav",
}

local KILL_TARGET = {
  "EagleEye/TargetKill/1.wav",
  "EagleEye/TargetKill/2.wav",
}

local KILL_GROUND_TARGET = {
  "EagleEye/GroundTargetKill/1.wav",
  "EagleEye/GroundTargetKill/2.wav",
}

local KILL_TANK = {
  "EagleEye/TankKill/1.wav",
  "EagleEye/TankKill/2.wav",
  "EagleEye/TankKill/3.wav",
  "EagleEye/TankKill/4.wav",
}

local KILL_VEHICLE = {
  "EagleEye/VehicleKill/1.wav",
  "EagleEye/VehicleKill/2.wav",
}

local KILL_SAM = {
  "EagleEye/SAMKill/1.wav",
  "EagleEye/SAMKill/2.wav",
}

--------------------------
-- Core functions
--------------------------

local function getRandomSoundFromArray(soundArray)
  return soundArray[math.random(#soundArray)]
end

function AceEagleEye.playSoundForGroup(args, time)
    trigger.action.outSoundForGroup(args.groupID, args.path)
    return nil
end

function AceEagleEye.playSoundForGroupDelayed(playerGroupID, soundPath, delay)
  timer.scheduleFunction(
    AceEagleEye.playSoundForGroup,
    { groupID = playerGroupID, path = soundPath },
    timer.getTime() + delay)
end

function AceEagleEye.reportMissileLow(playerGroupID)
  trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(MISSILE_LOW))
end

function AceEagleEye.reportMissileEmpty(playerGroupID)
  trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(MISSILE_EMPTY))
end

function AceEagleEye.reportSPWeaponLow(playerGroupID)
  trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(SP_WEAPON_LOW))
end

function AceEagleEye.reportSPWeaponEmpty(playerGroupID)
  trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(SP_WEAPON_EMPTY))
end

---@param minutes integer
function AceEagleEye.reportMinutesRemainingForAll(minutes)
  if MINUTES_REMAINING[minutes] then
    trigger.action.outSound(MINUTES_REMAINING[minutes])
  end
end

---@param minutes integer
function AceEagleEye.reportMinutesRemainingForGroup(playerGroupID, minutes)
  if MINUTES_REMAINING[minutes] then
    trigger.action.outSoundForGroup(playerGroupID, MINUTES_REMAINING[minutes])
  end
end

function AceEagleEye.onShot(time, firedByUnit, weapon)
  -- Missile incoming warning on the missile's target.
  if Ace.isAirToAirMissile(weapon) or Ace.isSurfaceToAirMissile(weapon) then
    local targetObject = weapon:getTarget()
    if targetObject then
     local _, targetAircraftUnit = Ace.isObjectAnAircraft(targetObject)
      if targetAircraftUnit and targetAircraftUnit:getPlayerName() then
        local groupID = targetAircraftUnit:getGroup():getID()
        trigger.action.outSoundForGroup(groupID, getRandomSoundFromArray(MISSILE_INCOMING))
        local weaponName = Ace.trimTypeName(weapon:getTypeName())
        trigger.action.outTextForGroup(groupID, weaponName .. " incoming!", 5, false)
      end
    end
  end
end

function AceEagleEye.onHit(time, firedByUnit, weapon, hitObject)
  -- Only players care about messages.
  local playerName = firedByUnit:getPlayerName()
  if not playerName then return end

  -- Has to be a valid unit.
  local hitUnit = Ace.objectToUnit(hitObject)
  if not hitUnit or not hitObject:isExist() then return end

  -- Report friendly fire!
  local firedByGroupID = firedByUnit:getGroup():getID()
  if AceEagleEye.ReportFriendlyFire and firedByUnit:getCoalition() == hitUnit:getCoalition() then
    AceEagleEye.playSoundForGroupDelayed(firedByGroupID, getRandomSoundFromArray(FRIENDLY_HIT), AceEagleEye.ReportHitDelay)
    return
  end

  -- Normal hit against an enemy aircraft.
  if AceEagleEye.ReportHits and Ace.isAirToAirMissile(weapon) and firedByUnit:getPlayerName() and hitUnit then
    AceEagleEye.playSoundForGroupDelayed(firedByGroupID, getRandomSoundFromArray(MISSILE_HIT), AceEagleEye.ReportHitDelay)
  end
end

function AceEagleEye.onKill(time, killerUnit, weapon, unitKilled, weaponName)

  -- Don't try to interact with dead units.
  if not killerUnit or not killerUnit:isExist() then return end

  -- Messages are only for player aircraft.
  local playerName = killerUnit:getPlayerName()
  if playerName == nil then return end

  -- Don't say anything if a friendly was killed, just let the friendly hit mesag
  if unitKilled:getCoalition() == killerUnit:getCoalition() then return end

  printDebug("onKill", playerName .. " killed unit with unit category " .. tostring(unitKilled:getDesc().category))

  local playerGroupID = killerUnit:getGroup():getID()
  local killMessage = ""

  local isAircraft = Ace.isUnitAnAircraft(unitKilled, true)
  if isAircraft then
    if unitKilled:getPlayerName() then
      killMessage = "Shot down " .. unitKilled:getPlayerName() .. " (" .. unitKilled:getTypeName() .. ") with " .. weaponName .. "!"
    else
      killMessage = "Shot down " .. unitKilled:getTypeName() .. " with " .. weaponName .. "!"
    end
    AceEagleEye.playSoundForGroupDelayed(playerGroupID, getRandomSoundFromArray(KILL_PLANE), AceEagleEye.ReportKillDelay)
  else -- Ground unit of some kind.
    local isTank = unitKilled:hasAttribute("Tanks")
    local isVehicle = unitKilled:hasAttribute("Vehicles")
    local isStructure = unitKilled:hasAttribute("Fortifications")
    local isAAA = unitKilled:hasAttribute("AAA")
    local isSAM = unitKilled:hasAttribute("SAM")

    killMessage = "Destroyed " .. unitKilled:getTypeName() .. " with " .. weaponName .. "!"

    if isSAM then
      AceEagleEye.playSoundForGroupDelayed(playerGroupID, getRandomSoundFromArray(KILL_SAM), AceEagleEye.ReportKillDelay)
    elseif isAAA then
      AceEagleEye.playSoundForGroupDelayed(playerGroupID, getRandomSoundFromArray(KILL_AAA), AceEagleEye.ReportKillDelay)
    elseif isTank then
      AceEagleEye.playSoundForGroupDelayed(playerGroupID, getRandomSoundFromArray(KILL_TANK), AceEagleEye.ReportKillDelay)
    elseif isVehicle then
      AceEagleEye.playSoundForGroupDelayed(playerGroupID, getRandomSoundFromArray(KILL_VEHICLE), AceEagleEye.ReportKillDelay)
    elseif isStructure then
      AceEagleEye.playSoundForGroupDelayed(playerGroupID, getRandomSoundFromArray(KILL_GROUND_TARGET), AceEagleEye.ReportKillDelay)
    else
      AceEagleEye.playSoundForGroupDelayed(playerGroupID, getRandomSoundFromArray(KILL_TARGET), AceEagleEye.ReportKillDelay)
    end
  end

  trigger.action.outTextForGroup(playerGroupID, killMessage, 15, false)
end
