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

Blood and bullet decals use `DecalInstanceCompatibility` MultiMesh managers. Efficient rendering with automatic fade-out. Blood intensity scales with damage taken.

### Sin City Style

High-contrast Black & White palette. Bright Red only for blood, hit flashes, and critical UI.

### Comic Book Shaders

Toon-shading or halftoning for a hand-drawn feel.

### Diegetic UI

High-contrast ammo/health counters positioned in-world or on the weapon model.

### Muzzle Flash

Billboard sprite flash at gun barrel on fire. Single bright-white frame.


## Dungeon integration plan

1. Room Scene Architecture (The "Prefab" Setup)
Each room .tscn must be standardized to ensure the generator doesn't break the logic.

Task: Add a NavigationRegion3D as a child of the Room Root.

Task: Create a NavigationMesh resource for each room.

Task: Bake the NavMesh in the editor. Since rooms are modular, the "floor" is always in the same local position, so the bake remains valid when the room is moved.

Task: Add an Area3D named ActivationArea. Its collision shape should cover the entire room + the doorways.

Detail: Ensure the NavigationRegion3D has its Travel Cost and Layers set correctly so enemies don't try to "walk" into the void between rooms.

2. Enemy "Sleeper" Logic (enemy_base.gd)
Modify the base class so enemies don't drain resources the moment they are instanced.

Task: Add a setup_as_sleeper() function.

Detail: This function should set process_mode = Node.PROCESS_MODE_DISABLED and hide().

Task: In _ready(), call setup_as_sleeper() if a certain flag (e.g., is_procedural) is true.

Detail: This ensures that when the Dungeon Generator instances 50 rooms at once, the CPU usage stays at 0% for AI.

3. Room Controller Script (RoomManager.gd)
Create a script to attach to the root of every room prefab to handle the "Wake/Sleep" cycle.

Task: Connect the body_entered and body_exited signals of the ActivationArea.

Task: On body_entered:

Loop through children in the "Enemies" group.

Set process_mode = Node.PROCESS_MODE_INHERIT.

Call show() (Optional, but saves draw calls on Web).

Task: On body_exited:

Set process_mode = Node.PROCESS_MODE_DISABLED.

Call hide().

4. Navigation Map Synchronization
This is the "magic" step to ensure the NavMesh moves with the room.

Task: Ensure the Dungeon Generator sets the room's global_position before adding it to the SceneTree (or immediately after).

Detail: In Godot 4, NavigationRegion3D automatically registers its global transform with the NavigationServer3D upon entering the tree.

Warning: If you move a room after it has been spawned, you may need to call NavigationServer3D.region_set_transform() or simply toggle the enabled property of the NavigationRegion3D to force a sync.

5. Dungeon Generator Integration
Task: Update the generator script to call a "Finalize" function on each room after placement.

Detail: The generator should ensure all Area3D collision layers are set so they only detect the Player (Layer 1 or 2), not other enemies or projectiles.


## Inspos

- Sincity comicbooks
- MadWorld (Wii)
- Fallen aces (https://www.youtube.com/watch?v=eW80gudQ5lw)
- Forgive me father 2 (https://www.youtube.com/watch?v=5H1PQT2XSwM)
- https://www.youtube.com/watch?v=Y7mVylU9ULo
