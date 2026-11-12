# Climbing a harness's standing prefix

Every agent harness pays a **standing prefix**: the system prompt, the tool
schemas, the manual index, the project rules, all of it, resent before the
user's first word on every request. Nothing guards it. It grows by accretion
and no test fails when it does.

This example makes that number the score, and climbs it.

- Check: `prefix-score.sh` opens one fresh session, sends one turn, and prints
  the prompt tokens that turn paid (`input + cached input`).
- Guard: `prefix-guard.sh` fails the step unless the turn completed and the
  model answered `PONG`. A cheaper prompt that breaks the harness is not a win.

The score is deterministic. Wall time is not: in this climb it was
provider-bound (2 to 6 s to first token) and did not move with the work, so
the climb optimizes the one number the harness actually controls.

## Start a climb

```sh
mkdir -p myharness && cd myharness && git init
# put prefix-score.sh and prefix-guard.sh here, then:
python3 "$HILL_CLIMB/scripts/climb.py" init "Cut the standing prefix every request pays" \
  --check "bash prefix-score.sh" --score 'tokens=(\d+)' --direction min \
  --target 2200 --runs 3 --min-gain 20 --timeout 300 \
  --guard "bash prefix-guard.sh" --lock prefix-score.sh --lock prefix-guard.sh
```

`--lock` matters more here than usual: the scripts are the ruler, and a step
can trivially "improve" the score by weakening the probe.

## Adapt it to your harness

`prefix-score.sh` is the only harness-specific file. Replace the `nodecode rpc`
call with your harness's one-shot mode, keep the shape:

1. a throwaway store, so the session is genuinely fresh;
2. a prompt whose answer is checkable, here `Reply with exactly: PONG`;
3. the usage event of that one turn, printed as `tokens=<n>`;
4. exit 0 whatever the score, so a broken probe reads as a bad score and the
   guard explains it.

If your harness reports prompt tokens only in logs, take the last `usage`
line of the turn. Do not estimate with a tokenizer: the provider's number is
the one you pay.

## What it found on nodecode

Bar was 2200. Start 2552 tokens.

| stage | tokens |
|---|---|
| start | 2552 |
| help index cut at each topic's title clause | 2293 |
| shorter folder and help headers, shorter standing skill | 2186 |
| curated one-line label per help topic | **2195** |

Three steps were kept. Two were undone: they measured under `min_gain`, which
is exactly the behaviour that keeps a climb honest.

The standing sections were all mutable material in nodecode, so the whole
climb was a user-level override, no source change: a shorter `folder` header,
a shorter `help` header, a trimmed built-in "context" skill, and one hook that
renders each manual topic as `:topic - short label` instead of a sentence.

## Two traps this climb hit

Both were caught by the check, not by reading code. Both cost more than the
tokens they saved, so read them before you trim a prompt.

1. **A hook's helpers must live in the same file as the hook.** The layer loads
   files in name order; a hook that calls a helper defined in a later file is
   skipped at boot, silently. The section then reverts to its long form and the
   score goes *up* — or, worse, the rendered text goes empty.
2. **A trimmed format string must keep its placeholder.** The `help` section is
   one format string with `~a` for the topic list. Shortening the prose and
   dropping the `~a` renders a header with no topics: a smaller prompt, a green
   guard, and a manual index that no longer exists. Only a dump of the real
   request body showed it. Dump the request the check measures at least once.

## What this suggests upstream

The same finding, from the harness side: headings are the cheapest thing in a
prompt. In nodecode the manual index is 16 lines of `:topic - subtitle`; the
topic name alone resolves every lookup. Cutting the subtitles to a short label
is worth about 30 tokens per request, every request, forever. A knob such as
`help.headings = full | short | off` would let a user choose that in one line.

Two upstream PRs came out of this climb: nodecode-ai/nodecode#470 (the core
topics and the image line) and nodecode-ai/cells#129 (five cell topics).
Together they are about 480 tokens per request, for every user of the build.
