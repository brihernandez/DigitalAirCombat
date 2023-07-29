AceAmmo = {}

--------------------------
-- Options
--------------------------

-- When true, if any weapon is fired from the given plane, it will be removed.
AceAmmo.USE_AMMO_DATA_AS_WHITELIST = true

-- Puts a hard limit on the different TYPES that can be loaded onto a plane.
-- This is a very gamey way of limiting things to prevent the trick of loading
-- one example of every type of weapon and then having a crazy arsenal.
AceAmmo.MAX_NUMBER_OF_WEAPON_TYPES = 2

-- When true, AI are allowed to fire an infinite number of any weapons. When false
-- they obey the same ammo rules as players do.
AceAmmo.TRACK_AMMO_ONLY_ON_PLAYERS = true

-- When true, a weapon is not considered loaded onto the plane unless there are
-- two examples of it on the plane. Can be used to prevent weird loadouts.
AceAmmo.REQUIRE_WEAPONS_LOADED_IN_PAIRS = true

-- Fallback for when the ammo count for a weapon drops below this value, and if
-- the AceEagleEye module is active, then it will report that ammo is low.
AceAmmo.DEFAULT_LOW_AMMO_COUNT = 4

--------------------------
-- Debug
--------------------------

local SHOW_DEBUG = false
local SHOW_ERROR = true

local function printDebug(source, message)
  if SHOW_DEBUG then
    local output = "AceAmmo (" .. source .. "): " .. message
    trigger.action.outText(output, 5, false)
  end
end

local function printError(source, message)
  if SHOW_ERROR then
    local output = "AceAmmo ERROR (" .. source .. "): " .. message
    trigger.action.outText(output, 5, false)
  end
end

--------------------------
-- Data tables
--------------------------

-- displayName: Nicer name used when printing the ammo counts.
local AMMO_DATA = {
  ["F-16C_50"] = {
    displayName = "F-16C",
    ["AIM-9L"] = 10,
    ["AIM_120"] = 4,
    ["Mk_82"] = 24,
    ["Mk_84"] = 8,
    ["HYDRA_70_M151"] = 114,
    ["AGM_65D"] = 8,
    ["CBU_87"] = 16,
  },
  ["FA-18C_hornet"] = {
    displayName = "F/A-18C",
    ["AIM-9L"] = 10,
    ["Mk_82"] = 24,
    ["Mk_84"] = 8,
    ["HYDRA_70_M151"] = 114,
    ["AGM_65F"] = 8,
    ["Zuni_127"] = 24,
  },
  ["MiG-29S"] = {
    ["P_60"] = 14,
    ["P_73"] = 6,
    ["C_8"] = 120,
    ["C_8OFP2"] = 120,
  },
}

local WEAPON_DATA = {
  -- AAMs
  ["AIM-9L"] = { displayName = "AIM-9", timeToLive = 7.0 },
  ["AIM_120"] = { displayName = "AIM-120", timeToLive = 9.0, maxSupported = 1 },
  ["P_60"] = { displayName = "R-60", timeToLive = 7.0 },
  ["P_73"] = { displayName = "R-73", timeToLive = 8.0 },

  -- Rockets
  ["HYDRA_70_M151"] = { displayName = "Hydra", lowAmmo = 38},
  ["Zuni_127"] = { displayName = "Zuni", lowAmmo = 8},
  ["C_8"] = { displayName = "S-8 (HEAT/Frag)", lowAmmo = 32, },
  ["C_8OFP2"] = { displayName = "S-8 (MPP)", lowAmmo = 32 },

  -- Bombs
  ["Mk_82"] = { displayName = "Mk82", lowAmmo = 6},
  ["Mk_84"] = { displayName = "Mk84" },

  -- AGMs
  ["AGM_65D"] = { displayName = "AGM-65D", lowAmmo = 2 },
  ["AGM_65F"] = { displayName = "AGM-65F", lowAmmo = 2 },
}

--------------------------
-- Table functions
--------------------------

