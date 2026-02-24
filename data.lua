local EVOLUTION_COMBINATOR_NAME = "evolution-constant-combinator"
local EVOLUTION_SIGNAL_NAME = "signal-evolution-factor"
local ENTITY_SPRITE_PATH = "__simple-evolution-combinator__/graphics/entity/evolution-constant-combinator/evolution-constant-combinator.png"
local ITEM_ICON_PATH = "__simple-evolution-combinator__/graphics/icons/evolution-constant-combinator.png"
local SIGNAL_ICON_PATH = "__simple-evolution-combinator__/graphics/icons/signal/signal-evolution-factor.png"

local function replace_entity_sprite_filenames(value, visited)
  if type(value) ~= "table" then
    return
  end

  visited = visited or {}
  if visited[value] then
    return
  end
  visited[value] = true

  for key, nested in pairs(value) do
    if key == "filename" and nested == "__base__/graphics/entity/combinator/constant-combinator.png" then
      value[key] = ENTITY_SPRITE_PATH
    else
      replace_entity_sprite_filenames(nested, visited)
    end
  end
end

local entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
entity.name = EVOLUTION_COMBINATOR_NAME
entity.minable.result = EVOLUTION_COMBINATOR_NAME
entity.fast_replaceable_group = "constant-combinator"
entity.next_upgrade = nil
entity.icon = ITEM_ICON_PATH
entity.icon_size = 64
replace_entity_sprite_filenames(entity)

local item = table.deepcopy(data.raw["item"]["constant-combinator"])
item.name = EVOLUTION_COMBINATOR_NAME
item.place_result = EVOLUTION_COMBINATOR_NAME
item.order = "c[combinators]-d[evolution-constant-combinator]"
item.icon = ITEM_ICON_PATH
item.icon_size = 64

local recipe = {
  type = "recipe",
  name = EVOLUTION_COMBINATOR_NAME,
  enabled = false,
  ingredients = {
    { type = "item", name = "constant-combinator", amount = 1 }
  },
  results = {
    { type = "item", name = EVOLUTION_COMBINATOR_NAME, amount = 1 }
  }
}

local signal = {
  type = "virtual-signal",
  name = EVOLUTION_SIGNAL_NAME,
  icon = SIGNAL_ICON_PATH,
  icon_size = 64,
  subgroup = "virtual-signal-special",
  order = "z[evolution-factor]"
}

local circuit_network = data.raw["technology"]["circuit-network"]
if circuit_network and circuit_network.effects then
  table.insert(circuit_network.effects, {
    type = "unlock-recipe",
    recipe = EVOLUTION_COMBINATOR_NAME
  })
end

data:extend({
  entity,
  item,
  recipe,
  signal
})
