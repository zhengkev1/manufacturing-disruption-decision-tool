# Work log

This log records each planned step before work starts, then its result and reproduction commands. All inputs and results in this repository are synthetic unless a source is explicitly identified. Times are America/New_York.

## 2026-11-04 00:29 — Step 1: audit stability and generality

- **Plan before action:** Inspect the current simulator's input contracts, flow invariants, random-number handling, and tests. Identify the highest-impact failure that can be fixed without changing the approved decision rule.
- **Starting point / rollback:** `main` at commit `3081b74`, clean working tree. If the next implementation is unsound, reset only its uncommitted changes and return to this commit.
- **Reproduce audit:** `rg -n 'stop\(|stopifnot|set.seed|runif|capacity|defect|cost|order' R tests`; read the relevant source and tests; run focused checks as needed.
- **Result:** Found a concrete constraint bug: extending `horizon_buckets` beyond 20 lets the reassignment option run more than the stated two overtime hours. The existing tests cover only the starter 20-bucket horizon. Other input contracts are documented in `R/decision_model.R`; no employer data is involved.

## 2026-11-04 00:37 — Step 2: enforce the two-hour overtime limit

- **Plan before action:** Add a focused failing test with a 24-bucket horizon and one late release. Keep the 30-minute bucket and two-hour limit fixed; stop modeled work after four overtime buckets even when the observation horizon is longer. Preserve the starter results.
- **Rollback:** Restore `R/decision_model.R` and the new test from commit `3081b74` if the fix changes the starter scenario or fails flow conservation.
- **Reproduce:** `Rscript tests/test_decision_model.R`, then `for f in tests/*.R; do Rscript "$f" || exit 1; done`.
- **Result:** The new 24-bucket test failed before the fix (`overtime_hours == 2` was false), then passed after stopping work after bucket 20. All six R tests passed, and the starter 12% outputs remained 78/80/80 good units shipped and $2599/$2602/$2502 estimated cost.

## 2026-11-04 00:32 — Step 3: preserve continuity through the usage window

- **Plan before action:** Inspect the account's five-hour reset time and create a temporary heartbeat for this same chat near the natural reset. It should resume only unfinished project work and stop at 08:00 New York time; it must not spend reset credits.
- **Reproduce:** Read-only `get_usage_limits` before scheduling, then inspect the saved automation if creation succeeds.
- **Result:** The five-hour window is 45% used and resets at 05:13:45 New York time. Two free reset credits exist but are not authorized for use. Created one same-chat heartbeat at 05:15 New York time (`continue-manufacturing-model-until-08-00`, one occurrence) with an 08:00 stop instruction. The saved automation was inspected locally. No reset credit was spent.

## 2026-11-04 00:34 — Step 4: assess public data fit

- **Plan before action:** Search authoritative public dataset pages for fields that could calibrate this line model: process flow, station capacity, testing defects, rework, order due dates, and costs. Record only sources that supply a relevant field and document missing fields. Do not import unrelated sensor classification data as if it were line performance data.
- **Reproduce:** Use source links and a field-fit table in a short note under `docs/` if a concrete source is found; otherwise log the reason to keep transparent synthetic inputs.
- **Result:** Inspected the primary dataset pages for UCI SECOM, Mendeley Simulation Input Data, and Mendeley Machine Configurations. Their public descriptions do not document a complete matched set of order deadlines, defect/rework outcomes, station capacity, and costs for this decision. Added `docs/public_data_assessment.md` with source links and field-fit limits. No external data was downloaded or substituted into the synthetic scenario.

## 2026-11-04 00:38 — Step 5: accept equivalent station CSV row orders

- **Plan before action:** Test whether reordering the four named station rows changes or breaks the model. If it does, normalize by station name at the shared capacity-schedule boundary while rejecting missing or duplicated station names. This keeps the same four-stage contract and avoids a new model feature.
- **Reproduce:** Add a focused test in `tests/test_decision_model.R`; watch it fail; implement the smallest correction; rerun all R tests and independently compare starter outputs.
- **Rollback:** Return `R/decision_model.R` and the new test to the state after Step 2 if normalization changes the actual capacities or outputs.
- **Result:** A reordered station vector failed before the change. `capacity_schedule()` now selects the four required capacities by name, while still rejecting missing or extra station entries. Focused and full R tests passed; a copied and reordered `stations.csv` produced an identical 12% comparison.

## 2026-11-04 00:37 — Step 6: randomized input stress check

