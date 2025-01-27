local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

--Lua functions
local _G = _G
local wipe, date = wipe, date
local format, select, type, ipairs, pairs = format, select, type, ipairs, pairs
local strmatch, strfind, tonumber, tostring = strmatch, strfind, tonumber, tostring
local tinsert, tremove = table.insert, table.remove
--WoW API / Variables
local GetActiveTalentGroup = GetActiveTalentGroup
local GetCVarBool = GetCVarBool
local GetFunctionCPUUsage = GetFunctionCPUUsage
local GetTalentTabInfo = GetTalentTabInfo
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHasVehicleUI = UnitHasVehicleUI
local IsInInstance = IsInInstance
local IsSpellKnown = IsSpellKnown

local MAX_TALENT_TABS = MAX_TALENT_TABS
local NONE = NONE

do -- other non-english locales require this
  E.UnlocalizedClasses = {}
  for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do E.UnlocalizedClasses[v] = k end
  for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE) do E.UnlocalizedClasses[v] = k end

  function E:UnlocalizedClassName(className)
    return (className and className ~= "") and E.UnlocalizedClasses[className]
  end
end

function E:IsFoolsDay()
  return strfind(date(), "04/01/") and not E.global.aprilFools
end

function E:ScanTooltipTextures(clean, grabTextures)
  local textures
  for i = 1, 10 do
    local tex = _G["ElvUI_ScanTooltipTexture"..i]
    local texture = tex and tex:GetTexture()
    if texture then
      if grabTextures then
        if not textures then textures = {} end
        textures[i] = texture
      end
      if clean then
        tex:SetTexture()
      end
    end
  end

  return textures
end

function E:CheckTalentTree(tree)
  local talentTree = self.TalentTree
  if not talentTree then return false end

  if type(tree) == "number" then
    return tree == talentTree
  elseif type(tree) == "table" then
    for _, index in ipairs(tree) do
      if index == talentTree then
        return true
      end
    end
  end
end

function E:GetPlayerRole()
  local isTank, isHealer, isDamage = UnitGroupRolesAssigned("player")

  if isTank or isHealer or isDamage then
    return isTank and "TANK" or isHealer and "HEALER" or isDamage and "DAMAGER"
  else
    if self.HealingClasses[self.myclass] ~= nil and self:CheckTalentTree(self.HealingClasses[E.myclass]) then
      return "HEALER"
    elseif E.Role == "Tank" then
      return "TANK"
    else
      return "DAMAGER"
    end
  end
end

function E:GetTalentSpecInfo(isInspect)
  local talantGroup = GetActiveTalentGroup(isInspect)
  local maxPoints, specIdx, specName, specIcon = 0, 0

  for i = 1, MAX_TALENT_TABS do
    local name, icon, pointsSpent = GetTalentTabInfo(i, isInspect, nil, talantGroup)
    if maxPoints < pointsSpent then
      maxPoints = pointsSpent
      specIdx = i
      specName = name
      specIcon = icon
    end
  end

  if not specName then
    specName = NONE
  end
  if not specIcon then
    specIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
  end

  return specIdx, specName, specIcon
end

function E:CheckRole(event)
  local talentTree = self:GetTalentSpecInfo()
  local role

  if type(self.ClassRole[self.myclass]) == "string" then
    role = self.ClassRole[self.myclass]
  elseif talentTree then
    if self.myclass == "DRUID" and talentTree == 2 then
      role = select(5, GetTalentInfo(talentTree, 22)) > 0 and "Tank" or "Melee"
    elseif self.myclass == "DEATHKNIGHT" and talentTree == 2 then
      role = select(5, GetTalentInfo(talentTree, 25)) > 0 and "Tank" or "Melee"
    else
      role = self.ClassRole[self.myclass][talentTree]
    end
  end

  if not role then role = "Melee" end

  if self.Role ~= role then
    self.Role = role
    self.TalentTree = talentTree
    self.callbacks:Fire("RoleChanged")
  end

  if E.myclass == "SHAMAN" then
    if talentTree == 3 and IsSpellKnown(51886) then
      self.DispelClasses[self.myclass].Curse = true
    else
      self.DispelClasses[self.myclass].Curse = false
    end
  end

  if event == "SPELL_UPDATE_USABLE" then
    self:UnregisterEvent(event)
  end
