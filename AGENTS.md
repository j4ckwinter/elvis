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

For a change to how he looks, run `make sheets` and look at the images. A passing test suite does not show that a drawing looks right.

For a change to how he behaves on screen, film a separate instance and read the contact sheets it writes:

```sh
ELVIS_HOME="$(mktemp -d)" ELVIS_FILM=<directory> .build/release/elvis run
```

`ELVIS_HOME` gives that instance its own socket, lock, and `state.json`, so it leaves Jack's running Elvis and his saved state alone. Send it events with the same `ELVIS_HOME` set. Keep the path short: a Unix socket path is limited to about 100 characters.

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
| Where the yard window may rest on a screen | `Placement.swift` |
| Windows, the menu, sound, the socket, the command line | `Sources/elvis` |

`ElvisKit` stays free of AppKit, clocks, and unseeded randomness, so that any behaviour can be reproduced in a test from a seed and a list of events. Time reaches `Brain` only through `tick`.

## Write clean code

- Name things for what they mean to Elvis or to the caller: `finish(after:)`, not `handleStopEvent2`. Rename before reaching for a comment.
- Keep functions short enough to read in one pass, and give each one job. Split a function when its name needs "and".
- Make the simplest change that meets the outcome. Add an abstraction only when it removes real duplication or protects an invariant that exists today.
- Keep state narrowly owned. Prefer values and pure functions; pass in what a function needs rather than reaching for it.
- Put a number that tunes behaviour in `Brain.Tuning` or beside the pose it shapes, with a name. Do not scatter the same threshold across files.
- Delete code that nothing calls. Do not leave commented-out code, debug switches, or options added for a future that has not arrived.
- Handle failure where it can be handled. Do not swallow an error that the user would need to know about.

## Leave comments out

Write code that needs no comments. A comment is the exception, and it has to earn its place.

- Before writing one, try a clearer name, a smaller function, or a type that makes the point. Write the comment only when all of those fail.
- A comment may stay when it records something the code cannot express and a reader would get wrong without it: the unit or sign convention of a number, a constraint imposed by Claude Code, macOS, or a file format, or the reason for a choice that looks like a mistake.
- Do not describe what the code does, restate a name, label sections, narrate the steps of a test, or record history. No `// MARK:` banners, no commented-out code, and no TODO notes.
- Doc comments (`///`) follow the same rule. A type or function whose name says what it is needs none.
- When a change makes a comment untrue, fix or delete the comment in the same commit.
- Remove an unnecessary comment when you are already changing the code it sits on. Do not sweep other files for comments unless Jack asks for a cleanup.

## Keep the hook harmless

The hook runs inside the user's Claude Code session on every event. It must print nothing and exit 0 whatever happens. It returns in milliseconds, except on a session start that has to launch the app, where it waits up to two seconds for the app to listen. Only the fields of `WorkEvent` may cross the socket. A prompt, command, path, or tool output must never leave the hook process.

The hook path is `ClaudeHooks.swift`, `WorkEvent.swift`, `EventSocket.swift`, the `hook` case in `Sources/elvis/main.swift`, and `plugin/hooks/hooks.json`. A change to the two ElvisKit files needs a test. After any change to the path, confirm the built hook is still silent without touching the running app:

```sh
ELVIS_HOME="$(mktemp -d)" ELVIS_AUTOSTART=0 plugin/bin/elvis hook < payload.json; echo "exit $?"
```

Expect no output before `exit 0`, for a valid payload and for garbage.

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

Commit on the branch that is checked out. Do not create or switch branches unless asked.

Committing is expected. Anything that reaches beyond this working tree needs Jack's request: pushing, opening a pull request, tagging a release, `make install`, installing the plugin into anyone's settings, and starting or quitting his running Elvis.