- **Plan before action:** Generate a bounded collection of small valid synthetic input cases with varying orders, release timing, station capacities, defect rates, repair rates, and horizons. Check externally visible invariants for all three responses: no more shipments than ordered demand, on-time classification matches completion buckets, total cost equals named components, overtime never exceeds two hours, and total released units balance shipped/scrap/finished goods/WIP. Save any failing case as a deterministic regression test before changing model code.
- **Reproduce:** `Rscript audit/stress_general_inputs.R` uses explicit seed `20261104` and reports case count and failures. Promote only a meaningful bug-reproducing case to `tests/`.
- **Result:** The stress script ran with seed `20261104`: 300 bounded valid synthetic input cases × 3 responses passed all listed invariants. The script is retained in `audit/` for reproduction; it is not a factory validation or an input source. No model change was needed.

## 2026-11-04 00:38 — Step 7: reject malformed random-draw CSV values

- **Plan before action:** Probe whether character-valued `defect_draw` or `repair_draw` entries can pass range checks through R's comparison coercion. If they can, add a focused regression test and require finite numeric draws in `simulate_day()` before routing any units. Keep legitimate numeric CSV behavior unchanged.
- **Reproduce:** `Rscript tests/test_decision_model.R`, then all R tests and a copied CSV with one malformed draw.
- **Rollback:** Restore only the input-validation and test edits if they reject valid generated draws.
- **Result:** The malformed `"0.01x"` defect draw passed the old range check and made the focused test fail. Added finite-numeric validation for both defect and repair draws. Focused and full R tests passed. A copied `unit_draws.csv` with the malformed value was rejected with the intended explicit error.

## 2026-11-04 00:40 — Step 8: document and checkpoint the verified fixes

- **Plan before action:** Update README and verification notes for the overtime cap, station-row-order handling, draw validation, and public-data assessment. Re-run the full tests and starter analysis, review the diff, obtain independent code review, then commit and push to the confirmed private repository. This commit becomes the rollback point for later experiments.
- **Reproduce:** `for f in tests/*.R; do Rscript "$f" || exit 1; done`; `Rscript R/run_analysis.R`; `git diff --check`; inspect the logged commands and output.
- **Result:** Full R tests, starter analysis, the 300-case stress audit, and `git diff --check` passed. Independent review found two documentation/reproducibility gaps; Step 9 resolved both. Committed and pushed checkpoint `ffccf77` to the verified private `main`; GitHub file retrieval confirmed the retained stress script, and the local tree was clean.

## 2026-11-04 00:42 — Step 9: close review gaps before checkpoint

- **Plan before action:** Add a failing baseline test for reordered named station capacities, normalize by name in the baseline implementation, and preserve the stress script inside the repository with its seed and run command. Re-run focused/full checks and verify reviewer findings are resolved.
- **Reproduce:** `Rscript tests/test_baseline.R`; `Rscript audit/stress_general_inputs.R`; full `tests/*.R` suite.
- **Rollback:** Keep the pre-review baseline code available in commit `3081b74`; revert only this new normalization if it changes canonical results.
- **Result:** The reordered baseline test failed before the fix and passed after normalizing three named station capacities. The 300-case script was copied into `audit/stress_general_inputs.R`. Full R tests, standalone baseline CLI, stress audit, and `git diff --check` passed. The independent reviewer confirmed both findings resolved.

## 2026-11-04 00:44 — Step 10: add automated regression checks

- **Plan before action:** Verify current official GitHub Actions setup instructions, then add the smallest private-repository workflow that runs the R test suite and the retained stress audit on each push and pull request. Check the workflow syntax and inspect the first remote run before calling it working.
- **Rollback:** Commit `ffccf77` is the known-good local and remote state. If the workflow is blocked by environment or package installation, remove only the workflow and document the result.
- **Reproduce:** Inspect `.github/workflows/`; push the workflow; check its actual GitHub Actions run and logs, not only local YAML syntax.
- **Result:** Workflow YAML parsed locally with Ruby and was pushed as commit `6569c52`. GitHub run `41781249722` completed successfully: R setup, Shiny installation, all R tests, and the retained stress audit passed on Ubuntu.

## 2026-11-04 00:47 — Step 11: exercise a different low-volume synthetic line

