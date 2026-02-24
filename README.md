# Simple Evolution Combinator

A Factorio 2.0 mod that adds a dedicated combinator which outputs the current enemy evolution factor for the surface it is placed on.

## What This Mod Does

- Adds a new entity: `evolution-constant-combinator` (based on `constant-combinator`).
- Adds a virtual signal: `signal-evolution-factor`.
- Outputs `round(evolution * 100)`:
  - `0` = 0%
  - `100` = 100%
- Updates automatically during gameplay.
- The combinator GUI is force-closed (it acts as a read-only signal source).

## Recipe and Unlock

- Recipe: `1x constant-combinator -> 1x evolution-constant-combinator`.
- The recipe is unlocked via `circuit-network` technology (if present in `data.raw`).

## Compatibility

- Factorio: `2.0`
- Dependency: `base`

## Project Structure

```text
simple-evolution-combinator/
  control.lua
  data.lua
  info.json
  changelog.txt
  graphics/
    entity/evolution-constant-combinator/evolution-constant-combinator.png
    icons/evolution-constant-combinator.png
    icons/signal/signal-evolution-factor.png
  locale/
    en/simple-evolution-combinator.cfg
    ru/simple-evolution-combinator.cfg
```

## License

See `LICENSE`.
