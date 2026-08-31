local Addon, Core = _G.YiboReputation, _G.YiboCore
local Theme = Core.UITheme
function Addon:CreateSettingsPanel(parent, context)
 local panel=parent.yrpSettings or CreateFrame("Frame",nil,parent); parent.yrpSettings=panel; panel.yiboSettingsOwner="reputation"; panel:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0); panel:SetWidth(parent:GetWidth()); panel:Show(); panel.controls=panel.controls or {}
 local settings=self:GetSettings(); if settings.defaultMatrixFilter~="monitored" then settings.defaultMatrixFilter="all" end; local items={{"Broker 悬停：监控声望账号对比",nil},{"好友度显示累计进度",function(v) settings.showFriendshipTotal=v end},{"主窗口默认过滤："..({all="全部",monitored="已监控"})[settings.defaultMatrixFilter],function() settings.defaultMatrixFilter=settings.defaultMatrixFilter=="monitored" and "all" or "monitored" end}}
 local y=0; for i,item in ipairs(items) do
  local entry=item; local control=panel.controls[i] or ((i==1 or i==3) and Theme:CreateButton(panel,230,"") or Theme:CreateCheckbox(panel,""));panel.controls[i]=control;control:ClearAllPoints();control:SetPoint("TOPLEFT",panel,"TOPLEFT",((i==1 or i==3) and 0 or 252),-y)
  if i==1 or i==3 then control:SetText(entry[1]);control:SetState(i==1 and "disabled" or "default");control:SetScript("OnClick",function() if entry[2] then entry[2](); context.notifyPageChanged() end end)
  else control.label:SetText(entry[1]);control:SetChecked(settings.showFriendshipTotal);control:SetScript("OnClick",function(c) c:SetChecked(not c:GetChecked()); entry[2](c:GetChecked());context.notifyPageChanged() end) end;y=y+32
 end
 local list=settings.monitoredFactionIDs
 local heading=panel.monitorHeading or Theme:CreateText(panel,Theme.Font.body,Theme.Colors.accent,"LEFT");panel.monitorHeading=heading;heading:ClearAllPoints();heading:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-y);heading:SetText("快速监控声望（"..#list.." / 10）");y=y+24
 panel.monitorRows=panel.monitorRows or {}
 panel.monitorUp=panel.monitorUp or {};panel.monitorDown=panel.monitorDown or {}
 for index,id in ipairs(list) do
  local button=panel.monitorRows[index] or Theme:CreateButton(panel,190,"","secondary");panel.monitorRows[index]=button;button:ClearAllPoints();button:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-y);button:SetText("移除  "..self:GetFactionName(id));button:SetScript("OnClick",function() table.remove(settings.monitoredFactionIDs,index);context.notifyPageChanged() end);button:Show()
  local up=panel.monitorUp[index] or Theme:CreateButton(panel,28,"↑","secondary");panel.monitorUp[index]=up;up:ClearAllPoints();up:SetPoint("LEFT",button,"RIGHT",6,0);up:SetState(index>1 and "default" or "disabled");up:SetScript("OnClick",function() if index>1 then list[index],list[index-1]=list[index-1],list[index];context.notifyPageChanged() end end);up:Show()
  local down=panel.monitorDown[index] or Theme:CreateButton(panel,28,"↓","secondary");panel.monitorDown[index]=down;down:ClearAllPoints();down:SetPoint("LEFT",up,"RIGHT",4,0);down:SetState(index<#list and "default" or "disabled");down:SetScript("OnClick",function() if index<#list then list[index],list[index+1]=list[index+1],list[index];context.notifyPageChanged() end end);down:Show();y=y+30
 end
 for index=#list+1,#panel.monitorRows do panel.monitorRows[index]:Hide();panel.monitorUp[index]:Hide();panel.monitorDown[index]:Hide() end
 local note=panel.monitorNote or Theme:CreateText(panel,Theme.Font.assist,Theme.Colors.muted,"LEFT");panel.monitorNote=note;note:ClearAllPoints();note:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-y);note:SetText("星标可在主矩阵中快速添加；此处按当前顺序显示并可移除。");y=y+24
 panel:SetHeight(y);return y
end