-- Returns 0 if either the given aircraft doesn't exist, or the given aircraft
-- does not have the given ammo type.
function AMMO_DATA:getAmmoCount(aircrafTypeName, ammoTypeName)
  if self[aircrafTypeName] and self[aircrafTypeName][ammoTypeName] then
    return self[aircrafTypeName][ammoTypeName]
  else
    printError("getAmmoCount", string.format("No ammo type found on aircraft %s for %s", aircrafTypeName, ammoTypeName))
    return 0
  end
end

function AMMO_DATA:getDisplayName(aircraftTypeName)
  if self[aircraftTypeName] and self[aircraftTypeName].displayName then
    return self[aircraftTypeName].displayName
  else
    return aircraftTypeName
  end
end

-- Returns -1 if the weapon has no data for time to live.
function WEAPON_DATA:getTimeToLive(weaponTypeName)
  local data = WEAPON_DATA[weaponTypeName]
  if data and data.timeToLive then return data.timeToLive
  else return -1 end
end

-- Returns the weaponTypeName if no displayname is found.
function WEAPON_DATA:getDisplayName(weaponTypeName)
  local data = WEAPON_DATA[weaponTypeName]
  if data and data.displayName then return data.displayName
  else return weaponTypeName end
end

-- Returns -1 if the weapon has no data for time to live.
function WEAPON_DATA:getMaxSupported(weaponTypeName)
  local data = WEAPON_DATA[weaponTypeName]
  if data and data.maxSupported then return data.maxSupported
  else return -1 end
end

function WEAPON_DATA:getLowAmmo(weaponTypeName)
  local data = WEAPON_DATA[weaponTypeName]
  if data and data.lowAmmo then return data.lowAmmo
  else return AceAmmo.destroyMissile end
end

--------------------------
-- Core functions
--------------------------

-- Checks the current physical loadout of the game aircraft and then generates
-- an ammo table. This is the same thing as reloading.
-- Returns the ammo table.
-- Format of
-- {
--   ["weaponTypeName"] = 10,
--   ["weaponTypeName"] = 8,
-- }
function AceAmmo.validateLoadout(aircraft)
  if not aircraft then return {} end

  if AceAmmo.TRACK_AMMO_ONLY_ON_PLAYERS and not aircraft.isPlayer then
    printDebug("onValidateLoadout", string.format("Ignoring ammo for AI aircraft %s.", aircraft.fullName))
    return {}
  end

  printDebug("onValidateLoadout", "Building ammo loadout for " .. aircraft.fullName .. ".")
  aircraft.ammo = {}
  local dcsAmmo = aircraft.unit:getAmmo()
  local loadedTypeCount = 0
  for i = 1, #dcsAmmo do

    -- Check to make sure the ammo limit hasn't already been hit.
    if loadedTypeCount > AceAmmo.MAX_NUMBER_OF_WEAPON_TYPES then break end

    -- Gun ammo is ignored.
    local isMunition = dcsAmmo[i].desc.category > 0

    -- Check to make sure a pair is loaded instead of just a single weapon (optional).
    local hasPairLoaded = dcsAmmo[i].count >= 2
    local isLoadingAllowed = not AceAmmo.REQUIRE_WEAPONS_LOADED_IN_PAIRS or (AceAmmo.REQUIRE_WEAPONS_LOADED_IN_PAIRS and hasPairLoaded)

    if isMunition and isLoadingAllowed then
      -- The DCS ammo array is stored by weapon type, not pylon or launcher. Each entry in
      -- the array corresponds to one type of weapon.
      local ammoTypeName = Ace.trimTypeName(dcsAmmo[i].desc.typeName)
      printDebug("onValidateLoadout", "DCS ammo " .. ammoTypeName .. ".")
      local gameAmmoCount = AMMO_DATA:getAmmoCount(aircraft.typeName, ammoTypeName)
      printDebug("onValidateLoadout", "Game ammo count for type: " .. gameAmmoCount .. ".")
      if gameAmmoCount > 0 then
        aircraft.ammo[ammoTypeName] = gameAmmoCount
        printDebug("onValidateLoadout", "Added " .. gameAmmoCount .. " " .. ammoTypeName .. " to aircraft.")
      end

      -- Track how many different types of ammo have been loaded since that's how it works.
      loadedTypeCount = loadedTypeCount + 1
      printDebug("onValidateLoadout", "Number of ammo types: " .. tostring(loadedTypeCount))
      if loadedTypeCount >= AceAmmo.MAX_NUMBER_OF_WEAPON_TYPES then
        printDebug("onValidateLoadout",
          "Max number of weapon types (" .. tostring(AceAmmo.MAX_NUMBER_OF_WEAPON_TYPES) .. ") reached.")
        break
      end
    end
  end

  return aircraft.ammo
