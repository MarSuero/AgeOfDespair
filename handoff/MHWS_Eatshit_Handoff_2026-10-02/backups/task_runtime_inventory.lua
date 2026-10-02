local completed = false
local frame_count = 0
local min_frames = 300
local max_frames = 3600

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
        return false, nil, "object=nil"
    end
    local ok, value = pcall(function()
        return object:call(method_name)
    end)
    return ok, value, ok and nil or tostring(value)
end

local function type_name(object)
    if object == nil then
        return "<nil>"
    end
    local ok, definition = pcall(function()
        return object:get_type_definition()
    end)
    if not ok or definition == nil then
        return "<type-error>"
    end
    local name_ok, name = pcall(function()
        return definition:get_name()
    end)
    return name_ok and tostring(name) or "<name-error>"
end

local function log_methods(label, object)
    log.info(string.format("[mhws-eatshit] task %s type=%s", label, type_name(object)))
    if object == nil then
        return
    end

    local type_ok, definition = pcall(function()
        return object:get_type_definition()
    end)
    if not type_ok or definition == nil then
        return
    end

    local methods_ok, methods = pcall(function()
        return definition:get_methods()
    end)
    if not methods_ok or methods == nil then
        log.info("[mhws-eatshit] task " .. label .. " methods=<error>")
        return
    end

    log.info(string.format(
        "[mhws-eatshit] task %s method_count=%s",
        label,
        tostring(#methods)
    ))

    for _, method in ipairs(methods) do
        local name_ok, name = pcall(function()
            return method:get_name()
        end)
        if name_ok and name ~= nil and matches(name) then
            local full_ok, full_name = pcall(function()
                return method:get_full_name()
            end)
            log.info(string.format(
                "[mhws-eatshit] task %s method=%s full=%s",
                label,
                tostring(name),
                tostring(full_ok and full_name or "<unavailable>")
            ))
        end
    end
end

local function get_objects()
    local result = {}
    result.manager = sdk.get_managed_singleton("app.PlayerManager")
    local manager_ok, manager_value = pcall(function()
        return result.manager
    end)
    if not manager_ok or manager_value == nil then
        return result
    end

    local ok
    ok, result.master = safe_call(result.manager, "getMasterPlayer")
    ok, result.catalog = safe_call(result.manager, "get_Catalog")
    ok, result.character = safe_call(result.master, "get_Character")
    ok, result.item_param = safe_call(result.catalog, "get_PlayerItemParam")
    ok, result.action_controller = safe_call(result.character, "get_BaseActionController")
    ok, result.common_action = safe_call(result.catalog, "get_CommonActionBTable")
    ok, result.common_sub_action = safe_call(result.catalog, "get_CommonSubActionBTable")
    return result
end

re.on_frame(function()
    if completed then
        return
    end

    frame_count = frame_count + 1
    if frame_count < min_frames then
        return
    end

    local ok, objects = pcall(get_objects)
    if not ok then
        if frame_count >= max_frames then
            completed = true
            log.error("[mhws-eatshit] task runtime inventory failed: " .. tostring(objects))
        end
        return
    end

    if objects.master == nil or objects.character == nil or objects.action_controller == nil then
        if frame_count >= max_frames then
            completed = true
            log.error("[mhws-eatshit] task runtime inventory timed out waiting for player objects")
        end
        return
    end

    completed = true
    log.info("[mhws-eatshit] task runtime inventory started")
    log_methods("PlayerManager", objects.manager)
    log_methods("MasterPlayer", objects.master)
    log_methods("PlayerCatalog", objects.catalog)
    log_methods("PlayerItemParam", objects.item_param)
    log_methods("HunterCharacter", objects.character)
    log_methods("BaseActionController", objects.action_controller)
    log_methods("CommonActionBTable", objects.common_action)
    log_methods("CommonSubActionBTable", objects.common_sub_action)

    local action_ok, action_id = safe_call(objects.action_controller, "get_CurrentActionID")
    if action_ok and action_id ~= nil then
        local action_type = sdk.find_type_definition("ace.ACTION_ID")
        local bank_ok, bank = pcall(function()
            return sdk.get_native_field(action_id, action_type, "_Category")
        end)
        local index_ok, index = pcall(function()
            return sdk.get_native_field(action_id, action_type, "_Index")
        end)
        log.info(string.format(
            "[mhws-eatshit] task current_action bank_ok=%s bank=%s index_ok=%s index=%s",
            tostring(bank_ok),
            tostring(bank),
            tostring(index_ok),
            tostring(index)
        ))
    end

    log.info("[mhws-eatshit] task runtime inventory finished")
end)
