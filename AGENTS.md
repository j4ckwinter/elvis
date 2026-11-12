# Working on Elvis

Elvis is a macOS desktop pet that reacts to Claude Code. The [README](README.md) describes his behaviour, how to run him, and his known limits. Read it before changing anything he does.

## Build and check

Run commands from the repository root.

```sh
make            # release build, copied to plugin/bin/elvis
make test       # the whole suite
make sheets     # every pose as PNGs in sheets/
make fingerprint  # a hash of every pose, a scripted run and its pixels, for refactors
```

Use `make test`, not `swift test`. With Command Line Tools only, the Swift Testing macros need the plugin path the Makefile supplies.

For a change to how he looks, run `make sheets` and look at the images. A passing test suite does not show that a drawing looks right.

For a change to how he behaves on screen, film a separate instance and read the contact sheets it writes:

```sh
ELVIS_HOME="$(mktemp -d)" ELVIS_FILM=<directory> .build/release/elvis run
```

`ELVIS_HOME` gives that instance its own socket, lock, and `state.json`, so it leaves Jack's running Elvis and his saved state alone. Send it events with the same `ELVIS_HOME` set. Keep the path short: a Unix socket path is limited to about 100 characters.

Set `ELVIS_HEADLESS` as well to run the socket, brain, and timer with no window and no menu-bar item, which is how the app tests start him without a second dog on screen.

## Where things live

Each decision has one owner. Put new code with the owner of the decision it makes.

| Decision | Owner |
| --- | --- |
| What a Claude Code hook payload means | `ClaudeHooks.swift` |
| Whether a command was a test run, and how it went | `TestRuns.swift` |
| What Claude Code's sessions are doing | `Sessions.swift` |
| How Elvis reacts to an event, and the order he does things in | `Brain.swift` |
| What he does when left to himself | `Brain+Habits.swift` |
| The pose for an action at a moment | `Choreography.swift`, one `Choreography+<Family>.swift` per family of poses, `Gaits.swift` |
| Blending between actions, ear physics, blinking | `Stage.swift` |
| What each action scatters | `Stage+Particles.swift` |
| Drawing Elvis | `Dog.swift`, `Dog+Head.swift` |
| Drawing everything else | `Painter.swift` and its `Painter+<Part>.swift` files |
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

## Keep each file to one responsibility

- A file holds one responsibility, and its name says which. When a file gains a second reason to change, split it before adding more to it.
- Treat about 300 lines as a prompt to look, not a limit. A long file that does one thing can stay. A short file that does three cannot.
- Split along the owners table. Put a separable role of a type in an extension file named `Type+Role.swift`, and a new type in a file of its own name.
- Widen `private` only for the members the new file needs. If a split would expose most of a type's state, the pieces are not separate, so leave them together.
- Keep every `switch` over `Action` exhaustive, with no `default`, so the compiler points at each place a new action needs handling.
- A split is a `refactor` commit of its own with no behaviour change. Prove it: the tests pass unedited, and `make fingerprint` prints the same line before and after. The fingerprint hashes every pose, a long scripted run, and the pixels it paints, and takes about a minute.

## Leave comments out

Write code that needs no comments. Expect a handful in the whole repository, not a handful per file.

- When something needs explaining, change the code until it does not: name the condition, extract and name the function, or choose a type that cannot hold the confusing state.
- Conventions that many files share belong in the section below, not in comments beside each use.
- A comment may stay only when it stops a reader from making a plausible wrong fix, and nothing in the code can carry the reason. The two in the repository today are of this kind: the hook must stay silent, and a press is checked again because the window starts catching clicks a tick late.
- That rules out doc comments (`///`) that describe a type, function, parameter, or field, as well as narration, section banners, commented-out code, and TODO notes.
- Do not add comments to tests. The test name states the behaviour.

## Conventions the code relies on

These were once comments. Keep them true, and change them here when the code changes.

