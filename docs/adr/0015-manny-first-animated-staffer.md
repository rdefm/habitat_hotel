# One real animated Staffer (Manny), everyone else a placeholder

The prototype and the current `ui/lobby_view.gd` both render every actor as an abstract colored shape. We now have real sprite-sheet art (walk/idle/sweep) for one character only, so Staffer `marlon` is renamed `manny` and gets real animation — playing whichever animation matches his *current task* (sweeping while cleaning, walking between Stations) regardless of which Station he's assigned to. This confirms ADR-0005's any-Staffer-any-Station model extends to presentation, not just mechanics: Manny sweeps when doing Housekeeping work even though sweeping isn't his home Skill.

Every other Staffer and every Guest stays a plain moving rectangle until their own art arrives — this is a deliberate, incremental scoping choice, not a placeholder for its own sake. The animation system must be built so a new sprite set drops in per Staffer/task without redesigning the system itself; that constraint is intentional up front, not deferred.

Status: accepted.
