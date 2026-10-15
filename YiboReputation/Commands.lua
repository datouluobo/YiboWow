local Addon=_G.YiboReputation
SLASH_YIBOREPUTATION1="/yrp"
SlashCmdList["YIBOREPUTATION"]=function(message)
 local command=tostring(message or ""):match("^%s*(%S*)"):lower()
 if Addon.CoreIntegration and Addon.CoreIntegration.initialized then
  if command=="scan" then
   local ok,err=Addon:ScanCurrent("command")
   Addon:Print(ok and Addon:T("COMMAND.SCAN_OK") or Addon:T("COMMAND.SCAN_FAILED",tostring(err)))
   return
  elseif command=="migrate" then
   local count,failed=Addon:ImportLegacySnapshots()
   Addon:Print(count and Addon:T("COMMAND.MIGRATED",count,failed) or tostring(failed))
   return
  elseif command=="status" then
   local count,failed=0,0
   for _ in pairs(Addon.Store.db.characters) do count=count+1 end
   for _,record in pairs(Addon.Store.db.migrations.coreReputationV1.characters) do if record.status=="failed" then failed=failed+1 end end
   local current=_G.YiboCore.Characters:GetCurrent({identityOnly=true})
   local snapshot=current and Addon:GetSnapshot(current.id)
   Addon:Print(Addon:T("COMMAND.STATUS",count,failed,Addon:FormatState(snapshot) or Addon:T("COMMAND.SCAN_OK")))
   return
  end
 end
 if command=="tree" then Addon:Print(Addon:T("PAGE.HOVER_MODE")) end
 if Addon.CoreIntegration and Addon.CoreIntegration.initialized then _G.YiboCore.AccountView:ShowPage("reputation",{autoFit=true}) else Addon:Print(Addon:T("ERROR.NOT_READY")) end
end
