local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")
local TT = E:GetModule("Tooltip")
local LDB = E.Libs.LDB
local LSM = E.Libs.LSM

--Lua functions
local pairs, type, error = pairs, type, error
local strlen = strlen
--WoW API / Variables
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance

function DT:Initialize()
  --if E.db.datatexts.enable ~= true then return end

  self.Initialized = true
  self.db = E.db.datatexts

  self.tooltip = CreateFrame("GameTooltip", "DatatextTooltip", nil, "GameTooltipTemplate")
  self.tooltip:SetParent(E.UIParent)
  self.tooltip:SetFrameStrata("TOOLTIP")
  TT:HookScript(self.tooltip, "OnShow", "SetStyle")

  -- Ignore header font size on DatatextTooltip
  local font = LSM:Fetch("font", E.db.tooltip.font)
  local fontOutline = E.db.tooltip.fontOutline
  local textSize = E.db.tooltip.textFontSize
  DatatextTooltipTextLeft1:FontTemplate(font, textSize, fontOutline)
  DatatextTooltipTextRight1:FontTemplate(font, textSize, fontOutline)

  self:RegisterLDB()
  LDB.RegisterCallback(E, "LibDataBroker_DataObjectCreated", DT.SetupObjectLDB)

  self:LoadDataTexts()

  self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

DT.RegisteredPanels = {}
DT.RegisteredDataTexts = {}

DT.PointLocation = {
  [1] = "middle",
  [2] = "left",
  [3] = "right"
}

function DT:PLAYER_ENTERING_WORLD()
  local inInstance, instanceType = IsInInstance()
  self.isInPVP = inInstance and instanceType == "pvp"

  if (not self.isInPVP and self.ShowingBGStats)
  or (self.isInPVP and not self.ShowingBGStats and self.db.battleground)
  then
    self:LoadDataTexts()
    self.ShowingBGStats = not self.ShowingBGStats
  end
end

local LDBHex = "|cffFFFFFF"
function DT:SetupObjectLDB(name, obj)
  local curFrame = nil

  local function OnEnter(dt)
    DT:SetupTooltip(dt)
    if obj.OnTooltipShow then
      obj.OnTooltipShow(DT.tooltip)
    end
    if obj.OnEnter then
      obj.OnEnter(dt)
    end
    DT.tooltip:Show()
  end

  local function OnLeave(dt)
    if obj.OnLeave then
      obj.OnLeave(dt)
    end
    DT.tooltip:Hide()
  end

  local function OnClick(dt, button)
    if obj.OnClick then
      obj.OnClick(dt, button)
    end
  end

  local function textUpdate(_, Name, _, Value)
    if Value == nil or (strlen(Value) >= 3) or Value == "n/a" or Name == Value then
      curFrame.text:SetText(Value ~= "n/a" and Value or Name)
    else
      curFrame.text:SetFormattedText("%s: %s%s|r", Name, LDBHex, Value)
    end
  end

  local function OnCallback(newHex)
    if name and obj then
      LDBHex = newHex
      LDB.callbacks:Fire("LibDataBroker_AttributeChanged_"..name.."_text", name, nil, obj.text, obj)
    end
  end

  local function OnEvent(dt)
    curFrame = dt
    LDB:RegisterCallback("LibDataBroker_AttributeChanged_"..name.."_text", textUpdate)
    LDB:RegisterCallback("LibDataBroker_AttributeChanged_"..name.."_value", textUpdate)
    OnCallback(LDBHex)
  end

  DT:RegisterDatatext(name, {"PLAYER_ENTERING_WORLD"}, OnEvent, nil, OnClick, OnEnter, OnLeave)
  E.valueColorUpdateFuncs[OnCallback] = true

  --Update config if it has been loaded
  if DT.PanelLayoutOptions then
    DT:PanelLayoutOptions()
  end
end

function DT:RegisterLDB()
  for name, obj in LDB:DataObjectIterator() do
    self:SetupObjectLDB(name, obj)
  end
end

