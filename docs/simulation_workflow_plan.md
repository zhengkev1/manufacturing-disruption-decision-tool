# Manufacturing Decision Tool: Simulation and Decision Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The user has already delegated project execution; review this plan before beginning the next model milestone.

**Goal:** Turn the current synthetic three-stage comparison into a reproducible decision experiment that can evaluate feasible staffing and overtime policies under explicit processing-time uncertainty, while remaining explainable to an industrial-engineering internship interviewer.

**Architecture:** Keep the verified R bucket model as a reference and teaching baseline. Build a separate, standard-library Python discrete-event engine for finer timing; use a shared CSV input contract and separate policy, experiment, and reporting modules. Only integrate outputs into the Shiny site after the event model passes flow, timing, and R-reference checks.

**Tech Stack:** R/base R and existing Shiny app; Python 3 standard library (`dataclasses`, `heapq`, `csv`, `random`, `statistics`); CSV/Markdown/PNG outputs; GitHub Actions. No machine learning or new heavy simulation framework in this phase.

**Spec:** [Approved project design](project_spec.md), [current methods](../README.md), and the [timing-sensitivity finding](time_resolution_audit.md). This is an extension proposal; the approved original model and its results remain separate.

## Global constraints and definitions

- Project is independent and synthetic; no employer inputs, measured improvements, or factory probabilities may be claimed.
- Keep all assumptions, formula units, random seeds, and decision priorities visible. Current base case: three stages, one rework attempt, 8-hour shift, at most 2 hours of overtime, and orders due at hours 6/8/10.
- A product cannot ship before passing test; a repaired product consumes a retest operation. Inventory balance must hold at every event boundary: released = shipped + scrap + finished goods + WIP.
- All policies on a synthetic day receive the same unit-level defect and repair draws and the same service-time draws. A policy may change *when* a unit is tested, so its pre/post-shock defect probability can differ; this is a modeled timing effect, not a matched defect outcome guarantee.
- The primary decision priority remains maximum number of fully on-time orders, then minimum estimated cost. Report other metrics so a manager can see tradeoffs. Do not silently replace this rule with a weighted score.
- Record each planned phase in `docs/work_log.md` before acting. Work in reviewable commits; preserve the private repository and existing synthetic inputs. Every milestone needs a reproducible command and an independently checked representative value.

## Current state and why this plan exists

The R model, Shiny dashboard, synthetic data generator, 100-day comparisons, capacity sensitivity, and CI are working. An independent Python audit reproduced the R fixed-day comparison at 30 minutes. Reducing the modeled transfer step to 15 minutes changed the recommended response on 49 of 100 paired synthetic days. This means a larger search over worker counts would currently optimize a timing convention. The next model must make service and transfer times explicit before optimizing staffing.

## File map and ownership

| File | Responsibility |
|---|---|
| `data/event_settings.csv` (new) | Synthetic, documented processing-time, transfer-time, and timing-variation assumptions with units. Never overwrite the existing starter CSVs. |
| `python/model_inputs.py` (new) | Parse existing CSVs plus event settings; validate quantities, units, capacities, skill limits, and probability bounds. |
| `python/event_sim.py` (new) | Event queue, station resources, unit lifecycle, order allocation, and conservation checks. No recommendation logic. |
| `python/policies.py` (new) | Immutable policy definitions, feasibility checks, and choices at decision times. |
| `python/experiments.py` (new) | Matched random scenarios, policy comparisons, seeds, aggregation, and sensitivity sweeps. |
| `python/run_experiments.py` (new) | Reproducible CLI writing clearly labeled CSV summaries and a short Markdown decision memo under `output/event/`. |
| `tests_py/` (new) | Focused Python `unittest` tests, including hand-calculated tiny lines and timing boundary cases. |
| `app/app.R` (later) | Display precomputed event-model results with their assumptions and provenance; retain the existing R view. |
| `README.md`, `docs/verification.md`, `docs/work_log.md`, `.github/workflows/r-checks.yml` | Method, commands, verified limits, progress, and automated checks. |

## Review focus: five likely failure modes

1. A unit finishes exactly at an order due time: define it as on time and test that boundary.
2. Defect shock occurs exactly when test starts: use the test-start timestamp to select pre/post rate; test both sides of hour 4.
3. A worker is reassigned while already serving a unit: let the in-progress operation finish; change capacity only for the next start. Test no double booking.
4. Overtime is requested after all orders are complete: do not incur overtime or start unnecessary work; test a zero-overtime case.
5. The same unit is scheduled for test and rework or counted twice as finished: assert one live state per unit plus conservation after every event in small tests and after each day in experiments.

