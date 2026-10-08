# 010: Brief F: Run ticket book
<!-- rbxmap:meta {"hashes":{"src/shared/Logic/RunLog.luau":"10b0b93d49dad41c","src/shared/Types.luau":"32cdbe16ce80e2d0","src/server/Services/RunDirector.luau":"89068b7f6904f221","src/server/Services/CrewService.luau":"ae6141bd4cf71ade","src/client/UI/Stamp.luau":"5dc24d9f7999e1b4","src/client/UI/TicketBook.luau":"6c107a5a3a200caa","src/client/UI/RunCard.luau":"90e42efb2a1af00c","src/client/Controllers/UIController.luau":"ea375eea9d8e05de","src/shared/Config/Difficulty.luau":"7ab19e47a1437ada"}} -->

Status: done

## Goal
A run log of every resolved stop (ticket, vote split, unanimous, mystery and reveal, close calls,
outcome) held in StateService at `run.log`, shown in-run as a ticket book (stubs along an inked track,
CLOSE CALL / GAMBLED / UNANIMOUS stamps) and at the end of the run as a one-screen run card (crew
headshots, timeline with a stamp cascade, total km and coal, final stamp). In-session only.
Full brief: user's "BRIEF F" (2026-10-08). Depends on 005 (B); reads 008 (D) and 009 (E).

## Files to edit
- `src/shared/Logic/RunLog.luau` (new: entry building, reveal, resolve, ordering, stamps, totals, final stamp)
- `src/shared/Types.luau` (LogEntry, StopOutcome)
- `src/server/Services/RunDirector.luau` (pending entry at Cruise, reveal at Arrival, append at stop resolution and RunEnd)
- `src/server/Services/CrewService.luau` (ResolveDeparture returns the close-call names)
- `src/client/UI/Stamp.luau` (word stamp)
- `src/client/UI/TicketBook.luau` (new: the in-run book and the shared track)
- `src/client/UI/RunCard.luau` (new: the end-of-run card)
- `src/client/Controllers/UIController.luau` (mount both)
- `tests/RunLog.spec.luau` (new)
- `tasks/010-brief-f-run-ticket-book.md`, `HANDOFF.md`

## Files NOT to touch
- `src/shared/Config/Difficulty.luau`, DataStore code (no persistence)

## Acceptance checks
- [x] On-disk edits only (Rojo sync), never Studio edits
- [x] `lune run check` passes
- [x] Studio: `start_stop_play`, `get_console_output` (no errors), `screen_capture` of the book and the run card

## Builder notes
- 2026-10-08: Built as listed. `lune run check` passes (192 tests, audit clean). Studio Play (Dev skip, tp mid/train): close call at stop 1 stamped CLOSE CALL in the book (B); a voted mystery at stop 2 logged as revealed SIGNAL WORKS with GAMBLED; being left behind ends the run, the run card shows the headshot, stubs cascade, totals and "LOST AT STOP n". Fixed during play: a crew lost at departure logged that stop as Cleared and the stamp said the next stop; the receipt stole gamepad selection; "1 STOPS". Console clean. Victory (TERMINUS) not reached in Studio. Studio steps: Play, READY, Dev skip through a stop, press B; get left behind (tp mid at Last Call, skip) to see the card, press H to hide CLOSE.
