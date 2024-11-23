local prefix = "module-inserter-ex-"
data:extend({
    {
        type = "int-setting",
        name = prefix .. "proxies-per-tick",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 1,
        order = "a"
    },
    {
        type = "bool-setting",
        name = prefix .. "close-after-load",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "a"
    },
    {
        type = "bool-setting",
        name = prefix .. "fill-all",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "c"
    },
    {
        type = "bool-setting",
        name = prefix .. "hide-button",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "d"
    },
    {
        type = "string-setting",
        name = prefix .. "button-style",
        setting_type = "runtime-per-user",
        default_value = "mod_gui_button",
        allowed_values = {"mod_gui_button", "slot_button"}
    }
})