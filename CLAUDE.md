# FPS 2D — Agent Context

## Project Overview
A Doom-style 2.5D FPS game built in **Godot 4** with a **Sin City aesthetic** (B&W with red blood accents).
The player moves in 3D space but all characters/enemies are rendered as 2D billboard sprites (Sprite3D).
Target platform: Web (Compatibility renderer).

## Rendering
- **Renderer: Compatibility** (required for web export)
- `shader_type spatial` with `render_mode unshaded` on all enemy/character Sprite3Ds
- Hit flash shader: `scenes/enemies/hit_flash.gdshader` (spatial, not canvas_item)
- Speedlines: `scenes/player/speedlines.gdshader` (canvas_item on a CanvasLayer ColorRect)
- Toon world shader: `scenes/shaders/toon_world.gdshader` — apply to MeshInstance3D geometry (walls, floors, doors); uses `light()` with stepped cel-shading bands (`cuts`, `wrap`, `steepness`, `shadow_lift`) + rim darkening; B&W output via `ALBEDO = vec3(1.0)` + quantized diffuse bands; replaces the old `noir_world.gdshader` screentone which swam in screen-space
- Noir sprite shader: `scenes/shaders/noir_sprite.gdshader` — drop-in replacement for `hit_flash.gdshader` on enemy/pickup Sprite3D; same `active`/`flash_color` uniforms so `enemy_base.gd` needs no changes; desaturates sprite to B&W, preserves red channel for blood details
- All Sprite3D materials need `resource_local_to_scene = true` for per-instance shader params
- Level needs explicit `WorldEnvironment` + `DirectionalLight3D` — Compatibility has no free ambient light

## Architecture

### Autoloads (project.godot)
- `GameManager` — `scenes/general/game_manager.tscn` — kill count, impact pause, player ref
- `SoundManager` — `scenes/general/sound_manager.tscn` — all audio, fire-and-forget SFX pattern
- `Log` — logger addon singleton

### Key Scenes
| Scene | Path |
|---|---|
| Player | `scenes/player/player.tscn` |
| HUD | inside player.tscn — `Hud` CanvasLayer with `process_mode = ALWAYS` |
| Melee Enemy | `scenes/enemies/melee/enemy_melee.tscn` |
| Shooter Enemy | `scenes/enemies/shooter/enemy_shooter.tscn` |
| Bullet | `scenes/enemies/shooter/projectile/bullet.tscn` |
| Weapon (hitscan) | `scenes/weapons/weapon.tscn` / `HitScanWeapon.gd` |
| Pickup | `scenes/pickups/pickup.gd` |
| Health node | `scenes/general/health.tscn` — emits `died` / `damaged` signals |
| Hurtbox | `scenes/general/hurtbox.gd` — Area3D, handles damage + `delete_after` / `repeat_cooldown` |
| BloodDecals | `scenes/blood_decal/blood_decal_manager.tscn` — extends DecalInstanceCompatibility, sphere-cast blood spray |
| BulletDecals | `scenes/weapons/bullet_decal_manager.tscn` — extends DecalInstanceCompatibility, bullet holes |

### Enemy System
- `enemy_base.gd` (`BaseEnemy`) — shared base: movement, hit-stun, hit-flash, die, take_damage
- `enemy_melee.gd` (`MeleeEnemy`) — sets `movement_type = MovementType.FLANK`, calls `super._ready()`
- `enemy_shooter.gd` (`EnemyShooter`) — sets `movement_type = MovementType.STRAFE`, fires bullets
- Movement types: `STATIONARY`, `DIRECT`, `FLANK`, `STRAFE`
- All enemies must be in the `"enemies"` group for `GameManager.register_player()` to reach them

### Damage / Hurtbox Architecture
- **`hurtbox.gd` owns damage** — calls `body.take_damage(damage)` on `body_entered`
- `delete_after = false` + `repeat_cooldown = 0.5` → melee/contact damage
- `delete_after = false` + `repeat_cooldown = 0.0` → bullet hurtbox (bullet.gd self-destructs instead)
- `bullet.gd` connects `body_entered` only for FX + `queue_free()` — no `take_damage` call
- Bullet hurtbox uses `set_deferred("monitoring", false)` then `set_deferred("monitoring", true)` on spawn to avoid spawn-overlap false positives
- On `die()`, enemy's Hurtbox monitoring is disabled via `hurtbox.set_deferred("monitoring", false)`

### Decal System (DecalInstanceCompatibility plugin)
- `BloodDecals` and `BulletDecals` extend `DecalInstanceCompatibility` directly
- Uses MultiMesh for efficient rendering — 4-5 draw calls total vs 50+ with old system
- `BloodDecals` has 4 random textures, 100 instances = 100 blood decals in 4 draw calls
- `BulletDecals` has 100 bullet holes in 1 draw call
- Ring buffer pattern — automatically cycles through instances when pool fills
- Built-in fade-out via `fade_out_instance()` with custom_data alpha tweening
- Classes handle raycasting, positioning, rotation, and lifecycle scheduling
- Blood spray uses sphere-casting pattern — casts rays in multiple random directions biased toward attacker
- Decals naturally conform to any surface (floors, walls, corners) via normal-based orientation
- Random scale (0.7–1.2) normally, 2x on death; 5 rays on damage, 12 rays on death
- Random texture selection from `BLOOD_TEXTURES` array on each blood decal spawn

### HUD / Player
- Gun is a `Sprite2D` (`GunSprite`) in a `Control` node inside `Hud` CanvasLayer
- Weapon bob/sway driven in `hud.gd._update_weapon_bob_sway()` by translating `gun_sprite.position`
- Screen shake in `player.gd` — offsets `camera.position` from `_camera_base_pos`
- Speed lines driven by `player.velocity.length()` via `remap()` + `lerpf()` in `hud.gd`
- Pause: `get_tree().paused` toggled in `hud.gd`; HUD CanvasLayer has `process_mode = ALWAYS`

### Audio (SoundManager)
- Fire-and-forget: `AudioStreamPlayer` created, played, then `finished.connect(queue_free)`
- `play_enemy_death()` picks randomly from two death sounds
- All SFX constants are preloaded in `sound_manager.gd`

### Impact Pause
- Every 5th kill: `Engine.time_scale = 0.0` for 0.02s
- Uses `create_timer(duration, true, false, true)` — `ignore_time_scale = true` so timer runs in real time

## Common Gotchas
- **Sprite3D needs `shader_type spatial`** — canvas_item shaders don't work on 3D nodes
- **`resource_local_to_scene = true`** on ShaderMaterials — required for per-instance shader params
- **Export vars serialised as `null` in .tscn** — can happen when script changes after scene was created; remove the `= null` lines from the .tscn
- **Double `body_entered` connections** — if a hurtbox script and a parent script both connect the same signal, both fire; architecture fix: only one script owns the response
- **`await` in freeable nodes** — use `set_deferred` instead of `await get_tree().physics_frame` to avoid freed-lambda errors
- **Lambda captures in tween callbacks** — lambdas in `fade_out_instance()` capture decal refs; DecalInstanceCompatibility guards with validity checks internally
- **Compatibility mode** — no free ambient light; Level01.tscn needs `WorldEnvironment` + `DirectionalLight3D`

## Logging
Uses the `Log` addon (autoloaded as `Log`):
- `Log.info(msg, {dict})` — game state changes (kills, game start/over, pickups, enemy deaths)
- `Log.dbg(msg, {dict})` — frequent events (damage, shots fired, hurtbox hits)
- Raise `Log.current_log_level = Log.LogLevel.INFO` to silence debug spam in production
