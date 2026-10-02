local probe_loaded = false
local frame_count = 0
local wait_frames = 300

re.on_frame(function()
    if probe_loaded then
        return
    end

    frame_count = frame_count + 1
    if frame_count < wait_frames then
        return
    end

    probe_loaded = true
    log.info("[mhws-eatshit] delayed read-only probe loaded after " .. tostring(frame_count) .. " frames")
    log.info("[mhws-eatshit] sdk.find_type_definition = " .. tostring(type(sdk.find_type_definition)))
    log.info("[mhws-eatshit] sdk.get_managed_singleton = " .. tostring(type(sdk.get_managed_singleton)))
    log.info("[mhws-eatshit] sdk.hook = " .. tostring(type(sdk.hook)))
    log.info("[mhws-eatshit] re.on_draw_ui = " .. tostring(type(re.on_draw_ui)))

    local ok, item_name_method = pcall(function()
        return sdk.find_type_definition("app.ItemDef"):get_method("NameString(app.ItemDef.ID)")
    end)

    log.info("[mhws-eatshit] app.ItemDef.NameString lookup = " .. tostring(ok and item_name_method ~= nil))
    if ok and item_name_method ~= nil then
        for _, item_id in ipairs({98, 100}) do
            local name_ok, item_name = pcall(function()
                return item_name_method(nil, item_id)
            end)
            log.info(string.format(
                "[mhws-eatshit] item id %d name lookup ok=%s name=%s",
                item_id,
                tostring(name_ok),
                tostring(item_name)
            ))
        end
    end

    local data_ok, data_method = pcall(function()
        return sdk.find_type_definition("app.ItemDef"):get_method("Data(app.ItemDef.ID)")
    end)
    local valid_ok, valid_method = pcall(function()
        return sdk.find_type_definition("app.ItemDef"):get_method("isValidItem(app.ItemDef.ID)")
    end)
    log.info("[mhws-eatshit] app.ItemDef.Data lookup = " .. tostring(data_ok and data_method ~= nil))
    log.info("[mhws-eatshit] app.ItemDef.isValidItem lookup = " .. tostring(valid_ok and valid_method ~= nil))

    if data_ok and data_method ~= nil and valid_ok and valid_method ~= nil then
        for _, item_id in ipairs({98, 100}) do
            local item_data_ok, item_data = pcall(function()
                return data_method(nil, item_id)
            end)
            local item_valid_ok, item_valid = pcall(function()
                return valid_method(nil, item_id)
            end)
            log.info(string.format(
                "[mhws-eatshit] item id %d data_ok=%s data=%s valid_ok=%s valid=%s",
                item_id,
                tostring(item_data_ok),
                tostring(item_data),
                tostring(item_valid_ok),
                tostring(item_valid)
            ))

            if item_data_ok and item_data ~= nil then
                local fields = {"_ItemId", "_SortId", "_Eatable", "_Heal", "_Infinit", "_MaxCount"}
                for _, field_name in ipairs(fields) do
                    local field_ok, field_value = pcall(function()
                        return item_data:get_field(field_name)
                    end)
                    log.info(string.format(
                        "[mhws-eatshit] item id %d field %s ok=%s value=%s",
                        item_id,
                        field_name,
                        tostring(field_ok),
                        tostring(field_value)
                    ))
                end

                local type_ok, item_type = pcall(function()
                    return item_data:call("get_Type")
                end)
                log.info(string.format(
                    "[mhws-eatshit] item id %d get_Type ok=%s value=%s",
                    item_id,
                    tostring(type_ok),
                    tostring(item_type)
                ))
            end
        end
    end
end)
