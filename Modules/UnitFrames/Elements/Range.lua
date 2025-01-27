local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")
local SpellRange = E.Libs.SpellRange

--Lua functions
local pairs, ipairs = pairs, ipairs
local find = string.find
--WoW API / Variables
local CheckInteractDistance = CheckInteractDistance
local UnitCanAttack = UnitCanAttack
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitInRange = UnitInRange
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsUnit = UnitIsUnit

local SRT = {}
local function AddTable(tbl)
  SRT[E.myclass][tbl] = {}
end

local function AddSpell(tbl, spellID)
  SRT[E.myclass][tbl][#SRT[E.myclass][tbl] + 1] = spellID
end

function UF:UpdateRangeCheckSpells()
  if not SRT[E.myclass] then SRT[E.myclass] = {} end

  for tbl, spells in pairs(E.global.unitframe.spellRangeCheck[E.myclass]) do
    AddTable(tbl) --Create the table holding spells, even if it ends up being an empty table
    for spellID in pairs(spells) do
      local enabled = spells[spellID]
      if enabled then --We will allow value to be false to disable this spell from being used
        AddSpell(tbl, spellID, enabled)
      end
    end
  end
end

local function getUnit(unit)
  if not find(unit, "party") or not find(unit, "raid") then
    for i = 1, 4 do
      if UnitIsUnit(unit, "party"..i) then
        return "party"..i
      end
    end

    for i = 1, 40 do
      if UnitIsUnit(unit, "raid"..i) then
        return "raid"..i
      end
    end
  else
    return unit
  end
end

local function friendlyIsInRange(unit)
  if (not UnitIsUnit(unit, "player")) and (UnitInParty(unit) or UnitInRaid(unit)) then
    unit = getUnit(unit) -- swap the unit with `raid#` or `party#` when its NOT `player`, UnitIsUnit is true, and its not using `raid#` or `party#` already
  end

  local inRange, checkedRange = UnitInRange(unit)
  if checkedRange and not inRange then
    return false -- blizz checked and said the unit is out of range
  end

  if CheckInteractDistance(unit, 1) then
    return true -- within 28 yards (arg2 as 1 is Compare Achievements distance)
  end

  if SRT[E.myclass] then
    if SRT[E.myclass].resSpells and UnitIsDeadOrGhost(unit) and (#SRT[E.myclass].resSpells > 0) then -- dead with rez spells
      for _, spellID in ipairs(SRT[E.myclass].resSpells) do
        if SpellRange.IsSpellInRange(spellID, unit) == 1 then
          return true -- within rez range
        end
      end

      return false -- dead but no spells are in range
    end

    if SRT[E.myclass].friendlySpells and (#SRT[E.myclass].friendlySpells > 0) then -- you have some healy spell
      for _, spellID in ipairs(SRT[E.myclass].friendlySpells) do
        if SpellRange.IsSpellInRange(spellID, unit) == 1 then
          return true -- within healy spell range
        end
      end
    end
  end

  return false -- not within 28 yards and no spells in range
end

local function petIsInRange(unit)
  if CheckInteractDistance(unit, 2) then
    return true -- within 8 yards (arg2 as 2 is Trade distance)
  end

  if SRT[E.myclass] then
    if SRT[E.myclass].friendlySpells and (#SRT[E.myclass].friendlySpells > 0) then -- you have some healy spell
      for _, spellID in ipairs(SRT[E.myclass].friendlySpells) do
        if SpellRange.IsSpellInRange(spellID, unit) == 1 then
          return true
        end
      end
    end

    if SRT[E.myclass].petSpells and (#SRT[E.myclass].petSpells > 0) then -- you have some pet spell
      for _, spellID in ipairs(SRT[E.myclass].petSpells) do
        if SpellRange.IsSpellInRange(spellID, unit) == 1 then
          return true
        end
      end
    end
  end

  return false -- not within 8 yards and no spells in range
end

local function enemyIsInRange(unit)
  if CheckInteractDistance(unit, 2) then
    return true -- within 8 yards (arg2 as 2 is Trade distance)
  end

  if SRT[E.myclass] then
    if SRT[E.myclass].enemySpells and (#SRT[E.myclass].enemySpells > 0) then -- you have some damage spell
      for _, spellID in ipairs(SRT[E.myclass].enemySpells) do
        if SpellRange.IsSpellInRange(spellID, unit) == 1 then
          return true
        end
      end
    end
  end

  return false -- not within 8 yards and no spells in range
end

local function enemyIsInLongRange(unit)
  if SRT[E.myclass] then
    if SRT[E.myclass].longEnemySpells and (#SRT[E.myclass].longEnemySpells > 0) then -- you have some 30+ range damage spell
      for _, spellID in ipairs(SRT[E.myclass].longEnemySpells) do
        if SpellRange.IsSpellInRange(spellID, unit) == 1 then
          return true
        end
      end
    end
  end

  return false
end

function UF:UpdateRange(unit)
  if not self.Fader then return end
  local alpha

  unit = unit or self.unit

  if self.forceInRange or unit == "player" then
    alpha = self.Fader.MaxAlpha
  elseif self.forceNotInRange then
    alpha = self.Fader.MinAlpha
  elseif unit then
    if UnitCanAttack("player", unit) then
      alpha = ((enemyIsInRange(unit) or enemyIsInLongRange(unit)) and self.Fader.MaxAlpha) or self.Fader.MinAlpha
    elseif UnitIsUnit(unit, "pet") then
      alpha = (petIsInRange(unit) and self.Fader.MaxAlpha) or self.Fader.MinAlpha
    else
      alpha = (UnitIsConnected(unit) and friendlyIsInRange(unit) and self.Fader.MaxAlpha) or self.Fader.MinAlpha
    end
  else
    alpha = self.Fader.MaxAlpha
  end

  self.Fader.RangeAlpha = alpha
end