source("R/decision_model.R")

base <- c(processing = 1L, assembly = 1L, test = 1L, rework = 1L)
stopifnot(identical(capacity_schedule(base, "continue", 9L), base))
stopifnot(identical(capacity_schedule(base, "continue", 17L), setNames(rep(0L, 4), names(base))))
stopifnot(capacity_schedule(c(processing = 8L, assembly = 7L, test = 6L, rework = 2L), "flex", 9L)["test"] == 7L)
stopifnot(capacity_schedule(c(processing = 8L, assembly = 7L, test = 6L, rework = 2L), "flex", 9L)["rework"] == 3L)
stopifnot(capacity_schedule(c(processing = 8L, assembly = 7L, test = 6L, rework = 2L), "reassign_overtime", 9L)["assembly"] == 5L)
stopifnot(capacity_schedule(c(processing = 8L, assembly = 7L, test = 6L, rework = 2L), "reassign_overtime", 17L)["test"] == 8L)

# One unit: process in bucket 1, assemble in 2, fail test in 3,
# succeed rework in 4, pass retest in 5, and miss the bucket-4 due time.
orders <- data.frame(order_id = "A", quantity_units = 1L, due_bucket = 4L)
releases <- data.frame(bucket = 1:20, units = c(1L, rep(0L, 19)))
draws <- data.frame(unit_id = 1L, defect_draw = 0.01, repair_draw = 0.20)
costs <- list(base_labor_usd = 2400, floater_usd_per_hour = 25,
              overtime_usd_per_hour = 450, rework_usd_per_unit = 5,
              scrap_usd_per_unit = 30, late_usd_per_order = 100,
              end_wip_usd_per_unit = 1)
x <- simulate_day(orders, releases, base, draws, "continue", costs)
stopifnot(x$orders$completed_bucket == 5L, !x$orders$on_time)
stopifnot(x$summary$good_units_shipped == 1L, x$summary$on_time_orders == 0L)
stopifnot(x$summary$reworked_units == 1L, x$summary$scrap_units == 0L)
stopifnot(x$summary$end_wip_units == 0L)
stopifnot(x$summary$total_cost_usd == 2505)
stopifnot(x$bucket_log$tested_fresh[3] == 1L, x$bucket_log$reworked[4] == 1L,
          x$bucket_log$tested_rework[5] == 1L)

# A failed repair is scrap, cannot ship, and still balances the released unit.
draws$repair_draw <- 0.99
y <- simulate_day(orders, releases, base, draws, "continue", costs)
stopifnot(y$summary$scrap_units == 1L, y$summary$good_units_shipped == 0L)
stopifnot(y$summary$end_wip_units == 0L, y$summary$total_cost_usd == 2535)

# Changing an input assumption changes the outcome without changing flow code.
settings <- default_settings()
settings$pre_defect_rate <- 0
z <- simulate_day(orders, releases, base, draws, "continue", costs, settings)
stopifnot(z$orders$completed_bucket == 3L, z$orders$on_time,
          z$summary$reworked_units == 0L)

# Overtime is used only while orders remain open; a late release can require it.
larger_base <- c(processing = 8L, assembly = 7L, test = 6L, rework = 2L)
finished_in_shift <- simulate_day(orders, releases, larger_base, draws,
                                  "reassign_overtime", costs, settings)
stopifnot(finished_in_shift$summary$overtime_hours == 0)
late_release <- data.frame(bucket = 1:20, units = c(rep(0L, 15), 1L, rep(0L, 4)))
late_order <- data.frame(order_id = "B", quantity_units = 1L, due_bucket = 20L)
good_draw <- data.frame(unit_id = 1L, defect_draw = 0.99, repair_draw = 0.20)
needs_overtime <- simulate_day(late_order, late_release, larger_base, good_draw,
                               "reassign_overtime", costs)
stopifnot(needs_overtime$orders$completed_bucket == 18L,
          needs_overtime$summary$overtime_hours == 1)
cat("decision model tests passed\n")
