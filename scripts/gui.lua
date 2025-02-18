local table = require("__flib__.table")
local gui = require("__flib__.gui")

local import_export = require("scripts.import-export")
local types = require("scripts.types")
local util = require("scripts.util")

local TARGET_SECTION_WIDTH = 276
local MODULE_SET_WIDTH = 440
local PRESET_BUTTON_FIELD_WIDTH = 200

local mi_gui = {}
mi_gui.templates = {
    --- @param row_index int index of the config row this is part of
    --- @param config_index int index of this entity in the target.entities array
    --- @param table_index int? index of this button in its parent
    --- @return flib.GuiElemDef
    assembler_button = function(row_index, config_index, table_index)
        return {
            type = "choose-elem-button",
            name = "assembler-" .. config_index,
            index = table_index,
            style = "slot_button",
            handler = { [defines.events.on_gui_elem_changed] = mi_gui.handlers.main.choose_assembler },
            elem_type = "entity",
            elem_filters = { { filter = "name", name = storage.module_entities } },
            tooltip = { "module-inserter-ex-choose-assembler" },
            --- @type TargetButtonTags
            tags = {
                row_index = row_index,
                slot_index = config_index,
            }
        }
    end,

    --- @param row_index int index of the config row this is part of
    --- @param config_index int index of this recipe in the target.recipes array
    --- @param table_index int? index of this button in its parent
    --- @return flib.GuiElemDef
    recipe_button = function(row_index, config_index, table_index)
        return {
            type = "choose-elem-button",
            name = "recipe-" .. config_index,
            index = table_index,
            style = "yellow_slot_button",
            handler = { [defines.events.on_gui_elem_changed] = mi_gui.handlers.main.choose_recipe },
            elem_type = "recipe-with-quality",
            tooltip = { "module-inserter-ex-choose-recipe" },
            --- @type TargetButtonTags
            tags = {
                row_index = row_index,
                slot_index = config_index,
            }
        }
    end,

    --- @param module_row_tags ModuleRowTags
    --- @param slot_index int
    --- @return flib.GuiElemDef
    module_button = function(module_row_tags, slot_index)
        -- TODO This could be filtered based on the current assembler to only valid modules (e.g. hide productivity for beacons)
        return {
            type = "choose-elem-button",
            style = "slot_button",
            name = "module_button_" .. slot_index,
            handler = { [defines.events.on_gui_elem_changed] = mi_gui.handlers.main.choose_module },
            elem_type = "item-with-quality",
            elem_filters = { { filter = "type", type = "module" } },
            --- @type ModuleButtonTags
            tags = {
                row_index = module_row_tags.row_index,
                module_row_index = module_row_tags.module_row_index,
                slot_index = slot_index,
            }
        }
    end,

    --- A single module configuration row, defining the modules to place in machines
    --- @param row_index int
    --- @param module_row_index int
    --- @param slots int
    --- @return flib.GuiElemDef
    module_row = function(row_index, module_row_index, slots)
        --- @type ModuleRowTags
        local module_row_tags = {
            row_index = row_index,
            module_row_index = module_row_index,
        }
        local module_table = {
            type = "table",
            name = "module_row_table_" .. module_row_index,
            column_count = 8,
            tags = module_row_tags,
            style = "slot_table",
            children = {},
        }
        for m = 1, slots do
            module_table.children[m] = mi_gui.templates.module_button(module_row_tags, m)
        end
        local row_frame = {
            type = "frame",
            name = "module_row_frame_" .. module_row_index,
            style = "slot_button_deep_frame",
            tags = module_row_tags,
            children = {
                module_table,
                {
                    type = "sprite-button",
                    name = "delete_module_row_button",
                    tooltip = { "module-inserter-ex-delete-module-set" },
                    sprite = "utility/trash",
                    style = "tool_button_red",
                    style_mods = { margin = 6, },
                    handler = mi_gui.handlers.main.delete_module_row,
                },
                {
                    type = "sprite-button",
                    name = "add_module_row_button",
                    tooltip = { "module-inserter-ex-add-module-set" },
                    sprite = "utility/add",
                    style = "tool_button",
                    style_mods = { margin = 6, },
                    handler = mi_gui.handlers.main.add_module_row,
                },
            },
        }
        return row_frame
    end,

    --- A set of possibly multiple module row configs
    --- @param name string Name to give this gui element
    --- @param row_index int? Index of the row of this module set (nil for the default module set)
    --- @return flib.GuiElemDef
    module_set = function(name, row_index)
        return {
            type = "frame",
            name = row_index and (name .. "_" .. row_index) or name,
            direction = "vertical",
            style = "inside_shallow_frame_with_padding",
            style_mods = { horizontally_stretchable = true, vertically_stretchable = true, },
            --- @type TargetFrameTags
            tags = {
                row_index = row_index or 0,
            },
            children = {},
        }
    end,

    --- @param row_index int
    --- @return flib.GuiElemDef
    target_entity_table = function(row_index, column_count)
        return {
            type = "table",
            column_count = column_count,
            name = "target_entity_table",
            style = "filter_slot_table",
            --- @type TargetFrameTags
            tags = {
                row_index = row_index,
            },
            children = {
                mi_gui.templates.assembler_button(row_index, 1),
            },
        }
    end,

    --- @param row_index int
    --- @return flib.GuiElemDef
    target_section = function(row_index)
        return {
            type = "frame",
            name = "target_section_" .. row_index,
            style = "inside_shallow_frame_with_padding",
            style_mods = { horizontally_stretchable = true, vertically_stretchable = true, },
            children = {
                {
                    type = "flow",
                    direction = "vertical",
                    name = "reorder_buttons",
                    style_mods = { vertical_spacing = 0, },
                    children = {
                        {
                            type = "sprite-button",
                            name = "move_up_button",
                            handler = mi_gui.handlers.main.move_up,
                            sprite = "miex_arrow_up",
                            tooltip = { "module-inserter-ex-move-config-row-up-tooltip" },
                            style_mods = { width = 16, height = 14, },
                            --- @type TargetFrameTags
                            tags = {
                                row_index = row_index,
                            },
                        },
                        {
                            type = "sprite-button",
                            name = "move_down_button",
                            handler = mi_gui.handlers.main.move_down,
                            sprite = "miex_arrow_down",
                            tooltip = { "module-inserter-ex-move-config-row-down-tooltip" },
                            style_mods = { width = 16, height = 14, },
                            --- @type TargetFrameTags
                            tags = {
                                row_index = row_index,
                            },
                        }
                    }
                },
                {
                    type = "frame",
                    name = "target_frame",
                    style = "slot_button_deep_frame",
                    style_mods = {
                        horizontally_stretchable = false,
                    },
                    --- @type TargetFrameTags
                    tags = {
                        row_index = row_index,
                    },
                    children = {
                        mi_gui.templates.target_entity_table(row_index, 6),
                    }
                }
            },
        }
    end,

    --- @param index int preset index for this row
    --- @return flib.GuiElemDef
    preset_row = function(index)
        return {
            type = "flow",
            direction = "horizontal",
            name = "preset_row_" .. index,
            --- @type PresetRowTags
            tags = {
                preset_index = index,
            },
            children = {
                {
                    type = "flow",
                    direction = "vertical",
                    name = "reorder_buttons",
                    style_mods = { vertical_spacing = 0, },
                    children = {
                        {
                            type = "sprite-button",
                            name = "move_up_button",
                            handler = mi_gui.handlers.preset.move_up,
                            sprite = "miex_arrow_up",
                            tooltip = { "module-inserter-ex-move-preset-up-tooltip" },
                            style_mods = { width = 16, height = 14, },
                        },
                        {
                            type = "sprite-button",
                            name = "move_down_button",
                            handler = mi_gui.handlers.preset.move_down,
                            sprite = "miex_arrow_down",
                            tooltip = { "module-inserter-ex-move-preset-down-tooltip" },
                            style_mods = { width = 16, height = 14, },
                        }
                    }
                },
                {
                    type = "button",
                    name = "select_button",
                    style_mods = { width = PRESET_BUTTON_FIELD_WIDTH },
                    handler = mi_gui.handlers.preset.load,
                },
                {
                    type = "sprite-button",
                    name = "rename_button",
                    style = "tool_button",
                    sprite = "utility/rename_icon",
                    tooltip = { "module-inserter-ex-rename-preset" },
                    handler = mi_gui.handlers.preset.rename,
                },
                {
                    type = "textfield",
                    name = "rename_textfield",
                    icon_selector = true,
                    visible = false,
                    style_mods = { width = PRESET_BUTTON_FIELD_WIDTH },
                    handler = { [defines.events.on_gui_confirmed] = mi_gui.handlers.preset.rename, }
                },
                {
                    type = "sprite-button",
                    name = "rename_confirm_button",
                    style = "item_and_count_select_confirm",
                    sprite = "utility/enter",
                    tooltip = { "module-inserter-ex-confirm-rename-preset" },
                    visible = false,
                    handler = mi_gui.handlers.preset.rename,
                },
                {
                    type = "sprite-button",
                    name = "export_button",
                    style = "tool_button",
                    sprite = "utility/export_slot",
                    tooltip = { "module-inserter-ex-export-single" },
                    handler = mi_gui.handlers.preset.export,
                },
                {
                    type = "sprite-button",
                    name = "delete_button",
                    style = "tool_button_red",
                    sprite = "utility/trash",
                    tooltip = { "module-inserter-ex-delete-preset" },
                    handler = mi_gui.handlers.preset.delete,
                },
            }
        }
    end,

    pushers = {
        --- @return flib.GuiElemDef
        horizontal = { type = "empty-widget", style_mods = { horizontally_stretchable = true } },
        --- @return flib.GuiElemDef
        vertical = { type = "empty-widget", style_mods = { vertically_stretchable = true } }
    },

    --- @return flib.GuiElemDef
    import_export_window = function(bp_string)
        local caption = bp_string and { "gui.export-to-string" } or { "gui-blueprint-library.import-string" }
        local button_caption = bp_string and { "gui.close" } or { "gui-blueprint-library.import" }
        local button_handler = bp_string and mi_gui.handlers.import.close_button or mi_gui.handlers.import.import_button
        return {
            type = "frame",
            direction = "vertical",
            name = "miex_import_export_window",
            children = {
                {
                    type = "flow",
                    name = "titlebar_flow",
                    drag_target = "miex_import_export_window",
                    children = {
                        { type = "label",        style = "frame_title",               caption = caption,                            elem_mods = { ignored_by_interaction = true } },
                        { type = "empty-widget", style = "flib_titlebar_drag_handle", elem_mods = { ignored_by_interaction = true } },
                        {
                            type = "sprite-button",
                            style = "frame_action_button",
                            sprite = "utility/close",
                            hovered_sprite = "utility/close_black",
                            clicked_sprite = "utility/close_black",
                            handler = mi_gui.handlers.import.close_button,
                        }
                    }
                },
                {
                    type = "text-box",
                    text = bp_string,
                    elem_mods = { word_wrap = true },
                    style_mods = { width = 400, height = 250 },
                    name = "textbox",
                },
                {
                    type = "flow",
                    direction = "horizontal",
                    children = {
                        mi_gui.templates.pushers.horizontal,
                        {
                            type = "button",
                            style = "dialog_button",
                            caption = button_caption,
                            handler = button_handler,
                        }
                    }
                }
            }
        }
    end,
}

