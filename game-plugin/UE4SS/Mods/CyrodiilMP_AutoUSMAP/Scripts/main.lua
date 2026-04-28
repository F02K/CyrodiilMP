local delaySeconds = 12

print("[CyrodiilMP_AutoUSMAP] Loaded. Waiting " .. delaySeconds .. " seconds before DumpUSMAP().")

ExecuteWithDelay(delaySeconds * 1000, function()
    print("[CyrodiilMP_AutoUSMAP] Running DumpUSMAP().")
    local ok, err = pcall(function()
        DumpUSMAP()
    end)

    if ok then
        print("[CyrodiilMP_AutoUSMAP] DumpUSMAP() finished. Check the Win64 folder for Mappings.usmap.")
    else
        print("[CyrodiilMP_AutoUSMAP] DumpUSMAP() failed: " .. tostring(err))
    end
end)
