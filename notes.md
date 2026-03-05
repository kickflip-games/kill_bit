# Game Dev TODO

---

## Phase 1 — Core Combat Feel

### Hit-Stun Mechanics

Enemies physically stop moving (speed = 0) for ~0.2s when hit to reward the player.

### Screen Shake

Implement varied intensities for firing weapons vs. taking damage.

### Impact Pause

Briefly freeze the game world (Time Scale = 0) for ~0.02s on a critical kill for "crunchy" feedback.

### Hit-Stun Visuals

Sprite "whitens" (via modulate or shader) for 0.05s upon taking damage.

### Audio Feedback

Distinct, punchy SFX for: gun shot, bullet impact (flesh vs. wall), enemy death. Audio is as important as visuals for making hits feel real.

---

## Phase 2 — Enemy AI

### Zombie (Melee) AI

**The Flank:** Targets a random offset around the player to prevent enemies from clumping into a single line.

**The Lunge:** Sudden speed burst when the enemy is within 3 meters to catch the player off-guard.

### Shooter AI

**Strafe & Shoot:** Moves laterally while firing to remain a harder target for the player to hit.

**Predictive Aim:** Fires at the player's projected path based on current velocity, rather than their current position.

### Enemy Spawning

Spawn manager with wave-based or proximity-triggered spawning. Enemies should feel like they're coming from somewhere, not just appearing.

---

## Phase 3 — Movement & Player Polish

### Weapon Sway & Bob

Gun moves in a figure-eight pattern while walking and leans into turns (Sway) to feel attached to the player's movement.

### Dynamic FOV

Slightly increase Field of View when at maximum move speed to heighten the sensation of velocity.

### Speed Lines

GPU Particles (long thin white lines) on Camera3D that trigger at high velocity.

### Footstep Audio

Sound cues tied to player movement speed and surface type. Sells physicality of movement.

---

## Phase 4 — World & Content

### Pickups

Area3D items (Ammo/Health) featuring spinning billboard sprites.

### Verticality

Utilize the 2.5D engine to allow for stairs, platforms, and varying floor heights.

### Procedural Generation

Integrate the SimpleDungeons plugin for randomized, endless dungeon layouts.

### Doors & Chokepoints

Simple openable doors to create tension and break up sightlines. Even basic sliding doors add a lot to level feel.

---

## Phase 5 — Aesthetics & Visuals

### Sin City Style

High-contrast Black & White palette. Use Bright Red only for blood, hit flashes, and critical UI elements.

### Comic Book Shaders

Look into toon-shading or halftoning to give the 3D environment a hand-drawn feel.

### Diegetic UI

High-contrast ammo/health counters (White text on Black) positioned in the world or attached to the weapon model.

### Blood Decals

Persistent red splat decals on walls/floors where enemies are killed. Reinforces the Sin City palette and gives combat history to spaces.

### Muzzle Flash

Billboard sprite flash at gun barrel on fire. Should be a single bright-white frame — fast and stark.