function DT:GetDataPanelPoint(panel, i, numPoints)
  if numPoints == 1 then
    return "CENTER", panel, "CENTER"
  else
    if i == 1 then
      return "CENTER", panel, "CENTER"
    elseif i == 2 then
      return "RIGHT", panel.dataPanels.middle, "LEFT", -4, 0
    elseif i == 3 then
      return "LEFT", panel.dataPanels.middle, "RIGHT", 4, 0
    end
  end
end

function DT:UpdateAllDimensions()
  for _, panel in pairs(DT.RegisteredPanels) do
    local width = (panel:GetWidth() / panel.numPoints) - 4
    local height = panel:GetHeight() - 4
    for i = 1, panel.numPoints do
      local pointIndex = DT.PointLocation[i]
      panel.dataPanels[pointIndex]:Width(width)
      panel.dataPanels[pointIndex]:Height(height)
      panel.dataPanels[pointIndex]:Point(DT:GetDataPanelPoint(panel, i, panel.numPoints))
    end
  end
end

function DT:Data_OnLeave()
  DT.tooltip:Hide()
end

function DT:SetupTooltip(panel)
  local parent = panel:GetParent()
  self.tooltip:Hide()
  self.tooltip:SetOwner(parent, parent.anchor, parent.xOff, parent.yOff)
  self.tooltip:ClearLines()
  GameTooltip:Hide()
end

function DT:RegisterPanel(panel, numPoints, anchor, xOff, yOff)
  DT.RegisteredPanels[panel:GetName()] = panel
  panel.dataPanels = {}
  panel.numPoints = numPoints

  panel.xOff = xOff
  panel.yOff = yOff
  panel.anchor = anchor
  for i = 1, numPoints do
    local pointIndex = DT.PointLocation[i]
    if not panel.dataPanels[pointIndex] then
      panel.dataPanels[pointIndex] = CreateFrame("Button", "DataText"..i, panel)
      panel.dataPanels[pointIndex]:RegisterForClicks("AnyUp")
      panel.dataPanels[pointIndex].text = panel.dataPanels[pointIndex]:CreateFontString(nil, "OVERLAY")
      panel.dataPanels[pointIndex].text:SetAllPoints()
      panel.dataPanels[pointIndex].text:FontTemplate()
      panel.dataPanels[pointIndex].text:SetJustifyH("CENTER")
      panel.dataPanels[pointIndex].text:SetJustifyV("MIDDLE")
    end

    panel.dataPanels[pointIndex]:Point(DT:GetDataPanelPoint(panel, i, numPoints))
  end

  panel:SetScript("OnSizeChanged", DT.UpdateAllDimensions)
  DT.UpdateAllDimensions(panel)
end

function DT:AssignPanelToDataText(panel, data)
  panel.name = ""
  if data.name then
    panel.name = data.name
  end

  if data.events then
    for _, event in pairs(data.events) do
      panel:RegisterEvent(event)
    end
  end

  if data.eventFunc then
    panel:SetScript("OnEvent", data.eventFunc)
    data.eventFunc(panel, "ELVUI_FORCE_RUN")
  end

  if data.onUpdate then
    panel:SetScript("OnUpdate", data.onUpdate)
    data.onUpdate(panel, 20000)
  end

  if data.onClick then
    panel:SetScript("OnClick", function(p, button)
      if E.db.datatexts.noCombatClick and InCombatLockdown() then return end
      data.onClick(p, button)
    end)
  end

  if data.onEnter then
    panel:SetScript("OnEnter", function(p)
      if E.db.datatexts.noCombatHover and InCombatLockdown() then return end
      data.onEnter(p)
    end)
  end

  if data.onLeave then
    panel:SetScript("OnLeave", data.onLeave)
  else
    panel:SetScript("OnLeave", DT.Data_OnLeave)
  end
end