- **Plan before action:** Build a temporary end-to-end CSV case with fewer releases/orders, different station capacities, no fixed-draw defects, and zero reassignment. Run the existing `run_analysis()` path and check that all outputs, including charts, are generated with zero final WIP. If it fails, write a focused regression test, repair the specific edge case, and keep starter outputs unchanged.
- **Reproduce:** A deterministic test script under `tests/` using temporary copied CSVs, then full R tests and the stress audit.
- **Rollback:** Commit `6569c52` is the current remote baseline; revert only alternate-case fixes if they alter starter results.
- **Result:** The first test fixture still released units near shift end, so nonzero WIP was the correct model result; it was not a code defect. After moving releases into buckets 1–12, the alternate-line test passed with 10 good units shipped and zero final WIP in all three responses. Chart and memo files were created. No production-code change was needed.

## 2026-11-04 00:50 — Step 12: verify CI and preserve alternate-line evidence

- **Plan before action:** Wait for GitHub Actions run `41781249722` to reach a final conclusion; inspect failed step logs if needed. Run the expanded local test suite, then commit the alternate-line test and documentation. Confirm the next CI run includes that test and returns success.
- **Reproduce:** `for f in tests/*.R; do Rscript "$f" || exit 1; done`; inspect the run's job steps and final conclusion through GitHub; compare local/remote commit IDs.
- **Rollback:** Retain `6569c52` as the pre-alternate-line checkpoint; if the new test is flaky or mis-specified, remove it without changing the simulator.
- **Result:** The expanded local suite passed all seven test scripts, and `git diff --check` passed. First CI run succeeded. Committed and pushed alternate-line evidence as `83767c3`; second GitHub run `41781652114` completed successfully.

## 2026-11-04 00:51 — Step 13: keep repeated simulations from changing the caller's RNG state

- **Plan before action:** Test whether `run_replications()` changes `.Random.seed` when called with fixed seeds. If it does, preserve and restore the caller's seed, including when the function errors, without adding a package dependency. This makes the reusable function less surprising to other R analyses while keeping its saved outputs identical.
- **Reproduce:** Add a focused red-green check in `tests/test_replications.R`; run all R tests and compare the 12% saved summary against a fresh call.
- **Rollback:** Commit `83767c3` is the last remote checkpoint; revert only RNG handling if it changes documented results.
- **Result:** The new test showed that `run_replications()` changed `.Random.seed`. The function now restores an existing seed or removes the temporary seed if none existed, including after an error. Focused and full R tests passed. Re-running `R/run_replications.R` reproduced the saved 12% means, cost quantiles, and 5/15/80 selection counts without changing the tracked output CSVs.

## 2026-11-04 00:53 — Step 14: checkpoint RNG isolation and inspect CI

- **Plan before action:** Confirm second GitHub Actions run reaches a final conclusion, review the RNG-isolation diff, then commit/push this verified change. If remote CI fails, inspect the failed step and fix that before declaring automation reliable.
- **Reproduce:** `git diff --check`; `for f in tests/*.R; do Rscript "$f" || exit 1; done`; inspect GitHub run `41781652114` and the next run after push.
- **Rollback:** Commit `83767c3` is the last remote checkpoint before RNG isolation.
- **Result:** Second GitHub run `41781652114` completed successfully. The RNG change passed the focused and full local suites; the 12% saved output CSVs were unchanged. Committed and pushed as `26880f6`; the tree was clean. Third GitHub run `41781966885` was in progress at 00:54.

## 2026-11-04 00:54 — Step 15: check Monte Carlo stability at the starter shock rate

- **Plan before action:** Use the same fixed assumptions at 12% but extend independent synthetic days to 1,000. Compare selection frequencies and mean on-time orders at prefixes 100, 500, and 1,000. Treat these as simulation convergence evidence conditional on the synthetic inputs, not a factory probability estimate. Change no recommendation rule based on this audit alone.
- **Reproduce:** Run `run_replications(0.12, load_dashboard_inputs(), seeds = 1001:2000)` and aggregate its `daily` table by prefix. Record only summary values, not a second large dataset unless a failure requires it.
- **Rollback:** This is read-only analysis; commit `26880f6` remains the checkpoint.
- **Result:** At 12% and seeds 1001–2000, the 100/500/1000-day prefixes selected reassignment on 80/417/848 days (fractions 0.800/0.834/0.848); Continue on 5/26/49; Flex on 15/57/103. Mean on-time orders for reassignment stayed 3.000 in all three prefixes. The ranking was stable, but 100-day fractions are not precise estimates of even the synthetic long-run frequency.

## 2026-11-04 00:55 — Step 16: close the current audit and prepare natural-reset continuation

