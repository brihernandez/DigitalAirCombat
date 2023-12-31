Ace = {}

--------------------------
-- Options
--------------------------

local SHOW_DEBUG = false
local SHOW_ERROR = true

local VALIDATE_LOADOUT_STRING = "Validate Loadout"

-- Required to enable helicopter related features.
-- I didn't test this! I don't know if it works!
Ace.ENABLE_HELICOPTERS = false

--------------------------
-- Framework Init
--------------------------

trigger.action.outText("Starting Ace Gameplay Framework...", 5, false)

local function confirmModulesLoaded()
  local text = "Ace modules loaded:"
  if AceHP then text = text .. "\nHitpoints" end
  if AceSplash then text = text .. "\nSplash" end
  if AceEagleEye then text = text .. "\nEagle Eye" end
  if AceAmmo then text = text .. "\nAmmo" end
  trigger.action.outText(text, 15, false)
end

local function initializeModules()
  Ace.TrackedAircraftByID:startTrackingAllAircraftAlreadyInMission()
end

world.addEventHandler(Ace)
timer.scheduleFunction(initializeModules, nil, timer.getTime() + 1)
timer.scheduleFunction(confirmModulesLoaded, nil, timer.getTime() + 2)

--------------------------
-- Various Utilities
--------------------------

local function printDebug(source, message)
  if SHOW_DEBUG then
    local output = "AceBase (" .. source .. "): " .. message
    env.log(output, false)
    trigger.action.outText(output, 5, false)
  end
end

local function printError(source, message)
  if SHOW_ERROR then
    local output = "AceBase ERROR (" .. source .. "): " .. message
    env.error(output, false)
    trigger.action.outText(output, 5, false)
  end
end

local vec3 = {}
function vec3.distance(pointA, pointB)
  local x = pointA.x - pointB.x
  local y = pointA.y - pointB.y
  local z = pointA.z - pointB.z
  local square = (x * x) + (y * y) + (z * z)
  return math.sqrt(square)
end

-- Attempts to convert an Object to Unit. If this fails, it probably returns nil.
function Ace.objectToUnit(object)
  if object then return Unit.getByName(object:getName()) else return nil end
end

-- Converts long type names like "weapons.shells.GAU8_30_HE" into "GAU8_30_HE".
function Ace.trimTypeName(typename)
  if typename then
    return string.match(typename, "[^.]-$")
  end
end

-- Returns true/false.
function Ace.isUnitAnAircraft(unit, includeHelicopters)
  if not unit or not unit:isExist() then return false end
  if includeHelicopters then return unit:getDesc().category < 2
  else return unit:getDesc().category < 1 end
end

-- Returns true for anything that's not a helicopter or aircraft.
function Ace.isUnitASurfaceObject(unit)
  if not unit or not unit:isExist() then return false end
  return unit:getDesc().category > 1
end

-- If the object is an aircraft or helicopter, returns (true, Unit)
-- Otherwise, returns false.
function Ace.isObjectAnAircraft(object, includeHelicopters)
  if not object:isExist() then return false end

  local unit = Ace.objectToUnit(object)
  if unit then
    if Ace.isUnitAnAircraft(unit, includeHelicopters) then
      printDebug("isObjectAnAircraft", object:getName() .. " is an AIRCRAFT.")
      return true, unit
    else
      printDebug("isObjectAnAircraft", object:getName() .. " is a UNIT, but not an AIRCRAFT!\nUnit category: " .. tostring(unit:getDesc().category))
      return false
    end
  else
    --printDebug("isObjectAnAircraft", object:getName() .. " is not a valid unit!\nObject category: " .. object:getCategory())
    return false
  end
end

-- Checks against DCS' own data. Returns boolean.
function Ace.isAirToAirMissile(weapon)
  return weapon:getDesc().category == 1 and weapon:getDesc().missileCategory == 1
end

-- Checks against DCS' own data. Returns boolean.
function Ace.isSurfaceToAirMissile(weapon)
  return weapon:getDesc().category == 1 and weapon:getDesc().missileCategory == 2