end

function E:IsDispellableByMe(debuffType)
  if not self.DispelClasses[self.myclass] then return end

  if self.DispelClasses[self.myclass][debuffType] then return true end
end

do
  local LBF = E.Libs.LBF
  local LBFGroupToTableElement = {
    ["ActionBars"] = "actionbar",
    ["Auras"] = "auras"
  }

  function E:LBFCallback(SkinID, _, _, Group)
    if not E.private then return end

    local element = LBFGroupToTableElement[Group]
    if element then
      if E.private[element].lbf.enable then
        E.private[element].lbf.skin = SkinID
      end
    end
  end

  if LBF then
    LBF:RegisterSkinCallback("ElvUI", E.LBFCallback, E)
  end
end

do
  local CPU_USAGE = {}
  local function CompareCPUDiff(showall, minCalls)
    local greatestUsage, greatestCalls, greatestName, newName, newFunc
    local greatestDiff, lastModule, mod, usage, calls, diff = 0

    for name, oldUsage in pairs(CPU_USAGE) do
      newName, newFunc = strmatch(name, "^([^:]+):(.+)$")
      if not newFunc then
        E:Print("CPU_USAGE:", name, newFunc)
      else
        if newName ~= lastModule then
          mod = E:GetModule(newName, true) or E
          lastModule = newName
        end
        usage, calls = GetFunctionCPUUsage(mod[newFunc], true)
        diff = usage - oldUsage
        if showall and (calls > minCalls) then
          E:Print("Name("..name..") Calls("..calls..") Diff("..(diff > 0 and format("%.3f", diff) or 0)..")")
        end
        if (diff > greatestDiff) and calls > minCalls then
          greatestName, greatestUsage, greatestCalls, greatestDiff = name, usage, calls, diff
        end
      end
    end

    if greatestName then
      E:Print(greatestName.." had the CPU usage of: "..(greatestUsage > 0 and format("%.3f", greatestUsage) or 0).."ms. And has been called "..greatestCalls.." times.")
    else
      E:Print("CPU Usage: No CPU Usage differences found.")
    end

    wipe(CPU_USAGE)
  end

  function E:GetTopCPUFunc(msg)
    if not GetCVarBool("scriptProfile") then
      E:Print("For `/cpuusage` to work, you need to enable script profiling via: `/console scriptProfile 1` then reload. Disable after testing by setting it back to 0.")
      return
    end

    local module, showall, delay, minCalls = strmatch(msg, "^(%S+)%s*(%S*)%s*(%S*)%s*(.*)$")
    local checkCore, mod = (not module or module == "") and "E"

    showall = (showall == "true" and true) or false
    delay = (delay == "nil" and nil) or tonumber(delay) or 5
    minCalls = (minCalls == "nil" and nil) or tonumber(minCalls) or 15

    wipe(CPU_USAGE)
    if module == "all" then
      for moduName, modu in pairs(self.modules) do
        for funcName, func in pairs(modu) do
          if (funcName ~= "GetModule") and (type(func) == "function") then
            CPU_USAGE[moduName..":"..funcName] = GetFunctionCPUUsage(func, true)
          end
        end
      end
    else
      if not checkCore then
        mod = self:GetModule(module, true)
        if not mod then
          self:Print(module.." not found, falling back to checking core.")
          mod, checkCore = self, "E"
        end
      else
        mod = self
      end
      for name, func in pairs(mod) do
        if (name ~= "GetModule") and type(func) == "function" then
          CPU_USAGE[(checkCore or module)..":"..name] = GetFunctionCPUUsage(func, true)
        end
      end
    end

    self:Delay(delay, CompareCPUDiff, showall, minCalls)
    self:Print("Calculating CPU Usage differences (module: "..(checkCore or module)..", showall: "..tostring(showall)..", minCalls: "..tostring(minCalls)..", delay: "..tostring(delay)..")")
  end
end

