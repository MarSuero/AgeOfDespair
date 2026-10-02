local done = false
local frame_count = 0
local deadline = os.clock() + 600
local target_id = 98

local function safe(fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then return false, tostring(r[2]) end
    return true, r[2]
end

local function get_item_data()
    local ok, def = safe(function()
        return sdk.find_type_definition("app.ItemDef")
    end)
    if not ok or not def then return nil end
    local m_ok, method = safe(function()
        return def:get_method("Data(app.ItemDef.ID)")
    end)
    if not m_ok or not method then return nil end
    local d_ok, data = safe(function()
        return method:call(nil, target_id)
    end)
    return d_ok and data or nil
end

local function get_hunter_item()
    local ok, manager = safe(function()
        return sdk.get_managed_singleton("app.PlayerManager")
    end)
    if not ok or not manager then return nil end
    local m_ok, master = safe(function() return manager:call("getMasterPlayer") end)
    if not m_ok or not master then return nil end
    local c_ok, character = safe(function() return master:call("get_Character") end)
    if not c_ok or not character then return nil end
    local i_ok, item = safe(function() return character:call("get_Item") end)
    return i_ok and item or nil
end

re.on_frame(function()
    if done then return end
    frame_count = frame_count + 1
    if frame_count % 30 ~= 0 then return end
    if os.clock() > deadline then
        done = true
        log.error("[mhws-eatshit] usable-v2 timeout waiting for player item")
        return
    end

    local data = get_item_data()
    local hunter_item = get_hunter_item()
    if data == nil or hunter_item == nil then return end

    done = true

    local fields = {
        _TextType = 1,
        _Window = true,
        _Eatable = true,
        _Heal = true,
        _EnableOnRaptor = true,
        _OutBox = false,
    }
    for name, value in pairs(fields) do
        local ok, err = safe(function()
            data[name] = value
        end)
        log.info(string.format(
            "[mhws-eatshit] usable-v2 field=%s ok=%s value=%s error=%s",
            name, tostring(ok), tostring(value), tostring(err)
        ))
    end

    local set_ok, disabled_set = safe(function()
        return hunter_item:get_field("_DisabledItemID")
    end)
    if set_ok and disabled_set then
        local td_ok, td = safe(function() return disabled_set:get_type_definition() end)
        local contains_ok, contains = safe(function()
            return td:get_method("Contains(System.Int32)")
        end)
        local remove_ok, remove = safe(function()
            return td:get_method("Remove(System.Int32)")
        end)
        if td and contains and remove then
            local has_ok, has = safe(function() return contains:call(disabled_set, target_id) end)
            log.info(string.format(
                "[mhws-eatshit] usable-v2 disabled_contains98 ok=%s value=%s",
                tostring(has_ok), tostring(has)
            ))
            if has_ok and has == true then
                local rem_call_ok, removed = safe(function()
                    return remove:call(disabled_set, target_id)
                end)
                log.info(string.format(
                    "[mhws-eatshit] usable-v2 disabled_remove98 ok=%s value=%s",
                    tostring(rem_call_ok), tostring(removed)
                ))
            end
        end
    end

    log.info("[mhws-eatshit] usable-v2 completed")
end)