## Milestone 0 — Freeze the comparison contract (0.5–1 day)

**Deliverable:** A written metric and timing contract that an interviewer can follow without reading code.

### Task 0.1: Define what the event model measures

**Files:** Create `docs/event_model_contract.md`; modify `docs/work_log.md`.

- [ ] Write exact meanings and units for release, processing start/end, station availability, transfer delay, test start, shock time, ship time, due time, overtime use, WIP, finished goods, rework count, and cost components.
- [ ] Specify event ordering at equal timestamps: completions, shipment/order updates, policy changes, then new operation starts. Record why this choice avoids a unit using two resources simultaneously.
- [ ] Specify which quantities the R and Python models should agree on (conservation, cost formula, decision priority) and which may differ (completion timestamps and final counts due to different timing rules).
- [ ] Independently work one four-unit, two-order example by hand and include its expected event timeline and cost. Commit the contract before implementing the engine.

**Gate:** No engine work until the contract includes the five review-focus boundaries above. If a material time or staffing definition is unresolved, label it **UNVERIFIED** and resolve it before coding.

## Milestone 1 — Input contract and event engine (3–5 days)

**Deliverable:** `python/event_sim.py` runs a tiny line and the starter line without any decision optimizer.

### Task 1.1: Load and validate synthetic inputs

**Files:** Create `data/event_settings.csv`, `python/model_inputs.py`, `tests_py/test_model_inputs.py`.

**Interfaces:** `load_inputs(data_dir: Path, event_settings_path: Path) -> ModelInputs`; immutable `ModelInputs` contains orders, releases, station capacities, costs, probabilities, service-time assumptions, and decision times.

- [ ] Write failing tests for a valid starter load; duplicate station name; negative/zero service time; missing unit; probability outside `[0,1]`; and reassignment exceeding the skilled-worker limit.
- [ ] Run `python3 -m unittest tests_py.test_model_inputs -v` and confirm the intended failures.
- [ ] Implement parsing and validation. Keep starter timing assumptions explicitly synthetic; begin with constant service and transfer times, then add variation only after deterministic behavior is verified.
- [ ] Re-run focused tests; commit only input contract and fixture files.

### Task 1.2: Implement event flow and queues

**Files:** Create `python/event_sim.py`, `tests_py/test_event_sim.py`.

**Interfaces:** `simulate_day(inputs: ModelInputs, policy: Policy, draws: DayDraws) -> DayResult`; `DayResult` carries per-order completion, per-unit terminal state, event log, daily metrics, and named cost components.

- [ ] Write failing hand-derived tests for a defect-free four-unit line, a test failure followed by successful rework and retest, a failed repair leading to scrap, and an order completed exactly at its due time.
- [ ] Confirm red tests. Implement a priority queue ordered by `(timestamp, event_priority, sequence_id)`; schedule release, operation completion, transfer readiness, and decision events. A station may start a unit only when its resource is free and the unit has finished its predecessor.
- [ ] Check conservation and exclusive unit state after each event in tiny tests. Run `python3 -m unittest tests_py.test_event_sim -v` and commit.

### Task 1.3: Add shift, reassignment, and overtime boundaries

**Files:** Modify `python/event_sim.py`, `tests_py/test_event_sim.py`.

- [ ] Write failing tests for exactly hour-4 shock, hour-8 shift end, no overtime after all orders finish, a worker moving only after an in-progress operation completes, and a hard hour-10 stop.
- [ ] Implement the smallest capacity calendar consistent with `docs/event_model_contract.md`; do not let an event occupy a worker on two stations at once.
- [ ] Verify elapsed overtime hours independently from the event log; compare each named cost component with a hand calculation. Run focused tests and commit.

**Milestone 1 gate:** All tests pass, every unit has one state, and at least one starter scenario can be traced in an event log. If the event engine cannot satisfy conservation, fix it before adding candidate policies.

## Milestone 2 — Parameterized feasible policies (2–3 days)

**Deliverable:** The three current responses and a small, explainable set of worker/time allocations run through the same event engine.

### Task 2.1: Represent policies and reject impossible actions

**Files:** Create `python/policies.py`, `tests_py/test_policies.py`.

**Interfaces:** `FixedPolicy(reassigned_workers: int, floater_test_fraction: float, max_overtime_hours: float)` and `check_feasible(policy, inputs) -> None`; retain named constructors for `continue`, `flex`, and `reassign_overtime`.