function E:RegisterObjectForVehicleLock(object, originalParent)
  if not object or not originalParent then
    E:Print("Error. Usage: RegisterObjectForVehicleLock(object, originalParent)")
    return
  end

  object = _G[object] or object
  --Entering/Exiting vehicles will often happen in combat.
  --For this reason we cannot allow protected objects.
  if object.IsProtected and object:IsProtected() then
    E:Print("Error. Object is protected and cannot be changed in combat.")
    return
  end

  --Check if we are already in a vehicles
  if UnitHasVehicleUI("player") then
    object:SetParent(E.HiddenFrame)
  end

  --Add object to table
  E.VehicleLocks[object] = originalParent
end

function E:UnregisterObjectForVehicleLock(object)
  if not object then
    E:Print("Error. Usage: UnregisterObjectForVehicleLock(object)")
    return
  end

  object = _G[object] or object
  --Check if object was registered to begin with
  if not E.VehicleLocks[object] then return end

  --Change parent of object back to original parent
  local originalParent = E.VehicleLocks[object]
  if originalParent then
    object:SetParent(originalParent)
  end

  --Remove object from table
  E.VehicleLocks[object] = nil
end

function E:EnterVehicleHideFrames(_, unit)
  if unit ~= "player" then return end

  for object in pairs(E.VehicleLocks) do
    object:SetParent(E.HiddenFrame)
  end
end

function E:ExitVehicleShowFrames(_, unit)
  if unit ~= "player" then return end

  for object, originalParent in pairs(E.VehicleLocks) do
    object:SetParent(originalParent)
  end
end

E.CreatedSpinnerFrames = {}

function E:CreateSpinnerFrame()
  local frame = CreateFrame("Frame")
  frame:EnableMouse(true)
  frame:Hide()

  frame.Background = frame:CreateTexture(nil, "BACKGROUND")
  frame.Background:SetTexture(0, 0, 0, 0.5)
  frame.Background:SetAllPoints()

  frame.Framing = frame:CreateTexture()
  frame.Framing:Size(48)
  frame.Framing:SetTexture(E.Media.Textures.StreamFrame)
  frame.Framing:SetPoint("CENTER")

  frame.Circle = frame:CreateTexture(nil, "BORDER")
  frame.Circle:Size(48)
  frame.Circle:SetTexture(E.Media.Textures.StreamCircle)
  frame.Circle:SetVertexColor(1, .82, 0)
  frame.Circle:SetPoint("CENTER")

  frame.Circle.Anim = frame.Circle:CreateAnimationGroup()
  frame.Circle.Anim:SetLooping("REPEAT")
  frame.Circle.Anim.Rotation = frame.Circle.Anim:CreateAnimation("Rotation")
  frame.Circle.Anim.Rotation:SetDuration(1)
  frame.Circle.Anim.Rotation:SetDegrees(-360)

  frame.Spark = frame:CreateTexture(nil, "OVERLAY")
  frame.Spark:Size(48)
  frame.Spark:SetTexture(E.Media.Textures.StreamSpark)
  frame.Spark:SetPoint("CENTER")

  frame.Spark.Anim = frame.Spark:CreateAnimationGroup()
  frame.Spark.Anim:SetLooping("REPEAT")
  frame.Spark.Anim.Rotation = frame.Spark.Anim:CreateAnimation("Rotation")
  frame.Spark.Anim.Rotation:SetDuration(1)
  frame.Spark.Anim.Rotation:SetDegrees(-360)

  return frame
end

function E:StartSpinnerFrame(parent, left, top, right, bottom)
  if parent.SpinnerFrame then return end

  local frame = #self.CreatedSpinnerFrames > 0 and tremove(self.CreatedSpinnerFrames) or self:CreateSpinnerFrame()

  frame:SetParent(parent)
  frame:SetFrameLevel(parent:GetFrameLevel() + 10)
  frame:ClearAllPoints()
  if top or bottom or left or right then
    frame:Point("TOPLEFT", left or 0, -top or 0)
    frame:Point("BOTTOMRIGHT", -right or 0, bottom or 0)
  else
    frame:SetAllPoints()
  end

  frame:Show()
  frame.Circle.Anim.Rotation:Play()
  frame.Spark.Anim.Rotation:Play()

  parent.SpinnerFrame = frame
end

