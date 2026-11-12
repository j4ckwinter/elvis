# Working on Elvis

Elvis is a macOS desktop pet that reacts to Claude Code. The [README](README.md) describes his behaviour, how to run him, and his known limits. Read it before changing anything he does.

## Build and check

Run commands from the repository root.

```sh
make            # release build, copied to plugin/bin/elvis
make test       # the whole suite
make sheets     # every pose as PNGs in sheets/
```

Use `make test`, not `swift test`. With Command Line Tools only, the Swift Testing macros need the plugin path the Makefile supplies.

For a change to how he looks, run `make sheets` and look at the images. For a change to how he behaves on screen, run him with `ELVIS_FILM=<directory>` and read the contact sheets it writes. A passing test suite does not show that a drawing looks right.

## Where things live

Each decision has one owner. Put new code with the owner of the decision it makes.

| Decision | Owner |
| --- | --- |
| What a Claude Code hook payload means | `ClaudeHooks.swift` |
| Whether a command was a test run, and how it went | `TestRuns.swift` |
| What Elvis does next | `Brain.swift` |
| The pose for an action at a moment | `Choreography.swift` |
| Blending, ear physics, blinking, particles | `Stage.swift` |
| Drawing | `Painter.swift`, `Dog.swift` |
| Windows, the menu, sound, the socket, the command line | `Sources/elvis` |

`ElvisKit` stays free of AppKit, clocks, and unseeded randomness, so that any behaviour can be reproduced in a test from a seed and a list of events. Time reaches `Brain` only through `tick`.

## Write clean code

- Name things for what they mean to Elvis or to the caller: `finish(after:)`, not `handleStopEvent2`. Rename before reaching for a comment.
- Keep functions short enough to read in one pass, and give each one job. Split a function when its name needs "and".
- Make the simplest change that meets the outcome. Add an abstraction only when it removes real duplication or protects an invariant that exists today.
- Keep state narrowly owned. Prefer values and pure functions; pass in what a function needs rather than reaching for it.
- Put a number that tunes behaviour in `Brain.Tuning` or beside the pose it shapes, with a name. Do not scatter the same threshold across files.
- Delete code that nothing calls. Do not leave commented-out code, debug switches, or options added for a future that has not arrived.
- Comment only what the code cannot say: units and sign conventions, a constraint imposed by Claude Code or macOS, the reason for a surprising choice. No section banners and no narration.
- Handle failure where it can be handled. Do not swallow an error that the user would need to know about.

## Keep the hook harmless

The hook runs inside the user's Claude Code session on every event. It must print nothing, exit 0 whatever happens, and finish in milliseconds. Only the fields of `WorkEvent` may cross the socket. A prompt, command, path, or tool output must never leave the hook process. Any change to `ClaudeHooks.swift`, `WorkEvent.swift`, `EventSocket.swift`, or `plugin/hooks/hooks.json` needs a test for the new behaviour and a check that the hook stays silent.

## Test what he does

- Add or update a test with every behaviour change. Name it for the behaviour: `waitsAtTheDoorUntilAnswered`.
- When a new test passes first time, break the code briefly to confirm the test can fail.
- When he gets a result wrong, be quiet rather than guess. A missed celebration costs nothing; a wag for failing tests costs trust.
- Never weaken an assertion or skip a test to get a pass.

## Commit as you go

Commit each time a unit of work is complete and `make test` passes. Do not wait until the end of a session, and do not commit work that fails its tests.

- One logical change per commit. Keep a refactor separate from the behaviour change it enables, and a fix separate from an unrelated feature.
- Commit before starting the next unit, and before a risky restructuring, so each step can be reviewed or reverted alone.
- Use Conventional Commits: `type(scope): summary`, with the scope optional. Types in use are `feat`, `fix`, `refactor`, `test`, `docs`, `perf`, and `chore`. Write the summary in the imperative, under 72 characters, and say in the body why the change was needed when the summary does not.
- Stage files by name after reading `git status`. Build output, `sheets/`, and `plugin/bin/` stay out of the repository.
- Do not amend or rebase commits that have been pushed.

Committing is expected. Pushing, opening a pull request, tagging a release, and installing the plugin into anyone's settings each need Jack's request.