end

function AceAmmo.getLoadoutDisplayString(aircraftTypeName, ammoTable)
  local output = AMMO_DATA:getDisplayName(aircraftTypeName)
  for ammoName, ammoCount in pairs(ammoTable) do
    local displayName = WEAPON_DATA:getDisplayName(ammoName)
    output = output .. string.format("\n%3d  %s", ammoCount, displayName)
  end
  return output
end

-- Returns the ammo table for the given tracked aircraft.
-- Format of
-- {
--   ["weaponTypeName"] = 10,
--   ["weaponTypeName"] = 8,
-- }
function AceAmmo.getAmmoTableForAircraft(aircraft)
  return aircraft.ammo
end

function AceAmmo.destroyMissile(weapon)
  if not weapon or not weapon:isExist() then return end
  printDebug("destroyMissile", "Destroyed weapon " .. Ace.trimTypeName(weapon:getDesc().typeName))
  weapon:destroy()
end

function AceAmmo.onShot(time, firedByUnit, weapon)
  local weaponTypeName = Ace.trimTypeName(weapon:getDesc().typeName)
  printDebug("onShot", string.format("Shot %s.", weaponTypeName))

  -- Handle time to live overrides.
  local timeToLive = WEAPON_DATA:getTimeToLive(weaponTypeName)
  if timeToLive >= 0 then
    timer.scheduleFunction(AceAmmo.destroyMissile, weapon, timer.getTime() + timeToLive)
  end

  -- Early return for ammo checks.
  local aircraft = Ace.TrackedAircraftByID:getAircraftByUnit(firedByUnit)
  if not aircraft then return end
  if AceAmmo.TRACK_AMMO_ONLY_ON_PLAYERS and not aircraft.isPlayer then return end

  if aircraft.ammo then
    if aircraft.ammo[weaponTypeName] then
      local ammo = aircraft.ammo[weaponTypeName]
      if ammo > 0 then
        ammo = ammo - 1
        aircraft.ammo[weaponTypeName] = ammo
        if ammo == 0 then
          trigger.action.outTextForGroup(
            aircraft.groupID,
            string.format("Out of %s!", weaponTypeName),
            5, false)
          if AceEagleEye then
            if Ace.isAirToAirMissile(weapon) then AceEagleEye.reportMissileEmpty(aircraft.groupID)
            else AceEagleEye.reportSPWeaponEmpty(aircraft.groupID) end
          end
        elseif ammo == WEAPON_DATA:getLowAmmo(weaponTypeName) then
          if Ace.isAirToAirMissile(weapon) then AceEagleEye.reportMissileLow(aircraft.groupID)
          else AceEagleEye.reportSPWeaponLow(aircraft.groupID) end
        end
      else
      -- Out of ammo, so nullify the shot weapon.
      weapon:destroy()
      trigger.action.outTextForGroup(
        aircraft.groupID,
        string.format("Out of %s!", weaponTypeName),
        5, false)
      end
      trigger.action.outTextForGroup(
        aircraft.groupID,
        AceAmmo.getLoadoutDisplayString(aircraft.typeName, aircraft.ammo),
        5, false)
    elseif AceAmmo.USE_AMMO_DATA_AS_WHITELIST then
      -- When the ammo is used as a whitelist, then any weapon fired by the player that isn't
      -- listed on the loadout will be nullified.
      weapon:destroy()
      trigger.action.outTextForGroup(
        aircraft.groupID,
        string.format("%s is not loaded on aircraft!", weaponTypeName),
        5, false)
    end
  else
    printError("onShot", string.format("%s aircraft does not have ammo loadout!", aircraft.fullName))
  end
end
