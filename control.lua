local ENTITY_NAME = "evolution-constant-combinator"
local SIGNAL = { type = "virtual", name = "signal-evolution-factor", quality = "normal" }
local UPDATE_INTERVAL = 60
local REGISTRY_RESCAN_INTERVAL = 300

local function ensure_globals()
  storage.combinators = storage.combinators or {}
end

local function is_valid(entity)
  return entity and entity.valid and entity.name == ENTITY_NAME
end

local function register_entity(entity)
  if not is_valid(entity) or not entity.unit_number then
    return
  end
  storage.combinators[entity.unit_number] = entity
end

local function unregister_entity(entity)
  if not entity or not entity.unit_number then
    return
  end
  storage.combinators[entity.unit_number] = nil
end

local function get_or_create_section(behavior)
  if not behavior or not behavior.valid then
    return nil
  end

  for i = 1, behavior.sections_count do
    local section = behavior.get_section(i)
    if section and section.valid and section.is_manual then
      return section
    end
  end

  local new_section = behavior.add_section()
  if new_section and new_section.valid and new_section.is_manual then
    return new_section
  end

  return nil
end

local function update_combinator(entity)
  if not is_valid(entity) then
    return false
  end

  local enemy_force = game.forces["enemy"]
  if not enemy_force then
    return true
  end

  local behavior = entity.get_or_create_control_behavior()
  local section = get_or_create_section(behavior)
  if not section or not section.valid then
    return true
  end

  behavior.enabled = true

  local evolution = enemy_force.get_evolution_factor(entity.surface)
  local scaled_evolution = math.floor(evolution * 100 + 0.5)

  section.filters = {
    {
      value = SIGNAL,
      min = scaled_evolution
    }
  }

  return true
end

local function rebuild_registry()
  ensure_globals()
  storage.combinators = {}

  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered({ name = ENTITY_NAME })
    for _, entity in pairs(found) do
      register_entity(entity)
      update_combinator(entity)
    end
  end
end

local function register_missing_entities()
  ensure_globals()

  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered({ name = ENTITY_NAME })
    for _, entity in pairs(found) do
      register_entity(entity)
      update_combinator(entity)
    end
  end
end

local function on_entity_built(event)
  local entity = event.entity or event.created_entity or event.destination
  if is_valid(entity) then
    register_entity(entity)
    update_combinator(entity)
  end
end

local function on_entity_removed(event)
  local entity = event.entity
  if entity and entity.name == ENTITY_NAME then
    unregister_entity(entity)
  end
end

local function on_gui_opened(event)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then
    return
  end

  local opened = player.opened
  if not opened then
    return
  end

  if opened.object_name == "LuaEntity" and opened.valid and opened.name == ENTITY_NAME then
    player.opened = nil
  end
end

script.on_init(function()
  ensure_globals()
  rebuild_registry()
  for _, entity in pairs(storage.combinators) do
    update_combinator(entity)
  end
end)

script.on_configuration_changed(function()
  ensure_globals()
  rebuild_registry()
  for _, entity in pairs(storage.combinators) do
    update_combinator(entity)
  end
end)

script.on_event(defines.events.on_built_entity, on_entity_built)
script.on_event(defines.events.on_robot_built_entity, on_entity_built)
script.on_event(defines.events.script_raised_built, on_entity_built)
script.on_event(defines.events.script_raised_revive, on_entity_built)
if defines.events.on_space_platform_built_entity then
  script.on_event(defines.events.on_space_platform_built_entity, on_entity_built)
end

script.on_event(defines.events.on_player_mined_entity, on_entity_removed)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed)
script.on_event(defines.events.on_entity_died, on_entity_removed)
script.on_event(defines.events.script_raised_destroy, on_entity_removed)
if defines.events.on_space_platform_mined_entity then
  script.on_event(defines.events.on_space_platform_mined_entity, on_entity_removed)
end
script.on_event(defines.events.on_gui_opened, on_gui_opened)

script.on_nth_tick(UPDATE_INTERVAL, function()
  ensure_globals()

  for unit_number, entity in pairs(storage.combinators) do
    if not update_combinator(entity) then
      storage.combinators[unit_number] = nil
    end
  end

  if game.tick % REGISTRY_RESCAN_INTERVAL == 0 then
    register_missing_entities()
  end
end)
