
--- @class (exact) GlobalData
--- @field to_create {[int]:{[int]:ToCreateData}}
--- @field name_to_slot_count {[string]:int} Name of all entities mapped to their module slot count
--- @field max_slot_count int Number of slots the entity with the most has (used for default config slot count)
--- @field module_entities string[] all entities that have valid module slots
--- @field _pdata {[int]:PlayerConfig}

--- @class (exact) PlayerConfig
--- @field last_preset string
--- @field config PresetConfig
--- @field config_tmp PresetConfig
--- @field config_by_entity ConfigByEntity
--- @field saved_presets SavedPresets
--- @field gui PlayerGui
--- @field gui_open boolean
--- @field pinned boolean Is the gui pinned
--- @field cursor boolean True when the module inserter item is in this players cursor

--- @alias SavedPresets {string:PresetConfig}

--- @alias ConfigByEntity {[string]: ModuleConfigSet}

--- @class (exact) PlayerGui
--- @field main PlayerGuiMain
--- @field presets PlayerGuiPresets
--- @field import PlayerGuiImport?

--- @class (exact) PlayerGuiMain
--- @field window LuaGuiElement
--- @field pin_button LuaGuiElement
--- @field destroy_tool_button LuaGuiElement
--- @field config_rows LuaGuiElement
--- @field default_checkbox LuaGuiElement
--- @field default_module_set LuaGuiElement

--- @class (exact) PlayerGuiPresets
--- @field textfield LuaGuiElement
--- @field scroll_pane LuaGuiElement

--- @class (exact) PlayerGuiImport
--- @field textbox LuaGuiElement
--- @field window LuaGuiElement


--- @class (exact) PresetConfig
--- @field default ModuleConfigSet
--- @field use_default boolean
--- @field rows RowConfig[]

--- @class (exact) RowConfig
--- @field from string? the entity name this config applies to
--- @field module_configs ModuleConfigSet set of module configs for this row

--- @class (exact) ModuleConfigSet
--- @field configs ModuleConfig[]

--- @class (exact) ModuleConfig
--- @field module_list ItemIDAndQualityIDPair[] array of module slot indexes to the module in that slot


--- @class (exact) MiEventInfo
--- @field event flib.GuiEventData
--- @field player LuaPlayer
--- @field pdata PlayerConfig

--- @class (exact) ToCreateData
--- @field entity LuaEntity
--- @field modules ItemIDAndQualityIDPair[]
--- @field player LuaPlayer
--- @field surface LuaSurface


local types = {}


--- @return PresetConfig
function types.make_preset_config()
    --- @type PresetConfig
    return {
        use_default = false,
        default = types.make_module_config_set(),
        rows = {
            types.make_row_config()
        },
    }
end

--- @return RowConfig
function types.make_row_config()
    --- @type RowConfig
    return {
        from = nil,
        module_configs = types.make_module_config_set(),
    }
end

--- @return ModuleConfigSet
function types.make_module_config_set()
    --- @type ModuleConfigSet
    return {
        configs = { types.make_module_config() },
    }
end

--- @return ModuleConfig
function types.make_module_config()
    --- @type ModuleConfig
    return {
        module_list = {},
    }
end

return types
