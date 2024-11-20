
local import_export = {}

function import_export.export_config(player, config_data, name)
    local status, result = pcall(function()
        local to_bp_entities = function(data)
            local entities = {}
            local bp_index = 1
            for i, config in pairs(data) do
                if config.from then
                    local items = {}
                    for _, module in pairs(config.module_list) do
                        items[module] = items[module] and items[module] + 1 or 1
                    end
                    entities[bp_index] = {
                        entity_number = i,
                        items = items,
                        name = config.from,
                        position = { x = 0, y = i * 5.5 },
                    }
                    bp_index = bp_index + 1
                end
            end
            return entities
        end
        local inventory, stack, result
        --export a single preset
        if name then
            inventory = game.create_inventory(1)
            inventory.insert { name = "blueprint" }
            stack = inventory[1]
            stack.set_blueprint_entities(to_bp_entities(config_data))
            stack.label = name

            result = stack.export_stack()
            inventory.destroy()
            --export all presets
        else
            inventory = game.create_inventory(1)
            inventory.insert { name = "blueprint-book" }
            local book = inventory[1]
            local book_inventory = book.get_inventory(defines.inventory.item_main)
            local index = 1
            for preset_name, preset_config in pairs(config_data) do
                book_inventory.insert { name = "blueprint" }
                book_inventory[index].set_blueprint_entities(to_bp_entities(preset_config))
                book_inventory[index].label = preset_name
                index = index + 1
            end
            book.label = "ModuleInserter Configuration"
            result = book.export_stack()
            inventory.destroy()
        end
        return result
    end)
    if not status then
        player.print(result)
        return false
    else
        return result
    end
end

--- @param player any
--- @param bp_string any
--- @return int status return of import_stack, or 2 for other errors
--- @return PresetConfig|{[string]:PresetConfig}
--- @return string
--- @nodiscard
function import_export.import_config(player, bp_string)
    local status, a, b, c = pcall(function()
        local to_config = function(entities)
            if not entities then return end
            local config = {}
            local config_index = 0
            local modules
            for _, ent in pairs(entities) do
                if storage.name_to_slot_count[ent.name] then
                    modules = {}
                    config_index = config_index + 1
                    if ent.items then
                        for module, amount in pairs(ent.items) do
                            for _ = 1, amount do
                                modules[table_size(modules) + 1] = module
                            end
                        end
                    end
                    config[config_index] = { cTable = ent.items or {}, from = ent.name, to = modules }
                end
            end
            for i = 1, #config do
                if not config[i] then
                    config[i] = { cTable = {}, to = {} }
                end
            end
            return config
        end

        local inventory = game.create_inventory(1)
        inventory.insert { name = "blueprint" }
        local stack = inventory[1]
        local result = stack.import_stack(bp_string)
        if result ~= 0 then return result end

        if stack.type == "blueprint" then
            local name = stack.label or "ModuleInserter Configuration"
            local config = to_config(stack.get_blueprint_entities())
            inventory.destroy()
            return result, config, name
        elseif stack.type == "blueprint-book" then
            local presets = {}
            local name, item
            local book_inventory = stack.get_inventory(defines.inventory.item_main)
            for i = 1, #book_inventory do
                item = book_inventory[i]
                name = item.label or "ModuleInserter Configuration"
                presets[name] = to_config(item.get_blueprint_entities())
            end
            return result, presets
        end
    end)
    if not status then
        player.print("Import failed: " .. a)
        return 2
    else
        return a, b, c
    end
end

return import_export
