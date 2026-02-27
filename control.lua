local ENTITY_NAME = "evolution-constant-combinator"
local SIGNAL = { type = "virtual", name = "signal-evolution-factor", quality = "normal" }
local UPDATE_INTERVAL = 300 -- was 60 (1s), now 300 (5s) — evolution changes slowly
local REGISTRY_RESCAN_INTERVAL = 300

local function ensure_globals()
  storage.combinators   = storage.combinators or {}
  storage.section_cache = storage.section_cache or {} -- cached section references
  storage.evo_cache     = storage.evo_cache or {}     -- last written evolution value
end

local function is_valid(entity)
  return entity and entity.valid and entity.name == ENTITY_NAME
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

local function register_entity(entity)
  if not is_valid(entity) or not entity.unit_number then
    return
  end
  local uid = entity.unit_number
  storage.combinators[uid] = entity

  -- Pre-cache the section so update_combinator avoids repeated API traversal
  local behavior = entity.get_or_create_control_behavior()
  if behavior and behavior.valid then
    behavior.enabled = true
    local section = get_or_create_section(behavior)
    if section and section.valid then
      storage.section_cache[uid] = section
    end
  end
end

local function unregister_entity(entity)
  if not entity or not entity.unit_number then
    return
  end
  local uid                  = entity.unit_number
  storage.combinators[uid]   = nil
  storage.section_cache[uid] = nil
  storage.evo_cache[uid]     = nil
end

local function update_combinator(entity)
  if not is_valid(entity) then
    return false
  end

  local enemy_force = game.forces["enemy"]
  if not enemy_force then
    return true
  end

  local uid = entity.unit_number
  local evolution = enemy_force.get_evolution_factor(entity.surface)
  local scaled_evolution = math.floor(evolution * 100 + 0.5)

  -- Skip write if value hasn't changed (main UPS saving)
  if storage.evo_cache[uid] == scaled_evolution then
    return true
  end

  -- Use cached section; re-acquire if stale
  local section = storage.section_cache[uid]
  if not section or not section.valid then
    local behavior = entity.get_or_create_control_behavior()
    if not behavior or not behavior.valid then
      return true
    end
    behavior.enabled = true
    section = get_or_create_section(behavior)
    if not section or not section.valid then
      return true
    end
    storage.section_cache[uid] = section
  end

  section.filters = {
    {
      value = SIGNAL,
      min = scaled_evolution
    }
  }
  -- Cache written only after confirmed successful write to section.filters
  storage.evo_cache[uid] = scaled_evolution

  return true
end

local function rebuild_registry()
  ensure_globals()
  storage.combinators   = {}
  storage.section_cache = {}
  storage.evo_cache     = {}

  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered({ name = ENTITY_NAME })
    for _, entity in pairs(found) do
      register_entity(entity)
      update_combinator(entity)
    end
  end
end

-- Rescan kept intentionally for Warp Drive Machine compatibility (platform teleportation
-- moves entities across surfaces, bypassing normal build/destroy events).
-- Unlike rebuild_registry, this only adds missing entries and does NOT clear the cache,
-- so already-registered combinators incur zero overhead here.
local function register_missing_entities()
  ensure_globals()

  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered({ name = ENTITY_NAME })
    for _, entity in pairs(found) do
      if entity.unit_number and not storage.combinators[entity.unit_number] then
        -- Only newly discovered entities get registered + updated
        register_entity(entity)
        update_combinator(entity)
      end
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
end)

script.on_configuration_changed(function()
  ensure_globals()
  rebuild_registry()
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

  -- Main update loop: skips write if evolution value unchanged (evo_cache)
  for unit_number, entity in pairs(storage.combinators) do
    if not update_combinator(entity) then
      storage.combinators[unit_number]   = nil
      storage.section_cache[unit_number] = nil
      storage.evo_cache[unit_number]     = nil
    end
  end

  -- Rescan: only registers combinators missing from the registry (e.g. after Warp Drive teleport)
  -- No double-update: register_missing_entities skips already-known entities
  if game.tick % REGISTRY_RESCAN_INTERVAL == 0 then
    register_missing_entities()
  end
end)
