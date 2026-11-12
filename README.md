# Elvis

Elvis is a small black sprocker who lives in the corner of your Mac's screen and reacts to what Claude Code is doing. He is eager, wants you to be pleased with him, and is not very bright.

He draws in a transparent strip above the Dock and never takes focus. Clicks pass straight through the strip everywhere except on Elvis himself.

## Get him running

Requires macOS 14 or later and the Swift toolchain (Xcode or Command Line Tools).

```sh
make            # builds .build/release/elvis and copies it to plugin/bin/elvis
plugin/bin/elvis start
plugin/bin/elvis demo     # walks through his reactions, about 85 seconds
```

`make install` also copies the binary to `~/.local/bin/elvis`.

Press on Elvis and drag to pick him up, carry him anywhere on any display, and let go to put him down. He lives there until you move him again. A click without a drag is a pat. **Back to His Corner** in the menu sends him home.

The paw print in the menu bar says what he thinks he is doing, counts the Claude Code sessions that are working or waiting for you and the subagents they have out, throws a ball, turns sounds off, moves him between corners, and quits.

## Connect him to Claude Code

The `plugin/` directory is a Claude Code plugin. Its hooks run `plugin/bin/elvis hook` on session events, so build first.

For one session:

```sh
claude --plugin-dir /path/to/elvis/plugin
```

To keep him, register this repository as a local marketplace and install the plugin from it. These commands follow the Claude Code plugin docs as read on 2026-11-12, and the plugin was installed this way at user scope that day.

```sh
claude plugin marketplace add /path/to/elvis
claude plugin install elvis@elvis
```

Claude Code reads a plugin from a local marketplace in place, so its hooks run `plugin/bin/elvis` from this checkout and a later `make` changes them at once. Checked on 2026-11-12 with Claude Code 2.1.322, whose debug log shows the hook command resolved to the checkout. The Elvis already on screen keeps running the build he was started from. To swap him for a new build:

```sh
make restart
```

To install him without building, use the `release` branch. GitHub Actions builds each `v*` tag into a universal binary and publishes the plugin and that binary there, so no Swift toolchain is needed:

```sh
claude plugin marketplace add j4ckwinter/elvis#release
claude plugin install elvis@elvis
```

The `main` branch carries no binary. Installed from there, the hooks do nothing until you run `make`. Each [release](https://github.com/j4ckwinter/elvis/releases) also has the binary as a zip, for running `elvis demo` and the other commands by hand. macOS quarantines a browser download; clear it with `xattr -d com.apple.quarantine elvis`.

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
| Claude sends out subagents | Stops and cocks his head one way, then the other. He keeps an ear out for them until they are back |
| Tests fail | Sits, ears down, and whines softly, at most once every 90 seconds |
| Tests pass | Chases a ball, trots it back, and sits there looking proud. One fetch per 45 seconds; otherwise a wag. A pass straight after a failure gets a spin and a yip first |
| Claude commits | Buries a bone where it will be safe. One bone per 20 seconds |
| Claude pushes | Barks twice to tell the whole street. One bark a minute; otherwise a wag |
| Claude needs your approval or an answer | Goes to the door, sits, and stares at you. He tilts his head, paws the door, and after a couple of minutes lies down with his chin on the floor. He stays silent while he waits |
| You answer | A relieved hop, then back to work |
| A run of two minutes or more ends | Flops flat out, tongue out, tail thumping |
| A shorter run ends | Trots over and wags at you |

Left alone he scratches, sneezes, stretches, chases his tail and regrets it, circles before lying down, twitches and dreams of tennis balls in his sleep, and nudges the ball toward you in case you missed it. Mud builds up through the day as Claude edits; he shakes it off when things go quiet, and he starts each day clean. Move the pointer over him to stroke him.

## Your own test runs, commits, and pushes

Elvis can also react to tests you run yourself in zsh, and to your own `git commit` and `git push`. Add this to `~/.zshrc`:

```sh
eval "$(/path/to/elvis shell-init zsh)"
```

It reports each finished command's exit status to Elvis, who ignores everything that is not a test run, a commit, or a push. When a pipe hides the command's exit status, as in `npm test | tail` or `git push | cat`, he stays out of it rather than guess. He does the same when a chain such as `cd app && npm test` fails, because the status could belong to either command.

## What leaves the hook

The hook reads Claude Code's payload, reduces it to an event name, the session id, a broad tool category, and a hash that pairs a permission request with its tool call, and writes that to a Unix socket in `~/Library/Application Support/Elvis/`. Prompts, commands, file paths, and tool output go no further than the hook process. The hooks are asynchronous, print nothing, and always exit 0.

`state.json` in the same directory holds the day's mud, the two menu settings, and where you last put him down.

## Working on him

```sh
make test       # logic, hook translation, test-run detection, a drawing smoke test, and the built binary
make sheets     # renders every pose to sheets/poses-dark.png and sheets/poses-light.png
ELVIS_FILM=/some/dir .build/release/elvis run   # saves contact sheets of the live animation
```

- `Sources/ElvisKit/Brain.swift` decides what he does. It takes a seed and has no clock of its own, so behaviour is reproducible in tests. Timings live in `Brain.Tuning`.
- `Choreography.swift` turns an action into a pose, `Stage.swift` adds ear physics, blinking, and particles, and `Dog.swift` draws him. Coat colours are in `Painter.Coat`.
- `ClaudeHooks.swift` maps hook payloads to events, and `TestRuns.swift` decides whether a command was a test run and how it went.
- `Tests/ElvisAppTests` runs the built `elvis` binary: the hook, the command line, the socket, and starting and quitting the app. Each test gets a temporary `ELVIS_HOME`, and `ELVIS_HEADLESS` keeps the app it starts off the screen.

## Known limits

- In a full-screen Space he stays where the top of the Dock would be. Checked by eye on 2026-11-12.
- He starts on the primary display. Dragging him is the only way to move him to another one.
- While he is resting the app checks the pointer ten times a second, so a very fast click on him can pass through to the window underneath.
- With "Displays have separate Spaces" on, he may disappear briefly while he is carried across two displays. Not checked.
- Claude Code reports nothing at the moment you approve a command, so he stays by the door until that command finishes. This is also why he never whines there.
- When a chain such as `npm run build && npm test` fails, he blames the tests only if the output reports failing tests. After nothing but a `cd`, any failure is the runner's, unless the output shows the `cd` itself failed. Your own shell passes him no output, so there a failed chain goes unremarked.
- The menu counts sessions and subagents but cannot name them. Project names and paths stay inside the hook.
- Only `git commit` and `git push` count as saving and sending work. A merge, a rebase, or `gh pr create` goes unremarked.
- Test detection is a list of known runners. An unusual runner goes unnoticed until it is added to `TestRuns.swift`.
