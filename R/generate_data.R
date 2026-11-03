# Every value below is a project assumption, not an observed factory record.
dir.create("data", showWarnings = FALSE)
write.csv(data.frame(order_id = c("O1", "O2", "O3"),
                     quantity_units = c(35L, 30L, 15L),
                     due_bucket = c(12L, 16L, 20L)),
          "data/orders.csv", row.names = FALSE)
releases <- data.frame(bucket = 1:20, units = c(rep(8L, 16), rep(0L, 4)))
write.csv(releases, "data/releases.csv", row.names = FALSE)
write.csv(data.frame(station = c("processing", "assembly", "test", "rework"),
                     capacity_units_per_bucket = c(8L, 7L, 6L, 2L)),
          "data/stations.csv", row.names = FALSE)
write.csv(data.frame(key = c("shock_bucket", "shift_end_bucket", "horizon_buckets",
                             "pre_defect_rate", "post_defect_rate", "repair_success_rate",
                             "flex_test_units", "flex_rework_units", "reassignment_units"),
                     value = c(9, 16, 20, 0.02, 0.12, 0.75, 1, 1, 2)),
          "data/settings.csv", row.names = FALSE)
write.csv(data.frame(key = c("base_labor_usd", "floater_usd_per_hour",
                             "overtime_usd_per_hour", "rework_usd_per_unit",
                             "scrap_usd_per_unit", "late_usd_per_order",
                             "end_wip_usd_per_unit"),
                     value = c(2400, 25, 450, 5, 30, 100, 1)),
          "data/costs.csv", row.names = FALSE)
set.seed(20261103)
n_units <- sum(releases$units)
write.csv(data.frame(unit_id = seq_len(n_units), defect_draw = runif(n_units),
                     repair_draw = runif(n_units)),
          "data/unit_draws.csv", row.names = FALSE)
