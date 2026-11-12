# Elvis

Elvis is a small black sprocker who lives in the corner of your Mac's screen and reacts to what Claude Code is doing. He is eager, wants you to be pleased with him, and is not very bright.

He draws in a transparent strip above the Dock. Clicks pass straight through him, and he never takes focus.

## Get him running

Requires macOS 14 or later and the Swift toolchain (Xcode or Command Line Tools).

```sh
make            # builds .build/release/elvis and copies it to plugin/bin/elvis
plugin/bin/elvis start
plugin/bin/elvis demo     # walks through his reactions, about 70 seconds
```

`make install` also copies the binary to `~/.local/bin/elvis`.

The paw print in the menu bar says what he thinks he is doing, throws a ball, turns sounds off, moves him to the other corner, and quits.

## Connect him to Claude Code

The `plugin/` directory is a Claude Code plugin. Its hooks run `plugin/bin/elvis hook` on session events, so build first.

For one session:

```sh
claude --plugin-dir /path/to/elvis/plugin
```

To keep him, register this repository as a local marketplace and install the plugin from it. These commands follow the Claude Code plugin docs as read on 2026-11-12; `claude plugin validate .` passes, and the install itself has not been run here.

```sh
claude plugin marketplace add /path/to/elvis
claude plugin install elvis@elvis
```

Once the plugin is loaded, starting or resuming a Claude Code session wakes Elvis if he is not already running. That includes headless `claude -p` runs. Set `ELVIS_AUTOSTART=0` to stop that.

## What he does

| When | Elvis |
| --- | --- |
| Nothing is happening | Sits about, then lies down, dozes, and after about four minutes falls asleep |
| You send a prompt | Startles awake and bounds up |
| Claude reads and searches | Follows a scent trail, nose down, ears dragging |
| Claude edits files | Digs, which is where the mud comes from |
| Claude runs a command | Points at it, one paw up |
| Claude searches the web | Sniffs the air |
| Tests fail | Sits, ears down, and whines softly, at most once every 90 seconds |
| Tests pass | Chases a ball, trots it back, and sits there looking proud. One fetch per 45 seconds; otherwise a wag |
| Claude needs your approval or an answer | Goes to the door, sits, and stares at you. He tilts his head, paws the door, and after a couple of minutes lies down with his chin on the floor. He stays silent while he waits |
| You answer | A relieved hop, then back to work |
| A run of two minutes or more ends | Flops flat out, tongue out, tail thumping |
| A shorter run ends | Trots over and wags at you |

Left alone he scratches, sneezes, stretches, chases his tail and regrets it, circles before lying down, twitches and dreams of tennis balls in his sleep, and nudges the ball toward you in case you missed it. Mud builds up through the day as Claude edits; he shakes it off when things go quiet, and he starts each day clean. Move the pointer over him to stroke him.

## Your own test runs

Elvis can also react to tests you run yourself in zsh. Add this to `~/.zshrc`:

```sh
eval "$(/path/to/elvis shell-init zsh)"
```

It reports each finished command's exit status to Elvis, who ignores everything that is not a test run. When a pipe hides the runner's exit status, as in `npm test | tail`, he stays out of it rather than guess.

## What leaves the hook

The hook reads Claude Code's payload, reduces it to an event name, the session id, a broad tool category, and a hash that pairs a permission request with its tool call, and writes that to a Unix socket in `~/Library/Application Support/Elvis/`. Prompts, commands, file paths, and tool output go no further than the hook process. The hooks are asynchronous, print nothing, and always exit 0.

`state.json` in the same directory holds the day's mud and the two menu settings.

## Working on him

```sh
make test       # logic, hook translation, test-run detection, and a drawing smoke test
make sheets     # renders every pose to sheets/poses-dark.png and sheets/poses-light.png
ELVIS_FILM=/some/dir .build/release/elvis run   # saves contact sheets of the live animation
```

- `Sources/ElvisKit/Brain.swift` decides what he does. It takes a seed and has no clock of its own, so behaviour is reproducible in tests. Timings live in `Brain.Tuning`.
- `Choreography.swift` turns an action into a pose, `Stage.swift` adds ear physics, blinking, and particles, and `Dog.swift` draws him. Coat colours are in `Painter.Coat`.
- `ClaudeHooks.swift` maps hook payloads to events, and `TestRuns.swift` decides whether a command was a test run and how it went.

## Known limits

- In a full-screen Space he stays where the top of the Dock would be, so he may appear to float. Not checked.
- He lives on the primary display only.
- The permission-prompt behaviour follows the documented hook events. It has been exercised with simulated events, not with a live permission prompt.
- Claude Code reports nothing at the moment you approve a command, so he stays by the door until that command finishes. This is also why he never whines there.
- A command such as `cd missing && npm test` that fails before the runner starts is read as a test failure.
- Test detection is a list of known runners. An unusual runner goes unnoticed until it is added to `TestRuns.swift`.
