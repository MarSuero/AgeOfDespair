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

        local before_text_type = item_data:get_field("_TextType")
        local before_window = item_data:get_field("_Window")
        local before_eatable = item_data:get_field("_Eatable")
        local before_heal = item_data:get_field("_Heal")
        local before_raptor = item_data:get_field("_EnableOnRaptor")
        local before_outbox = item_data:get_field("_OutBox")
        item_data._TextType = 1
        item_data._Window = true
        item_data._Eatable = true
        item_data._Heal = true
        item_data._EnableOnRaptor = true
        item_data._OutBox = false
        local after_text_type = item_data:get_field("_TextType")
        local after_window = item_data:get_field("_Window")
        local after_eatable = item_data:get_field("_Eatable")
        local after_heal = item_data:get_field("_Heal")
        local after_raptor = item_data:get_field("_EnableOnRaptor")
        local after_outbox = item_data:get_field("_OutBox")
        return string.format(
            "text_type=%s->%s window=%s->%s eatable=%s->%s heal=%s->%s raptor=%s->%s outbox=%s->%s",
            tostring(before_text_type),
            tostring(after_text_type),
            tostring(before_window),
            tostring(after_window),
            tostring(before_eatable),
            tostring(after_eatable),
            tostring(before_heal),
            tostring(after_heal),
            tostring(before_raptor),
            tostring(after_raptor),
            tostring(before_outbox),
            tostring(after_outbox)
        )
    end)

    if ok then
        log.info("[mhws-eatshit] eatable patch applied to item 98: " .. tostring(result))
    else
        log.error("[mhws-eatshit] eatable patch failed for item 98: " .. tostring(result))
    end
end)
