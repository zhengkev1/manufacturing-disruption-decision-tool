# Time-resolution audit — synthetic starter line

The R model moves a unit at most one operation in each 30-minute bucket. This independent Python audit asks whether reducing that forced transfer delay to 15 minutes changes the decision. It is a **model sensitivity check**, not a claim that 15-minute timing is more accurate in a real factory.

Run `python3 audit/time_resolution.py` from the repository root. The script reads the existing synthetic CSVs and changes no input or saved analysis file. Its 30-minute fixed-day outputs are asserted against every numeric field in `output/comparison.csv`, which was produced by R. At both resolutions it asserts unit conservation in every step and no more than two hours of overtime.

## Comparable inputs and added assumptions

- The same 8 units are released at the start of each original 30-minute bucket. At 15-minute resolution, the second quarter-hour releases zero units.
- Each station's two 15-minute capacity slots sum to its original 30-minute capacity. Odd capacities put the extra slot in the second quarter-hour. The script asserts this equality for every bucket and response.
- Orders keep their original clock-time deadlines. The defect shock still begins after hour 4, the shift ends after hour 8, and observation ends after hour 10.
- Each unit still advances at most one operation per **new** time step, so the minimum modeled transfer delay changes from 30 to 15 minutes. This is the quantity under test.
- In the Flex response, the worker's extra test slot is in the first quarter-hour and extra rework slot is in the second. Reassignment removes one assembly slot and adds one test slot in each quarter-hour.
- The fixed-day audit reuses the CSV's unit-level defect and repair draws. The 100-day Python comparison uses deterministic Python-generated draws shared across both resolutions and all three responses on each day. Python and R use different random-number generators, so the Python 30-minute 100-day selection counts are **not expected** to equal R's 5/15/80 counts.

## Results

For the fixed CSV draw, the 30-minute Python implementation exactly reproduced the R comparison and selected reassignment. The 15-minute implementation also selected reassignment: Continue, Flex, and Reassign each delivered 3 orders on time, with estimated costs $2,504, $2,602, and $2,503 respectively. The one-dollar margin between Continue and Reassign shows this particular 15-minute recommendation is fragile under the illustrative cost assumptions.

Across 100 paired synthetic days, using the same Python draws at both resolutions:

| Time step | Continue selected | Flex selected | Reassign selected |
|---|---:|---:|---:|
| 30 minutes | 7 | 12 | 81 |
| 15 minutes | 40 | 0 | 60 |

The selected response changed on **49 of 100** paired days: 32 Reassign→Continue, 6 Flex→Continue, 6 Flex→Reassign, and 5 Continue→Reassign. These are conditional synthetic frequencies, not factory probabilities or confidence intervals.

## Interpretation and next decision

The recommendation depends materially on the modeled transfer delay and within-half-hour capacity schedule. The audit therefore does **not** justify declaring any fixed response universally best. Before a more precise operational claim, obtain or assume explicit processing-time and transfer-time distributions and compare the model with observed timestamps. For a portfolio extension, an event-level simulator could represent those times directly; it would still need calibration before being used for a real line.
