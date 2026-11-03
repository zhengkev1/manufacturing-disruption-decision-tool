# Manufacturing Disruption Decision Tool — approved design

This is an independent, simulated portfolio project. No employer data or results are used.

Model a three-stage line (processing, assembly, test) in R with 30-minute buckets. A defect-rate shock occurs after hour 4 of an eight-hour shift; up to two hours of overtime may follow. Compare: unchanged plan; one qualified floater split between inspection and rework; one cross-trained assembly worker reassigned to test, reducing assembly capacity, with overtime used only while orders remain incomplete.

Use documented synthetic orders, releases, station capacity, defect outcomes, rework outcomes, and cost rates. All scenarios begin from the same hour-4 state and share the same synthetic defect sequence. Extra inspection and rework do not lower the intrinsic defect rate. Failed units may be reworked once and retested; failed rework is scrap. No defective unit ships.

Allocate good units to orders by earliest due time. An order is on time only if its full quantity ships by its due time. Report good units shipped, on-time orders, WIP, overtime, rework, scrap, and estimated total cost at hour 10. Cost components and units must be shown. Feasible options must respect staffing and a two-hour overtime limit. Recommend by on-time order count, then total cost.

Milestone 1: create and verify synthetic inputs and a no-shock baseline flow. Milestone 2: model defects, rework, and three decisions. Milestone 3: visualization, README, decision memo, and truthful resume bullets after substantive results exist.
