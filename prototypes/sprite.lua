local data_util = require("__flib__.data-util")

local frame_action_icons = "__ModuleInserterEx__/graphics/frame-action-icons.png"

data:extend {
    -- frame action icons
    data_util.build_sprite("miex_pin_black", { 0, 64 }, frame_action_icons, 32),
    data_util.build_sprite("miex_pin_white", { 32, 64 }, frame_action_icons, 32),
}