end

-- Checks against DCS' own data. Returns boolean.
function Ace.isGun(weapon)
  return weapon:getDesc().category == 0
end

-- Checks against DCS' own data. Returns a predefined value if no data is found. Caliber is in mm.
local DEFAULT_CALIBER = 10
function Ace.getCaliber(weapon)
  local desc = weapon:getDesc()
  if desc.warhead then
    return desc.warhead.caliber
  else
    return DEFAULT_CALIBER
  end
end

-- Checks against DCS' own data. Returns boolean.
function Ace.isAirToGroundMunition(weapon)
  local isMunition = weapon:getDesc().category > 0
  local isMissile = weapon:getDesc().category == 1
  -- Guaranteed to be something like a rocket or bomb.
  if isMunition and not isMissile then return true end
  -- Missiles can include AAM and SAM, so make sure it's not those two.
  return isMissile and weapon:getDesc().missileCategory > 2
end

-- Returns (bool isAtAirfield, bool isAtFriendlyAirfield)
function Ace.IsUnitAtFriendlyAirfield(unit)
  if not unit or not unit:isExist() then return false, false end
  if unit:inAir() then return false, false end

  local allAirfields = world.getAirbases()
  local closestDistance = 999999999999999999999.9;
  local isClosestFriendly = false
  for i = 1, #allAirfields do
    local distance = vec3.distance(unit:getPoint(), allAirfields[i]:getPoint())
    if distance < closestDistance then
      closestDistance = distance
      isClosestFriendly = allAirfields[i]:getCoalition() == unit:getCoalition()
    end
  end

  return closestDistance < 5000.0, isClosestFriendly
end

