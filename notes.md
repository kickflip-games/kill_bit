# Game Dev TODO

---

## Phase 1 — Core Combat Feel

### ✅ Hit-Stun Mechanics

Enemies stop moving (speed = 0) for 0.2s on hit. `is_stunned` flag blocks movement in both MeleeEnemy and EnemyShooter. Duration exported per-enemy.

### ✅ Screen Shake

Fire shake (0.018) and damage shake (0.05) via `_shake_camera()` in player. Decays with `lerpf`, stacks via `maxf` so damage hits don't get wiped by rapid fire.

### ✅ Impact Pause

Every 5th kill freezes `Engine.time_scale = 0` for 0.02s via a real-time timer (`ignore_time_scale = true`) in `GameManager`. Trivial to swap "every 5th kill" for "critical kill" later.

### ✅ Hit-Stun Visuals

Spatial shader (`hit_flash.gdshader`) on enemy `Sprite3D` fades active 1→0 over 0.15s via Tween with EASE_OUT. `resource_local_to_scene = true` ensures per-enemy flash.

### ✅ Audio Feedback

Full SFX pass via `SoundManager` autoload. Covered: player shoot, bullet hits environment, player hit enemy, enemy takes damage, enemy death (randomised between 2), enemy shoots, player takes damage, player death, pickup, pause/unpause, win. Background music loops from game load.

### ✅ Pause Screen

ESC toggles pause via HUD (process_mode = ALWAYS). `get_tree().paused = true` freezes all game nodes. Resume button + ESC to unpause. Auto-unpauses on death.

---

## Phase 2 — Enemy AI

### ✅ Basic Melee & Shooter AI

Melee enemies navigate to player via NavigationAgent3D. Shooter strafes toward player and fires projectiles at fire_rate. Both respect `is_stunned` and `is_dead`.

### ✅ Zombie (Melee) AI — Polish

**The Flank:** Targets a random offset around the player and updates every 1 second to prevent clumping. Exported as `flank_radius` and `flank_update_interval`.

**The Lunge:** Sudden speed burst (1.8x) when within 3 meters. `lunge_distance` and `lunge_speed_multiplier` are tunable via exports.

**Enemy Avoidance:** Zombies detect nearby enemies within `avoid_radius` and push away from them to prevent stacking. `avoid_strength` controls how much they weight avoidance vs. flanking.

### ✅ Shooter AI — Polish

**Strafe & Shoot:** Shooters maintain distance while circling the player. `strafe_radius` controls circle size, `strafe_speed` is randomized per enemy (1.5-2.5 rad/s), and direction is randomized (clockwise/counterclockwise).

**Enemy Avoidance:** Shooters use the same avoidance system as melees to prevent clustering.

---

## Phase 3 — Movement & Player Polish

### ✅ Speed Lines

Canvas-item shader overlay (`speedlines.gdshader`) driven by player velocity. Density remapped from 4.2→MAX_SPEED via `hud.gd`. Smooth lerp in/out. Vignette renders on top.

### ✅ Weapon Sway & Bob

Gun moves in a figure-eight pattern while walking and leans into turns. Camera tilts in direction of turns for enhanced speed feeling. Gun sprite rotates with camera tilt to maintain visual cohesion.

### ✅ Dynamic FOV

Slightly increase Field of View at max move speed.

### Footstep Audio

Sound cues tied to player movement speed and surface type.

---

## Phase 4 — World & Content

### ✅ Pickups

Area3D with `@tool` script. Sprite frame set by `PickupType` (HEALTH/AMMO) via spritesheet. Bobbing animation. Calls `player.add_pickup()` on contact. `SoundManager` plays pickup SFX.


### Procedural Generation

Integrate the SimpleDungeons plugin for randomized, endless dungeon layouts.

### Doors & Chokepoints

Simple openable doors to create tension and break up sightlines.

---

## Phase 5 — Aesthetics & Visuals

### ✅ Blood Decals

Pooled blood decals (`BloodDecalPool`) spawn on enemy hit and death. Intensity scales with damage taken.

### Sin City Style

High-contrast Black & White palette. Bright Red only for blood, hit flashes, and critical UI.

### Comic Book Shaders

Toon-shading or halftoning for a hand-drawn feel.

### Diegetic UI

High-contrast ammo/health counters positioned in-world or on the weapon model.

### Muzzle Flash

Billboard sprite flash at gun barrel on fire. Single bright-white frame.