function E:StopSpinnerFrame(parent)
  if not parent.SpinnerFrame then return end

  local frame = parent.SpinnerFrame
  frame:Hide()
  frame.Circle.Anim:Stop()
  frame.Spark.Anim:Stop()

  parent.SpinnerFrame = nil
  tinsert(self.CreatedSpinnerFrames, frame)
end

function E:RequestBGInfo()
  RequestBattlefieldScoreData()
end

-- [ HookScript ]
-- Securely post-hooks a script handler.
-- 'f'          [frame]             the frame which needs a hook
-- 'script'     [string]            the handler to hook
-- 'func'       [function]          the function that should be added
function HookScript(f, script, func)
  local prev = f:GetScript(script)
  f:SetScript(script, function(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    if prev then prev(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    func(a1,a2,a3,a4,a5,a6,a7,a8,a9)
  end)
end

-- [ Enable Movable ]
-- Set all necessary functions to make a already existing frame movable.
-- 'name'       [frame/string]  Name of the Frame that should be movable
-- 'addon'      [string]        Addon that must be loaded before being able to access the frame
-- 'blacklist'  [table]         A list of frames that should be deactivated for mouse usage
function E:EnableMovable(name, blacklist, dontSave, addon)
  local OnDragStart = function() this:StartMoving() end
  local OnDragStop  = function() this:StopMovingOrSizing() end
  local OnShow      = function()
    if not this.lastPoint then return end
    this:ClearAllPoints()
    this:Point(this.lastPoint[1], this.lastPoint[4], this.lastPoint[5])
  end
  local OnHide = function()
    this.lastPoint = {this:GetPoint()}
  end

  if addon then
    local scan = CreateFrame("Frame")
    scan:RegisterEvent("ADDON_LOADED")
    scan:SetScript("OnEvent", function()
      if arg1 == addon then
        local frame = _G[name]

        if blacklist then
          for _, disable in pairs(blacklist) do
            _G[disable]:EnableMouse(false)
          end
        end

        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:HookScript("OnDragStart", OnDragStart)
        frame:HookScript("OnDragStop", OnDragStop)

        if not dontSave then
          frame:HookScript("OnShow", OnShow)
          frame:HookScript("OnHide", OnHide)
        end

        this:UnregisterAllEvents()
      end
    end)
  else
    if blacklist then
      for _, disable in pairs(blacklist) do
        _G[disable]:EnableMouse(false)
      end
    end

    local frame = name
    if type(name) == "string" then frame = _G[name] end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:HookScript("OnDragStart", OnDragStart)
    frame:HookScript("OnDragStop", OnDragStop)

    if not dontSave then
      frame:HookScript("OnShow", OnShow)
      frame:HookScript("OnHide", OnHide)
    end
  end
end

-- [ EnableClickRotate ]
-- Enables Modelframes to be rotated by click-drag
-- 'frame'    [frame]         the modelframe that should be used
function E:EnableClickRotate(frame, dontSave, speed)
  speed = speed or 0.025
  frame:EnableMouse(true)

  if not dontSave then
    HookScript(frame, "OnShow", function()
      if this.rotation then this:SetRotation(this.rotation) end
    end)
  end

  HookScript(frame, "OnUpdate", function()
    if this.rotate then
      local x,_ = GetCursorPosition()
      if this.curX > x then
        this.rotation = this.rotation - abs(x-this.curX) * speed
      elseif this.curX < x then
        this.rotation = this.rotation + abs(x-this.curX) * speed
      end
      this:SetRotation(this.rotation)
      this.curX = x
    end
  end)

  HookScript(frame, "OnMouseDown", function()
    if arg1 == "LeftButton" then
      this.rotate = true
      this.curX = GetCursorPosition()
    end
  end)
  HookScript(frame, "OnMouseUp", function()
    this.rotate, this.curX = nil, 0
  end)
end

-- [ EnableWheelZoom ]
-- Enables Modelframes to be zoomed with the mouse wheel
-- 'frame'    [frame]         the modelframe that should be used
function E:EnableWheelZoom(frame, dontSave, speed)
  local speed = speed or 0.5
  frame:EnableMouseWheel(true)

  if not dontSave then
    HookScript(frame, "OnShow", function()
      this.origZoomX, y, z = this:GetPosition()
      if this.zoomX then this:SetPosition(this.zoomX, y, z) end
    end)
  end

  HookScript(frame, "OnHide", function()
    local _, y, z = this:GetPosition()
    this:SetPosition(this.origZoomX, y, z)
  end)

  HookScript(frame, "OnMouseWheel", function(_, delta)
    local x, y, z = this:GetPosition()
    this.zoomX = math.min(5, math.max(-10, x + (delta == 1 and speed or -speed)))
    this:SetPosition(this.zoomX, y, z)
  end)
end

-- [ Enable Draggable ]
-- Set all necessary functions to make a already existing model frame draggable.
-- 'name'       [frame/string]  Name of the Frame that should be movable
function E:EnableMouseDrag(frame, dontSave, invert, button, step)
  button = button or "RightButton"
  step = step or 0.01

  frame:EnableMouse(true)
  frame.modelDrag = false
  frame.curX, frame.curY = 0, 0

  if not dontSave then
    HookScript(frame, "OnShow", function()
      local x, y, z = this:GetPosition()
      this.origDragYZ = { y = y, z = z }
      if this.dragYZ then
        this:SetPosition(x, this.dragYZ.y, this.dragYZ.z)
      end
    end)
  end

  HookScript(frame, "OnHide", function()
    local x, y, z = this:GetPosition()
    this:SetPosition(x, this.origDragYZ.y, this.origDragYZ.z)
  end)

  HookScript(frame, "OnMouseDown", function(_, btn)
    if btn == button then
      this.curX, this.curY = GetCursorPosition()
      this.mouseDrag = true
    end
  end)
  HookScript(frame, "OnMouseUp", function(_, btn)
    if btn == button then this.mouseDrag = false end
  end)
  HookScript(frame, "OnUpdate", function()
    if not this.mouseDrag then
      return
    end
    local curX, curY = GetCursorPosition()
    local difX, difY = (curX-this.curX) * step, (curY-this.curY) * step

    if invert then difX, difY = -difX, -difY end

    local x, y, z = this:GetPosition()
    local dragY = math.min(1.5, math.max(-1.5, y + difX))
    local dragZ = math.min(1.5, math.max(-1.5, z + difY))

    this.dragYZ = { y = dragY, z = dragZ }
    this:SetPosition(x, this.dragYZ.y, this.dragYZ.z)
    this.curX, this.curY = curX, curY
  end)
end

function E:PLAYER_ENTERING_WORLD()
  if not self.MediaUpdated then
    self:UpdateMedia()
    self.MediaUpdated = true
  end

  local _, instanceType = IsInInstance()
  if instanceType == "pvp" then
    self.BGTimer = self:ScheduleRepeatingTimer("RequestBGInfo", 5)
    self:RequestBGInfo()
  elseif self.BGTimer then
    self:CancelTimer(self.BGTimer)
    self.BGTimer = nil
  end
end

function E:PLAYER_LEVEL_UP(_, level)
  E.mylevel = level
end

function E:LoadAPI()
  self:RegisterEvent("PLAYER_LEVEL_UP")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("SPELL_UPDATE_USABLE", "CheckRole")
  self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "CheckRole")
  self:RegisterEvent("PLAYER_TALENT_UPDATE", "CheckRole")
--  self:RegisterEvent("CHARACTER_POINTS_CHANGED", "CheckRole")
--  self:RegisterEvent("UNIT_INVENTORY_CHANGED", "CheckRole")
--  self:RegisterEvent("UPDATE_BONUS_ACTIONBAR", "CheckRole")
  self:RegisterEvent("UNIT_ENTERED_VEHICLE", "EnterVehicleHideFrames")
  self:RegisterEvent("UNIT_EXITED_VEHICLE", "ExitVehicleShowFrames")
  self:RegisterEvent("UI_SCALE_CHANGED", "PixelScaleChanged")

  if date("%d%m") ~= "0104" then
    E.global.aprilFools = nil
  end

  do -- setup cropIcon texCoords
    local opt = E.db.general.cropIcon
    local modifier = 0.04 * opt
    for i, v in ipairs(E.TexCoords) do
      if i % 2 == 0 then
        E.TexCoords[i] = v - modifier
      else
        E.TexCoords[i] = v + modifier
      end
    end
  end
end