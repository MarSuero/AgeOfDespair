local done = false
local frame_count = 0
local wait_frames = 300

local keywords = {
    "item", "use", "select", "consume", "action", "eat", "drink",
    "current", "slot", "pouch", "quick", "request", "equip"
}

local function matches(name)
    local lower = string.lower(name)
    for _, keyword in ipairs(keywords) do
        if string.find(lower, keyword, 1, true) then
            return true
        end
    end
    return false
end

local function safe_call(object, method_name)
    if object == nil then
        return false, nil
    end
    return pcall(function()
        return object:call(method_name)
    end)
end

local function log_methods(label, object)
    if object == nil then
        log.info("[mhws-eatshit] " .. label .. " object=nil")
        return
    end

    local type_ok, type_def = pcall(function()
        return object:get_type_definition()
    end)
    if not type_ok or type_def == nil then
        log.info("[mhws-eatshit] " .. label .. " type lookup failed")
        return
    end

    local name_ok, type_name = pcall(function()
        return type_def:get_name()
    end)
    log.info(string.format(
        "[mhws-eatshit] %s type=%s",
        label,
        tostring(name_ok and type_name or "<unknown>")
    ))

    local methods_ok, methods = pcall(function()
        return type_def:get_methods()
    end)
    if not methods_ok or methods == nil then
        log.info("[mhws-eatshit] " .. label .. " methods lookup failed")
        return
    end

    log.info(string.format(
        "[mhws-eatshit] %s method_count=%s",
        label,
        tostring(#methods)
    ))

    for _, method in ipairs(methods) do
        local method_ok, method_name = pcall(function()
            return method:get_name()
        end)
        if method_ok and method_name ~= nil and matches(method_name) then
            local sig_ok, signature = pcall(function()
                return method:get_full_name()
            end)
            log.info(string.format(
                "[mhws-eatshit] %s candidate=%s signature=%s",
                label,
                tostring(method_name),
                tostring(sig_ok and signature or "<unavailable>")
            ))
        end
    end
end

local function log_object_shape(label, object)
    if object == nil then
        log.info("[mhws-eatshit] " .. label .. " object=nil")
        return
    end

    local type_ok, type_def = pcall(function()
        return object:get_type_definition()
    end)
    if not type_ok or type_def == nil then
        log.info("[mhws-eatshit] " .. label .. " type lookup failed")
        return
    end

    local name_ok, type_name = pcall(function()
        return type_def:get_name()
    end)
    log.info(string.format(
        "[mhws-eatshit] %s type=%s",
        label,
        tostring(name_ok and type_name or "<unknown>")
    ))

    local fields_ok, fields = pcall(function()
        return type_def:get_fields()
    end)
    if fields_ok and fields ~= nil then
        log.info(string.format(
            "[mhws-eatshit] %s field_count=%s",
            label,
            tostring(#fields)
        ))
        for _, field in ipairs(fields) do
            local field_ok, field_name = pcall(function()
                return field:get_name()
            end)
            if field_ok and field_name ~= nil and matches(field_name) then
                local value_ok, value = pcall(function()
                    return object:get_field(field_name)
                end)
                log.info(string.format(
                    "[mhws-eatshit] %s field=%s ok=%s value=%s",
                    label,
                    tostring(field_name),
                    tostring(value_ok),
                    tostring(value)
                ))
            end
        end
    end

    log_methods(label, object)
end

re.on_frame(function()
    if done then
        return
    end

    frame_count = frame_count + 1
    if frame_count < wait_frames then
        return
    end
    done = true

    local manager = sdk.get_managed_singleton("app.PlayerManager")
    if manager == nil then
        return
    end

    local master_ok, master = safe_call(manager, "getMasterPlayer")
    local catalog_ok, catalog = safe_call(manager, "get_Catalog")
    local item_param_ok, item_param = safe_call(catalog, "get_PlayerItemParam")

    if not master_ok or not catalog_ok or not item_param_ok or
        master == nil or catalog == nil or item_param == nil then
        log.info(string.format(
            "[mhws-eatshit] player object wait master=%s catalog=%s item_param=%s",
            tostring(master_ok and master ~= nil),
            tostring(catalog_ok and catalog ~= nil),
            tostring(item_param_ok and item_param ~= nil)
        ))
        return
    end

    local character_ok, character = safe_call(master, "get_Character")
    local controller_ok, controller = safe_call(character, "get_BaseActionController")
    local common_action_ok, common_action = safe_call(catalog, "get_CommonActionBTable")
    local common_sub_action_ok, common_sub_action = safe_call(catalog, "get_CommonSubActionBTable")

    log.info(string.format(
        "[mhws-eatshit] object calls character=%s controller=%s common_action=%s common_sub_action=%s",
        tostring(character_ok and character ~= nil),
        tostring(controller_ok and controller ~= nil),
        tostring(common_action_ok and common_action ~= nil),
        tostring(common_sub_action_ok and common_sub_action ~= nil)
    ))

    log_methods("PlayerItemParam", item_param)
    log_methods("PlayerCatalog", catalog)
    log_object_shape("CommonActionBTable", common_action)
    log_object_shape("CommonSubActionBTable", common_sub_action)
    log_methods("MasterPlayer", master)
    log_methods("HunterCharacter", character)
    log_methods("BaseActionController", controller)
    log.info("[mhws-eatshit] item method inventory finished")
end)