function mi_gui.create(player_index)
    local pdata = storage._pdata[player_index]
    local player = game.get_player(player_index)
    if not player or not pdata then return end

    local refs = gui.add(player.gui.screen, {
        type = "frame",
        style_mods = { height = 750 }, ---@diagnostic disable-line: missing-fields
        direction = "vertical",
        handler = { [defines.events.on_gui_closed] = mi_gui.handlers.main.close_window },
        name = "miex_main_window",
        children = {
            {
                type = "flow",
                name = "titlebar_flow",
                drag_target = "miex_main_window",
                children = {
                    {
                        type = "label",
                        style = "frame_title",
                        caption = { "module-inserter-ex-config-window-title" },
                        elem_mods = { ignored_by_interaction = true }, ---@diagnostic disable-line: missing-fields
                    },
                    {
                        type = "empty-widget",
                        style = "flib_titlebar_drag_handle",
                        elem_mods = { ignored_by_interaction = true }, ---@diagnostic disable-line: missing-fields
                    },
                    {
                        type = "sprite-button",
                        name = "pin_button",
                        style = "frame_action_button",
                        tooltip = { "module-inserter-ex-keep-open" },
                        toggled = pdata.pinned,
                        sprite = "flib_pin_white",
                        handler = mi_gui.handlers.main.pin,
                    },
                    {
                        type = "sprite-button",
                        style = "frame_action_button",
                        sprite = "utility/close",
                        hovered_sprite = "utility/close_black",
                        clicked_sprite = "utility/close_black",
                        handler = mi_gui.handlers.main.close,
                    }
                }
            },
            {
                type = "flow",
                direction = "horizontal",
                style = "inset_frame_container_horizontal_flow",
                children = {
                    {
                        type = "frame",
                        style = "inside_shallow_frame",
                        direction = "vertical",
                        children = {
                            {
                                type = "frame",
                                style = "subheader_frame",
                                children = {
                                    {
                                        type = "label",
                                        style = "subheader_caption_label",
                                        caption = { "", { "module-inserter-ex-config-frame-title" }, " [img=info]" },
                                        tooltip = { "module-inserter-ex-module-configuration-tooltip" },
                                    },
                                    mi_gui.templates.pushers.horizontal,
                                    {
                                        type = "sprite-button",
                                        style = "tool_button_red",
                                        sprite = "utility/trash",
                                        tooltip = { "module-inserter-ex-config-button-clear-all" },
                                        handler = mi_gui.handlers.main.clear_all,
                                    },
                                }
                            },
                            {
                                type = "scroll-pane",
                                name = "main_scroll",
                                style = "flib_naked_scroll_pane_no_padding",
                                vertical_scroll_policy = "always",
                                children = {
                                    {
                                        type = "table",
                                        name = "module_config_table",
                                        style_mods = { vertically_stretchable = false, }, ---@diagnostic disable-line: missing-fields
                                        column_count = 2,
                                        children = {
                                            {
                                                type = "frame",
                                                style = "repeated_subheader_frame",
                                                children = {
                                                    {
                                                        type = "label",
                                                        style_mods = { minimal_width = TARGET_SECTION_WIDTH, horizontal_align = "center", }, ---@diagnostic disable-line: missing-fields
                                                        caption = { "", { "module-inserter-ex-target-entities" }, " [img=info]" },
                                                        tooltip = { "module-inserter-ex-target-entities-tooltip" },
                                                    },
                                                }
                                            },
                                            {
                                                type = "frame",
                                                style = "repeated_subheader_frame",
                                                children = {
                                                    {
                                                        type = "label",
                                                        style_mods = { minimal_width = MODULE_SET_WIDTH, horizontal_align = "center", }, ---@diagnostic disable-line: missing-fields
                                                        caption = { "", { "module-inserter-ex-module-specification" }, " [img=info]" },
                                                        tooltip = { "module-inserter-ex-module-specification-tooltip" },
                                                    },
                                                }
                                            },
                                            {
                                                type = "frame",
                                                style = "inside_shallow_frame_with_padding",
                                                style_mods = { horizontally_stretchable = true, vertically_stretchable = true, }, ---@diagnostic disable-line: missing-fields
                                                children = {
                                                    {
                                                        type = "checkbox",
                                                        name = "default_checkbox",
                                                        caption = { "module-inserter-ex-default-modules" },
                                                        state = false,
                                                        style_mods = { margin = 6, horizontally_stretchable = true, }, ---@diagnostic disable-line: missing-fields
                                                        handler = { [defines.events.on_gui_checked_state_changed] = mi_gui.handlers.main.default_checkbox },
                                                        tooltip = { "module-inserter-ex-default-modules-tooltip" },
                                                    }
                                                },
                                            },
                                            {
                                                type = "flow",
                                                name = "default_module_set_holder",
                                                children = {
                                                    mi_gui.templates.module_set("default_module_set"),
                                                }
                                            },
                                        },
                                    },
                                }
                            },
                        }
                    },
                    {
                        type = "frame",
                        name = "preset_frame",
                        style = "inside_shallow_frame",
                        direction = "vertical",
                        children = {
                            {
                                type = "frame",
                                name = "preset_header",
                                style = "subheader_frame",
                                children = {
                                    {
                                        type = "label",
                                        style = "subheader_caption_label",
                                        caption = { "module-inserter-ex-storage-frame-title" }
                                    },
                                    mi_gui.templates.pushers.horizontal,
                                    {
                                        type = "sprite-button",
                                        name = "import_preset_button",
                                        style = "tool_button",
                                        sprite = "utility/import",
                                        tooltip = { "module-inserter-ex-import" },
                                        handler = mi_gui.handlers.presets.import,
                                    },
                                    {
                                        type = "sprite-button",
                                        name = "export_all_presets_button",
                                        style = "tool_button",
                                        sprite = "utility/export_slot",
                                        tooltip = { "module-inserter-ex-export-all" },
                                        handler = mi_gui.handlers.presets.export,
                                    },
                                },
                            },
                            {
                                type = "flow",
                                direction = "vertical",
                                children = {
                                    {
                                        type = "scroll-pane",
                                        style = "flib_naked_scroll_pane_no_padding",
                                        name = "preset_pane",
                                        style_mods = { vertically_stretchable = true }, ---@diagnostic disable-line: missing-fields
                                    },
                                },
                            },
                            {
                                type = "button",
                                name = "add_preset_button",
                                caption = { "module-inserter-ex-add-preset" },
                                tooltip = { "module-inserter-ex-add-preset-tooltip" },
                                style_mods = { horizontally_stretchable = true, }, ---@diagnostic disable-line: missing-fields
                                handler = mi_gui.handlers.presets.add
                            },
                        }
                    }
                }
            }
        }
    })
    pdata.gui.main = {
        window = refs.miex_main_window,
        pin_button = refs.pin_button,
        scroll = refs.main_scroll,
        module_config_table = refs.module_config_table,
        default_checkbox = refs.default_checkbox,
        default_module_set = refs.default_module_set,
        default_module_set_holder = refs.default_module_set_holder,
    }
    pdata.gui.presets = {
        preset_pane = refs.preset_pane,
    }

    refs.miex_main_window.force_auto_center()
    mi_gui.update_presets(pdata)
    mi_gui.update_module_config_table(player, pdata)
    refs.miex_main_window.visible = false
