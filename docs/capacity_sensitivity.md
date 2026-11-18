# Assembly-capacity sensitivity — synthetic starter case

This check changes only **base assembly capacity**, measured in units completed per 30-minute bucket, from 4 through 8. The post-shock defect rate stays at 12%. For each capacity, the model compares all three responses over 100 synthetic days (seeds 1001–1100), sharing unit-level random draws across responses and capacity values. The reassignment response still removes two assembly slots and adds two test slots after the shock.

| Base assembly capacity | Continue selected | Flex selected | Reassign + OT selected |
|---:|---:|---:|---:|
| 4 | 100 | 0 | 0 |
| 5 | 99 | 1 | 0 |
| 6 | 19 | 64 | 17 |
| 7 (starter) | 5 | 15 | 80 |
| 8 | 6 | 0 | 94 |

The [chart](../output/capacity_sensitivity.png) shows the shift in selection counts. At base capacity 6, reassignment leaves only 4 assembly slots per bucket after the shock and uses a mean 1.73 overtime hours in these synthetic runs, versus 0.08 hours at base capacity 7. Its mean estimated cost at capacity 6 is $3,308 versus $2,642 for Flex; Flex is selected more often under the stated per-day rule. At base capacity 7, reassignment is selected on 80 of 100 days. This is a useful reminder that a cross-trained worker's opportunity cost at the original station matters.

The rule is applied **separately on each synthetic day**: first maximize fully delivered on-time orders, then minimize estimated total cost. A selection count is therefore not the same as ranking scenarios by their across-day mean on-time orders. It is also not a real-world probability of being optimal. No capacity value here is an observed factory measurement or a recommendation to change a real line.

Reproduce from the repository root with `Rscript R/run_capacity_sensitivity.R`. The [15-row summary](../output/capacity_sensitivity.csv) and [1,500 scenario-day records](../output/capacity_sensitivity_daily.csv) contain the unrounded values; the capacity-7 row matches the existing 12% repeated-run output exactly.