- [ ] Test 0/1/2 reassigned workers, floater fractions 0/0.25/0.5/0.75/1, and overtime choices 0/0.5/1/1.5/2 hours. Reject a combination if the synthetic skill roster or available worker time is exceeded.
- [ ] Define how a fraction translates into minutes of worker availability. Never treat fractional people as extra simultaneous full-capacity workers.
- [ ] Confirm the three named policies reproduce their stated staffing actions in an event trace; commit.

### Task 2.2: Enumerate only feasible fixed policies

**Files:** Modify `python/policies.py`; create `tests_py/test_policy_grid.py`.

**Interface:** `candidate_policies(inputs: ModelInputs) -> list[FixedPolicy]` in a stable documented order.

- [ ] Test that every returned policy passes `check_feasible`, policies are unique, and the named baseline policies are included.
- [ ] Add an explicit small candidate grid rather than a general optimizer. Print the actual number of candidates before large experiments; cap the default grid so a Mac run finishes in a few minutes.
- [ ] Commit after the candidate list and feasibility tests pass.

**Milestone 2 gate:** No "optimal staffing" claim until time allocation is physically feasible and the search space is disclosed. Search only the documented grid.

## Milestone 3 — Matched simulation experiments (3–4 days)

**Deliverable:** Reproducible per-day and aggregate comparisons of fixed policies under uncertainty.

### Task 3.1: Generate common synthetic days

**Files:** Create `python/experiments.py`, `tests_py/test_experiments.py`.

**Interfaces:** `make_day_draws(seed: int, inputs: ModelInputs) -> DayDraws`; `run_paired_experiment(inputs, policies, seeds) -> (daily_rows, summary_rows)`.

- [ ] Write tests that the same seed reproduces identical unit draws, different policies share the same draws for the same day, and running experiments does not alter global RNG state.
- [ ] Pre-generate defect, repair, service, and transfer draws by unit/stage/attempt where applicable; avoid consuming random numbers in policy-dependent order.
- [ ] Run a three-seed experiment, independently rebuild one day from its seed, then commit.

### Task 3.2: Summarize service, cost, and risk

**Files:** Modify `python/experiments.py`, `tests_py/test_experiments.py`.

- [ ] Export per-policy/day: fully on-time orders, good units shipped, end WIP, overtime hours, reworked, scrap, total cost, and feasibility.
- [ ] Report means and empirical 10th/90th percentiles, plus the share of synthetic days with any late order. Label all as conditional synthetic results, not confidence intervals or real probabilities.
- [ ] Assert that all policies have exactly one row per seed, each day's recommendation follows the declared lexicographic rule, and cost equals the sum of named components. Verify one summary row with an independent Python or R aggregation; commit.

### Task 3.3: Choose a simulation budget by convergence

**Files:** Modify `python/run_experiments.py`; create `docs/event_convergence.md`.

- [ ] Compare prefix results at 100, 500, and 1,000 seeds for the top few feasible policies. Record runtime on the user's Mac and changes in policy ranking, mean cost, and late-order frequency.
- [ ] Pick the smallest default run count that gives a sufficiently stable *synthetic ranking* for a portfolio demo. Report any remaining instability instead of tuning seeds to favor a policy.
- [ ] Save seeds, input snapshot/hash, candidate grid, program version/commit, and run command with each output; commit.

**Milestone 3 gate:** A saved result is reproducible from its declared inputs. If rankings remain unstable, report a set of plausible policies rather than one winner.

## Milestone 4 — Policy that can react during the day (2–4 days)

**Deliverable:** One transparent threshold policy compared with the best fixed policies on the *same* synthetic days.

### Task 4.1: Implement one dynamic rule

**Files:** Modify `python/policies.py`, `python/event_sim.py`; create `tests_py/test_dynamic_policy.py`.

**Interface:** `ThresholdPolicy(test_queue_threshold: int, assembly_queue_ceiling: int, reassigned_workers: int = 1)` observes only information available at the decision time. Decisions are logged with timestamp and observed queue lengths.

- [ ] Test that the rule reassigns only when the test queue exceeds its threshold, the assembly queue is below its ceiling, and worker qualifications/availability allow it. Test moving back after a later decision point.
- [ ] Reject look-ahead: the policy cannot inspect future defects, future random draws, or final orders. Add a test in which future draws change but the current action remains identical.
- [ ] Run paired comparisons with fixed policies and commit.

### Task 4.2: Avoid selecting thresholds on evaluation days

**Files:** Modify `python/experiments.py`, `tests_py/test_experiments.py`; create `docs/policy_evaluation.md`.

