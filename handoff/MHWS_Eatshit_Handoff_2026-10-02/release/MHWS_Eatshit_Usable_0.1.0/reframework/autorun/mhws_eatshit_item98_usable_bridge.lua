-- Runtime-only category bridge for public item 98.
-- The native companion handles only mcHunterItem.notUseItem(98).

local applied = false
local frame_count = 0
local wait_frames = 300
local target_id = 98

local target_fields = {
    { name = "_TextType", value = 1 },
    { name = "_Window", value = true },
    { name = "_Eatable", value = true },
    { name = "_Heal", value = true },
    { name = "_EnableOnRaptor", value = true },
}

local function safe(fn, ...)
    local result = { pcall(fn, ...) }
    if not result[1] then
        return false, result[2]
    end
    return true, result[2]
end

local function get_item_data()
    local ok, type_def = safe(function()
        return sdk.find_type_definition("app.ItemDef")
    end)
    if not ok or type_def == nil then
        return nil
    end

    local method_ok, method = safe(function()
        return type_def:get_method("Data(app.ItemDef.ID)")
    end)
    if not method_ok or method == nil then
        return nil
    end

    local data_ok, data = safe(function()
        return method:call(nil, target_id)
    end)
    if not data_ok then
        return nil
    end
    return data
end

re.on_frame(function()
    if applied then
        return
    end

    frame_count = frame_count + 1
    if frame_count < wait_frames then
        return
    end

    local data = get_item_data()
    if data == nil then
        return
    end

    applied = true
    local parts = {}
    for _, entry in ipairs(target_fields) do
        local before_ok, before = safe(function()
            return data:get_field(entry.name)
        end)
        local write_ok = safe(function()
            data[entry.name] = entry.value
        end)
        local after_ok, after = safe(function()
            return data:get_field(entry.name)
        end)
        parts[#parts + 1] = string.format(
            "%s=%s->%s write=%s",
            entry.name,
            tostring(before_ok and before or "<read-failed>"),
            tostring(after_ok and after or "<read-failed>"),
            tostring(write_ok)
        )
    end

    log.info("[mhws-eatshit] item98 category bridge: " .. table.concat(parts, " "))
end)
