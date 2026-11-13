# Working on Elvis

Elvis is a macOS desktop pet that reacts to Claude Code. The [README](README.md) describes his behaviour, how to run him, and his known limits. Read it before changing anything he does.

## Build and check

Run commands from the repository root.

```sh
make            # release build, copied to plugin/bin/elvis
make test       # the whole suite
make restart    # rebuild, then swap the running Elvis for the new build
make install    # rebuild, then link ~/.local/bin/elvis to plugin/bin/elvis
make sheets     # every pose as PNGs in sheets/
make fingerprint  # a hash of every pose, a scripted run and its pixels, for refactors
```

Use `make test`, not `swift test`. With Command Line Tools only, the Swift Testing macros need the plugin path the Makefile supplies.

Jack's installed plugin runs `plugin/bin/elvis` from this checkout, and `make`, `make universal`, `make sheets`, `make install`, and `make restart` all replace that file. Every Claude Code session on this Mac starts using the new hook at once. `make install` links the `elvis` on the `PATH` to the same file instead of copying it, so a bare `elvis restart` cannot start a staler build than the hook runs. While a change to the hook path is half done, build with `swift build -c release` and run `.build/release/elvis` instead.

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
| How a shell command line splits into commands, and whose exit status it reports | `ShellLine.swift` |
| Whether a command was a test run, and how it went | `TestRuns.swift` |
| Whether a command typed in your own shell committed or pushed work | `GitRuns.swift` |
| What each shell must run to report your own commands | `ShellIntegration.swift` |
| What a finished shell command has to tell Elvis | `ShellNews.swift` |
| What Claude Code's sessions are doing | `Sessions.swift` |
| How Elvis reacts to an event, and the order he does things in | `Brain.swift` |
| What he does when left to himself | `Brain+Habits.swift` |
| The pose for an action at a moment | `Choreography.swift`, one `Choreography+<Family>.swift` per family of poses, `Gaits.swift` |
| Blending between actions, ear physics, blinking | `Stage.swift` |
| What each action scatters | `Stage+Particles.swift` |
| Drawing Elvis | `Dog.swift`, `Dog+Head.swift` |
| Drawing everything else | `Painter.swift` and its `Painter+<Part>.swift` files |
| Where the yard window may rest on a screen | `Placement.swift` |
| Whether a press on Elvis is a pat or a pick-up, and where the yard window goes while he is carried | `PickUpGesture.swift` |
| What each of his sounds is | `Voice.swift` |
| Which version this build is, and whether another is older | `Version.swift` |
| Windows, the menu, playing sound, the socket, the command line | `Sources/elvis` |

`ElvisKit` stays free of AppKit, clocks, and unseeded randomness, so that any behaviour can be reproduced in a test from a seed and a list of events. Time reaches `Brain` only through `tick`.

## Standards

Jack's coding standards apply here in full. In short:

- **One owner per decision.** Put new code with the owner in the table above, and state each fact and tuning number once. Numbers that tune behaviour live in `Brain.Tuning` or beside the pose they shape.
- **Clean code.** Name things for what they mean to Elvis or the caller. Keep a function to one job. Make the simplest change that meets the outcome, with no abstraction, option, or switch added for a future that has not arrived. Delete what nothing calls.
- **One responsibility per file.** When a file gains a second reason to change, split it along the owners table, as `Type+Role.swift` or a new type in a file of its own name. About 300 lines is a prompt to look, not a limit. If a split would expose most of a type's private state, the pieces are not separate.
- **Exhaustive matches.** Keep every `switch` over `Action` free of `default`, so the compiler points at each place a new action needs handling.
- **No comments.** Change the code until it needs none. The repository has two, each stopping a plausible wrong fix: the hook must stay silent, and a press is checked again because the window starts catching clicks a tick late. Shared conventions go in the next section, not beside each use.
- **Behaviour tests.** Add or update a test with every behaviour change and name it for the behaviour, such as `waitsAtTheDoorUntilAnswered`. When a new test passes first time, break the code briefly to confirm it can fail. Never weaken an assertion to get a pass.
- **Quiet over wrong.** When Elvis cannot tell how something went, he does nothing. A missed celebration costs nothing; a wag for failing tests costs trust.

