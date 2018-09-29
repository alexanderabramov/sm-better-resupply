----------------------------------------------------------------
-- Mod metadata (these must match the values in metadata.lua) --
----------------------------------------------------------------
-- <id> should be the mod's generated id
-- For an in-development mod and for the first upload use `nil` (no quotes) as the <steam_id>
-- Once the mod has a steam_id in metadata.lua use that (as a string).
-- <author> name will always be checked.
local id = "TryamnR"
local steam_id = "1349810398"
local author = "chippydip"

--------------------------------------------------
-- Validation logic, don't edit below this line --
--------------------------------------------------

-- Debug
local logf = logf or function() end
local try = try or function(f) f() end

try(function()
    -- Find this mod in the ModsLoaded list
    local found, mod = 0, nil
    for i, v in ipairs(ModsLoaded) do
        if v.id == id then
            found, mod = i, v
            break
        end
    end

    if not mod then
        logf("Mod not found (%s by %s)", id, author)
        return
    end

    -- Check author and steam_id
    if mod.author == author and (not steam_id or mod.steam_id == steam_id) then
        logf("Mod validated (%s by %s @ %s)", id, author, tostring(steam_id))
        return
    end

    logf("Mod copy detected! (%s by %s @ %s)", mod.id, mod.author, tostring(mod.steam_id))

    -- Metadata doesn't match, so disable the mod and reload
    table.remove(ModsLoaded, found)

    -- Also check the list in AccountStorage since that probably needs to be updated as well
    if AccountStorage.LoadMods[found] == mod.id then
        table.remove(AccountStorage.LoadMods, found)
        SaveAccountStorage()
    end

    ReloadLua()
end)
