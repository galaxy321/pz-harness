-- Test Ground Save Copier: the Java side (global TGSaveCopy) does the work; Test Ground's Benchmark Save button calls it.
-- This only says in the console whether it loaded.
Events.OnGameStart.Add(function()
	local ok, v = pcall(function() return TGSaveCopy.version() end)
	print("[TestGroundSaveCopy] " .. (ok and ("loaded " .. tostring(v)) or "Java side not loaded (is ZombieBuddy on, and the jar allowed?): " .. tostring(v)))
end)
Events.OnMainMenuEnter.Add(function()
	local ok, v = pcall(function() return TGSaveCopy.version() end)
	print("[TestGroundSaveCopy] main menu: " .. (ok and ("loaded " .. tostring(v)) or "Java side not loaded: " .. tostring(v)))
end)
