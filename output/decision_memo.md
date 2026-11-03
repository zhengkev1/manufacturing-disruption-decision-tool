# Decision memo — synthetic manufacturing disruption

**Scope:** An illustrative three-stage line with a detected defect-rate increase at hour 4. All inputs and costs are synthetic; this is not an employer case study or a validated factory forecast.

**Recommendation:** reassign_overtime under the stated priority: maximize fully delivered on-time orders, then minimize estimated cost. This choice is feasible under the modeled staffing and two-hour overtime limit.

The recommended case delivers 3 of 3 orders on time, ships 80 good units by hour 10, leaves 47 units of unfinished WIP, uses 0.0 overtime hours, reworks 5 units, scraps 1 units, and has estimated total cost $2502.

## Comparison

| Response | On-time orders | Good units shipped | End WIP | Overtime hours | Reworked | Scrap | Cost (synthetic USD) |
|---|---:|---:|---:|---:|---:|---:|---:|
| continue | 2 | 78 | 49 | 0.0 | 4 | 1 | 2599 |
| flex | 3 | 80 | 42 | 0.0 | 6 | 1 | 2602 |
| reassign_overtime | 3 | 80 | 47 | 0.0 | 5 | 1 | 2502 |

## Defect-rate sensitivity

The same synthetic unit draws were reused while changing only the post-shock defect probability. This is a small scenario check, not a confidence interval.

| Post-shock defect rate | Continue on time | Flex on time | Reassign on time | Recommended |
|---:|---:|---:|---:|---|
| 6% | 3 | 3 | 3 | continue |
| 12% | 2 | 3 | 3 | reassign_overtime |
| 18% | 2 | 3 | 3 | reassign_overtime |

## Decision limits

The result is one fixed-seed synthetic day. It is sensitive to assumed capacities, defect/repair outcomes, order deadlines, and cost rates. The late-order charge is a comparison proxy, not a contract penalty. Recalibrate and validate against real operations before operational use.
