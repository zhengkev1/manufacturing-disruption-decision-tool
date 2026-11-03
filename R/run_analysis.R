source("R/decision_model.R")

run_analysis <- function(out_dir = "output") {
  orders <- read.csv("data/orders.csv", stringsAsFactors = FALSE)
  releases <- read.csv("data/releases.csv")
  stations <- read.csv("data/stations.csv", stringsAsFactors = FALSE)
  draws <- read.csv("data/unit_draws.csv")
  settings_data <- read.csv("data/settings.csv", stringsAsFactors = FALSE)
  costs_data <- read.csv("data/costs.csv", stringsAsFactors = FALSE)
  capacities <- setNames(stations$capacity_units_per_bucket, stations$station)
  settings <- as.list(setNames(settings_data$value, settings_data$key))
  count_settings <- c("shock_bucket", "shift_end_bucket", "horizon_buckets",
                      "flex_test_units", "flex_rework_units", "reassignment_units")
  settings[count_settings] <- lapply(settings[count_settings], as.integer)
  costs <- as.list(setNames(costs_data$value, costs_data$key))

  scenarios <- c("continue", "flex", "reassign_overtime")
  runs <- setNames(lapply(scenarios, function(s)
    simulate_day(orders, releases, capacities, draws, s, costs, settings)), scenarios)
  comparison <- do.call(rbind, lapply(runs, function(x) x$summary))
  rownames(comparison) <- NULL
  recommended <- comparison$scenario[order(-comparison$on_time_orders,
                                             comparison$total_cost_usd)[1]]
  comparison$recommended <- comparison$scenario == recommended

  sensitivity <- do.call(rbind, lapply(c(0.06, settings$post_defect_rate, 0.18), function(rate) {
    varied <- settings
    varied$post_defect_rate <- rate
    candidate <- do.call(rbind, lapply(scenarios, function(s)
      simulate_day(orders, releases, capacities, draws, s, costs, varied)$summary))
    data.frame(post_defect_rate = rate,
      recommended = candidate$scenario[order(-candidate$on_time_orders,
                                              candidate$total_cost_usd)[1]],
      continue_on_time = candidate$on_time_orders[1],
      flex_on_time = candidate$on_time_orders[2],
      reassign_on_time = candidate$on_time_orders[3])
  }))

  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  write.csv(comparison, file.path(out_dir, "comparison.csv"), row.names = FALSE)
  write.csv(sensitivity, file.path(out_dir, "sensitivity.csv"), row.names = FALSE)
  write.csv(do.call(rbind, lapply(scenarios, function(s) {
    data.frame(scenario = s, cost_component = names(runs[[s]]$cost_detail),
               cost_usd = unname(runs[[s]]$cost_detail))
  })), file.path(out_dir, "cost_breakdown.csv"), row.names = FALSE)
  write.csv(do.call(rbind, lapply(scenarios, function(s)
    data.frame(scenario = s, runs[[s]]$orders))),
    file.path(out_dir, "order_results.csv"), row.names = FALSE)
  write.csv(do.call(rbind, lapply(scenarios, function(s)
    data.frame(scenario = s, runs[[s]]$bucket_log))),
    file.path(out_dir, "bucket_log.csv"), row.names = FALSE)

  labels <- c("Continue", "Flex worker", "Reassign + OT")
  colors <- ifelse(comparison$recommended, "#276C87", "#9DA8AD")
  png(file.path(out_dir, "comparison.png"), width = 1200, height = 850, res = 140)
  old_par <- par(mfrow = c(2, 2), mar = c(6, 5, 4, 1), oma = c(0, 0, 2, 0))
  on.exit({par(old_par); dev.off()}, add = TRUE)
  plot_metric <- function(values, title, ylab) {
    barplot(values, names.arg = labels, col = colors, border = NA,
            las = 2, main = title, ylab = ylab, ylim = c(0, max(values) * 1.18))
  }
  plot_metric(comparison$on_time_orders, "Orders delivered on time", "orders")
  plot_metric(comparison$good_units_shipped, "Good units shipped", "units")
  plot_metric(comparison$end_wip_units, "End work in process", "units")
  plot_metric(comparison$total_cost_usd, "Estimated total cost", "synthetic USD")
  mtext("One synthetic day; blue is the rule-based recommendation", outer = TRUE)

  winner <- comparison[comparison$recommended, ]
  memo <- c(
    "# Decision memo — synthetic manufacturing disruption",
    "",
    "**Scope:** An illustrative three-stage line with a detected defect-rate increase at hour 4. All inputs and costs are synthetic; this is not an employer case study or a validated factory forecast.",
    "",
    sprintf("**Recommendation:** %s under the stated priority: maximize fully delivered on-time orders, then minimize estimated cost. This choice is feasible under the modeled staffing and two-hour overtime limit.", recommended),
    "",
    sprintf("The recommended case delivers %d of %d orders on time, ships %d good units by hour 10, leaves %d units of unfinished WIP, uses %.1f overtime hours, reworks %d units, scraps %d units, and has estimated total cost $%.0f.",
            winner$on_time_orders, nrow(orders), winner$good_units_shipped,
            winner$end_wip_units, winner$overtime_hours, winner$reworked_units,
            winner$scrap_units, winner$total_cost_usd),
    "",
    "## Comparison",
    "",
    "| Response | On-time orders | Good units shipped | End WIP | Overtime hours | Reworked | Scrap | Cost (synthetic USD) |",
    "|---|---:|---:|---:|---:|---:|---:|---:|",
    sprintf("| %s | %d | %d | %d | %.1f | %d | %d | %.0f |",
            comparison$scenario, comparison$on_time_orders,
            comparison$good_units_shipped, comparison$end_wip_units,
            comparison$overtime_hours, comparison$reworked_units,
            comparison$scrap_units, comparison$total_cost_usd),
    "",
    "## Defect-rate sensitivity",
    "",
    "The same synthetic unit draws were reused while changing only the post-shock defect probability. This is a small scenario check, not a confidence interval.",
    "",
    "| Post-shock defect rate | Continue on time | Flex on time | Reassign on time | Recommended |",
    "|---:|---:|---:|---:|---|",
    sprintf("| %.0f%% | %d | %d | %d | %s |", 100 * sensitivity$post_defect_rate,
            sensitivity$continue_on_time, sensitivity$flex_on_time,
            sensitivity$reassign_on_time, sensitivity$recommended),
    "",
    "## Decision limits",
    "",
    "The result is one fixed-seed synthetic day. It is sensitive to assumed capacities, defect/repair outcomes, order deadlines, and cost rates. The late-order charge is a comparison proxy, not a contract penalty. Recalibrate and validate against real operations before operational use."
  )
  writeLines(memo, file.path(out_dir, "decision_memo.md"))
  list(comparison = comparison, recommended = recommended, runs = runs,
       releases = releases)
}

if (sys.nframe() == 0L) {
  result <- run_analysis()
  print(result$comparison, row.names = FALSE)
  cat("Recommended:", result$recommended, "\n")
}
