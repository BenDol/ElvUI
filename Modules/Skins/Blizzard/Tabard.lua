local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
--WoW API / Variables

S:AddCallback("Skin_Tabard", function()
  if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.tabard then return end

  TabardFrame:StripTextures()
  TabardFrame:CreateBackdrop("Transparent")
  TabardFrame.backdrop:Point("TOPLEFT", 11, -12)
  TabardFrame.backdrop:Point("BOTTOMRIGHT", -32, 76)
  E:EnableMovable("TabardFrame")

  S:SetUIPanelWindowInfo(TabardFrame, "width")
  S:SetBackdropHitRect(TabardFrame)

  S:HandleCloseButton(TabardFrameCloseButton, TabardFrame.backdrop)

  TabardFramePortrait:Kill()

  TabardModel:CreateBackdrop("Transparent")
  TabardModel.backdrop:Point("TOPLEFT", -2, 5)
  TabardModel.backdrop:Point("BOTTOMRIGHT", 20, -1)
  E:EnableClickRotate(TabardModel)
  E:EnableWheelZoom(TabardModel)
  E:EnableMouseDrag(TabardModel)

  S:HandleRotateButton(TabardCharacterModelRotateLeftButton)
  S:HandleRotateButton(TabardCharacterModelRotateRightButton)

  S:HandleButton(TabardFrameCancelButton)
  S:HandleButton(TabardFrameAcceptButton)

  TabardFrameCostFrame:StripTextures()
  TabardFrameCustomizationFrame:StripTextures()

  for i = 1, 5 do
    _G["TabardFrameCustomization"..i]:StripTextures()
    S:HandleNextPrevButton(_G["TabardFrameCustomization"..i.."LeftButton"])
    S:HandleNextPrevButton(_G["TabardFrameCustomization"..i.."RightButton"])
  end

  TabardModel:Point("BOTTOM", -20, 114)

  TabardCharacterModelRotateLeftButton:Point("BOTTOMLEFT", 2, 3)
  TabardCharacterModelRotateLeftButton:Hide()
  TabardCharacterModelRotateRightButton:Point("TOPLEFT", TabardCharacterModelRotateLeftButton, "TOPRIGHT", 3, 0)
  TabardCharacterModelRotateRightButton:Hide()

--  TabardCharacterModelRotateLeftButton.SetPoint = E.noop
--  TabardCharacterModelRotateRightButton.SetPoint = E.noop

  TabardFrameEmblemTopRight:Point("TOPRIGHT", TabardFrameOuterFrameTopRight, "TOPRIGHT", 24, 6)

  TabardFrameCustomization1:Point("TOPLEFT", TabardFrameCustomizationBorder, "TOPLEFT", 63, -63)

  TabardFrameMoneyFrame:Point("BOTTOMRIGHT", TabardFrame, "BOTTOMLEFT", 183, 88)

  TabardFrameCancelButton:Point("CENTER", TabardFrame, "TOPLEFT", 304, -417)
  TabardFrameAcceptButton:Point("CENTER", TabardFrame, "TOPLEFT", 221, -417)

  TabardModel:SetModelScale(1.25)
end)