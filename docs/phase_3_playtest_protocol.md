# Phase 3 Playtest Protocol

Phase 3 is feature-complete in repo. The remaining validation is a five-person observation pass.

## Setup

Do not explain the game before the session.

Opening prompt:

```text
Open Godot, run the game, and do what you want.
```

Stop after the player completes one `Build -> Race -> Analyze -> Rebuild` loop or after 15 minutes, whichever happens first.

## Notes Format

Record observations in three columns:

| Stop point | Wrong action | Spoken question |
| ---------- | ------------ | --------------- |
| Where they hesitate. | What they click or change by mistake. | What they ask out loud while playing. |

## Debrief

Ask only two questions after observation:

1. What was the most confusing thing?
2. Do you want to try again?

The second answer is the main retention signal.

## Batch Order

Run two players first.

Review the notes before inviting the next three players. If both first players hit the same confusion point, fix it once before continuing.

## Watch Item

The starter setup is `v4/na/aluminum`. On Power Ring, this is intentionally short on power. Analysis must teach this after the first race with a block rebuild instruction.

Guardrail:

```powershell
& 'D:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script 'res://tests/phase_3_default_guidance_smoke.gd'
```
