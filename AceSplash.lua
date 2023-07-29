-- This is a VERY simple implementation of a splash script. Basically if an
-- explosive weapon causes damage to anthing, then the full power of that weapon is
-- applied directly to the object. This makes for a fairly binary "damaged or not".
-- 1. By default, without overrides, this does NOT affect air to air missiles or SAMs.
-- 2. Gun damage is optional, and by default, affects only ground targets.
-- 3. If something would have done no damage (e.g. M61 on a T-72) then no extra
--    damage is applied. This nicely balances things IMO.
-- 4. An error message is thrown when the script encounters something it doesn't
--    know how to handle. See SPLASH_DATA for more information.
AceSplash = {}

--------------------------
-- Options
--------------------------

-- Can be used to disable extra splash damage on guns if desired. Splash damage
-- makes the guns more effective on targets they would have already killed. If
-- the gun was never going to penetrate the target, no explosive damage is applied.
AceSplash.ENABLE_GUN_SPLASH = true

-- Aircraft are fragile enough that applying the extra splash damage to them doesn't
-- really make a lot of sense IMO, but it's here if you want it.
AceSplash.ENABLE_GUN_DAMAGE_ON_AIRCRAFT = false

-- When true, splash is only applied to air launched weapons.
AceSplash.MUST_BE_FIRED_FROM_AIRCRAFT = true

local SHOW_DEBUG = false
local SHOW_ERROR = true

--------------------------
-- Weapons Table
--------------------------

-- This table overrides values used by DCS. Otherwise, the splash damage falls back
-- on DCS derived values. NOT ALL WEAPONS HAVE CORRECT DATA IN DCS (E.g. Zunis). In
-- those cases, they should be added to this table in order to be handled. This
-- lookup is also more performant than the DCS fallback.
-- explMass: Explosion mass of a warhead.
-- radiusLimit: Puts a hard limit on the distance at which splash damage is applied.
--              Some weapons have a huge radius at which they damage unarmored targets,
--              even if they only do 1% damage. Without this value, Zunis have a ~300m
--              splash radius. Be aware that large values do not expand the splash
--              radius, it can only limit.
local SPLASH_DATA = {
  ["HYDRA_70_M151"] = { explMass = 3 },
  ["S-5M"] = { explMass = 3, },
  ["C_8"] = { explMass = 5, radiusLimit = 20},
  ["C_8OFP2"] = { explMass = 5, radiusLimit = 20},
  ["Zuni_127"] = { explMass = 20, radiusLimit = 20, },
  ["C_13"] = { explMass = 20, radiusLimit = 20 },
  ["AGM_65D"] = { radiusLimit = 15, },
  ["AGM_65F"] = { radiusLimit = 15, },
  ["BLU-97B"] = { explMass = 50, },
  ["GAU8_30_AP"] = { explMass = 0.5, },
  ["GAU8_30_HE"] = { explMass = 2.0, },
  ["FAB_100"] = { explMass = 55, radiusLimit = 50},
  ["FAB_250"] = { explMass = 138, radiusLimit = 50},
  ["FAB_500"] = { explMass = 275, radiusLimit = 75},
  ["Mk_82"] = { explMass = 125, radiusLimit = 50},
  ["MK_82AIR"] = { explMass = 125, radiusLimit = 50},
  ["MK_82SNAKEYE"] = { explMass = 125, radiusLimit = 50 },
  ["Mk_83"] = { explMass = 250, radiusLimit = 75},
  ["Mk_84"] = { explMass = 500, radiusLimit = 100 },
}

-- Returns -1 if there is no valid data for the given weapon type.
function SPLASH_DATA:getExplosiveMass(weaponTypeName)
  local data = self[weaponTypeName]
  if data and data.explMass then return data.explMass
  else return -1 end
end

-- Returns -1 if there is no valid data for the given weapon type.
function SPLASH_DATA:getSplashRadiusMax(weaponTypeName)
  local data = self[weaponTypeName]
  if data and data.radiusLimit then return data.radiusLimit
  else return -1 end
end

--------------------------
-- Utilities
--------------------------

local function printDebug(source, message)
  if SHOW_DEBUG then
    local output = "AceSplash (" .. source .. "): " .. message
    trigger.action.outText(output, 5, false)
  end
end

