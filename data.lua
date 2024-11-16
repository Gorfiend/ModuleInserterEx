require "__ModuleInserterEx__/prototypes/style"

local data_util = require("__flib__.data-util")

local frame_action_icons = "__ModuleInserterEx__/graphics/frame-action-icons.png"

data:extend{
  -- frame action icons
  data_util.build_sprite("mi_pin_black", {0, 64}, frame_action_icons, 32),
  data_util.build_sprite("mi_pin_white", {32, 64}, frame_action_icons, 32),
  data_util.build_sprite("mi_settings_black", {0, 96}, frame_action_icons, 32),
  data_util.build_sprite("mi_settings_white", {32, 96}, frame_action_icons, 32),
}

data:extend({
    {
        type = 'custom-input',
        name = 'get-module-inserter',
        key_sequence = "",
        action = 'lua',
        consuming = 'none'
    },
    {
        type = 'custom-input',
        name = 'toggle-module-inserter',
        key_sequence = "CONTROL + I",
        action = 'lua',
        consuming = 'none',
    },
    {
        type = "custom-input",
        name = "mi-confirm-gui",
        key_sequence = "",
        linked_game_control = "confirm-gui",
    },
    {
        type = 'shortcut',
        name = 'module-inserter',
        --order = "a[yarm]",
        action = 'lua',
        style = 'green',
        icons = {{
            icon = "__ModuleInserterEx__/graphics/new-module-inserter-x32-white.png",
            priority = 'extra-high-no-scale',
            icon_size = 32,
            scale = 1,
            flags = {'icon'},
        }},
        small_icons = {{
            icon = "__ModuleInserterEx__/graphics/new-module-inserter-x24-white.png",
            priority = 'extra-high-no-scale',
            icon_size = 24,
            scale = 1,
            flags = {'icon'},
        }},
    },
    {
        type = "selection-tool",
        name = "module-inserter",
        icon = "__ModuleInserterEx__/graphics/module-inserter-icon.png",
        icon_size = 32,
        flags = {"not-stackable", "mod-openable", "spawnable"},
        hidden = true,
        stack_size = 1,
        select = {
            border_color = { r = 0, g = 1, b = 0 },
            mode = {"same-force", "deconstruct"},
            cursor_box_type = "copy",
            entity_type_filters = {"mining-drill", "furnace", "assembling-machine", "lab", "beacon", "rocket-silo", "item-request-proxy"},
            entity_filter_mode = "whitelist",
        },
        alt_select = {
            border_color = { r = 0, g = 0, b = 1 },
            mode = {"same-force", "any-entity"},
            cursor_box_type = "copy",
            entity_type_filters = {"mining-drill", "furnace", "assembling-machine", "lab", "beacon", "rocket-silo", "item-request-proxy"},
            entity_filter_mode = "whitelist",
        },
        reverse_select = {
            border_color = { r = 1, g = 0, b = 0 },
            mode = {"same-force", "deconstruct"},
            cursor_box_type = "copy",
            entity_type_filters = {"mining-drill", "furnace", "assembling-machine", "lab", "beacon", "rocket-silo", "item-request-proxy"},
            entity_filter_mode = "whitelist",
        },
    },
})