function Ace.printTable(node)
  local cache, stack, output = {}, {}, {}
  local depth = 1
  local output_str = "{\n"

  while true do
    local size = 0
    for k, v in pairs(node) do
      size = size + 1
    end

    local cur_index = 1
    for k, v in pairs(node) do
      if (cache[node] == nil) or (cur_index >= cache[node]) then
        if (string.find(output_str, "}", output_str:len())) then
          output_str = output_str .. ",\n"
        elseif not (string.find(output_str, "\n", output_str:len())) then
          output_str = output_str .. "\n"
        end

        -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
        table.insert(output, output_str)
        output_str = ""

        local key
        if (type(k) == "number" or type(k) == "boolean") then
          key = "[" .. tostring(k) .. "]"
        else
          key = "['" .. tostring(k) .. "']"
        end

        if (type(v) == "number" or type(v) == "boolean") then
          output_str = output_str .. string.rep('\t', depth) .. key .. " = " .. tostring(v)
        elseif (type(v) == "table") then
          output_str = output_str .. string.rep('\t', depth) .. key .. " = {\n"
          table.insert(stack, node)
          table.insert(stack, v)
          cache[node] = cur_index + 1
          break
        else
          output_str = output_str .. string.rep('\t', depth) .. key .. " = '" .. tostring(v) .. "'"
        end

        if (cur_index == size) then
          output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}"
        else
          output_str = output_str .. ","
        end
      else
        -- close the table
        if (cur_index == size) then
          output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}"
        end
      end

      cur_index = cur_index + 1
    end

    if (size == 0) then
      output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}"
    end

    if (#stack > 0) then
      node = stack[#stack]
      stack[#stack] = nil
      depth = cache[node] == nil and depth + 1 or depth - 1
    else
      break
    end
  end

  -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
  table.insert(output, output_str)
  output_str = table.concat(output)
  return output_str
end

--------------------------
-- Tracked Aircraft
--------------------------

Ace.TrackedAircraftByID = {}
local AI_PILOT_NAME = "AI Pilot"

-- Returns added aircraft or nil if aircraft already was added.
function Ace.TrackedAircraftByID:startTracking(unit)
  if not Ace.isUnitAnAircraft(unit, Ace.ENABLE_HELICOPTERS) then return end

  -- To prevent players from getting multiple times, guard against them getting re-initialized
  -- in the tracking. On respawn, players can be re-initialized through the onPlayerEnterUnit.
  -- On respawn, players DO NOT emit an onBirth event. However AI, on respawn, DO emit an onBirth
  -- event because when mist "respawns" them it's actually making new ones with the same name and
  -- somehow with the same IDs as well...
  if Unit.getPlayerName(unit) and Ace.TrackedAircraftByID:getAircraftByUnit(unit) then return end

  local group = unit:getGroup()
  local typeName = unit:getTypeName()
  local pilotName = AI_PILOT_NAME
  if Unit.getPlayerName(unit) then pilotName = tostring(Unit.getPlayerName(unit)) end
  local aircraft = {
    unit = unit,
    unitID = unit:getID(),
    group = group,
    groupID = group:getID(),
    groupName = group:getName(),
    controller = group:getController(),
    typeName = typeName,
    displayName = unit:getDesc().displayName,
    pilotName = pilotName,
    isPlayer = pilotName ~= AI_PILOT_NAME,
    fullName = pilotName .. " (" .. group:getName() .. ")",
    isAirborne = unit:inAir() == true,
    isLandedAtAirfield = false,
    isLandedAtFriendlyAirfield = false,
  }

  aircraft.isLandedAtAirfield, aircraft.isLandedAtFriendlyAirfield = Ace.IsUnitAtFriendlyAirfield(aircraft.unit)

  self[aircraft.unitID] = aircraft
  printDebug("startTracking", "Tracking aircraft " .. aircraft.fullName .. ".")

  -- Add commands.
  if AceAmmo then
    -- Removing the command before adding prevents double commands from appearing.
    missionCommands.removeItemForGroup(aircraft.groupID, { VALIDATE_LOADOUT_STRING })
    missionCommands.addCommandForGroup(
      aircraft.groupID,
      VALIDATE_LOADOUT_STRING, {},
      Ace.TrackedAircraftByID.RunValidateLoadoutCommand,
      aircraft)
  end

  -- Notify the modules.
  if AceHP then AceHP.onTrackingAircraftStarted(aircraft) end
  if AceAmmo then
    local ammo = AceAmmo.validateLoadout(aircraft)
    if ammo then
      trigger.action.outTextForGroup(
        aircraft.groupID,
        AceAmmo.getLoadoutDisplayString(aircraft.typeName, ammo),
        10, false)
    end
  end

  return aircraft
end

function Ace.TrackedAircraftByID.RunValidateLoadoutCommand(aircraft)
  if aircraft and aircraft.unit:isExist() then
    if aircraft.isLandedAtAirfield and aircraft.isLandedAtFriendlyAirfield then
      local message = "No loadout info!"
      if AceAmmo then
        AceAmmo.validateLoadout(aircraft)
        message = string.format("%s", AceAmmo.getLoadoutDisplayString(aircraft.typeName, aircraft.ammo))
      end
      trigger.action.outTextForGroup(aircraft.groupID, message, 10, false)
    else
      trigger.action.outTextForGroup(
        aircraft.groupID,
        "Must be landed at friendly airfield to validate loadout!",
        10, false)
    end
  end
end

function Ace.TrackedAircraftByID:stopTracking(unit)
  if not Ace.isUnitAnAircraft(unit, Ace.ENABLE_HELICOPTERS) then return end

  local aircraft = self:getAircraftByUnit(unit)
  if aircraft then
    printDebug("stopTracking", "Stopped tracking aircraft " .. aircraft.fullName .. ".")
    self[aircraft.unitID] = nil

    if AceAmmo then
      missionCommands.removeItemForGroup(aircraft.groupID, { VALIDATE_LOADOUT_STRING })
    end

    -- Notify the modules.
    if AceHP then AceHP.onTrackingAircraftStopped(aircraft) end

  else
    printDebug("stopTracking", "Failed to find aircraft with unit name " .. unit:getName() .. ".")
  end
end

function Ace.TrackedAircraftByID:getAircraftByObject(object)
  local unit = Ace.objectToUnit(object)
  if unit then return Ace.TrackedAircraftByID:getAircraftByUnit(unit)
  else return nil end
end

-- Returns nil if there is no valid entry.
function Ace.TrackedAircraftByID:getAircraftByUnit(unit)
  if not Ace.isUnitAnAircraft(unit, Ace.ENABLE_HELICOPTERS) then return end

  if unit then
    local aircraft = self[unit:getID()]
    if aircraft then
      printDebug("getAircraftByUnit", "Found aircraft " .. aircraft.fullName .. ".")
      return aircraft
    else
      printDebug("getAircraftByUnit", "Unit " .. unit:getName() .. " (" .. unit:getID() .. ") is not an aircraft.")
      return nil
    end
  else
    printDebug("getAircraftByUnit", "Failed to find aircraft because unit is not valid: " .. tostring(unit))
  end
end

function Ace.TrackedAircraftByID:takeoff(aircraft, place)
  printDebug("takeoff", "takeoff")

  if place then
    trigger.action.outTextForGroup(
      aircraft.groupID,
      aircraft.fullName .. " took off from " .. place:getName() .. ".",
      4, false)
  else
    trigger.action.outTextForGroup(
      aircraft.groupID,
      aircraft.fullName .. " took off from ground.",
      4, false)
  end

  aircraft.isAirborne = true
  aircraft.isLandedAtAirfield = false
  aircraft.isLandedAtFriendlyAirfield = false
end

function Ace.TrackedAircraftByID:land(aircraft, place)
  printDebug("land", "land")

  aircraft.isAirborne = false
  aircraft.isLandedAtAirfield = place ~= nil
  aircraft.isLandedAtFriendlyAirfield = place and place:getCoalition() == aircraft.unit:getCoalition()

  if aircraft.isLandedAtAirfield then
    trigger.action.outTextForGroup(
      aircraft.groupID,
      aircraft.fullName .. " landed at " .. place:getName() .. ".",
      4, false)
  else
    trigger.action.outTextForGroup(
      aircraft.groupID,
      aircraft.fullName .. " landed on ground.",
      4, false)
  end
end

function Ace.TrackedAircraftByID:startTrackingAllAircraftAlreadyInMission()
  for _, redPlaneGroup in pairs(coalition.getGroups(1, 0)) do
    if redPlaneGroup:getSize() > 0 then self:startTracking(redPlaneGroup:getUnit(1)) end
  end
  for _, bluePlaneGroup in pairs(coalition.getGroups(2, 0)) do
    if bluePlaneGroup:getSize() > 0 then self:startTracking(bluePlaneGroup:getUnit(1)) end
  end

  -- This might be buggy!
  if Ace.ENABLE_HELICOPTERS then
    for _, redHeloGroup in pairs(coalition.getGroups(1, 1)) do
      if redHeloGroup:getSize() > 0 then self:startTracking(redHeloGroup:getUnit(1)) end
    end
    for _, blueHeloGroup in pairs(coalition.getGroups(2, 1)) do
      if blueHeloGroup:getSize() > 0 then self:startTracking(blueHeloGroup:getUnit(1)) end
    end
  end

end

--------------------------
-- Event handlers
--------------------------

function Ace:onEvent(event)
  if event.id == 20 then Ace:onPlayerEnterUnit(event.time, event.initiator) end
  if event.id == 21 then Ace:onPlayerLeaveUnit(event.time, event.initiator) end
  if event.id == 2 then Ace:onHit(event.time, event.initiator, event.weapon, event.target) end
  if event.id == 28 then Ace:onKill(event.time, event.initiator, event.weapon, event.target, event.weapon_name) end
  if event.id == 15 then Ace:onBirth(event.time, event.initiator) end
  if event.id == 8 then Ace:onDead(event.time, event.initiator) end
  if event.id == 3 then Ace:onTakeoff(event.time, event.initiator, event.place, event.subplace) end
  if event.id == 4 then Ace:onLand(event.time, event.initiator, event.place, event.subplace) end
  if event.id == 6 then Ace:onEject(event.time, event.initiator) end
  if event.id == 1 then Ace:onShot(event.time, event.initiator, event.weapon) end
end

function Ace:onPlayerEnterUnit(time, unit)
  if unit then
    printDebug("onPlayerEnterUnit", tostring(Unit.getPlayerName(unit)) .. " entered slot " .. unit:getGroup():getName())
  end
end

function Ace:onPlayerLeaveUnit(time, unit)
  if unit then
    printDebug("onPlayerLeaveUnit", tostring(Unit.getPlayerName(unit)) .. " left unit " .. unit:getGroup():getName())
  end
end

function Ace:onHit(time, firedByUnit, weapon, targetObject)
  printDebug("onHit", string.format("fired by: %s, weapon: %s, hitObject: %s", tostring(firedByUnit:getTypeName()), tostring(weapon:getTypeName()), targetObject:getTypeName()))
  if AceHP then AceHP.onHit(time, firedByUnit, weapon, targetObject) end
  if AceSplash then AceSplash.onHit(time, firedByUnit, weapon, targetObject) end
  if AceEagleEye then AceEagleEye.onHit(time, firedByUnit, weapon, targetObject) end
end

function Ace:onKill(time, killerUnit, weapon, unitKilled, weaponName)
  if unitKilled then
    printDebug("onKill", "Unit killed " .. unitKilled:getName())
    if Ace.isUnitAnAircraft(unitKilled, Ace.ENABLE_HELICOPTERS) then
      Ace.TrackedAircraftByID:stopTracking(unitKilled)
    end
  end

  if AceEagleEye then AceEagleEye.onKill(time, killerUnit, weapon, unitKilled, weaponName) end
end

function Ace:onShot(time, firedByUnit, weapon)
  if AceEagleEye then AceEagleEye.onShot(time, firedByUnit, weapon) end
  if AceAmmo then AceAmmo.onShot(time, firedByUnit, weapon) end
end

function Ace:onEject(time, ejectedUnit)
  if Ace.isUnitAnAircraft(ejectedUnit, Ace.ENABLE_HELICOPTERS) then
    Ace.TrackedAircraftByID:stopTracking(ejectedUnit)
  end
end

function Ace:onBirth(time, unit)
  if Ace.isUnitAnAircraft(unit, Ace.ENABLE_HELICOPTERS) then
    printDebug("onBirth", "Player " .. tostring(Unit.getPlayerName(unit)) .. " " .. tostring(unit:getGroup():getName()))
    Ace.TrackedAircraftByID:startTracking(unit)
  end
end

function Ace:onDead(time, object)
  local unit = Ace.objectToUnit()
  if unit then
    printDebug("onDead", "Player " .. tostring(Unit.getPlayerName(unit)) .. " " .. tostring(unit:getGroup():getName()))
    Ace.TrackedAircraftByID:stopTracking(unit)
  end
end

function Ace:onTakeoff(time, unit, place, subplace)
  local aircraft = Ace.TrackedAircraftByID:getAircraftByUnit(unit)
  if aircraft then
    Ace.TrackedAircraftByID:takeoff(aircraft, place)

    -- Rearm/Repair
    if AceHP then AceHP.onAircraftTakeoff(aircraft) end
    if AceAmmo and aircraft.isLandedAtFriendlyAirfield then
      local ammo = AceAmmo.validateLoadout(aircraft)
      trigger.action.outTextForGroup(
        aircraft.groupID,
        AceAmmo.getLoadoutDisplayString(aircraft.typeName, ammo),
        10, false)
    end
  end
end

function Ace:onLand(time, unit, place, subplace)
  local aircraft = Ace.TrackedAircraftByID:getAircraftByUnit(unit)
  if aircraft then
    Ace.TrackedAircraftByID:land(aircraft, place)
    if AceHP then AceHP.onAircraftLanded(aircraft) end
  end
end
