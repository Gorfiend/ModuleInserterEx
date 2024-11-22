--- @class (exact) GlobalData
--- @field to_create {[int]:{[int]:ToCreateData}}
--- @field name_to_slot_count {[string]:int} Name of all entities mapped to their module slot count
--- @field max_slot_count int Number of slots the entity with the most has (used for default config slot count)
--- @field module_entities string[] all entities that have valid module slots
--- @field _pdata {[int]:PlayerConfig}

--- @class (exact) PlayerConfig
--- @field active_config PresetConfig One of the presets in saved_presets
--- @field temp_config PresetConfig? Temporarily save a config so you can revert changes
--- @field saved_presets SavedPresets
--- @field gui PlayerGui
--- @field gui_open boolean
--- @field naming PresetConfig? preset currently being renamed
--- @field closing boolean? Is the main window currently closing?
--- @field pinned boolean Is the gui pinned
--- @field cursor boolean True when the module inserter item is in this players cursor

--- @alias SavedPresets PresetConfig[]

--- @alias ConfigByEntity {[string]: ModuleConfigSet}

--- @class (exact) PlayerGui
--- @field main PlayerGuiMain
--- @field presets PlayerGuiPresets
--- @field rename PlayerGuiRename?
--- @field import PlayerGuiImport?

--- @class (exact) PlayerGuiMain
--- @field window LuaGuiElement
--- @field pin_button LuaGuiElement
--- @field destroy_tool_button LuaGuiElement
--- @field scroll LuaGuiElement
--- @field config_rows LuaGuiElement
--- @field default_checkbox LuaGuiElement
--- @field default_module_set LuaGuiElement

--- @class (exact) PlayerGuiPresets
--- @field scroll_pane LuaGuiElement

--- @class (exact) PlayerGuiRename
--- @field textfield LuaGuiElement
--- @field window LuaGuiElement

--- @class (exact) PlayerGuiImport
--- @field textbox LuaGuiElement
--- @field window LuaGuiElement


--- @class (exact) PresetConfig
--- @field name string This presets name
--- @field default ModuleConfigSet
--- @field use_default boolean
--- @field rows RowConfig[]

--- @class (exact) RowConfig
--- @field target TargetConfig Target entities to apply these modules to
--- @field module_configs ModuleConfigSet set of module configs for this row

--- @class (exact) TargetConfig
--- @field entities string[] List of entities (assemblers) to apply the config to

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
--- @field module_config ModuleConfig
--- @field player LuaPlayer
--- @field surface LuaSurface

--- @class (exact) ModuleRowTags
--- @field row_index int index of the row, 0 is the default row
--- @field module_row_index int index of the module row this is part of

--- @class (exact) ModuleButtonTags
--- @field row_index int index of the row, 0 is the default row
--- @field module_row_index int index of the module row this is part of
--- @field slot_index int index of the slot

--- @class (exact) TargetFrameTags
--- @field row_index int index of the row, 0 is the default row

--- @class (exact) TargetButtonTags
--- @field row_index int index of the row, 0 is the default row
--- @field slot_index int index of the slot

--- @class (exact) PresetRowTags
--- @field preset_index int index of the preset

local types = {}


--- @param name string
--- @return PresetConfig
function types.make_preset_config(name)
    --- @type PresetConfig
    return {
        name = name,
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
        target = types.make_target_config(),
        module_configs = types.make_module_config_set(),
    }
end

--- @return TargetConfig
function types.make_target_config()
    --- @type TargetConfig
    return {
        entities = {}
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
