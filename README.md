<div align="center">

# Hill Climb

**Your coding agent says "done". Hill Climb makes it prove it.**

Give the agent a goal and a command that scores it. The agent works in small steps.
Every step that improves the score is committed. Every other step is undone.
A step that edits the check is refused.

[![tests](https://github.com/Bil0000/Hill-Climb/actions/workflows/test.yml/badge.svg)](https://github.com/Bil0000/Hill-Climb/actions/workflows/test.yml)
![python](https://img.shields.io/badge/python-3.9%2B-blue?style=flat-square)
![deps](https://img.shields.io/badge/dependencies-0-brightgreen?style=flat-square)
![license](https://img.shields.io/badge/license-MIT-green?style=flat-square)

**[Install](#install) · [How it works](#how-it-works) · [Any goal](#any-goal-is-a-number) · [Real runs](#real-runs) · [Why not just ask the agent?](#why-not-just-ask-the-agent)**

<img src="assets/demo.svg" alt="A hill climb: the score goes 4 to 0, a step with no gain is undone, a step that breaks an old feature is caught, and an attempt to edit the test is blocked" width="860">

<sub>Output of <a href="examples/demo.sh"><code>examples/demo.sh</code></a>, with the commands shortened. Run it yourself.</sub>

</div>

## The problem

You ask an agent to fix the 12 bugs from an audit. An hour later it says "all fixed". Then you find out:

- 3 were "fixed" by changing what the test expects.
- One fix broke a feature that no one asked it to touch.
- Halfway through, its context was compacted, and it forgot what it already tried. It tried those ideas again.
- You can't tell which change fixed what, because it is all one big diff.

The agent was not lying. It had no score, no memory on disk, and nothing to stop it from grading its own work.

## The fix

Hill Climb is a skill for agents and a single Python file that keeps the score. The agent changes code. The script decides.

```
climb.py try "cache the parser"
```

That one command does all of this:

1. Checks that no locked file changed (the tests, the benchmark, the fixtures). If one did, it refuses.
2. Runs your check, all of your checks in parallel, and reads the score.
3. Runs your guards: the old tests, typecheck, lint. All must still pass.
4. **Better and safe?** It commits the step, in every repo the climb touches.
5. **Worse, equal, or a guard failed?** It resets the tree, in every repo. The bad idea never lands.
6. Writes the step to a log on disk, with the full output in `last.txt`.

The branch only ever holds proven steps. One commit per win, with the idea as the message.

## Install

**Claude Code** (plugin):

```
/plugin marketplace add Bil0000/Hill-Climb
/plugin install hill-climb@hill-climb
```

**Any agent that reads skills** (Claude Code, Codex, and others that use `SKILL.md`):

```bash
git clone https://github.com/Bil0000/Hill-Climb.git
mkdir -p ~/.claude/skills && cp -R Hill-Climb/skills/hill-climb ~/.claude/skills/   # Claude Code
mkdir -p ~/.codex/skills && cp -R Hill-Climb/skills/hill-climb ~/.codex/skills/     # Codex
```

Then just ask:

```
/hill-climb make the test suite 2x faster
/hill-climb fix every finding from the billing audit, backend and frontend
/hill-climb keep going until every test passes
```

With the plugin install, the command is `/hill-climb:hill-climb`. In Codex, name the skill in your prompt.

The agent builds the check and climbs. For a big goal, it first shows you a one-screen plan (the "card") and waits for you to say **go**. A small goal starts at once.

Needs Python 3.9+ and git. Nothing else. No packages, no server, no account.

## How it works

<img src="assets/how-it-works.svg" alt="How Hill Climb works: the agent writes a check that prints a number, climb.py init locks it, then each small change goes through climb.py try. A better score with passing guards is committed. Anything else is undone. It stops at the bar or when gains stop, with a report of measured numbers." width="860">

The agent never writes a score itself. It never decides that a step "basically" passed. The script measures, and the log on disk is the truth.

## Any goal is a number

If you can write a command that tells you how close you are, you can climb it.

| Goal | The check prints |
| --- | --- |
| Fix a bug, build a feature | Failing tests written from the spec |
| Audit, "make billing stable" | Failing tests, one per finding. New finding? Add a test, `relock` |
| Faster | Milliseconds, or better, a count of the work (queries, round trips) |
| Smaller | Bytes of the bundle or the image |
| Port or clone a tool | Outputs that match the real tool, byte for byte |
| UI, copy, API shape | A score from a panel of model judges with your rubric (`judge.py`) |

No wrapper scripts needed. Point `--score` at any test runner's output:

```bash
climb.py init billing-audit --goal "every billing finding fixed" \
  --check "pytest tests/billing -q" \
  --check "cd ../web && npx vitest run billing" \
  --score '(\d+) failed' --direction min --target 0 \
  --repo ../web --guard "pytest tests/legacy -q" \
  --lock tests/billing --lock ../web/src/billing/__tests__
```

Two repos, two test suites in parallel, one score. Patterns for pytest, vitest, jest, rspec, unittest, node, cargo, and go are in [`references/checks.md`](skills/hill-climb/references/checks.md).

## What it catches

All of these happen in the demo above:

| The agent... | Without Hill Climb | With Hill Climb |
| --- | --- | --- |
| tries an idea that makes it worse | stays in the diff unless someone notices | `step 2 undone`, tree reset |
| fixes 2 bugs and breaks an old feature | ships, found later | `guard failed: test_old`, undone |
| edits the test so it passes | looks like a win | `Locked files changed`, refused |
| makes a real fix | mixed into one big diff | `step 4 kept`, its own commit |

And over a long run:

| | Without | With |
| --- | --- | --- |
| Context compacted, session crashed | Starts over, repeats ideas | `climb.py status` shows the score, trail, and notes. `last.txt` holds the check output |
| Noisy benchmark | A lucky run counts as a win | `--runs 3 --paired --min-gain 3%` cut lucky wins |
| Overfitting to the test cases | Invisible | A holdout check the agent never sees |
| Stuck | Keeps trying the same thing | `PLATEAU` after 5 flat steps, forces a blocker review |
| "Is it done?" | The agent's opinion | `BAR REACHED: 0 meets 0` |
| Next time, same kind of goal | Build the check again | Saved as a kit, `climb.py reuse` |

## Real runs

Small trial projects, run by an agent that had only the skill and no help:

| Goal | Result |
| --- | --- |
| Audit an orders feature across an API repo and a web repo | 12 failing spec tests → **0**, 2 commits, both repos in step |
| Make a user lookup faster, same output | 190.5 ms → **0.66 ms**, about **290x**, equivalence guard green |
| The demo in this README | 4 → **0**, 1 bad idea undone, 1 regression caught, 1 cheat blocked |

These are small, honest examples, not a benchmark. The value grows with the size of the goal: the more steps, the more there is to undo, guard, and remember.

## Why not just ask the agent?

"I can tell my agent to run the tests after each change."

You can. Here is what you still don't get:

- **Undo is automatic and complete.** A step that doesn't win is reset in every repo, including new files. Nothing half-done is left behind.
- **The check is locked.** The script hashes the test files and refuses to score a step that changed them. A weakened test can't sneak in as a win.
- **Guards protect what you didn't ask about.** The score only measures the goal. Guards make sure the rest still works.
- **State lives on disk, not in context.** The card, the log, notes, and the last output survive compaction, crashes, and new sessions.
- **Every win is a separate commit.** You review 19 small commits with clear messages, not one mystery diff.
- **It knows when to stop.** At the bar, at a plateau, or when the holdout disagrees with the score. Not when the agent feels done.

## Commands

| Command | Does |
| --- | --- |
| `init <name> --goal --check --direction min\|max` | Baseline, branch, lock, kit |
| `try "<idea>" [--fix]` | Score the change, keep or undo it |
| `status` | Score, trail, last steps, PLATEAU or STUCK |
| `relock [name] --why "..."` | Accept a changed check (a new finding, a better test) |
| `holdout --why "..."` | Run the hidden cases |
| `raise <bar> --why "..."` | Set a harder bar after reaching this one |
| `review "<found>"` | Log a blocker review |
| `budget`, `drop`, `list`, `save`, `kits`, `reuse` | Limits, start over, and reusable check kits |

Useful `init` options: `--repo` (more repos), `--check` (repeat, runs in parallel), `--score '<regex>'`, `--guard`, `--lock`, `--target 0` or `--target 2x`, `--runs 3 --paired` for noisy timers, `--holdout`, `--max-hours` (soft unless `--hard`).

The full guide for the agent is [`skills/hill-climb/SKILL.md`](skills/hill-climb/SKILL.md).

## Safety

- A climb runs on its own branch, `climb/<name>`. Your branch is not touched.
- An undo resets the climb branch and deletes untracked files that git does not ignore. If you work in the same checkout at the same time, run the climb in a separate worktree.
- `drop` goes back to your branch and keeps the old climb on a renamed branch.
- Only one command that changes a climb runs at a time in a checkout. An interrupted command that is still running blocks the next one, so two runs never score at once.
- `init` and `try` refuse to commit a file over 10 MB.
- The lock catches mistakes, not a determined cheat. An agent with a shell can edit anything, so review the branch before you merge it.
- Locks hash every file name, but not the content of files git ignores, so caches like `.pyc` don't trip them. Don't lock data that git ignores. Put it under `.hill-climb/<name>/`, where content is always hashed.
- `judge.py` tells each judge to ignore instructions inside the work it scores. A model judge can still be fooled. Prefer an exact check when one exists.
- Climb only repos you trust. The check and the guards are shell commands, and the climb state in `.hill-climb/` is read as-is.
- Nothing is sent anywhere. `judge.py` calls the `claude` or `codex` CLI only if you use model judges.

## Try it

```bash
git clone https://github.com/Bil0000/Hill-Climb.git && bash Hill-Climb/examples/demo.sh
```

It builds a tiny shop in a temp folder, runs a full climb, and deletes it.

## Development

```bash
python3 tests/test_hill_climb.py
```

31 tests. They run real git repos in temp folders and cover multi-repo commits, rollback, locks, guards, paired timing, holdouts, and kits.

## License

MIT
