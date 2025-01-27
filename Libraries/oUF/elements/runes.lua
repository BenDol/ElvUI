--[[
# Element: Runes

Handles the visibility and updating of Death Knight's runes.

## Widget

Runes - An `table` holding `StatusBar`s.

## Sub-Widgets

.bg - A `Texture` used as a background. It will inherit the color of the main StatusBar.

## Notes

A default texture will be applied if the sub-widgets are StatusBars and don't have a texture set.

## Options

.colorSpec - Use `self.colors.runes[specID]` to color the bar based on player's spec. `specID` is defined by the return
             value of [GetSpecialization](http://wowprogramming.com/docs/api/GetSpecialization) (boolean)

## Sub-Widgets Options

.multiplier - Used to tint the background based on the main widgets R, G and B values. Defaults to 1 (number)[0-1]

## Examples

    local Runes = {}
    for index = 1, 6 do
        -- Position and size of the rune bar indicators
        local Rune = CreateFrame('StatusBar', nil, self)
        Rune:SetSize(120 / 6, 20)
        Rune:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', index * 120 / 6, 0)

        Runes[index] = Rune
    end

    -- Register with oUF
    self.Runes = Runes
--]]

if(select(2, UnitClass('player')) ~= 'DEATHKNIGHT') then return end

local _, ns = ...
local oUF = ns.oUF

local floor = math.floor

local GetRuneCooldown = GetRuneCooldown
local GetRuneType = GetRuneType
local GetTime = GetTime
local UnitHasVehicleUI = UnitHasVehicleUI

local runemap = {1, 2, 5, 6, 3, 4}

local VisibilityPath

local function onUpdate(self, elapsed)
  local duration = self.duration + elapsed
  self.duration = duration
  self:SetValue(duration)
end

local function UpdateType(self, event, runeID, alt)
  local element = self.Runes
  local rune = element[runemap[runeID]]
  local runeType = GetRuneType(runeID) or alt

  if not runeType then return end

  local color = self.colors.runes[runeType]
  local r, g, b = color[1], color[2], color[3]

  rune:SetStatusBarColor(r, g, b)

  if(rune.bg) then
    local mu = rune.bg.multiplier or 1
    rune.bg:SetVertexColor(r * mu, g * mu, b * mu)
  end

  if(element.PostUpdateType) then
    return element:PostUpdateType(rune, runeID, alt)
  end
end

local function Update(self, event, runeID)
  local element = self.Runes
  local rune = element[runemap[runeID]]
  if(not rune) then return end

  local start, duration, runeReady
  if(UnitHasVehicleUI('player')) then
    rune:Hide()
  else
    start, duration, runeReady = GetRuneCooldown(runeID)
    if(not start) then return end

    if(runeReady) then
      rune:SetMinMaxValues(0, 1)
      rune:SetValue(1)
      rune:SetScript('OnUpdate', nil)
    else
      rune.duration = GetTime() - start
      rune.max = duration
      rune:SetMinMaxValues(0, duration)
      rune:SetValue(0)
      rune:SetScript('OnUpdate', onUpdate)
    end

    rune:Show()
  end

  --[[ Callback: Runes:PostUpdate(rune, runeID, start, duration, isReady)
  Called after the element has been updated.

  * self     - the Runes element
  * rune     - the updated rune (StatusBar)
  * runeID   - the index of the updated rune (number)
  * start    - the value of `GetTime()` when the rune cooldown started (0 for ready) (number)
  * duration - the duration of the rune's cooldown (number)
  * isReady  - indicates if the rune is ready for use (boolean)
  --]]
  if(element.PostUpdate) then
    return element:PostUpdate(rune, runeID, start, duration, runeReady)
  end
end

local function Path(self, event, ...)
  local element = self.Runes
  --[[ Override: Runes.Override(self, event, ...)
  Used to completely override the internal update function.

  * self  - the parent object
  * event - the event triggering the update (string)
  * ...   - the arguments accompanying the event
  --]]
  local UpdateMethod = element.Override or Update
  if(event == 'RUNE_POWER_UPDATE') then
    return UpdateMethod(self, event, ...)
  else
    --[[ Override: Runes:UpdateType(powerType)
    Used to completely override the internal function for updating the widgets' colors.

    * self  - the Runes element
    * index - the index of the updated rune (number)
    --]]
    local UpdateTypeMethod = element.UpdateType or UpdateType
    for index = 1, #element do
      UpdateTypeMethod(self, element, index)
      UpdateMethod(self, event, index)
    end
  end
end

local function RunesEnable(self)
  self:RegisterEvent('UNIT_ENTERED_VEHICLE', VisibilityPath)
  self:UnregisterEvent('UNIT_EXITED_VEHICLE', VisibilityPath)

  self.Runes:Show()

  if self.Runes.PostUpdateVisibility then
    self.Runes:PostUpdateVisibility(true, not self.Runes.isEnabled)
  end

  self.Runes.isEnabled = true

  Path(self, 'RunesEnable')
end

local function RunesDisable(self)
  self:UnregisterEvent('UNIT_ENTERED_VEHICLE', VisibilityPath)
  self:RegisterEvent('UNIT_EXITED_VEHICLE', VisibilityPath)

  self.Runes:Hide()

  if self.Runes.PostUpdateVisibility then
    self.Runes:PostUpdateVisibility(false, self.Runes.isEnabled)
  end

  self.Runes.isEnabled = false

  Path(self, 'RunesDisable')
end

local function Visibility(self, event, ...)
  local element = self.Runes
  local shouldEnable

  if not (UnitHasVehicleUI('player')) then
    shouldEnable = true
  end

  local isEnabled = element.isEnabled
  if(shouldEnable and not isEnabled) then
    RunesEnable(self)
  elseif(not shouldEnable and (isEnabled or isEnabled == nil)) then
    RunesDisable(self)
  elseif(shouldEnable and isEnabled) then
    Path(self, event, ...)
  end
end

VisibilityPath = function(self, ...)
  return (self.Runes.OverrideVisibility or Visibility) (self, ...)
end

local ForceUpdate = function(element)
  return VisibilityPath(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local function Enable(self, unit)
  local element = self.Runes
  if(element and unit == 'player') then
    element.__owner = self
    element.ForceUpdate = ForceUpdate

    for i = 1, #element do
      local rune = element[runemap[i]]
      if(rune:IsObjectType('StatusBar') and not rune:GetStatusBarTexture()) then
        rune:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
      end

      -- From my minor testing this is a okey solution. A full login always remove
      -- the death runes, or at least the clients knowledge about them.
      UpdateType(self, nil, i, floor((i + 1) / 2))
    end

    self:RegisterEvent('RUNE_POWER_UPDATE', Path, true)
    self:RegisterEvent('RUNE_TYPE_UPDATE', UpdateType, true)
    self:RegisterEvent('PLAYER_ENTERING_WORLD', Path)

    -- oUF leaves the vehicle events registered on the player frame, so
    -- buffs and such are correctly updated when entering/exiting vehicles.
    --
    -- This however makes the code also show/hide the RuneFrame.
    RuneFrame.Show = RuneFrame.Hide
    RuneFrame:Hide()

    return true
  end
end

local function Disable(self)
  RuneFrame.Show = nil
  RuneFrame:Show()

  local element = self.Runes
  if(element) then
    for i = 1, #element do
      element[i]:Hide()
    end

    self:SetScript('OnUpdate', nil)

    self:UnregisterEvent('RUNE_POWER_UPDATE', Path)
    self:UnregisterEvent('RUNE_TYPE_UPDATE', UpdateType)
    self:UnregisterEvent('PLAYER_ENTERING_WORLD', Path)

    RunesDisable(self)
  end
end

oUF:AddElement('Runes', VisibilityPath, Enable, Disable)