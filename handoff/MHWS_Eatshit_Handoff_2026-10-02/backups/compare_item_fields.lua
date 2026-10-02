local done = false
local frame_count = 0
local wait_frames = 300
local item_ids = {98, 1}

local function safe_string(value)
    local ok, text = pcall(tostring, value)
    if ok then
        return text
    end
    return "<tostring-error>"
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
    log.info("[mhws-eatshit] item field comparison started")

    local item_def = sdk.find_type_definition("app.ItemDef")
    local data_method = item_def:get_method("Data(app.ItemDef.ID)")
    local name_method = item_def:get_method("NameString(app.ItemDef.ID)")

    for _, item_id in ipairs(item_ids) do
        local data_ok, item_data = pcall(function()
            return data_method(nil, item_id)
        end)
        local name_ok, item_name = pcall(function()
            return name_method(nil, item_id)
        end)

        log.info(string.format(
            "[mhws-eatshit] item %d name_ok=%s name=%s data_ok=%s data=%s",
            item_id,
            tostring(name_ok),
            safe_string(item_name),
            tostring(data_ok),
            safe_string(item_data)
        ))

        if data_ok and item_data ~= nil then
            local type_ok, item_type = pcall(function()
                return item_data:get_type_definition()
            end)

            log.info(string.format(
                "[mhws-eatshit] item %d type_ok=%s type=%s",
                item_id,
                tostring(type_ok),
                safe_string(item_type)
            ))

            if type_ok and item_type ~= nil then
                local fields_ok, fields = pcall(function()
                    return item_type:get_fields()
                end)

                log.info(string.format(
                    "[mhws-eatshit] item %d fields_ok=%s count=%s",
                    item_id,
                    tostring(fields_ok),
                    fields_ok and safe_string(#fields) or "<none>"
                ))

                if fields_ok and fields ~= nil then
                    for _, field in ipairs(fields) do
                        local field_name_ok, field_name = pcall(function()
                            return field:get_name()
                        end)
                        if field_name_ok and field_name ~= nil then
                            local value_ok, value = pcall(function()
                                return item_data:get_field(field_name)
                            end)
                            log.info(string.format(
                                "[mhws-eatshit] item %d field %s ok=%s value=%s",
                                item_id,
                                safe_string(field_name),
                                tostring(value_ok),
                                safe_string(value)
                            ))
                        end
                    end
                end
            end
        end
    end

    log.info("[mhws-eatshit] item field comparison finished")
end)