- **Plan before action:** Confirm GitHub run `41781966885` reaches a final conclusion, commit/push the convergence audit and final logs, check the tree is clean, and read the five-hour usage limit. If the limit interrupts work, leave the 05:15 same-chat heartbeat active; resume from this log after the natural reset and stop by 08:00 New York time. Do not use reset credits.
- **Reproduce:** GitHub workflow run API, `git status --short --branch`, `get_usage_limits`, and the saved heartbeat automation record.
- **Result:** GitHub run `41781966885` completed successfully; its R tests and stress audit both passed. `git diff --check` passed. The convergence note and this log are ready for a documentation checkpoint. The natural-reset heartbeat remains active for 05:15.

## 2026-11-04 05:16 — Step 17: test sensitivity to assembly capacity

- **Plan before action:** With all other starter inputs fixed, vary the assembly station's per-bucket capacity from 4 through 8 and run 100 paired synthetic days at 12% post-shock defects for each value. Record mean on-time orders, cost, and days selected for the three responses. This probes whether the current recommendation depends on spare assembly capacity. Decide after seeing results whether to add a reproducible sensitivity artifact; do not tune the base scenario to force a result.
- **Reproduce:** Copy `load_dashboard_inputs()` in memory, set `inputs$capacities["assembly"]` for each value, run `run_replications(0.12, inputs, seeds = 1001:1100)`, and compare the 7-capacity row to saved 12% output.
- **Rollback:** Read-only analysis initially; remote checkpoint `aa3e3e9` remains intact.
- **Result:** Reassignment was selected on 0/0/17/80/94 of 100 synthetic days as base assembly capacity rose from 4 to 8 units per 30 minutes. At capacity 6, Flex was selected 64 days and reassignment 17; at capacity 7, reassignment was selected 80. The base capacity-7 row exactly matched the saved 12% 5/15/80 result. This is an assumption sensitivity, not a proposed change to the actual line.

## 2026-11-04 05:18 — Step 18: make capacity sensitivity reproducible

- **Plan before action:** Add a small reusable R function around the existing repeated simulator, with a focused failing test for paired capacities and validation of capacity values. Add a CLI script that exports 4–8 capacity summaries and underlying daily records for the starter 12% case, plus a short explanation of what the result means. Keep base inputs and decision rule unchanged.
- **Reproduce:** `Rscript tests/test_replications.R` red then green; `Rscript R/run_capacity_sensitivity.R`; independently aggregate daily CSV with Python; full R suite.
- **Rollback:** Commit `aa3e3e9` is the prior clean checkpoint; revert only this new function/script/artifact if the outputs cannot be explained or independently checked.
- **Result:** Added `run_capacity_sensitivity()` after a missing-function test failed, then passed. The CLI script generated a 15-row summary, 1,500-row daily CSV, and a legible base-R chart. Independent Python aggregation reproduced every count, mean, and cost percentile; base capacity 7 matched the saved 12% repeated results in every field. All seven R test scripts, the 300-case audit, and `git diff --check` passed. The base inputs and decision rule were not changed.

## 2026-11-04 05:21 — Step 19: review and checkpoint the capacity stress test

- **Plan before action:** Obtain an independent review of the new function, script, synthetic results, and documentation. Fix any material issue, then commit and push to the verified private repository. Inspect the GitHub Actions run for this commit.
- **Reproduce:** Review the uncommitted diff against `aa3e3e9`; run the full local suite; inspect GitHub workflow status after push.
- **Rollback:** Commit `aa3e3e9` is the last clean remote checkpoint.
- **Result:** Pending.

## 2026-11-18 — Step 20: finish the pending capacity checkpoint

- **Plan before action:** Add a literal regression check proving that assembly capacity 6 and 7 produce different selections for the documented three seeds. Re-run focused and full tests, review generated artifacts, then commit and push the capacity analysis to the private repository. Keep the starter inputs and decision rule unchanged.
- **Reproduce:** `Rscript tests/test_replications.R`; all `tests/*.R`; `Rscript audit/stress_general_inputs.R`; `git diff --check`; compare the capacity-7 row to the saved 12% replication summary.
- **Rollback:** Remote commit `aa3e3e9` remains the checkpoint until this phase passes.
- **Result:** The three-seed regression now proves capacity 6 selects Continue/Flex/Reassign on 1/2/0 days while capacity 7 selects 1/0/2. All seven R test scripts, the 300-case × 3-response audit, and `git diff --check` passed. GitHub confirmed `zhengkev1/manufacturing-disruption-decision-tool` is private. Commit and remote CI verification follow.