end

--- @param module_config_table LuaGuiElement
--- @param row_index int index of the row to get
--- @return LuaGuiElement target_section the target section for the row provided
function mi_gui.get_mct_target_section(module_config_table, row_index)
    return module_config_table.children[row_index * 2 + 3].target_frame
end

--- @param module_config_table LuaGuiElement
--- @param row_index int index of the row to get
--- @return LuaGuiElement target_reorder_buttons the reorder button frame for the row provided
function mi_gui.get_mct_reorder_buttons(module_config_table, row_index)
    return module_config_table.children[row_index * 2 + 3].reorder_buttons
end

--- @param module_config_table LuaGuiElement
--- @param row_index int index of the row to get
--- @return LuaGuiElement module_set the module set for the row provided
function mi_gui.get_mct_module_set(module_config_table, row_index)
    return module_config_table.children[row_index * 2 + 4]
end

--- @param pdata PlayerConfig
--- @param player LuaPlayer
--- @param bp_string string?
function mi_gui.create_import_window(pdata, player, bp_string)
    local import_gui = pdata.gui.import
    if import_gui and import_gui.window and import_gui.window.valid then
        import_gui.window.destroy()
        pdata.gui.import = nil
    end
    local refs = gui.add(player.gui.screen, { mi_gui.templates.import_export_window(bp_string) })
    pdata.gui.import = {
        window = refs.miex_import_export_window,
        textbox = refs.textbox,
    }

    refs.miex_import_export_window.force_auto_center()
    local textbox = refs.textbox
    if bp_string then
        textbox.read_only = true
    end
    textbox.select_all()
    textbox.focus()
