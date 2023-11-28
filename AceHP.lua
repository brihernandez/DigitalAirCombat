-- Uses DCS' immortal/invulnerability setting to create a hitpoint system
-- DCS. When airborne, aicraft become invincible and until their HP has been
-- depleted, cannot be damaged through normal means. Missile impacts and gun
-- hits deplete a configurable amount HP.
-- When on the ground, aircraft become vulnerable and the HP system is
-- totally bypassed to allow for both destruction from crashing into the
-- ground, and to allow for aircraft to be destroyed while on the airfield.
-- On takeoff/landing from a friendly airfield, HP is automatically restored.
AceHP = {}

--------------------------
-- Options
--------------------------

-- If there is no data for an aircraft, this is the HP used.
AceHP.DEFAULT_HP = 100
-- Any air to air missile fired by an aircraft.
AceHP.DAMAGE_MISSILE_A2A = 50
-- Any missile fired from a SAM.
AceHP.DAMAGE_MISSILE_SAM = 50
-- Any bomb, rocket, or AGM.
AceHP.DAMAGE_MUNITION_A2G = 1000
-- HP damage applied by bullets depends on caliber. A value of 0.5 means
-- a 20mm shell will do 10 damage.
AceHP.DAMAGE_CALIBER_MULTIPLIER = 1.0
-- Used to adjust the HP damage caused by gunfire from ground units.
AceHP.AAA_DAMAGE_MULTIPLIER = 0.5

-- Sometimes when a plane runs out of HP, the thing that killed it won't
-- apply the damage because it doesn't become vulnerable "fast enough".
-- Enabling this causes an explosion at a random point near the plane
-- to make sure it goes down when the HP reaces zero.
-- This only affects missiles.
AceHP.DESTROY_ON_HP_ZERO = true
-- Strength of the destroy on HP zero explosion. High values can totally
-- obliterate the plane.
AceHP.DESTROY_EXPLOSION_POWER = 10.0

-- Can be used to set players apart from AI.
AceHP.PLAYER_HP_MULTIPLIER = 2.0

--------------------------
-- Debug
--------------------------

local SHOW_DEBUG = true
local SHOW_ERROR = true

local function printDebug(source, message)
  if SHOW_DEBUG then
    local output = "AceHP (" .. source .. "): " .. message
    env.info(output, false)
    trigger.action.outText(output, 5, false)
  end
end

local function printError(source, message)
  if SHOW_ERROR then
    local output = "AceHP ERROR (" .. source .. "): " .. message
    env.error(output, false)
    trigger.action.outText(output, 5, false)
  end
end

--------------------------
-- HP Data Table
--------------------------

local HP_DATA = {
  -- Attacker
  ["A-10C"] = 200,
  ["A-10C_2"] = 200,
  ["AJS37"] = 125,
  ["AV8BNA"] = 125,

  -- Fighter
  ["F-14A-135-GR"] = 100,
  ["F-14B"] = 100,
  ["F-15ESE"] = 125,
  ["F-16C_50"] = 100,
  ["FA-18C_hornet"] = 100,
  ["MiG-19P"] = 100,
  ["MiG-21Bis"] = 100,

  -- FC3
  ["A-10A"] = 200,
  ["F-15C"] = 100,
  ["MiG-29A"] = 100,
  ["MiG-29G"] = 100,
  ["MiG-29S"] = 100,
  ["Su-25"] = 200,
  ["Su-25T"] = 200,
  ["Su-27"] = 100,
  ["Su-33"] = 100,
}

--------------------------
-- Utilities
--------------------------

-- Returns random {x, y, z} with each component [-1, 1]
-- This is not normalized in any way.
local function vec3Random(multiplier)
  return {
    x = (math.random() * 2.0 - 1.0) * multiplier,
    y = (math.random() * 2.0 - 1.0) * multiplier,
    z = (math.random() * 2.0 - 1.0) * multiplier,
  }
end

local function vec3Add(a, b)
  return {
    x = a.x + b.x,
    y = a.y + b.y,
    z = a.z + b.z,
  }
end

local function box3GetMaxSize(box)
  return math.max(
    math.abs(box.max.x),
    math.abs(box.max.y),
    math.abs(box.max.z))
end

-- Relevant only for the HP system.
local function getWeaponHPDamage(weapon, firedFromUnit)
  if Ace.isAirToAirMissile(weapon) then
    return AceHP.DAMAGE_MISSILE_A2A
  elseif Ace.isSurfaceToAirMissile(weapon) then
    return AceHP.DAMAGE_MISSILE_SAM
  elseif Ace.isAirToGroundMunition(weapon) then
    return AceHP.DAMAGE_MUNITION_A2G
  elseif Ace.isGun(weapon) then
    local damage = Ace.getCaliber(weapon) * AceHP.DAMAGE_CALIBER_MULTIPLIER
    if Ace.isUnitASurfaceObject(firedFromUnit) then
      damage = damage * AceHP.AAA_DAMAGE_MULTIPLIER
    end
    return damage
  else
    printError("getWeaponHPDamage", weapon:getTypeName() .. ": Unhandled HP damage!")
    return 0
  end
end

--------------------------
-- HP Data Functions
--------------------------

function HP_DATA:getAircraftHPByTypeName(typeName)
  if self[typeName] then
    return self[typeName]
  else
    printDebug("getAircraftHP", "Falling back on default HP for " .. typeName .. ".")
    return AceHP.DEFAULT_HP
  end
