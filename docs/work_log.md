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
- **Result:** Full R tests, starter analysis, the 300-case stress audit, and `git diff --check` passed. Independent review found two documentation/reproducibility gaps; Step 9 resolved both. Checkpoint commit and push follow.

## 2026-11-04 00:42 — Step 9: close review gaps before checkpoint

- **Plan before action:** Add a failing baseline test for reordered named station capacities, normalize by name in the baseline implementation, and preserve the stress script inside the repository with its seed and run command. Re-run focused/full checks and verify reviewer findings are resolved.
- **Reproduce:** `Rscript tests/test_baseline.R`; `Rscript audit/stress_general_inputs.R`; full `tests/*.R` suite.
- **Rollback:** Keep the pre-review baseline code available in commit `3081b74`; revert only this new normalization if it changes canonical results.
- **Result:** The reordered baseline test failed before the fix and passed after normalizing three named station capacities. The 300-case script was copied into `audit/stress_general_inputs.R`. Full R tests, standalone baseline CLI, stress audit, and `git diff --check` passed. The independent reviewer confirmed both findings resolved.
