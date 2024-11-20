local data_util = require("__flib__.data-util")

local frame_action_icons = "__ModuleInserterEx__/graphics/frame-action-icons.png"

data:extend {
    -- frame action icons
    data_util.build_sprite("mi_pin_black", { 0, 64 }, frame_action_icons, 32),
    data_util.build_sprite("mi_pin_white", { 32, 64 }, frame_action_icons, 32),
    data_util.build_sprite("mi_settings_black", { 0, 96 }, frame_action_icons, 32),
    data_util.build_sprite("mi_settings_white", { 32, 96 }, frame_action_icons, 32),
}
