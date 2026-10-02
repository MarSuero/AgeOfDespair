local started = false
local frame_count = 0
local wait_frames = 300
local last_bank = nil
local last_index = nil
local fields_logged = false

local function get_item_param()
    local manager = sdk.get_managed_singleton("app.PlayerManager")
    if manager == nil then return nil end
    local catalog = manager:call("get_Catalog")
    if catalog == nil then return nil end
    return catalog:call("get_PlayerItemParam")
end

local function log_item_param_fields(param)
    local type_def = param:get_type_definition()
    local fields = type_def:get_fields()
    log.info("[mhws-eatshit] PlayerItemParam field count=" .. tostring(#fields))

    for _, field in ipairs(fields) do
        local name_ok, name = pcall(function()
            return field:get_name()
        end)
        if name_ok and name ~= nil then
            local value_ok, value = pcall(function()
                return param:get_field(name)
            end)
            if string.match(name, "[Ii]tem") or string.match(name, "[Ss]elect") or
                string.match(name, "[Cc]urrent") or string.match(name, "[Uu]se") then
                log.info(string.format(
                    "[mhws-eatshit] PlayerItemParam field %s ok=%s value=%s",
                    tostring(name),
                    tostring(value_ok),
                    tostring(value)
                ))
            end
        end
    end
end

local function read_action()
    local manager = sdk.get_managed_singleton("app.PlayerManager")
    if manager == nil then return nil, nil end
    local master = manager:call("getMasterPlayer")
    if master == nil then return nil, nil end
    local character = master:call("get_Character")
    if character == nil then return nil, nil end
    local controller = character:call("get_BaseActionController")
    if controller == nil then return nil, nil end
    local action_id = controller:call("get_CurrentActionID")
    if action_id == nil then return nil, nil end
    local action_type = sdk.find_type_definition("ace.ACTION_ID")
    return sdk.get_native_field(action_id, action_type, "_Category"),
        sdk.get_native_field(action_id, action_type, "_Index")
end

re.on_frame(function()
    frame_count = frame_count + 1
    if frame_count < wait_frames then return end

    local ok, bank, index = pcall(read_action)
    if not ok then
        if not started then
            started = true
            log.error("[mhws-eatshit] selected item probe action read failed: " .. tostring(bank))
        end
        return
    end

    local param_ok, param = pcall(get_item_param)
    if param_ok and param ~= nil and not fields_logged then
        fields_logged = true
        pcall(log_item_param_fields, param)
    end

    if not started then
        started = true
        log.info("[mhws-eatshit] selected item probe started")
    end

    if bank ~= nil and index ~= nil and (bank ~= last_bank or index ~= last_index) then
        last_bank = bank
        last_index = index
        log.info(string.format(
            "[mhws-eatshit] action/item snapshot bank=%s index=%s param=%s",
            tostring(bank),
            tostring(index),
            tostring(param)
        ))
    end
end)