function DT:LoadDataTexts()
  LDB:UnregisterAllCallbacks(self)

  local fontTemplate = LSM:Fetch("font", self.db.font)
  local enableBGPanel = self.isInPVP and not self.ForceHideBGStats and self.db.battleground
  local pointIndex, showBGPanel

  if ElvConfigToggle then
    ElvConfigToggle.text:FontTemplate(fontTemplate, self.db.fontSize, self.db.fontOutline)
  end

  for panelName, panel in pairs(DT.RegisteredPanels) do
    showBGPanel = enableBGPanel and (panelName == "LeftChatDataPanel" or panelName == "RightChatDataPanel")

    --Restore Panels
    for i = 1, panel.numPoints do
      pointIndex = DT.PointLocation[i]
      panel.dataPanels[pointIndex]:UnregisterAllEvents()
      panel.dataPanels[pointIndex]:SetScript("OnUpdate", nil)
      panel.dataPanels[pointIndex]:SetScript("OnEnter", nil)
      panel.dataPanels[pointIndex]:SetScript("OnLeave", nil)
      panel.dataPanels[pointIndex]:SetScript("OnClick", nil)
      panel.dataPanels[pointIndex].text:FontTemplate(fontTemplate, self.db.fontSize, self.db.fontOutline)
      panel.dataPanels[pointIndex].text:SetWordWrap(self.db.wordWrap)
      panel.dataPanels[pointIndex].text:SetText(nil)
      panel.dataPanels[pointIndex].pointIndex = pointIndex

      if showBGPanel then
        panel.dataPanels[pointIndex]:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
        panel.dataPanels[pointIndex]:SetScript("OnEvent", DT.UPDATE_BATTLEFIELD_SCORE)
        panel.dataPanels[pointIndex]:SetScript("OnEnter", DT.BattlegroundStats)
        panel.dataPanels[pointIndex]:SetScript("OnLeave", DT.Data_OnLeave)
        panel.dataPanels[pointIndex]:SetScript("OnClick", DT.HideBattlegroundTexts)
        DT.UPDATE_BATTLEFIELD_SCORE(panel.dataPanels[pointIndex])
      else
        --Register Panel to Datatext
        for name, data in pairs(DT.RegisteredDataTexts) do
          for option, value in pairs(self.db.panels) do
            if value and type(value) == "table" then
              if option == panelName and self.db.panels[option][pointIndex] and self.db.panels[option][pointIndex] == name then
                DT:AssignPanelToDataText(panel.dataPanels[pointIndex], data)
              end
            elseif value and type(value) == "string" and value == name then
              if self.db.panels[option] == name and option == panelName then
                DT:AssignPanelToDataText(panel.dataPanels[pointIndex], data)
              end
            end
          end
        end
      end
    end
  end

  if DT.ForceHideBGStats then
    DT.ForceHideBGStats = nil
  end
end

--[[
  DT:RegisterDatatext(name, events, eventFunc, updateFunc, clickFunc, onEnterFunc, onLeaveFunc, localizedName)

  name - name of the datatext (required)
  events - must be a table with string values of event names to register
  eventFunc - function that gets fired when an event gets triggered
  updateFunc - onUpdate script target function
  click - function to fire when clicking the datatext
  onEnterFunc - function to fire OnEnter
  onLeaveFunc - function to fire OnLeave, if not provided one will be set for you that hides the tooltip.
  localizedName - localized name of the datetext
]]
function DT:RegisterDatatext(name, events, eventFunc, updateFunc, clickFunc, onEnterFunc, onLeaveFunc, localizedName)
  if name then
    DT.RegisteredDataTexts[name] = {}
  else
    error("Cannot register datatext no name was provided.")
  end

  DT.RegisteredDataTexts[name].name = name

  if type(events) ~= "table" and events ~= nil then
    error("Events must be registered as a table.")
  else
    DT.RegisteredDataTexts[name].events = events
    DT.RegisteredDataTexts[name].eventFunc = eventFunc
  end

  if updateFunc and type(updateFunc) == "function" then
    DT.RegisteredDataTexts[name].onUpdate = updateFunc
  end

  if clickFunc and type(clickFunc) == "function" then
    DT.RegisteredDataTexts[name].onClick = clickFunc
  end

  if onEnterFunc and type(onEnterFunc) == "function" then
    DT.RegisteredDataTexts[name].onEnter = onEnterFunc
  end

  if onLeaveFunc and type(onLeaveFunc) == "function" then
    DT.RegisteredDataTexts[name].onLeave = onLeaveFunc
  end

  if localizedName and type(localizedName) == "string" then
    DT.RegisteredDataTexts[name].localizedName = localizedName
  end
end

local function InitializeCallback()
  DT:Initialize()
end

E:RegisterModule(DT:GetName(), InitializeCallback)