end

--------------------------
-- AceHP Functions
--------------------------

function AceHP.applyDamageToAircraft(aircraft, damage, isFromGun)
  if aircraft and aircraft.hp > 0 and aircraft.isAirborne then
    aircraft.hp = math.max(aircraft.hp - damage, 0)

    printDebug("applyDamageToAircraft", "Applying " .. tostring(damage) .. " to " .. aircraft.fullName .. ".")
    trigger.action.outTextForGroup(
      aircraft.groupID,
      "Took damage!\nHP: " .. aircraft.hp,
      5, false)

    if aircraft.hp <= 0 then
      AceHP.updateImmortalityOnAircraft(aircraft)
      if AceHP.DESTROY_ON_HP_ZERO and not isFromGun then
        local maxExtent = box3GetMaxSize(aircraft.unit:getDesc().box)
        local explodePoint = aircraft.unit:getPoint()
        explodePoint = vec3Add(explodePoint, vec3Random(maxExtent * 0.5))
        printDebug("applyDamageToAircraft", "Plane at: \n" .. Ace.printTable(aircraft.unit:getPoint()) .. "\nKill explosion at: \n" .. Ace.printTable(explodePoint))
        trigger.action.explosion(explodePoint, AceHP.DESTROY_EXPLOSION_POWER)
      end
    end
  end
end

function AceHP.onHit(time, firedByUnit, weapon, hitObject)
  printDebug("onHit", string.format("fired by: %s, weapon: %s, hitObject: %s", tostring(firedByUnit:getTypeName()), tostring(weapon:getTypeName()), hitObject:getTypeName()))
  local _, hitAircraftUnit = Ace.isObjectAnAircraft(hitObject)
  if hitAircraftUnit then
    local aircraft = Ace.TrackedAircraftByID:getAircraftByUnit(hitAircraftUnit)
    if aircraft and aircraft.hp > 0 then
      printDebug("onHit", aircraft.fullName .. " is valid.")
      local damage = math.ceil(getWeaponHPDamage(weapon, firedByUnit))
      printDebug("onHit", "Damage is " .. tostring(damage))
      AceHP.applyDamageToAircraft(aircraft, damage, Ace.isGun(weapon))

      -- Notify the person who shot that they hit the target.
      -- Hit markers...
      local aggressor = Ace.TrackedAircraftByID:getAircraftByUnit(firedByUnit)
      if aggressor then
        trigger.action.outTextForGroup(
          aggressor.groupID,
          "Hit!\n" .. aircraft.typeName .. " HP Remaining: " .. aircraft.hp,
          5, false)
      end
    end
  else
      printDebug("onHit", "Hit object is not aircraft.")
  end
end

local IMMORTAL_ENABLE = {
  id = 'SetImmortal',
  params = {
    value = true
  }
}

local IMMORTAL_DISABLE = {
  id = 'SetImmortal',
  params = {
    value = false
  }
}

function AceHP.updateImmortalityOnAircraft(aircraft)
  printDebug("updateImmortalityOnAircraft", aircraft.fullName .. " beginning immortal update!")
  local isImmortal = aircraft.hp > 0 and aircraft.isAirborne
  if isImmortal then
    aircraft.controller:setCommand(IMMORTAL_ENABLE)
    printDebug("updateImmortalityOnAircraft", aircraft.fullName .. " is immortal!\nHP: " .. tostring(aircraft.hp) .. "\nIsAirborne: " .. tostring(aircraft.isAirborne))
  else
    aircraft.controller:setCommand(IMMORTAL_DISABLE)
    printDebug("updateImmortalityOnAircraft", aircraft.fullName .. " is destructible!\nHP: " .. tostring(aircraft.hp) .. "\nIsAirborne: " .. tostring(aircraft.isAirborne))
  end
end

function AceHP.onTrackingAircraftStarted(aircraft)
  aircraft.hp = HP_DATA:getAircraftHPByTypeName(aircraft.typeName)
  if aircraft.isPlayer then
    printDebug("onNewTrackedAircraft", aircraft.fullName .. " is player with HP multiplier " .. tostring(AceHP.PLAYER_HP_MULTIPLIER) .. ".")
    aircraft.hp = aircraft.hp * AceHP.PLAYER_HP_MULTIPLIER
  end
  AceHP.updateImmortalityOnAircraft(aircraft)

  trigger.action.outTextForGroup(
    aircraft.groupID,
    aircraft.fullName .. "\nHP: " .. aircraft.hp,
    4, false)
end

function AceHP.onTrackingAircraftStopped(aircraft)
  aircraft.hp = 0
  AceHP.updateImmortalityOnAircraft(aircraft)
end

function AceHP.repairAircraft(aircraft)
  if not aircraft then return end
  local hp = HP_DATA:getAircraftHPByTypeName(aircraft.typeName)
  if aircraft.isPlayer then hp = hp * AceHP.PLAYER_HP_MULTIPLIER end
  aircraft.hp = hp
end

function AceHP.onAircraftTakeoff(aircraft)
  if aircraft.isLandedAtFriendlyAirfield then AceHP.repairAircraft(aircraft) end
  AceHP.updateImmortalityOnAircraft(aircraft)
end

function AceHP.onAircraftLanded(aircraft)
  if aircraft.isLandedAtFriendlyAirfield then AceHP.repairAircraft(aircraft) end
  AceHP.updateImmortalityOnAircraft(aircraft)
end