- Geometry is in dog units, with the ground at y = 0, x growing to the right, and angles in radians. `Painter.draw` expects the context's origin at the yard's bottom-left corner with y pointing up.
- Poses are authored facing right. `World.facing` is +1 for right and -1 for left. `Frame.facing` is the signed horizontal scale actually drawn, which passes through zero while he turns round.
- `Pose.paws` are ordered front near, front far, rear near, rear far. `rearBend` is -1 with the hock bent back (standing) and +1 with the knee folded forward (sitting or lying). `front` above 0.5 draws the head facing the viewer. Positive `pitch` lifts the nose of the profile head; `tilt` rolls the front-facing head. `tail` is the angle above straight-back, including any wag. `turn` is a horizontal scale, swept through zero to turn on the spot.
- `Frame.ears` are angles from straight down in the dog's own frame. A profile head uses the first.
- `World.glum` is 1 straight after a test failure and fades to 0.
- Everything `Painter.draw` paints must lie inside `Painter.bounds(of:)`, because the app repaints only that patch. A test enforces it.
- Limbs and discs are drawn as stroked lines and ellipses, not as outlined paths. Outlining them roughly tripled the app's CPU use.
- `Brain.actionSerial` changes each time an action starts, including a repeat of the same action.
- In `WorkEvent`, an empty `session` means the event belongs to no Claude Code session, `subject` is an opaque fingerprint that pairs a permission request with its tool call, and `agent` is set only for events from inside a subagent.
- Hook payload field names follow https://code.claude.com/docs/en/hooks.md as read on 2026-11-12. Hooks are asynchronous, so an event can arrive after its session has ended; `Sessions` ignores those.
- `Brain.Tuning.staleAfter` is longer than any single tool call may run, so that much silence means the session has gone. `siblingWindow` covers tool calls that start alongside a permission request and are not an answer to it.
- `Keepsakes.spot` is in screen points. Nil means his corner.

## Keep the hook harmless

The hook runs inside the user's Claude Code session on every event. It must print nothing and exit 0 whatever happens. It returns in milliseconds, except on a session start that has to launch the app, where it waits up to two seconds for the app to listen. Only the fields of `WorkEvent` may cross the socket. A prompt, command, path, or tool output must never leave the hook process.

The hook path is `ClaudeHooks.swift`, `WorkEvent.swift`, `EventSocket.swift`, the `hook` case in `Sources/elvis/main.swift`, and `plugin/hooks/hooks.json`. A change to the two ElvisKit files needs a test. After any change to the path, confirm the built hook is still silent without touching the running app:

```sh
ELVIS_HOME="$(mktemp -d)" ELVIS_AUTOSTART=0 plugin/bin/elvis hook < payload.json; echo "exit $?"
```

Expect no output before `exit 0`, for a valid payload and for garbage. `Tests/ElvisAppTests` makes the same check on the debug build in every `make test`; the command above checks the release binary the plugin runs.

## Test what he does

- Add or update a test with every behaviour change. Name it for the behaviour: `waitsAtTheDoorUntilAnswered`.
- Test `ElvisKit` in `Tests/ElvisKitTests`. Test the command line, the hook, the socket, and starting and quitting the app in `Tests/ElvisAppTests`, which runs the built binary through `IsolatedElvis`: a temporary `ELVIS_HOME`, `ELVIS_HEADLESS` set, and `ELVIS_AUTOSTART=0` unless the test is about waking him. Never run the binary from a test any other way.
- When a new test passes first time, break the code briefly to confirm the test can fail.
- When he gets a result wrong, be quiet rather than guess. A missed celebration costs nothing; a wag for failing tests costs trust.
- Never weaken an assertion or skip a test to get a pass.

## Commit as you go

Commit each time a unit of work is complete and `make test` passes. Do not wait until the end of a session, and do not commit work that fails its tests.

- One logical change per commit. Keep a refactor separate from the behaviour change it enables, and a fix separate from an unrelated feature.
- Commit before starting the next unit, and before a risky restructuring, so each step can be reviewed or reverted alone.
- Use Conventional Commits: `type(scope): summary`, with the scope optional. Types in use are `feat`, `fix`, `refactor`, `test`, `docs`, `perf`, and `chore`. Write the summary in the imperative, under 72 characters, and say in the body why the change was needed when the summary does not.
- Do not add `Co-Authored-By` trailers or any other line crediting an AI tool, in commit messages or pull request descriptions. Commits carry Jack's authorship only.
- Stage files by name after reading `git status`. Build output, `sheets/`, and `plugin/bin/` stay out of the repository.
- Do not amend or rebase commits that have been pushed.

Commit on the branch that is checked out. Do not create or switch branches unless asked.

Committing is expected. Anything that reaches beyond this working tree needs Jack's request: pushing, opening a pull request, tagging a release, `make install`, installing the plugin into anyone's settings, and starting or quitting his running Elvis.