- [ ] Use one declared seed set to pick a small threshold pair and a disjoint seed set to evaluate it. Keep the same candidate grid and seed split in version control.
- [ ] Compare on-time orders, late-order frequency, cost, WIP, overtime, and worst observed cases. Hand-check one decision trace.
- [ ] State whether the dynamic rule helps under the chosen synthetic assumptions; report failure cases and tradeoffs. Commit.

**Milestone 4 gate:** Do not call a dynamic rule "better" based on days used to choose its thresholds.

## Milestone 5 — Robustness and adversarial checks (2–3 days)

**Deliverable:** A matrix showing when the decision changes, plus clear validity limits.

### Task 5.1: Sweep assumptions without hiding denominators

**Files:** Modify `python/run_experiments.py`; create `docs/event_sensitivity.md` and a CSV under `output/event/`.

- [ ] Sweep a small declared set of post-shock defect rates, assembly/test capacities, service-time variability, repair success rates, and order tightness. Use matching seeds within each comparison.
- [ ] For each cell, show inputs, number of synthetic days, selected policy or tied set, and service/cost measures. Mark infeasible cells. Do not aggregate across different demand bases as if they were the same population.
- [ ] Include at least one deliberately adverse case: assembly bottleneck, late shock detection, and zero overtime availability. Independently verify one cell; commit.

### Task 5.2: Compare event model with existing R baseline

**Files:** Create `tests_py/test_cross_model.py`; update `docs/verification.md`.

- [ ] Verify exact agreement on shared definitions: orders, releases, defects/rework draw identities, cost components, conservation, and 2-hour overtime cap. Explain differences in completion timing and recommendation rather than forcing the event model to match bucket totals.
- [ ] Keep `audit/time_resolution.py` as a regression warning. Do not delete the existing R result or re-label it as incorrect merely because timing assumptions differ.
- [ ] Run all R and Python tests and the retained 300-case R stress audit; commit.

**Milestone 5 gate:** Any critical unit balance, deadline, or cost mismatch blocks publication of a new recommendation.

## Milestone 6 — Visualization and portfolio package (2–3 days)

**Deliverable:** An interviewer can change a few assumptions, compare fixed and dynamic policies, and identify which model produced a result.

### Task 6.1: Add a separate event-model view to Shiny

**Files:** Modify `app/app.R`; add a small data-loading helper in `R/` only if needed; update `tests/test_shiny_app.R`.

- [ ] First show saved, versioned event-model outputs rather than launching a long Python simulation on every slider movement. Label the model, seed set, input assumptions, and last generation command in the UI.
- [ ] Show a policy comparison table, service/cost distributions, and a sensitivity view. Preserve the current R single-day page as a distinct baseline view.
- [ ] Browser-check the Mac layout, labels, numeric consistency with saved CSVs, and narrow viewport; commit.

### Task 6.2: Final reporting and interview explanation

**Files:** Update `README.md`, `docs/verification.md`, `output/decision_memo.md` or create a separate `output/event/decision_memo.md`, and `docs/resume_bullets.md`.

- [ ] Explain the IE ideas: bottlenecks, queueing, worker opportunity cost, common random numbers, policy feasibility, sensitivity, and why synthetic validation is limited.
- [ ] Include one hand-worked unit timeline and one hand-worked cost calculation. Separate verified program behavior from unverified external validity.
- [ ] Write two truthful résumé bullets that describe methods and artifacts, with no invented factory savings or throughput improvements.
- [ ] Run full local checks, inspect the rendered page and figures, push to the private repository, and confirm GitHub Actions. Commit only after the narrative agrees with the CSV results.

## Execution cadence, budget, and stop rules

Estimated effort is **roughly 3–4 focused weeks**, not a promise of elapsed calendar time. Milestones 0–1 establish correctness; 2–3 add meaningful decision comparison; 4–6 extend the portfolio story. Each milestone is useful on its own and can be reviewed before proceeding. The smallest useful second version stops after Milestone 3 if the event model, fixed-policy grid, and paired results are stable.

For each task: log the planned action, write one focused failing test, implement, run that test, check one representative result independently, update the relevant contract/report, commit, push to the private repo, and confirm CI when workflow behavior changes. If a critical check fails, save a minimal reproducing case and repair the root cause before expanding the experiment. Roll back to the last clean commit if the new model cannot be made explainable within this scope.

**Success criterion:** A manager can see which response or rule is recommended *for stated synthetic inputs*, what service/cost tradeoff led to it, and which assumption changes the answer. An interviewer can reproduce the run and explain every principal formula and limitation.
