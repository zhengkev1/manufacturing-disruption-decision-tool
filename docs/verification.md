# Verification record

The source of truth is the user-approved design in `docs/project_spec.md`. `R/generate_data.R` produces every CSV input; all are synthetic. No external or employer data were used.

## Independent calculations

In the no-shock baseline, 16 buckets release `16 × 8 = 128` units. Processing completes 128; assembly completes `15 × 7 = 105` because its first bucket is empty; test completes `14 × 6 = 84` because its first two buckets are empty. Orders request 80 units, so 80 ship, 4 become finished goods, and `128 − 84 = 44` remain WIP. This matches `Rscript R/baseline.R`.

In the fixed-seed 12% shock case, the flow balances are: continue `78 shipped + 1 scrap + 0 finished goods + 49 WIP = 128`; flex `80 + 1 + 5 + 42 = 128`; reassign `80 + 1 + 0 + 47 = 128`. The reassign cost is independently rebuilt as `$2400 base labor + 5 × $5 rework + 1 × $30 scrap + 47 × $1 WIP = $2502`. No overtime or late-order proxy is incurred in this sample.

## Checks

- `tests/test_baseline.R`: hand-derived five-bucket flow, earliest-due allocation, late completion, and conservation.
- `tests/test_decision_model.R`: capacity changes, one-bucket routing, repair success/failure, due-time calculation, cost, changeable defect probability, conditional overtime, missing-cost rejection, and fractional-capacity rejection.
- `tests/test_analysis.R`: outputs and required fields, recommendation rule, identical pre-shock logs, and final flow balances.
- `tests/test_dashboard_data.R`: dashboard 12% results match the saved comparison; at 6% the recommendation changes to continue; input settings remain unchanged.
- `tests/test_shiny_app.R`: Shiny app boots from the repository.
- `tests/test_replications.R`: repeated runs are deterministic for the same seeds, selection counts sum to the number of synthetic days, and one day reproduces from its seed.
- `output/comparison.png` was visually inspected for legible labels.
- The local Shiny page was opened in a browser; the 12% result displayed reassign with 3/3 orders and $2502, and the slider showed continue at 6%. The dashboard was also checked at a narrow viewport for readable charts.
- The 100-day button was clicked once in the local browser after loading; the page displayed 5/15/80 selected days. A separate Python calculation from `output/replication_daily.csv` confirmed 100 distinct days and 300 scenario-day records, all three selection counts, the displayed means for on-time orders, units shipped, and cost, and the saved 10th/90th cost percentiles.

These checks verify the implementation under the stated assumptions, not real-world predictive accuracy.
