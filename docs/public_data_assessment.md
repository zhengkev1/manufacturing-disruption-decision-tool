# Public data fit assessment — 2026-11-04

The decision tool needs a consistent set of unit releases, station capacities, test defects, rework outcomes, order quantities and due times, and cost assumptions for the **same line and time period**. The starter inputs remain explicitly synthetic.

| Public source | Documented relevant fields | Not documented on the dataset page for this decision question |
|---|---|---|
| [UCI SECOM](https://archive.ics.uci.edu/dataset/179/secom) | Per-entity test pass/fail labels, timestamps, and process measurements | Station routing/capacity, rework, customer orders and due times, costs |
| [Mendeley Simulation Input Data](https://data.mendeley.com/datasets/mfw36tn9xy/2) | Item arrivals, manufacturing steps, processing times, operators, working days/hours | Test-defect and rework outcomes, customer due times, costs |
| [Mendeley Machine Configurations](https://data.mendeley.com/datasets/d92brjg97d/1) | Machine processing, failure, and repair rates; buffer capacities | Product test defects, rework decisions, orders and due times, costs |

These are **field-fit observations from the linked dataset descriptions**, not a claim that every file or every public dataset has been audited. Machine failure/repair is also a different event from a product defect/rework loop. Combining unrelated datasets into one apparently real factory day would create unsupported relationships between orders, quality, staffing, and cost.

**Decision for this version:** keep transparent synthetic inputs. The Olaitan dataset is the most relevant future candidate for a separate arrival-time and processing-time calibration exercise, but its high-mix routing would require a different model structure. SECOM could support a separate quality classification project; it does not validate this line's response recommendation. No public data was downloaded or used in the current results.
