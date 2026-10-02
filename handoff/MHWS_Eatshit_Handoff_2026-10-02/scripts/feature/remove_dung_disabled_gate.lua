local done = false
local frame_count = 0
local wait_frames = 300

local function safe(fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then return false, tostring(r[2]) end
    return true, r[2]
end

re.on_frame(function()
    if done then return end
    frame_count = frame_count + 1
    if frame_count < wait_frames then return end
    done = true

    local ok, manager = safe(function()
        return sdk.get_managed_singleton("app.PlayerManager")
    end)
    if not ok or manager == nil then
        log.error("[mhws-eatshit] disabled-gate: PlayerManager unavailable")
        return
    end

    local master_ok, master = safe(function() return manager:call("getMasterPlayer") end)
    local char_ok, character = safe(function() return master:call("get_Character") end)
    local item_ok, hunter_item = safe(function() return character:call("get_Item") end)
    if not master_ok or not char_ok or not item_ok or hunter_item == nil then
        log.error("[mhws-eatshit] disabled-gate: player item unavailable")
        return
    end

    local set_ok, disabled_set = safe(function()
        return hunter_item:get_field("_DisabledItemID")
    end)
    if not set_ok or disabled_set == nil then
        log.error("[mhws-eatshit] disabled-gate: _DisabledItemID unavailable")
        return
    end

    local type_ok, type_def = safe(function() return disabled_set:get_type_definition() end)
    local contains_ok, contains_method = safe(function()
        return type_def:get_method("Contains(System.Int32)")
    end)
    local remove_ok, remove_method = safe(function()
        return type_def:get_method("Remove(System.Int32)")
    end)
    if not type_ok or not contains_ok or not remove_ok
        or contains_method == nil or remove_method == nil then
        log.error("[mhws-eatshit] disabled-gate: HashSet methods unavailable")
        return
    end

    local has_ok, has_dung = safe(function()
        return contains_method:call(disabled_set, 98)
    end)
    log.info(string.format(
        "[mhws-eatshit] disabled-gate contains public98 ok=%s value=%s",
        tostring(has_ok), tostring(has_dung)
    ))

    if has_ok and has_dung == true then
        local remove_call_ok, removed = safe(function()
            return remove_method:call(disabled_set, 98)
        end)
        log.info(string.format(
            "[mhws-eatshit] disabled-gate remove public98 ok=%s removed=%s",
            tostring(remove_call_ok), tostring(removed)
        ))
    end
end)
