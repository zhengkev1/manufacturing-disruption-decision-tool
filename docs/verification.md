# Verification record

The source of truth is the user-approved design in `docs/project_spec.md`. `R/generate_data.R` produces every CSV input; all are synthetic. No external or employer data were used.

## Independent calculations

In the no-shock baseline, 16 buckets release `16 × 8 = 128` units. Processing completes 128; assembly completes `15 × 7 = 105` because its first bucket is empty; test completes `14 × 6 = 84` because its first two buckets are empty. Orders request 80 units, so 80 ship, 4 become finished goods, and `128 − 84 = 44` remain WIP. This matches `Rscript R/baseline.R`.

In the fixed-seed 12% shock case, the flow balances are: continue `78 shipped + 1 scrap + 0 finished goods + 49 WIP = 128`; flex `80 + 1 + 5 + 42 = 128`; reassign `80 + 1 + 0 + 47 = 128`. The reassign cost is independently rebuilt as `$2400 base labor + 5 × $5 rework + 1 × $30 scrap + 47 × $1 WIP = $2502`. No overtime or late-order proxy is incurred in this sample.

## Checks

- `tests/test_baseline.R`: hand-derived five-bucket flow, earliest-due allocation, late completion, and conservation.
- `tests/test_decision_model.R`: capacity changes, one-bucket routing, repair success/failure, due-time calculation, cost, changeable defect probability, and conditional overtime.
- `tests/test_analysis.R`: outputs and required fields, recommendation rule, identical pre-shock logs, and final flow balances.
- `output/comparison.png` was visually inspected for legible labels.

These checks verify the implementation under the stated assumptions, not real-world predictive accuracy.
