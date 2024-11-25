local prefix = "module-inserter-ex-"
data:extend({
    {
        type = "int-setting",
        name = prefix .. "proxies-per-tick",
        setting_type = "runtime-global",
        default_value = 20,
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
})