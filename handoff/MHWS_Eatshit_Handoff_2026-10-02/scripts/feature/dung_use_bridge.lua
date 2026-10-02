local applied = false
local started_at = os.clock()
local deadline_seconds = 600

local function safe(fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then return false, tostring(r[2]) end
    return true, r[2]
end

local function get_player_item()
    local ok, manager = safe(function()
        return sdk.get_managed_singleton("app.PlayerManager")
    end)
    if not ok or manager == nil then return nil end

    local master_ok, master = safe(function()
        return manager:call("getMasterPlayer")
    end)
    if not master_ok or master == nil then return nil end

    local char_ok, character = safe(function()
        return master:call("get_Character")
    end)
    if not char_ok or character == nil then return nil end

    local item_ok, hunter_item = safe(function()
        return character:call("get_Item")
    end)
    if not item_ok then return nil end
    return hunter_item
end

local function get_item_data()
    local ok, item_def = safe(function()
        return sdk.find_type_definition("app.ItemDef")
    end)
    if not ok or item_def == nil then return nil end

    local method_ok, data_method = safe(function()
        return item_def:get_method("Data(app.ItemDef.ID)")
    end)
    if not method_ok or data_method == nil then return nil end

    local data_ok, data = safe(function()
        return data_method:call(nil, 98)
    end)
    if not data_ok then return nil end
    return data
end

local function write_field(data, name, value)
    local ok, err = safe(function()
        data[name] = value
    end)
    if ok then
        local read_ok, readback = safe(function()
            return data:get_field(name)
        end)
        log.info(string.format(
            "[mhws-eatshit] bridge field=%s set=%s readback=%s read_ok=%s",
            name, tostring(value), tostring(readback), tostring(read_ok)
        ))
        return
    end
    log.error(string.format(
        "[mhws-eatshit] bridge field=%s write_failed=%s",
        name, tostring(err)
    ))
end

local function remove_disabled_item(hunter_item)
    local set_ok, disabled_set = safe(function()
        return hunter_item:get_field("_DisabledItemID")
    end)
    if not set_ok or disabled_set == nil then
        log.info("[mhws-eatshit] bridge disabled_set unavailable")
        return
    end

    local type_ok, type_def = safe(function()
        return disabled_set:get_type_definition()
    end)
    if not type_ok or type_def == nil then return end

    local contains_ok, contains = safe(function()
        return type_def:get_method("Contains(System.Int32)")
    end)
    local remove_ok, remove = safe(function()
        return type_def:get_method("Remove(System.Int32)")
    end)
    if not contains_ok or not remove_ok or contains == nil or remove == nil then
        log.info("[mhws-eatshit] bridge HashSet methods unavailable")
        return
    end

    local has_ok, has_item = safe(function()
        return contains:call(disabled_set, 98)
    end)
    log.info(string.format(
        "[mhws-eatshit] bridge disabled_contains98 ok=%s value=%s",
        tostring(has_ok), tostring(has_item)
    ))

    if has_ok and has_item == true then
        local removed_ok, removed = safe(function()
            return remove:call(disabled_set, 98)
        end)
        log.info(string.format(
            "[mhws-eatshit] bridge disabled_remove98 ok=%s value=%s",
            tostring(removed_ok), tostring(removed)
        ))
    end
end

re.on_frame(function()
    if applied then return end
    if os.clock() - started_at > deadline_seconds then
        applied = true
        log.error("[mhws-eatshit] bridge timeout waiting for runtime objects")
        return
    end

    local hunter_item = get_player_item()
    local item_data = get_item_data()
    if hunter_item == nil or item_data == nil then return end

    applied = true
    log.info("[mhws-eatshit] bridge runtime objects ready")

    write_field(item_data, "_TextType", 1)
    write_field(item_data, "_Window", true)
    write_field(item_data, "_Eatable", true)
    write_field(item_data, "_Heal", true)
    write_field(item_data, "_EnableOnRaptor", true)
    write_field(item_data, "_OutBox", false)

    remove_disabled_item(hunter_item)
    log.info("[mhws-eatshit] bridge completed for public item 98")
end)
