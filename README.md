# Spinoff AI Portfolio Sample
Made as a small ARCSoft AI portfolio sample, and also as documentation for myself when I come back to this system.

This is not the full Spinoff project. It is just a small slice of the AI framework showing how I structure enemy data, AI types, state logic, and movement decisions.

## Folder Structure

- `Core/` — server-side modules. This is where most of the AI framework lives.
- `AIData/` — data for each AI, such as health, damage, attack range, shoot range, sounds, animations, and behaviour values.
- `Types/` — reusable AI behaviour types like `Melee`, `Gun`, and `Universal`.
- `Server/` — an example server use case.

## AI Types

`Melee` is for close-range enemies.  
`Gun` is for ranged enemies with shooting and reload behaviour.  
`Universal` is the experimental one.

Universal was meant to let me create more unique enemies by reusing behaviour from other types. For example, an AI could use both gun logic and melee logic instead of me rewriting everything from scratch. Or they can just be a boss

The idea works, but it also exposed some issues. Some actions are too connected right now. For example, if gun logic runs a function from within the AITypeHandler :Cancel() which changes the token and at the wrong time, it can interrupt an active melee swing. That is one of the main things I would clean up later

## Core Files

- `Config.luau` — pathfinding settings and fallback defaults.
- `Navigation.luau` — movement and line-of-sight decision logic. The main function splits movement into `direct`, `below`, or `pathfinding`.
- `AIUnit.luau` — initializes the AI model, loads its data, connects callbacks, registers it, and starts the handler.
- `AITypeHandler.luau` — connects the AIData, selected Type, FSM logic, animations, combat helpers, movement callbacks, stun checks, and death handling.

## Notes

Created on 3/26/2026

This is a working prototype, not a perfect final framework.

The main thing I like about it is that creating new AIs is mostly data-driven. I can make melee, gun, or more complex enemies without rewriting the entire AI system each time.

The main thing I dislike is that `AITypeHandler` does too much. It works, but it became the connector for too many systems at once. If I continue this version, that is the first file I would refactor or rewrite.

I am sending this as an early sample before exams; I'm available just less, after the exams I would like to send a stronger portfolio
