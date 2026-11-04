source("R/decision_model.R")
set.seed(20261104)
for (case in seq_len(300L)) {
  horizon <- sample(18:26, 1)
  shift_end <- sample(12:16, 1)
  shock <- sample(seq_len(shift_end), 1)
  release_units <- integer(horizon)
  release_units[seq_len(shift_end)] <- sample(0:5, shift_end, replace = TRUE)
  if (sum(release_units) == 0L) release_units[1] <- 1L
  releases <- data.frame(bucket = seq_len(horizon), units = release_units)
  n <- sum(release_units)
  draws <- data.frame(unit_id = seq_len(n), defect_draw = runif(n), repair_draw = runif(n))
  n_orders <- sample(1:4, 1)
  orders <- data.frame(order_id = paste0("O", seq_len(n_orders)),
                       quantity_units = sample(1:12, n_orders, replace = TRUE),
                       due_bucket = sample(seq_len(horizon), n_orders, replace = TRUE))
  caps <- c(processing = sample(1:8, 1), assembly = sample(1:8, 1),
            test = sample(1:8, 1), rework = sample(1:4, 1))
  settings <- default_settings()
  settings$horizon_buckets <- horizon
  settings$shift_end_bucket <- shift_end
  settings$shock_bucket <- shock
  settings$reassignment_units <- sample(0:min(2, caps["assembly"]), 1)
  settings$flex_test_units <- sample(0:2, 1)
  settings$flex_rework_units <- sample(0:2, 1)
  settings$pre_defect_rate <- runif(1, 0, 0.2)
  settings$post_defect_rate <- runif(1, 0, 0.5)
  settings$repair_success_rate <- runif(1)
  costs <- list(base_labor_usd = 100, floater_usd_per_hour = 10,
                overtime_usd_per_hour = 40, rework_usd_per_unit = 3,
                scrap_usd_per_unit = 12, late_usd_per_order = 100,
                end_wip_usd_per_unit = 1)
  for (scenario in c("continue", "flex", "reassign_overtime")) {
    x <- simulate_day(orders, releases, caps, draws, scenario, costs, settings)
    stopifnot(x$summary$good_units_shipped == sum(x$orders$shipped_units),
              x$summary$good_units_shipped <= sum(orders$quantity_units),
              all(x$orders$shipped_units <= orders$quantity_units),
              identical(x$orders$on_time,
                        !is.na(x$orders$completed_bucket) &
                          x$orders$completed_bucket <= x$orders$due_bucket),
              x$summary$on_time_orders == sum(x$orders$on_time),
              x$summary$overtime_hours <= 2,
              x$summary$total_cost_usd == sum(x$cost_detail),
              sum(releases$units) == x$summary$good_units_shipped +
                x$summary$scrap_units + x$summary$finished_goods_units +
                x$summary$end_wip_units)
  }
}
cat("300 synthetic input cases x 3 responses passed\n")
