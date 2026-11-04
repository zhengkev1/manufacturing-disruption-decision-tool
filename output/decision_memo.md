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

## Repeated synthetic days

At each rate, 100 synthetic days use seeds 1001–1100. The same random draws are shared by the three responses within each day and by matching seeds across rates. Orders, capacities, and cost assumptions stay fixed.

| Post-shock defect rate | Response | Mean on-time orders | Mean good units shipped | Mean cost (synthetic USD) | Days selected |
|---:|---|---:|---:|---:|---:|
| 6% | continue | 2.70 | 79.44 | 2516 | 16 |
| 6% | flex | 2.99 | 79.99 | 2584 | 2 |
| 6% | reassign_overtime | 3.00 | 80.00 | 2490 | 82 |
| 12% | continue | 2.16 | 77.48 | 2606 | 5 |
| 12% | flex | 2.99 | 79.96 | 2623 | 15 |
| 12% | reassign_overtime | 3.00 | 80.00 | 2561 | 80 |
| 18% | continue | 2.01 | 75.05 | 2651 | 0 |
| 18% | flex | 2.80 | 79.55 | 2680 | 19 |
| 18% | reassign_overtime | 3.00 | 80.00 | 2647 | 81 |

Days selected counts how often the stated rule chose each response in these synthetic draws. The single-day result above and these frequencies answer different questions. Neither is a real-world success probability or a confidence interval.

## Decision limits

The recommendation at the top applies to one fixed-seed synthetic day. It is sensitive to assumed capacities, defect/repair outcomes, order deadlines, and cost rates. The late-order charge is a comparison proxy, not a contract penalty. Recalibrate and validate against real operations before operational use.
