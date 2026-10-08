# 009: Brief E: Mystery ticket
<!-- rbxmap:meta {"hashes":{"src/shared/Types.luau":"4188fe2e3e6694c4","src/shared/Logic/TicketModel.luau":"7a8a9099d422802a","src/server/Services/RunDirector.luau":"dfe86cc987b3bd20","src/server/Services/RouteService.luau":"5f6ce4b76c8efe57","src/server/Services/DevService.luau":"610067ebfb2b2f27","src/server/Builders/TrainInterior.luau":"196fc138b3c6771f","src/client/UI/Ticket.luau":"de3a8041c2a068dd","src/client/UI/RouteVote.luau":"15e08f749915d84f","src/client/UI/RouteBoard.luau":"94b6a7b534edc189","src/client/Controllers/UIController.luau":"18a2bdd52b53985b","src/client/UI/Hud.luau":"d64787d838c8a6b4","src/client/UI/ChalkSlate.luau":"80fdfcceae0c1350","src/shared/Config/Difficulty.luau":"7ab19e47a1437ada"}} -->

Status: done

## Goal
Some junctions offer a sealed "mystery" line: a real station from the normal generator whose name, type,
danger and loot bonus stay server-only until arrival. Distance and coal are visible. Frequency from a config
table with a flag: never at the first junction, never two in a row, ~25% otherwise, pity after 5 junctions
without one, rolled on the run seed. Reveal at Arrival with an unseal animation. Mystery Ticket variant
(smudged, "????", flickering neutral lantern), three-ticket reflow on screen and on the route board, and a
Dev `mystery` command. Full brief: user's "BRIEF E" (2026-10-08). Depends on 005 (B), 007 (C).

## Files to edit
- `src/shared/Config/Mystery.luau` (new: flag, chance, pity, rewards)
- `src/shared/Logic/Mystery.luau` (new: offer rule, redaction, hidden pick)
- `src/shared/Types.luau` (RouteOption.mystery, Destination)
- `src/shared/Logic/TicketModel.luau` (mystery view)
- `src/server/Services/RunDirector.luau` (mystery at Junction, hidden choice at Cruise, reveal at Arrival)
- `src/server/Services/RouteService.luau` (server-only hidden options)
- `src/server/Services/DevService.luau` (`mystery` command)
- `src/server/Builders/TrainInterior.luau` (three-way slots and a middle lantern on the board)
- `src/client/UI/Ticket.luau` (mystery variant)
- `src/client/UI/RouteVote.luau` (no dossier for a mystery)
- `src/client/UI/RouteBoard.luau` (three-way slots, neutral flicker)
- `src/client/UI/Unseal.luau` (new: the reveal), `src/client/Controllers/UIController.luau` (mount it)
- `src/client/UI/Hud.luau`, `src/client/UI/ChalkSlate.luau` (sealed destination text)
- `tests/Mystery.spec.luau` (new), `tests/Run.spec.luau`, `tests/TicketModel.spec.luau`
- `tasks/009-brief-e-mystery-ticket.md`, `HANDOFF.md`

## Files NOT to touch
- `src/shared/Config/Difficulty.luau`, DifficultyModel (the danger bias stays outside the Difficulty system)

## Acceptance checks
- [x] `lune run check` passes
- [x] Studio: `start_stop_play`, `get_console_output` (no errors), `screen_capture` of a mystery ballot and the reveal

## Builder notes
- 2026-10-08: Built as listed. Vote/tieNote already N-option (no fix). lune run check passes (182 tests, audit clean). Studio Play via Dev skip/mystery: 3rd ticket sealed on screen and on the board WideSlots; Patch stream showed only the redacted option and sealed destination before Arrival; reveal named Whistle-Stop Halt with lootMul x1.3; Unseal card shown (wipe end state not captured). Console clean. Studio steps: Play, READY, Dev skip to a Junction, Dev `mystery`, vote the ???? ticket, skip twice to Arrival and watch the top of the screen.