A refactor is a commit of its own with no behaviour change. Prove it: the tests pass unedited, and `make fingerprint` prints the same line before and after. It hashes every pose, a long scripted run, and the pixels it paints, and takes about a minute.

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
- In `WorkEvent`, an empty `session` means the event belongs to no Claude Code session, `subject` is an opaque fingerprint that pairs a permission request with its tool call, and `agent` is set only for events from inside a subagent and for a helper going out or coming back.
- Hook payload field names follow https://code.claude.com/docs/en/hooks.md as read on 2026-11-12. Hooks are asynchronous, so an event can arrive after its session has ended; `Sessions` ignores those.
- `SubagentStop` also fires for agents Claude Code runs for itself, with an empty `agent_type`. Only a subagent with a type counts as a helper. A helper can outlive the turn that sent it out, and one that is interrupted may never report back. `Sessions` forgets a helper when it reports back and forgets them all at the next prompt, when Claude Code reports the session idle, when the session ends, or when it has been silent for `staleAfter`. A helper still at work is counted again at its next tool call.
- Claude Code 2.1.322 adds `gitOperation` to a Bash `tool_response`, with a `commit` key, a `push` key, or both, when the command committed or pushed. A push with nothing to send and a dry run carry neither. The hooks reference does not describe the field; it was read from real payloads on 2026-11-12. It is the only thing `ClaudeHooks` takes as proof of a commit or push, because the command text can mention one without doing it. `GitRuns` reads the command only for the shell integration, which has nothing else to go on.
- `Brain.Tuning.staleAfter` is longer than any single tool call may run, so that much silence means the session has gone. `siblingWindow` covers tool calls that start alongside a permission request and are not an answer to it.
- zsh hands `preexec` the line that was typed. Bash does not, so the bash integration takes the line from `history 1` inside a `DEBUG` trap and keeps it only when the history entry is new and starts with the same word as `BASH_COMMAND`, or is unchanged and equals `BASH_COMMAND`. That second case is a repeat that `HISTCONTROL` did not record again. `Tests/ElvisAppTests/ShellIntegrationTests.swift` types into the real `/bin/zsh` and `/bin/bash`.
- `Keepsakes.spot` is in screen points. Nil means his corner.
- The running Elvis writes his version into `elvis.lock` when he claims it. An Elvis built before `Version.swift` existed leaves the file empty, which counts as older than any release.
- A session-start hook swaps the running Elvis for its own build only when his recorded version is older than the hook's. An equal or newer one stays, so two installs of different versions cannot keep replacing each other. Builds of the same version are never swapped; `make restart` does that. `ELVIS_AUTOSTART=0` turns the swap off along with the wake.

## Keep the hook harmless

The hook runs inside the user's Claude Code session on every event. It must print nothing and exit 0 whatever happens. It returns in milliseconds, except on a session start that has to launch the app or swap an older Elvis for its own build. Launching waits up to two seconds for the app to listen. A swap also waits up to two seconds for the old one to quit, and stays inside the five-second timeout in `plugin/hooks/hooks.json`. Only the fields of `WorkEvent` may cross the socket. A prompt, command, path, or tool output must never leave the hook process.

The hook path is `ClaudeHooks.swift`, `WorkEvent.swift`, `EventSocket.swift`, the `hook` case in `Sources/elvis/main.swift`, and `plugin/hooks/hooks.json`. A change to the two ElvisKit files needs a test. After any change to the path, confirm the built hook is still silent without touching the running app:

```sh
ELVIS_HOME="$(mktemp -d)" ELVIS_AUTOSTART=0 plugin/bin/elvis hook < payload.json; echo "exit $?"
```

Expect no output before `exit 0`, for a valid payload and for garbage. `Tests/ElvisAppTests` makes the same check on the debug build in every `make test`; the command above checks the release binary the plugin runs.

## Release

A release is a `v<version>` tag whose version matches `plugin/.claude-plugin/plugin.json`. Pushing the tag runs `.github/workflows/release.yml`. It runs the suite, builds a universal binary with `make universal`, adds a commit holding the plugin, that binary, and the licence to the `release` branch, and attaches the binary to a GitHub release. `.github/publish-release-branch.sh` refuses a tag that does not match the version.

People who installed from `j4ckwinter/elvis#release` stay on their copy until the version string changes, so bump it in a commit before tagging. The version is stated twice, because Claude Code reads one and the binary carries the other: `plugin/.claude-plugin/plugin.json` and `Version.current`. Change both; a test fails while they differ. Only that workflow writes to the `release` branch.

## Commit as you go

Committing is expected here. Commit each time a unit of work is complete and `make test` passes, before starting the next unit, and before a risky restructuring.

- One logical change per commit, in Conventional Commits: `type(scope): summary`, imperative and under 72 characters, with a body that says why when the summary does not. Types in use are `feat`, `fix`, `refactor`, `test`, `docs`, `perf`, `build`, `ci`, and `chore`.
- No `Co-Authored-By` trailers or any other line crediting an AI tool, in commits or pull request descriptions.
- Stage files by name after reading `git status`. Build output, `sheets/`, and `plugin/bin/` stay out of the repository.
- Commit on the branch that is checked out. Do not create or switch branches unless asked, and do not amend or rebase pushed commits.

Anything that reaches beyond this working tree needs Jack's request: pushing, opening a pull request, tagging a release, `make install`, installing the plugin into anyone's settings, and starting, quitting, or restarting his running Elvis.