local function printError(source, message)
  if SHOW_ERROR then
    local output = "AceSplash ERROR (" .. source .. "): " .. message
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

--------------------------
-- Core functions
--------------------------

-- Prefers using data from the script-defined weapon database. Falls back on DCS
-- to get the combined explosive and shaped charge mass from the weapon description.
-- Returns 0 if there is no valid data.
function AceSplash.getExplosiveMass(weapon, target)
  local typeName = Ace.trimTypeName(weapon:getTypeName())

  printDebug("getExplosiveMass", "Getting explosive mass of " .. typeName)

  -- Early out in case this has a splash radius override and the target is too far.
  -- Some weapons have crazy splash damage for some reason (e.g. Zunis) and get too
  -- ridiculous if anything that falls under the explosion radius takes full damage.
  local splashRadiusOverride = SPLASH_DATA:getSplashRadiusMax(typeName)
  if splashRadiusOverride >= 0 and target then
    local distance = vec3.distance(weapon:getPoint(), target:getPoint())
    printDebug("getExplosiveMass", "Explosion distance of " .. distance .. " is too far for " .. typeName .. " (" .. splashRadiusOverride .. ").")
    if distance > splashRadiusOverride then return 0 end
  end

  -- Early out in case there is an override for explosion mass.
  local explosiveMassOverride = SPLASH_DATA:getExplosiveMass(typeName)
  if explosiveMassOverride >= 0 then
    printDebug("getExplosiveMass", typeName .. " has override explosive mass of " .. tostring(explosiveMassOverride))
    return explosiveMassOverride
  end

  -- Without specific overrides, fall back of DCS' own data for warhead mass. DCS is very
  -- weird thoguh and sometiems random weapons won't have data. In that case a messaage is
  -- thrown and should be handled by adding new data to the weapons database.
  local power = 0
  local warhead = weapon:getDesc().warhead
  if warhead then
    if warhead.explosiveMass then power = warhead.explosiveMass end
    if warhead.shapedExplosiveMass then power = power + warhead.shapedExplosiveMass end
    printDebug("getExplosiveMass", typeName .. " has warhead explosive total of " .. tostring(power))
  else
    printError("getExplosiveMass", typeName .. " has no warhead data!")
  end
  return power
end

function AceSplash.onHit(time, firedByUnit, weapon, targetObject)
  -- This should only apply to weapons launched by aircraft.
  local isAircraft = Ace.isUnitAnAircraft(firedByUnit)
  if AceSplash.MUST_BE_FIRED_FROM_AIRCRAFT and not isAircraft then return end

  -- Filter out anything that's not a weapon. E.g. splash damage from a vehicle exploding.
  local typeName = Ace.trimTypeName(weapon:getTypeName())
  if weapon:getCategory() ~= 2 then
    printDebug("onHit", weapon:getTypeName() .. " is not a weapon.")
  end

  -- Guns damage is optional.
  local isGun = Ace.isGun(weapon)
  if isGun and not AceSplash.ENABLE_GUN_SPLASH then
    printDebug("onHit", "ENABLE_GUN_SPLASH = false. Guns are excluded from splash.")
    return
  end

  -- Prevent splash damage against things like wrecks.
  local hitUnit = Ace.objectToUnit(targetObject)
  if not hitUnit or not hitUnit:isExist() then
    printDebug("onHit", targetObject:getName() .. " is not a Unit.")
    return
  end

  -- Splash against aircraft is optional.
  if isGun and Ace.isUnitAnAircraft(hitUnit, Ace.ENABLE_HELICOPTERS) and not AceSplash.ENABLE_GUN_DAMAGE_ON_AIRCRAFT then
    printDebug("onHit", typeName .. " is a gun and does not apply splash to aircraft.")
    return
  end

  -- Boost the damage for anything that gets caught in splash.
  if isGun or Ace.isAirToGroundMunition(weapon) then
    local blastPower = AceSplash.getExplosiveMass(weapon, targetObject)
    if blastPower > 0 then
      trigger.action.explosion(targetObject:getPoint(), blastPower)
      printDebug("onHit", "Splash of " .. tostring(blastPower) .. " applied to " .. typeName .. ".")
    end
  else
    printDebug("onHit", typeName .. " is not an air to ground munition. No splash applied.")
  end
end
