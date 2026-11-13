# The card

The one message the user reads before a big climb starts.

Send me one message with the card filled in and nothing else to decide. Send
it as Markdown, not in a code block, so it renders. Use this layout:

> ### Climb card: `build-speed`
> **Goal:** cold build of the app 2x faster, same output
>
> | Score | Now | Bar |
> | --- | --- | --- |
> | Median build seconds, lower is better | **47.0s** | **23.5s** (2x) |
>
> | Setting | Recommended | Default | Why |
> | --- | --- | --- | --- |
> | Check | `./scripts/bench-build.sh` | none | Builds from clean, prints seconds |
> | Kit | new | none | No saved kit fits |
> | Runs per score | **3** | 1 | Score drifts 1.2s between runs |
> | Paired | **yes** | no | Shared machine, so old and new run in turns |
> | Min gain | **3%** | 0 | Above the drift, so luck can't win |
> | Guards | `npm test`, `npm run typecheck` | none | Faster must still be correct |
> | Holdout | 3 of the 12 sample apps | none | Catches overfitting |
> | Locked | `scripts/bench-build.sh`, `test/`, `samples/` | none | So no step can edit the check |
> | Timeout | 1800s | 1800s | |
> | Budget | no limit | no limit | About 2 min a step, so 40 steps is about 1.5 hours |
> | After the bar | **stop** | stop | |
> | Branch | `climb/build-speed` | `climb/<name>` | One commit per kept step |
>
> **Needs your answer:** none
>
> Reply **go** to start, or change a line, like "runs 5".

Bold a recommendation that differs from the default. Keep each "Why" to a few
words, and leave it empty when the default is fine. Fill every line with your
best guess. List a line under "Needs your answer" only when I must confirm it.
If I named a goal but no bar, propose one that is ambitious and checkable,
like "2x faster" or "every sample matches".

Then start it:

```
python3 "$CLIMB" init build-speed --goal "cold build 2x faster" \
  --check ./scripts/bench-build.sh --direction min --target 2x --after stop \
  --runs 3 --paired --min-gain 3% --guard "npm test" --guard "npm run typecheck" \
  --holdout ./scripts/bench-holdout.sh --lock scripts --lock test \
  --lock .hill-climb/build-speed/holdout
```

An audit over a backend and a frontend looks like this:

```
python3 "$CLIMB" init billing-audit --goal "every billing finding fixed" \
  --check "pytest tests/billing -q" --check "cd ../web && npx vitest run billing" \
  --score '(\d+) failed' --direction min --target 0 --repo ../web \
  --guard "cd ../web && npx tsc --noEmit" \
  --lock tests/billing --lock ../web/src/billing/__tests__
```
