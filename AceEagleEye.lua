-- Provides voice callouts for incoming missiles, to confirm kills,
-- and can be used in conjunction with the ammo script to give voice
-- callouts for ammo status.
AceEagleEye = {}

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

local MISSILE_INCOMING = {
  "Sounds/MissileIncoming/1.wav",
  "Sounds/MissileIncoming/2.wav",
  "Sounds/MissileIncoming/3.wav",
}

local MISSILE_HIT = {
  "Sounds/MissileHit/1.wav",
  "Sounds/MissileHit/2.wav",
  "Sounds/MissileHit/3.wav",
}

local MISSILE_LOW = {
  "Sounds/MissileAmmo/Low1.wav",
  "Sounds/MissileAmmo/Low2.wav",
}

local MISSILE_EMPTY = {
  "Sounds/MissileAmmo/Empty1.wav",
  "Sounds/MissileAmmo/Empty2.wav",
}

local SP_WEAPON_LOW = {
  "Sounds/SPWeaponAmmo/Low1.wav",
  "Sounds/SPWeaponAmmo/Low2.wav",
}

local SP_WEAPON_EMPTY = {
  "Sounds/SPWeaponAmmo/Empty1.wav",
  "Sounds/SPWeaponAmmo/Empty2.wav",
  "Sounds/SPWeaponAmmo/Empty3.wav",
}

local FRIENDLY_HIT = {
  "Sounds/FriendlyHit/1.wav",
  "Sounds/FriendlyHit/2.wav",
}

local KILL_PLANE = {
  "Sounds/PlaneKill/1.wav",
  "Sounds/PlaneKill/2.wav",
  "Sounds/PlaneKill/3.wav",
  "Sounds/PlaneKill/4.wav",
  "Sounds/PlaneKill/5.wav",
  "Sounds/PlaneKill/6.wav",
  "Sounds/PlaneKill/7.wav",
  "Sounds/PlaneKill/8.wav",
  "Sounds/PlaneKill/9.wav",
  "Sounds/PlaneKill/10.wav",
}

local KILL_AAA = {
  "Sounds/AAAKill/1.wav",
  "Sounds/AAAKill/2.wav",
  "Sounds/AAAKill/3.wav",
  "Sounds/AAAKill/4.wav",
}

local KILL_TARGET = {
  "Sounds/TargetKill/1.wav",
  "Sounds/TargetKill/2.wav",
}

local KILL_GROUND_TARGET = {
  "Sounds/GroundTargetKill/1.wav",
  "Sounds/GroundTargetKill/2.wav",
}

local KILL_TANK = {
  "Sounds/TankKill/1.wav",
  "Sounds/TankKill/2.wav",
  "Sounds/TankKill/3.wav",
  "Sounds/TankKill/4.wav",
}

local KILL_VEHICLE = {
  "Sounds/VehicleKill/1.wav",
  "Sounds/VehicleKill/2.wav",
}

local KILL_SAM = {
  "Sounds/SAMKill/1.wav",
  "Sounds/SAMKill/2.wav",
}

--------------------------
-- Core functions
--------------------------

local function getRandomSoundFromArray(soundArray)
  return soundArray[math.random(#soundArray)]
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
  if firedByUnit:getCoalition() == hitUnit:getCoalition() then
    trigger.action.outSoundForGroup(firedByGroupID, getRandomSoundFromArray(FRIENDLY_HIT))
    return
  end

  -- Normal hit against an enemy aircraft.
  if Ace.isAirToAirMissile(weapon) and firedByUnit:getPlayerName() and hitUnit then
    trigger.action.outSoundForGroup(firedByGroupID, getRandomSoundFromArray(MISSILE_HIT))
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
    trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(KILL_PLANE))
  else -- Ground unit of some kind.
    local isTank = unitKilled:hasAttribute("Tanks")
    local isVehicle = unitKilled:hasAttribute("Vehicles")
    local isStructure = unitKilled:hasAttribute("Fortifications")
    local isAAA = unitKilled:hasAttribute("AAA")
    local isSAM = unitKilled:hasAttribute("SAM")

    killMessage = "Destroyed " .. unitKilled:getTypeName() .. " with " .. weaponName .. "!"

    if isSAM then
      trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(KILL_SAM))
    elseif isAAA then
      trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(KILL_AAA))
    elseif isTank then
      trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(KILL_TANK))
    elseif isVehicle then
      trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(KILL_VEHICLE))
    elseif isStructure then
      trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(KILL_GROUND_TARGET))
    else
      trigger.action.outSoundForGroup(playerGroupID, getRandomSoundFromArray(KILL_TARGET))
    end
  end

  trigger.action.outTextForGroup(playerGroupID, killMessage, 15, false)
end
