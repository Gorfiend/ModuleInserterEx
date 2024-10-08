local ent = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
local signal_anything = data.raw["virtual-signal"]["signal-anything"]

ent.name = "mi-default-proxy-machine"
ent.icons = nil
ent.icon = signal_anything.icon
ent.icon_mipmaps = signal_anything.icon_mipmaps
ent.icon_size = signal_anything.icon_size


local max_slots = 0
for _, assem in pairs(data.raw["assembling-machine"]) do
    if assem.module_specification and assem.module_specification.module_slots then
        max_slots = math.max(max_slots, assem.module_specification.module_slots)
    end
end
ent.module_specification = {
    module_slots = max_slots
}
ent.allowed_effects = { "speed", "productivity", "consumption", "pollution" }

ent.flags = {
    "player-creation",
    "hidden",
}
ent.crafting_speed = 1
ent.energy_source = {
    type = "void",
}


-- Item needed to be able to use the entity in a blueprint
local entItem = {}
entItem.name = "mi-default-proxy-machine"
entItem.type = "item"
entItem.icon = signal_anything.icon
entItem.icon_mipmaps = signal_anything.icon_mipmaps
entItem.icon_size = signal_anything.icon_size
entItem.place_result = "mi-default-proxy-machine"
entItem.stack_size = 1
entItem.flags = { "hidden" }


data:extend({ ent, entItem })
