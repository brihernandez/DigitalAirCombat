trigger.action.outText("Activating AceDamage!", 5, false)

dofile()

-- https://stackoverflow.com/a/42062321
local function print_table(node)
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k,v in pairs(node) do
            size = size + 1
        end

        local cur_index = 1
        for k,v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then

                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = {\n"
                    table.insert(stack,node)
                    table.insert(stack,v)
                    cache[node] = cur_index+1
                    break
                else
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
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
    table.insert(output,output_str)
    output_str = table.concat(output)
    return output_str
end

local DEFAULT_HP = 200
local DAMAGE_A2A_MISSILE = 50
local DAMAGE_A2G_MUNITION = 1000
local DAMAGE_CALIBER_MULTIPLIER = 0.5
local DEFAULT_BULLET_CALIBER = 10

local WEAPON_DATA = {
  ["AIM-9L"] = { timeToLive = 8.0 },
  ["P_60"] = { timeToLive = 8.0 },
  ["Mk_82"] = { },
  ["MK_82SNAKEYE"] = { },
  ["Mk_83"] = { },
  ["Mk_84"] = { },
  ["HYDRA_70_M151"] = { },
  ["Zuni_127"] = { explMass = 4.3, splashRadius = 50.0, },
  ["S-5M"] = { explMass = 0.5, },
  ["AGM_65D"] = { splashRadius = 10.0, },
  ["AGM_65F"] = { splashRadius = 10.0, },
  ["BLU-97B"] = { explMass = 10.0, },
}

-- Returns -1 if there is no override for time to live.
function WEAPON_DATA:GetTimeToLive(typeName)
  local data = self[typeName]
  local timeToLive = -1
  if data ~= nil and data.timeToLive ~= nil then
    timeToLive = data.timeToLive
  end
  return timeToLive
end

local AIRCRAFT_DATA = {
  ["F-16C_50"] = {
    hp = 200,
  },
  ["FA-18C_hornet"] = {
    hp = 200,
  },
  ["F-14A-135-GR"] = {
    hp = 200,
  },
  ["F-14B"] = {
    hp = 200,
  },
  ["F-15C"] = {
    hp = 200,
  },
  ["F-15ESE"] = {
    hp = 250,
  },
  ["AJS37"] = {
    hp = 250,
  },
  ["AV8BNA"] = {
    hp = 250,
  },
  ["A-10A"] = {
    hp = 400,
  },
  ["A-10C_2"] = {
    hp = 400,
  },
  ["MiG-19P"] = {
    hp = 200,
  },
  ["MiG-21Bis"] = {
    hp = 200,
  },
  ["MiG-29A"] = {
    hp = 200,
  },
  ["MiG-29G"] = {
    hp = 200,
  },
  ["MiG-29S"] = {
    hp = 200,
  },
  ["Su-25"] = {
    hp = 400,
  },
  ["Su-25T"] = {
    hp = 400,
  },
  ["Su-27"] = {
    hp = 200,
  },
  ["Su-33"] = {
    hp = 200,
  },
}

function AIRCRAFT_DATA:GetAircraftHP(typeName)
  if self[typeName] ~= nil then
    return self[typeName].hp
  else
    trigger.action.outText("Falling back on default HP for " .. typeName .. ".", 5, false)
    return DEFAULT_HP
  end
end

local AircraftHPArray = {}

local ImmortalEnable = {
  id = 'SetImmortal',
  params = {
    value = true
  }
}

local ImmortalDisable = {
  id = 'SetImmortal',
  params = {
    value = false
  }
}

local function ObjectToUnit(object)
  return Unit.getByName(object:getName())
end

local function TrimTypeName(typename)
	if typename ~= nil then
		return string.match(typename, "[^.]-$")
	end
end

local function SetGroupImmortal(group, isImmortal)
  local controller = group:getController()
  if isImmortal == true then
    controller:setCommand(ImmortalEnable)
    trigger.action.outText(group:getName() .. " is now immortal!", 5, false)
  else
    controller:setCommand(ImmortalDisable)
    trigger.action.outText(group:getName() .. " is now destructible!", 5, false)
  end
end

-- Checks against DCS' own data rather than the weapon database.
local function IsAirToAirMissile(weapon)
  return weapon:getDesc().category == 1 and weapon:getDesc().missileCategory == 1
end

-- Checks against DCS' own data rather than the weapon database.
local function IsGun(weapon)
  local category = weapon:getDesc().category
  return category == 0
end

-- Checks against DCS' own data rather than the weapon database.
local function IsAirToGroundMunition(weapon)
  if IsAirToAirMissile(weapon) then return false end
  if IsGun(weapon) then return false end
  return true
end

local function Distance(pointA, pointB)
  local x = pointA.x - pointB.x
  local y = pointA.y - pointB.y
  local z = pointA.z - pointB.z
  local square = (x * x) + (y * y) + (z * z)
  return math.sqrt(square)
end

-- Returns 0 if there is no valid data for the given weapon type.
function WEAPON_DATA:GetSplashRadiusMax(weaponTypeName)
  local data = self[weaponTypeName]
  if data ~= nil and data.splashRadius ~= nil then return data.splashRadius
  else return 0 end
end

-- Returns 0 if there is no valid data for the given weapon type.
function WEAPON_DATA:GetExplosiveMass(weaponTypeName)
  local data = self[weaponTypeName]
  if data ~= nil and data.explMass ~= nil then return data.explMass
  else return 0 end
end

-- Prefers using data from the script-defined weapon database. Falls back on DCS
-- to get the combined explosive and shaped charge mass from the weapon description.
-- Returns 0 if there is no valid data.
local function GetExplosiveMass(weapon, target)
  local typeName = weapon:getTypeName()

  -- Early out in case this has a splash radius override and the target is too far.
  -- Some weapons have crazy splash damage for some reason (e.g. Zunis) and get too
  -- ridiculous if anything that falls under the explosion radius takes full damage.
  local splashRadiusOverride = WEAPON_DATA:GetSplashRadiusMax(typeName)
  if splashRadiusOverride > 0 and target ~= nil then
    local distance = Distance(weapon:getPoint(), target:getPoint())
    trigger.action.outText("Explosion distance of " .. distance .. " is too far for " .. typeName .. " (" .. splashRadiusOverride .. ").", 5, false)
    if distance > splashRadiusOverride then return 0 end
  end

  -- Early out in case there is an override for explosion mass.
  local explosiveMassOverride = WEAPON_DATA:GetExplosiveMass(typeName)
  if explosiveMassOverride > 0 then
    trigger.action.outText(typeName .. " has override explosive mass of " .. tostring(explosiveMassOverride), 5, false)
    return explosiveMassOverride
  end

  -- Without specific overrides, fall back of DCS' own data for warhead mass. DCS is very
  -- weird thoguh and sometiems random weapons won't have data. In that case a messaage is
  -- thrown and should be handled by adding new data to the weapons database.
  local power = 0
  local warhead = weapon:getDesc().warhead
  if warhead ~= nil then
    if warhead.explosiveMass ~= nil then power = warhead.explosiveMass end
    if warhead.shapedExplosiveMass ~= nil then power = power + warhead.shapedExplosiveMass end
    trigger.action.outText(typeName .. " has warhead explosive total of " .. tostring(power), 5, false)
  else
    trigger.action.outText(typeName .. " has no warhead data!", 5, false)
  end
  return power
end

-- Returns a predefined value if no data is found for caliber. Caliber is in mm.
local function GetCaliber(weapon)
  local desc = weapon:getDesc()
  if desc.warhead ~= nil then return desc.warhead.caliber
  else return DEFAULT_BULLET_CALIBER end
end

-- Relevant only for the HP system.
local function GetWeaponHPDamage(weapon)
  if IsAirToAirMissile(weapon) then
    return DAMAGE_A2A_MISSILE
  elseif IsAirToGroundMunition(weapon) then
    return DAMAGE_A2G_MUNITION
  elseif IsGun(weapon) then
    return GetCaliber(weapon) * DAMAGE_CALIBER_MULTIPLIER
  end
end

local function PrintAircraftStatus(gameAircraft)
  local groupID = gameAircraft.groupID
  local output = gameAircraft.displayName .. "\nHP: " .. tostring(gameAircraft.hp) .. "\n"
  trigger.action.outTextForGroup(groupID, output, 10, false)
end

function AircraftHPArray:getAircraftFromUnit(unit)
  for i = 1, #self do
    if self[i].unit == unit then return self[i] end
  end
  return nil
end

function AircraftHPArray:addAircraft(unit)
  local aircraft = {}
  aircraft.unit = unit
  aircraft.unitName = unit:getName()
  aircraft.typeName = unit:getTypeName()
  aircraft.displayName = unit:getDesc().displayName
  aircraft.group = unit:getGroup()
  aircraft.groupName = aircraft.group:getName()
  aircraft.groupID = aircraft.group:getID()
  aircraft.isAirborne = unit:inAir() == true
  aircraft.isLandedAtAirfield = false
  aircraft.hp = AIRCRAFT_DATA:GetAircraftHP(aircraft.typeName)
  table.insert(self, aircraft)

  if aircraft.isAirborne then SetGroupImmortal(aircraft.group, true) end

  trigger.action.outText("Tracking new aircraft: " .. tostring(aircraft.groupName), 5, false);
  PrintAircraftStatus(aircraft)

  missionCommands.addCommandForGroup(aircraft.groupID, "Check Ammo/HP", nil, PrintAircraftStatus, aircraft)
end

function AircraftHPArray:removeAircraft(unit)
  trigger.action.outText("Removing aircraft from tracker: " .. unit:getName(), 5, false)

  local toRemoveIndex = -1
  local groupName = unit:getGroup():getName()

  for i = 1, #self do
    if self[i].groupName == groupName then toRemoveIndex = i end
  end
  if toRemoveIndex ~= -1 then
    SetGroupImmortal(self[toRemoveIndex].group, false)
    table.remove(self, toRemoveIndex)
  end
end

function AircraftHPArray:aircraftTookOff(unit, airbase)
  local aircraft = self:getAircraftFromUnit(unit)
  if aircraft ~= nil then
    aircraft.isAirborne = true
    aircraft.isLandedAtAirfield = false

    if airbase ~= nil then
      trigger.action.outText(aircraft.groupName .. " took off from " .. airbase:getName() .. ".", 5, false)
    else
      trigger.action.outText(aircraft.groupName .. " took off from ground.", 5, false)
    end

    SetGroupImmortal(aircraft.group, true)
  end
end

function AircraftHPArray:aircraftLanded(unit, airbase)
  local aircraft = self:getAircraftFromUnit(unit)
  if aircraft ~= nil then
    aircraft.isAirborne = false

    if airbase ~= nil then
      trigger.action.outText(aircraft.groupName .. " landed at " .. airbase:getName() .. ".", 5, false)
    else
      trigger.action.outText(aircraft.groupName .. " landed on ground.", 5, false)
    end

    -- Aircraft gets HP repaired upon landing at friendly airbase.
    aircraft.isLandedAtAirfield = airbase ~= nil and airbase:getCoalition() == unit:getCoalition()
    if aircraft.isLandedAtAirfield == true then
      aircraft.hp = AIRCRAFT_DATA:GetAircraftHP(aircraft.typeName)
      trigger.action.outText("Rearmed and repaired " .. aircraft.groupName .. " at airbase " .. airbase:getName() .. ".", 5, false)
      PrintAircraftStatus(aircraft)
    end
    SetGroupImmortal(aircraft.group, false)
  end
end

local AceEventHandler = {}
function AceEventHandler:onEvent(event)
  if event.id == 20 then AceEventHandler:onPlayerEnterUnit(event.time, event.initiator) end
  if event.id == 21 then AceEventHandler:onPlayerLeaveUnit(event.time, event.initiator) end
  if event.id == 2 then AceEventHandler:onHit(event.time, event.initiator, event.weapon, event.target) end
  if event.id == 15 then AceEventHandler:onBirth(event.time, event.initiator) end
  if event.id == 3 then AceEventHandler:onTakeoff(event.time, event.initiator, event.place, event.subplace) end
  if event.id == 4 then AceEventHandler:onLand(event.time, event.initiator, event.place, event.subplace) end
  if event.id == 6 then AceEventHandler:onEject(event.time, event.initiator) end
  if event.id == 1 then AceEventHandler:onShot(event.time, event.initiator, event.weapon) end
end

function AceEventHandler:onPlayerEnterUnit(time, unit)
  trigger.action.outText(unit:getPlayerName() .. " entered slot " .. unit:getName(), 60, false)
  AircraftHPArray:addAircraft(unit)
end

function AceEventHandler:onPlayerLeaveUnit(time, unit)
  trigger.action.outText(unit:getPlayerName() .. " left unit " .. unit:getName(), 60, false)
  AircraftHPArray:removeAircraft(unit)
end

function AceEventHandler:onHit(time, firedByUnit, weapon, targetObject)
  if firedByUnit == nil then return end

  local unit = ObjectToUnit(targetObject)
  if unit == nil then return end

  --trigger.action.outText("Potential Target: " .. targetObject:getName(), 5, false)

  -- Apply HP damage to aircraft.
  local gameAircraft = AircraftHPArray:getAircraftFromUnit(unit)
  if gameAircraft ~= nil and gameAircraft.isAirborne then
    if gameAircraft.hp > 0 then

      local hpDamage = GetWeaponHPDamage(weapon)
      trigger.action.outText("Applying " .. tostring(hpDamage) .. " damage!", 5, false)
      gameAircraft.hp = gameAircraft.hp - hpDamage

      trigger.action.outText(gameAircraft.groupName .. " took " .. tostring(hpDamage) .. " damage from " .. weapon:getTypeName() .. "!\nHP: " .. tostring(gameAircraft.hp) .. "/" .. tostring(AIRCRAFT_DATA:GetAircraftHP(gameAircraft.typeName)), 5, false)
      if gameAircraft.hp <= 0 then SetGroupImmortal(gameAircraft.group, false) end
    end
  else
    --trigger.action.outText("HIT SOMETHING THAT CAN'T HANDLE IT!\nObject: " .. tostring(targetObject) .. "\nName: " .. tostring(targetObject:getName()) .. "\nType: " .. targetObject:getTypeName(), 5, false)
  end

  -- Boost the damage for anything that gets caught in splash.
  if IsAirToGroundMunition(weapon) then
    local blastPower = GetExplosiveMass(weapon, targetObject)
    if blastPower > 0 then
      trigger.action.explosion(targetObject:getPoint(), blastPower)
      trigger.action.outText("EXPLOSION BOOST for " .. tostring(blastPower), 5, false)
    end
  end

end

local function DeleteObject(object)
  if object ~= nil and object:isExist() then object:destroy() end
end

function AceEventHandler:onShot(time, firedByUnit, weapon)
  trigger.action.outText("Shot " .. weapon:getTypeName(), 5, false)

  -- Some weapons have a max time to live and are removed if they live that long.
  -- Mostly used to keep air to air missile ranges short lol
  local data = WEAPON_DATA[weapon:getTypeName()]
  if data ~= nil then
    if data.timeToLive ~= nil then
      timer.scheduleFunction(DeleteObject, weapon, timer.getTime() + data.timeToLive)
      trigger.action.outText(weapon:getTypeName() .. " will expire after " .. data.timeToLive .. " seconds.", 5, false)
    end
  end

  -- Deduct ammo from the correct ammo pool of the firing aircraft. For untracked
  -- aircraft, they essentially have unlimited ammo.
  local aircraft = AircraftHPArray:getAircraftFromUnit(firedByUnit)
  if aircraft ~= nil and data ~= nil then
    --[[
    local firedAmmoType = data.ammoType
    local ammoDisplayName = AMMO_DISPLAY_NAMES[firedAmmoType]
    if aircraft.ammo[firedAmmoType] > 0 then
      aircraft.ammo[firedAmmoType] = aircraft.ammo[firedAmmoType] - 1
      trigger.action.outTextForGroup(aircraft.groupID, ammoDisplayName .. ": " .. tostring(aircraft.ammo[firedAmmoType]), 5, false)
    else
      trigger.action.outTextForGroup(aircraft.groupID, "Out of " .. ammoDisplayName .. "!", 15, false)
      weapon:destroy()
    end
    --]]
  end

end

function AceEventHandler:onEject(time, ejectedUnit)
  trigger.action.outText("Ejected unit: " .. ejectedUnit:getName(), 5, false)
  AircraftHPArray:removeAircraft(ejectedUnit)
end

function AceEventHandler:onBirth(time, unit)
  trigger.action.outText("Spawned unit: " .. unit:getName() .. "\nGroup: " .. unit:getGroup():getName(), 5, false)
end

function AceEventHandler:onTakeoff(time, unit, airbase, subplace)
  AircraftHPArray:aircraftTookOff(unit, airbase)
end

function AceEventHandler:onLand(time, unit, airbase, subplace)
  AircraftHPArray:aircraftLanded(unit, airbase)
end

world.addEventHandler(AceEventHandler)