end

--- @param player LuaPlayer
--- @param pdata PlayerConfig
function mi_gui.update_module_config_table(player, pdata)
    local active_config = pdata.active_config

    pdata.gui.main.default_checkbox.state = active_config.use_default
    if active_config.use_default then
        pdata.gui.main.default_module_set.visible = true
        mi_gui.update_module_set(player, 0, pdata.gui.main.default_module_set, storage.max_slot_count,
            active_config.default)
    else
        pdata.gui.main.default_module_set.visible = false
    end

    mi_gui.update_module_config_rows(player, pdata.gui.main.module_config_table, active_config)
end

--- @param player LuaPlayer
--- @param module_config_table LuaGuiElement
--- @param config_tmp PresetConfig
function mi_gui.update_module_config_rows(player, module_config_table, config_tmp)
    -- Add or destroy rows as needed
    while ((#module_config_table.children - 4) / 2) < #config_tmp.rows do
        local row_index = ((#module_config_table.children - 4) / 2) + 1
        gui.add(module_config_table, { mi_gui.templates.target_section(row_index) })
        gui.add(module_config_table, { mi_gui.templates.module_set("module_set", row_index) })
    end
    while ((#module_config_table.children - 4) / 2) > #config_tmp.rows do
        module_config_table.children[#module_config_table.children].destroy() -- module set
        module_config_table.children[#module_config_table.children].destroy() -- target section
    end

    for index, row_config in ipairs(config_tmp.rows) do
        mi_gui.update_module_config_row(player, mi_gui.get_mct_target_section(module_config_table, index),
            mi_gui.get_mct_module_set(module_config_table, index), row_config, index)

        local reorder_buttons_frame = mi_gui.get_mct_reorder_buttons(module_config_table, index)
        reorder_buttons_frame.move_up_button.enabled = (index > 1 and index < #config_tmp.rows)
        reorder_buttons_frame.move_down_button.enabled = index < #config_tmp.rows - 1
    end
end

--- @param player LuaPlayer
--- @param target_section LuaGuiElement
--- @param module_set LuaGuiElement
--- @param row_config RowConfig
--- @param row_index int index of the row config being updated
function mi_gui.update_module_config_row(player, target_section, module_set, row_config, row_index)
    mi_gui.update_target_section(target_section.target_entity_table, row_config.target)

    if not util.target_config_has_entries(row_config.target) then
        -- No target, delete the module section
        module_set.clear()
    else
        -- Update the module section
        local slots = util.get_target_config_max_slots(row_config.target)
        mi_gui.update_module_set(player, row_index, module_set, slots, row_config.module_configs)
    end
end

--- @param target_entity_table LuaGuiElement
--- @param target_config TargetConfig
function mi_gui.update_target_section(target_entity_table, target_config)
    target_entity_table.clear() -- TODO optimize - don't delete everything

    local table_tags = target_entity_table.tags --[[@as TargetFrameTags]]
    local row_index = table_tags.row_index
    -- Filter out already-selected entities
    local entity_filters = { { filter = "name", name = storage.module_entities } }
    for _, entity in pairs(target_config.entities) do
        table.insert(entity_filters, { filter = "name", name = entity, invert = true, mode = "and" })
    end
    -- Add entity buttons as needed
    for index, config_entity in ipairs(target_config.entities) do
        local _, button = gui.add(target_entity_table, { mi_gui.templates.assembler_button(row_index, index, index) })
        button.elem_value = config_entity
        button.tooltip = util.get_localised_entity_name(config_entity, { "module-inserter-ex-choose-assembler" })
        button.elem_filters = entity_filters
    end

    local m_button
    _, m_button = gui.add(target_entity_table, mi_gui.templates.assembler_button(row_index, #target_config.entities + 1, #target_config.entities + 1))
    m_button.elem_filters = entity_filters

    local recipe_filters = {}
    local categories = {}
    for _, entity in pairs(target_config.entities) do
        local entity_cats = prototypes.entity[entity].crafting_categories
        if entity_cats then
            for key, value in pairs(entity_cats) do
                categories[key] = value
            end
        end
    end
    -- Disable if entities with no recipes are selected (e.g. mining drills)
    -- Not actually disabling the button, so the user can choose to clear an existing selection
    local enable = not (#target_config.entities > 0 and util.table_is_empty(categories))
    if enable then
        for key, _ in pairs(categories) do
            table.insert(recipe_filters, { filter = "category", category = key })
        end
    else
        -- A filter that will pass nothing
        recipe_filters = { { filter = "enabled" }, { filter = "enabled", invert = true, mode = "and" } }
    end
    -- Add recipe buttons as needed
    for i, config_recipe in ipairs(target_config.recipes) do
        local index = i + #target_config.entities + 1
        local _, button = gui.add(target_entity_table, { mi_gui.templates.recipe_button(row_index, i) })
        button.elem_value = config_recipe
        button.elem_filters = recipe_filters
        if enable then
            button.tooltip = util.get_localised_recipe_name(config_recipe, { "module-inserter-ex-choose-recipe-with-quality" })
        else
            button.tooltip = { "module-inserter-ex-no-valid-recipes" }
        end
    end
    local _, q_button = gui.add(target_entity_table, mi_gui.templates.recipe_button(row_index, #target_config.recipes + 1))
    if enable then
        q_button.tooltip = { "module-inserter-ex-choose-recipe-with-quality" }
    else
        q_button.tooltip = { "module-inserter-ex-no-valid-recipes" }
    end
    q_button.elem_filters = recipe_filters
end

--- @param player LuaPlayer
--- @param row_index int index of the row being updated (0 for the default config)
--- @param module_set LuaGuiElement
--- @param slots int
--- @param config_set ModuleConfigSet
function mi_gui.update_module_set(player, row_index, module_set, slots, config_set)
    for i, _ in ipairs(config_set.configs) do
        local module_row = module_set.children[i]
        if not module_row then
            gui.add(module_set, mi_gui.templates.module_row(row_index, i, slots))
        end
        module_row = module_set.children[i]
        mi_gui.update_modules(player, module_row, slots, config_set, i)
    end

    while #module_set.children > #config_set.configs do
        module_set.children[#module_set.children].destroy()
    end
end

--- @param player LuaPlayer
--- @param gui_module_row LuaGuiElement
--- @param slots int
--- @param config_set ModuleConfigSet
--- @param index int index of this module row in the set
function mi_gui.update_modules(player, gui_module_row, slots, config_set, index)
    local module_config = config_set.configs[index]
    gui_module_row.add_module_row_button.visible = (index == #config_set.configs)
    gui_module_row.delete_module_row_button.enabled = #config_set.configs > 1
    local button_table = gui_module_row.children[1]
    slots = slots or 0
    local module_list = module_config.module_list or {}
    local module_row_tags = gui_module_row.tags --[[@as ModuleRowTags]]

    -- Add or destroy buttons as needed
    while #button_table.children < slots do
        gui.add(button_table, { mi_gui.templates.module_button(module_row_tags, #button_table.children + 1) })
    end
    while #button_table.children > slots do
        button_table.children[#button_table.children].destroy()
    end

    for i = 1, slots do
        local child = button_table.children[i]
        child.elem_value = module_list[i] --[[@as PrototypeWithQuality]] or nil
        local tooltip = module_list[i] and prototypes.item[module_list[i].name].localised_name or
            { "module-inserter-ex-choose-module" }
        if i == 1 and player.mod_settings["module-inserter-ex-fill-all"].value then
            tooltip = { "", tooltip, "\n", { "module-inserter-ex-choose-module-fill-all-tooltip" } }
        end
        child.tooltip = tooltip
    end
end

--- @param player LuaPlayer
--- @param pdata PlayerConfig
--- @param select boolean? Whether to select the new preset
--- @param data PresetConfig? data to restore
--- @return boolean
function mi_gui.add_preset(player, pdata, select, data)
    local new_preset = data or types.make_preset_config(util.generate_random_name())
    table.insert(pdata.saved_presets, new_preset)
    if select then
        pdata.active_config = new_preset
        mi_gui.update_module_config_table(player, pdata)
    end
    mi_gui.update_presets(pdata)
    return true
end

--- @param pdata PlayerConfig
function mi_gui.update_presets(pdata)
    local preset_pane = pdata.gui.presets.preset_pane
    while #preset_pane.children > #pdata.saved_presets do
        preset_pane.children[#preset_pane.children].destroy()
    end
    while #preset_pane.children < #pdata.saved_presets do
        gui.add(preset_pane, { mi_gui.templates.preset_row(#preset_pane.children + 1) })
    end
    for i, preset_flow in ipairs(preset_pane.children) do
        local preset_button = preset_flow.select_button
        local this_preset = pdata.saved_presets[i]
        preset_button.caption = this_preset.name
        if pdata.naming == this_preset then
            preset_flow.rename_textfield.visible = true
            preset_flow.rename_confirm_button.visible = true
            preset_button.visible = false
            preset_flow.rename_button.visible = false
        else
            preset_flow.rename_textfield.visible = false
            preset_flow.rename_confirm_button.visible = false
            preset_button.visible = true
            preset_flow.rename_button.visible = true
            preset_button.toggled = (this_preset == pdata.active_config)
        end
        -- Don't allow deleting the final preset
        preset_flow.delete_button.enabled = (#pdata.saved_presets > 1)

        preset_flow.reorder_buttons.move_up_button.enabled = (i > 1)
        preset_flow.reorder_buttons.move_down_button.enabled = (i < #pdata.saved_presets)
    end
end

--- @param player LuaPlayer
--- @param pdata PlayerConfig
--- @param new_preset PresetConfig The new preset to set as active
--- @param do_print boolean Whether to print a message the new preset was selected
function mi_gui.update_active_preset(player, pdata, new_preset, do_print)
    if pdata.active_config == new_preset then return end

    -- Ensure it is normalized
    util.normalize_preset_config(new_preset)
    pdata.active_config = new_preset
    pdata.naming = nil -- Cancel any active rename
    mi_gui.update_module_config_table(player, pdata)
    mi_gui.update_presets(pdata)
    if do_print then
        player.print({ "module-inserter-ex-storage-loaded", pdata.active_config.name },
            { skip = defines.print_skip.never })
    end
end

--- @param pdata PlayerConfig
--- @param player LuaPlayer
function mi_gui.destroy(pdata, player)
    local main_gui = pdata.gui.main
    if main_gui and main_gui.window and main_gui.window.valid then
        main_gui.window.destroy()
    end
    local import_gui = pdata.gui.import
    if import_gui and import_gui.window and import_gui.window.valid then
        import_gui.window.destroy()
    end
    if not pdata.pinned then
        player.opened = nil
    end
    pdata.gui.main = nil
    pdata.gui.presets = nil
    pdata.gui.import = nil
end

--- @param e MiEventInfo
function mi_gui.window_is_open(e)
    local window = e.pdata.gui and e.pdata.gui.main and e.pdata.gui.main.window
    return window and window.valid and window.visible
end

--- @param e MiEventInfo
function mi_gui.open(e)
    -- mi_gui.destroy(e.pdata, e.player) -- For debugging - uncomment to always recreate the dialog when opening
    local window = e.pdata.gui and e.pdata.gui.main and e.pdata.gui.main.window
    if not (window and window.valid) then
        mi_gui.destroy(e.pdata, e.player)
        mi_gui.create(e.event.player_index)
        window = e.pdata.gui.main.window
    end
    window.visible = true
    if not e.pdata.pinned then
        e.player.opened = window
    end
end

--- @param e MiEventInfo
function mi_gui.close(e)
    local pdata = e.pdata
    if pdata.closing then
        return
    end
    local window = pdata.gui.main.window
    if window and window.valid then
        window.visible = false
    end
    pdata.naming = nil
    mi_gui.update_presets(pdata)
    if e.player.opened == window then
        pdata.closing = true
        e.player.opened = nil
        pdata.closing = nil
    end
end

--- @param e MiEventInfo
function mi_gui.toggle(e)
    local window = e.pdata.gui and e.pdata.gui.main and e.pdata.gui.main.window
    if window and window.valid and window.visible then
        mi_gui.close(e)
    else
        mi_gui.open(e)
    end
end

mi_gui.handlers = {
    main = {
        --- @param e MiEventInfo
        default_checkbox = function(e)
            e.pdata.active_config.use_default = e.pdata.gui.main.default_checkbox.state
            mi_gui.update_module_config_table(e.player, e.pdata)
        end,
        --- @param e MiEventInfo
        clear_all = function(e)
            e.pdata.active_config.default = types.make_module_config_set()
            e.pdata.active_config.rows = { types.make_row_config() }
            mi_gui.update_module_config_table(e.player, e.pdata)
        end,
        --- @param e MiEventInfo
        close_window = function(e)
            if not e.pdata.pinned then
                mi_gui.close(e)
            end
        end,
        --- @param e MiEventInfo
        close = function(e)
            mi_gui.close(e)
        end,
        --- @param e MiEventInfo
        pin = function(e)
            local pdata = e.pdata
            local pin = pdata.gui.main.pin_button
            pdata.pinned = not pdata.pinned
            pin.toggled = pdata.pinned
            if pdata.pinned then
                pdata.gui.main.window.auto_center = false
                e.player.opened = nil
            else
                pdata.gui.main.window.force_auto_center()
                e.player.opened = pdata.gui.main.window
            end
        end,
        --- @param e MiEventInfo
        choose_assembler = function(e)
            local pdata = e.pdata
            local active_config = pdata.active_config
            local module_config_table = pdata.gui.main.module_config_table
            if not (module_config_table and module_config_table.valid) then return end
            local element = e.event.element
            if not element then return end
            local elem_value = element.elem_value

            local tags = e.event.element.tags --[[@as TargetButtonTags]]

            local row_config = active_config.rows[tags.row_index]
            local old_value = row_config.target.entities[tags.slot_index]
            if elem_value == old_value then
                return
            end

            if elem_value then
                -- Don't allow duplicates in the same row
                if util.array_contains(row_config.target.entities, elem_value) then
                    element.elem_value = old_value
                    e.player.print({ "module-inserter-ex-already-configured-in-this-row",
                        prototypes.entity[elem_value].localised_name })
                    return
                end
                -- If no target recipe, notify of duplicates in other rows with no recipe
                if #row_config.target.recipes == 0 then
                    for k, row in pairs(active_config.rows) do
                        if #row.target.recipes == 0 then
                            for _, target in pairs(row.target.entities) do
                                if target and target == elem_value then
                                    e.player.print({ "module-inserter-ex-already-configured-in-another-row", prototypes
                                        .entity[elem_value].localised_name, k })
                                end
                            end
                        end
                    end
                end
                -- TODO could add some more checks for if the entity/recipe combo appears elsewhere
                local valid, error = util.entity_valid_for_module_set(elem_value --[[@as string]],
                    row_config.module_configs)
                if not valid then
                    element.elem_value = old_value
                    e.player.print(error)
                    return
                end
            end


            if elem_value then
                row_config.target.entities[tags.slot_index] = elem_value --[[@as string]]
            else
                table.remove(row_config.target.entities, tags.slot_index)
            end

            local do_scroll = elem_value and tags.row_index == #active_config.rows

            util.normalize_preset_config(active_config)

            mi_gui.update_module_config_rows(e.player, e.pdata.gui.main.module_config_table, active_config)
            if do_scroll then
                e.pdata.gui.main.scroll.scroll_to_bottom()
            end
        end,

        --- @param e MiEventInfo
        choose_recipe = function(e)
            local pdata = e.pdata
            local active_config = pdata.active_config
            local module_config_table = pdata.gui.main.module_config_table
            if not (module_config_table and module_config_table.valid) then return end
            local element = e.event.element
            if not element then return end
            local elem_value = element.elem_value --[[@as PrototypeWithQuality]]

            local tags = e.event.element.tags --[[@as TargetButtonTags]]

            local row_config = active_config.rows[tags.row_index]
            local old_value = row_config.target.recipes[tags.slot_index]
            if elem_value == old_value then
                return
            end

            if elem_value then
                -- Don't allow duplicates in the same row
                if util.array_contains_recipe(row_config.target.recipes, elem_value) then
                    element.elem_value = old_value
                    e.player.print({ "module-inserter-ex-already-configured-in-this-row",
                        prototypes.recipe[elem_value.name].localised_name })
                    return
                end
            end
            -- TODO check duplicates in other rows, validity


            if elem_value then
                row_config.target.recipes[tags.slot_index] = elem_value --[[@as PrototypeWithQuality]]
            else
                table.remove(row_config.target.recipes, tags.slot_index)
            end

            local do_scroll = elem_value and tags.row_index == #active_config.rows

            util.normalize_preset_config(active_config)

            mi_gui.update_module_config_rows(e.player, e.pdata.gui.main.module_config_table, active_config)
            if do_scroll then
                e.pdata.gui.main.scroll.scroll_to_bottom()
            end
        end,

        --- @param e MiEventInfo
        choose_module = function(e)
            local element = e.event.element
            if not element then return end
            local active_config = e.pdata.active_config
            if not active_config then return end
            local module_config_table = e.pdata.gui.main.module_config_table
            if not (module_config_table and module_config_table.valid) then return end

            --- @type ModuleConfigSet
            local module_config_set
            --- @type TargetConfig
            local target_config
            local module_button_tags = element.tags --[[@as ModuleButtonTags]]
            local slot = module_button_tags.slot_index
            local is_default_config = (module_button_tags.row_index == 0)
            local row_config = nil
            local slot_count
            if is_default_config then
                module_config_set = active_config.default
                slot_count = storage.max_slot_count
            else
                row_config = active_config.rows[module_button_tags.row_index]
                module_config_set = row_config.module_configs
                target_config = row_config.target
                slot_count = util.get_target_config_max_slots(row_config.target)
            end

            local module_config = module_config_set.configs[module_button_tags.module_row_index]
            if element.elem_value and target_config then
                -- If a normal row with assembler targets selected, check if the module is valid
                local valid, error = util.module_valid_for_config(element.elem_value.name, target_config)
                if not valid then
                    e.player.print(error)
                    element.elem_value = module_config.module_list[slot] --[[@as PrototypeWithQuality]] or nil
                    return
                end
            end
            module_config.module_list[slot] = util.normalize_id_quality_pair(element
                .elem_value --[[@as ItemIDAndQualityIDPair]])

            if slot == 1 and e.player.mod_settings["module-inserter-ex-fill-all"].value then
                for i = 2, slot_count do
                    module_config.module_list[i] = module_config.module_list[slot]
                end
            end
            util.normalize_module_config(slot_count, module_config)

            if not is_default_config then
                mi_gui.update_module_set(e.player, module_button_tags.row_index,
                    mi_gui.get_mct_module_set(module_config_table, module_button_tags.row_index), slot_count,
                    module_config_set)
            else
                mi_gui.update_module_set(e.player, 0, e.pdata.gui.main.default_module_set, slot_count, module_config_set)
            end
        end,
        --- @param e MiEventInfo
        destroy_tool = function(e)
            e.player.get_main_inventory().remove { name = "module-inserter-ex", count = 1 }
            mi_gui.close(e)
        end,
        --- @param e MiEventInfo
        add_module_row = function(e)
            local module_row_tags = e.event.element.parent.tags --[[@as ModuleRowTags]]
            local row_index = module_row_tags.row_index
            --- @type ModuleConfigSet
            local config_set
            local slots
            local gui_module_set
            if row_index == 0 then
                config_set = e.pdata.active_config.default
                slots = storage.max_slot_count
                gui_module_set = e.pdata.gui.main.default_module_set
            else
                local row_config = e.pdata.active_config.rows[row_index]
                config_set = row_config.module_configs
                slots = util.get_target_config_max_slots(row_config.target)
                gui_module_set = mi_gui.get_mct_module_set(e.pdata.gui.main.module_config_table, row_index)
            end
            config_set.configs[#config_set.configs + 1] = types.make_module_config()
            mi_gui.update_module_set(e.player, row_index, gui_module_set, slots, config_set)
        end,
        --- @param e MiEventInfo
        delete_module_row = function(e)
            local module_row_tags = e.event.element.parent.tags --[[@as ModuleRowTags]]
            local row_index = module_row_tags.row_index
            --- @type ModuleConfigSet
            local config_set
            local slots
            local gui_module_set
            if row_index == 0 then
                config_set = e.pdata.active_config.default
                slots = storage.max_slot_count
                gui_module_set = e.pdata.gui.main.default_module_set
            else
                local row_config = e.pdata.active_config.rows[row_index]
                config_set = row_config.module_configs
                slots = util.get_target_config_max_slots(row_config.target)
                gui_module_set = mi_gui.get_mct_module_set(e.pdata.gui.main.module_config_table, row_index)
            end
            table.remove(config_set.configs, module_row_tags.module_row_index)
            mi_gui.update_module_set(e.player, row_index, gui_module_set, slots, config_set)
        end,

        --- @param e MiEventInfo
        move_up = function(e)
            local pdata = e.pdata
            local module_row_tags = e.event.element.tags --[[@as TargetFrameTags]]
            local index = module_row_tags.row_index

            if index == 1 or index > #pdata.active_config.rows then return end

            local config_row = pdata.active_config.rows[index]
            if not config_row then return end

            table.remove(pdata.active_config.rows, index)

            if e.event.shift then
                table.insert(pdata.active_config.rows, 1, config_row)
            else
                table.insert(pdata.active_config.rows, index - 1, config_row)
            end

            mi_gui.update_module_config_table(e.player, e.pdata)
        end,

        --- @param e MiEventInfo
        move_down = function(e)
            local pdata = e.pdata
            local module_row_tags = e.event.element.tags --[[@as TargetFrameTags]]
            local index = module_row_tags.row_index

            if index >= #pdata.active_config.rows - 1 then return end

            local config_row = pdata.active_config.rows[index]
            if not config_row then return end

            table.remove(pdata.active_config.rows, index)

            if e.event.shift then
                table.insert(pdata.active_config.rows, #pdata.active_config.rows, config_row)
            else
                table.insert(pdata.active_config.rows, index + 1, config_row)
            end

            mi_gui.update_module_config_table(e.player, e.pdata)
        end,
    },
    presets = {

        --- @param e MiEventInfo
        add = function(e)
            if e.event.shift then
                mi_gui.add_preset(e.player, e.pdata, true, table.deep_copy(e.pdata.active_config))
            else
                mi_gui.add_preset(e.player, e.pdata, true)
            end
        end,

        --- @param e MiEventInfo
        import = function(e)
            mi_gui.create_import_window(e.pdata, e.player)
        end,
        --- @param e MiEventInfo
        export = function(e)
            mi_gui.create_import_window(e.pdata, e.player, helpers.table_to_json(e.pdata.saved_presets))
        end
    },
    preset = {

        --- @param e MiEventInfo
        move_up = function(e)
            local pdata = e.pdata
            local tags = e.event.element.parent.parent.tags --[[@as PresetRowTags]]
            local index = tags.preset_index

            if index == 1 then return end

            local preset = pdata.saved_presets[index]
            if not preset then return end

            table.remove(pdata.saved_presets, index)

            if e.event.shift then
                table.insert(pdata.saved_presets, 1, preset)
            else
                table.insert(pdata.saved_presets, index - 1, preset)
            end

            mi_gui.update_presets(pdata)
        end,

        --- @param e MiEventInfo
        move_down = function(e)
            local pdata = e.pdata
            local tags = e.event.element.parent.parent.tags --[[@as PresetRowTags]]
            local index = tags.preset_index

            if index == #pdata.saved_presets then return end

            local preset = pdata.saved_presets[index]
            if not preset then return end

            table.remove(pdata.saved_presets, index)

            if e.event.shift then
                table.insert(pdata.saved_presets, preset)
            else
                table.insert(pdata.saved_presets, index + 1, preset)
            end

            mi_gui.update_presets(pdata)
        end,

        --- @param e MiEventInfo
        load = function(e)
            local pdata = e.pdata
            local tags = e.event.element.parent.tags --[[@as PresetRowTags]]
            local index = tags.preset_index

            local preset = pdata.saved_presets[index]
            if not preset then return end


            local keep_open = not e.player.mod_settings["module-inserter-ex-close-after-load"].value
            mi_gui.update_active_preset(e.player, e.pdata, preset, not keep_open)

            if not keep_open then
                mi_gui.close(e)
                e.player.print({ "module-inserter-ex-storage-loaded", pdata.active_config.name })
            end
        end,

        --- @param e MiEventInfo
        export = function(e)
            local tags = e.event.element.parent.tags --[[@as PresetRowTags]]
            local config = e.pdata.saved_presets[tags.preset_index]
            if not config then return end
            mi_gui.create_import_window(e.pdata, e.player, helpers.table_to_json(config))
        end,
        --- @param e MiEventInfo
        delete = function(e)
            if #e.pdata.saved_presets <= 1 then
                return
            end
            local tags = e.event.element.parent.tags --[[@as PresetRowTags]]
            local update_selection = (e.pdata.saved_presets[tags.preset_index] == e.pdata.active_config)
            table.remove(e.pdata.saved_presets, tags.preset_index)
            if update_selection then
                e.pdata.active_config = e.pdata.saved_presets[math.min(#e.pdata.saved_presets, tags.preset_index)]
                mi_gui.update_module_config_table(e.player, e.pdata)
            end
            mi_gui.update_presets(e.pdata)
        end,
        --- @param e MiEventInfo
        rename = function(e)
            --- @type LuaGuiElement
            local parent = e.event.element.parent
            if not parent then return end
            --- @type LuaGuiElement
            local textfield = parent.rename_textfield
            local tags = parent.tags --[[@as PresetRowTags]]
            local preset = e.pdata.saved_presets[tags.preset_index]
            if e.pdata.naming == preset then
                -- Confirm the rename
                local text = textfield.text
                if text == "" then
                    e.player.print({ "module-inserter-ex-storage-name-not-set" })
                    return
                end
                e.pdata.naming.name = textfield.text
                e.pdata.naming = nil
            else
                e.pdata.naming = preset
                textfield.text = preset.name
            end
            mi_gui.update_presets(e.pdata)
            textfield.select_all()
            textfield.focus()
        end,
    },
    import = {
        --- @param e MiEventInfo
        import_button = function(e)
            local player = e.player
            local pdata = e.pdata
            local text_box = pdata.gui.import.textbox
            local configs = import_export.import_config(text_box.text)
            if type(configs) == "string" then
                player.print({ "failed-to-import-string", configs })
                return
            end
            for _, preset in ipairs(configs) do
                util.normalize_preset_config(preset)
                mi_gui.add_preset(e.player, e.pdata, false, preset)
            end
            mi_gui.handlers.import.close_button(e)
        end,
        --- @param e MiEventInfo
        close_button = function(e)
            local window = e.pdata.gui.import.window
            window.destroy()
            e.pdata.gui.import = nil
        end
    },
}

return mi_gui
