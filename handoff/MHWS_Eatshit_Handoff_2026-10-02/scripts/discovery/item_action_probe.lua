local started = false
local frame_count = 0
local wait_frames = 300
local last_bank = nil
local last_index = nil

local function read_action()
    local manager = sdk.get_managed_singleton("app.PlayerManager")
    if manager == nil then
        return nil, nil
    end

    local master = manager:call("getMasterPlayer")
    if master == nil then
        return nil, nil
    end

    local character = master:call("get_Character")
    if character == nil then
        return nil, nil
    end

    local controller = character:call("get_BaseActionController")
    if controller == nil then
        return nil, nil
    end

    local action_id = controller:call("get_CurrentActionID")
    if action_id == nil then
        return nil, nil
    end

    local action_type = sdk.find_type_definition("ace.ACTION_ID")
    local bank = sdk.get_native_field(action_id, action_type, "_Category")
    local index = sdk.get_native_field(action_id, action_type, "_Index")
    return bank, index
end

re.on_frame(function()
    frame_count = frame_count + 1
    if frame_count < wait_frames then
        return
    end

    local ok, bank, index = pcall(read_action)
    if not ok then
        if not started then
            started = true
            log.error("[mhws-eatshit] action probe failed: " .. tostring(bank))
        end
        return
    end

    if not started then
        started = true
        log.info("[mhws-eatshit] action probe started")
    end

    if bank ~= nil and index ~= nil and (bank ~= last_bank or index ~= last_index) then
        last_bank = bank
        last_index = index
        log.info(string.format(
            "[mhws-eatshit] action changed bank=%s index=%s",
            tostring(bank),
            tostring(index)
        ))
    end
end)
