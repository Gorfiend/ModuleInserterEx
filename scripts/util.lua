
local util = {}

--- @param pair ItemIDAndQualityIDPair?
--- @return ItemIDAndQualityIDPair?
function util.normalize_id_quality_pair(pair)
    if not pair then return end
    if pair.quality and not type(pair.quality) == "string" then
        return {
            name = pair.name,
            quality = pair.quality.name,
        }
    end
    return pair
end

return util