# Manufacturing Disruption Decision Tool

An **independent synthetic portfolio project** in base R. No input or result comes from BorgWarner or any other employer. This demonstrates a decision method, not a validated forecast or a real performance improvement.

## Decision question

At hour 4 of an eight-hour shift, the probability of a defect found at test rises from 2% to 12%. Compare three responses:

1. **Continue:** original staffing; stop after hour 8.
2. **Flex worker:** add one qualified worker for hours 4–8, splitting each half-hour equally between inspection and rework.
3. **Reassign + conditional overtime:** move one qualified worker from assembly to test after hour 4; use up to two hours of full-line overtime only while orders remain incomplete.

The rule chooses the feasible option with the most **fully delivered on-time orders**, then the lowest estimated total cost. This is an explicit management priority, not a claim of global economic optimality.

## Run on a Mac

The command-line model uses base R. The optional local dashboard requires the R package `shiny` (`install.packages("shiny")` if needed). From the project root:

```sh
Rscript R/generate_data.R
Rscript R/run_analysis.R
Rscript tests/test_baseline.R
Rscript tests/test_decision_model.R
Rscript tests/test_analysis.R
Rscript tests/test_dashboard_data.R
Rscript tests/test_shiny_app.R
Rscript tests/test_replications.R
Rscript R/run_replications.R
```

To open the interactive dashboard on your Mac, run `Rscript -e 'shiny::runApp("app", launch.browser=TRUE)'` from the project root. It runs on your computer and is **not deployed publicly**. In the single-day view, the slider changes only the post-shock defect rate; the orders, capacities, and unit-level random draws remain fixed. If you edit input CSVs, restart the app to reload them. The dashboard does not overwrite input CSVs or saved analysis outputs.

The dashboard's **Run 100 synthetic days** button redraws defect and repair outcomes for seeds 1001–1100 at the selected post-shock rate. Within each day, all three responses share the same draws (common random numbers), so their differences reflect the response under matched random conditions. The button reports mean on-time orders, mean good units shipped, mean cost, the 10th–90th percentile range of cost, and how many days each response was selected by the existing rule. If the rate slider changes after running it, click the button again. `R/run_replications.R` saves the 12% case to `output/replication_daily.csv` and `output/replication_summary.csv`.

The generator **overwrites** the CSVs in `data/` with the starter scenario. Edit those CSVs after generating them to explore another case; do not rerun the generator unless you want to reset them. `R/run_analysis.R` writes `output/comparison.csv`, `comparison.png`, `order_results.csv`, `bucket_log.csv`, `cost_breakdown.csv`, `sensitivity.csv`, and `decision_memo.md`.

## Synthetic inputs and units

Each bucket is 30 minutes. Bucket 8 ends at hour 4, bucket 16 at hour 8, and bucket 20 at hour 10. All numbers below are project assumptions, **not industry benchmarks**.

| Input | Fields and units | Starter values |
|---|---|---|
| `orders.csv` | ID, quantity in units, due bucket | 35 due hour 6; 30 due hour 8; 15 due hour 10 |
| `releases.csv` | units released into processing per bucket | 8 in each of buckets 1–16; 0 thereafter |
| `stations.csv` | maximum units completed per bucket | processing 8, assembly 7, test 6, rework 2 |
| `settings.csv` | bucket boundaries, defect/repair probabilities, worker capacity changes | shock bucket 9; shift end 16; horizon 20; defect 0.02 then 0.12; repair success 0.75; flex +1 test and +1 rework; reassignment −2 assembly and +2 test |
| `costs.csv` | illustrative USD amounts | base labor 2400/day; floater 25/hour; overtime 450/hour; rework consumables 5/unit; scrap material 30/unit; late order proxy 100/order; end WIP proxy 1/unit |
| `unit_draws.csv` | one defect and repair draw in [0,1) per released unit | R seed `20261103`; shared across all responses |

One half-hour of the flex worker adds one test and one rework slot: each quarter-hour is assumed to handle one unit. Reassignment removes two assembly slots and adds two test slots per half-hour, preserving that worker's time. Overtime represents a synthetic 12-person crew at $37.50/person-hour; base labor represents the crew for eight hours at $25/person-hour. Rework consumables exclude labor already counted.

## Flow, measures, and formulas

The model tracks individual IDs through processing, assembly, first test, at most one rework attempt, and retest. A unit can advance only one operation per half-hour. A failed repair is scrap. A repaired unit uses test capacity again and then passes; no defective unit ships. Defect probability applies when a unit first reaches test. Shared unit draws make comparisons reproducible.

Good units ship to unfinished orders by earliest due bucket, then order ID. An order is **on time** only when every unit ships by the end of its due bucket. End WIP is unfinished units in the processing, assembly, test, rework, and retest queues at hour 10. Finished goods beyond ordered quantity are separate.

The model checks this balance after every bucket:

`cumulative released = shipped good + scrap + finished goods + unfinished WIP`.

Estimated total cost in synthetic USD is:

`base labor + floater hours × floater rate + used overtime hours × overtime rate + reworked units × consumables rate + scrap units × material rate + late/incomplete orders × late-order proxy + end WIP units × WIP proxy`.

Late-order and WIP charges are comparison proxies, not observed penalties or accounting values. Overtime hours count only half-hour buckets used after hour 8. The full line is staffed during those buckets.

## Findings and limitations

See the [decision memo](output/decision_memo.md) and [chart](output/comparison.png) for the fixed-seed scenario. A small sensitivity check repeats the comparison at 6%, 12%, and 18% post-shock defect probabilities using the same draws. This is **not** a confidence interval or empirical validation. The recommended action can change when assumptions change.

The 100-day check varies only defect and repair draws. Orders, capacities, costs, and routing remain fixed across days. Its selection count is a **synthetic-scenario frequency**, not a real-world probability that an action is optimal. The reported cost percentile range describes the simulated 100 values; it is not a confidence interval for a factory.

This is a three-stage, one-day template. Before applying it elsewhere, replace the CSV assumptions, confirm routing and worker qualifications, and compare predictions with observed production. The model omits machine breakdowns, variable processing times, multiple rework attempts, and real customer penalty contracts.

**Interview talking points:** test bottlenecks, one-bucket transfer, unit conservation, why reassignment lowers assembly capacity, good units versus fully on-time orders, and why a synthetic recommendation has limited external validity.
