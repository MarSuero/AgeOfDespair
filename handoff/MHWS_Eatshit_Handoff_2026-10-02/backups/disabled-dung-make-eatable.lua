local applied = false
local frame_count = 0
local wait_frames = 300
local target_item_id = 98

re.on_frame(function()
    if applied then
        return
    end

    frame_count = frame_count + 1
    if frame_count < wait_frames then
        return
    end

    applied = true

    local ok, result = pcall(function()
        local item_def = sdk.find_type_definition("app.ItemDef")
        local data_method = item_def:get_method("Data(app.ItemDef.ID)")
        local item_data = data_method(nil, target_item_id)
        if item_data == nil then
            return "item_data=nil"
        end

        local before = item_data:get_field("_Eatable")
        item_data._Eatable = true
        local after = item_data:get_field("_Eatable")
        return string.format("before=%s after=%s", tostring(before), tostring(after))
    end)

    if ok then
        log.info("[mhws-eatshit] eatable patch applied to item 98: " .. tostring(result))
    else
        log.error("[mhws-eatshit] eatable patch failed for item 98: " .. tostring(result))
    end
end)
