run_replications <- function(rate, inputs, seeds = 1001:1100) {
  if (!is.numeric(seeds) || length(seeds) < 1L || any(!is.finite(seeds)) ||
      any(seeds < 0 | seeds != floor(seeds)) || anyDuplicated(seeds))
    stop("Seeds must be distinct nonnegative integers")
  days <- lapply(seq_along(seeds), function(day) {
    set.seed(seeds[day])
    varied <- inputs
    varied$draws$defect_draw <- runif(nrow(inputs$draws))
    varied$draws$repair_draw <- runif(nrow(inputs$draws))
    comparison <- compare_at_defect_rate(rate, varied)$comparison
    data.frame(day = day, seed = seeds[day], comparison,
               selected = comparison$recommended)
  })
  daily <- do.call(rbind, days)
  rownames(daily) <- NULL
  scenarios <- c("continue", "flex", "reassign_overtime")
  summary <- do.call(rbind, lapply(scenarios, function(s) {
    x <- daily[daily$scenario == s, ]
    data.frame(scenario = s, synthetic_days = nrow(x),
      mean_on_time_orders = mean(x$on_time_orders),
      mean_good_units_shipped = mean(x$good_units_shipped),
      mean_cost_usd = mean(x$total_cost_usd),
      cost_p10_usd = unname(quantile(x$total_cost_usd, 0.10)),
      cost_p90_usd = unname(quantile(x$total_cost_usd, 0.90)),
      selected_days = sum(x$selected))
  }))
  rownames(summary) <- NULL
  list(rate = rate, seeds = seeds, daily = daily, summary = summary)
}
