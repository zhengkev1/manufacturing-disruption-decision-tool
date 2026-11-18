run_replications <- function(rate, inputs, seeds = 1001:1100) {
  if (!is.numeric(seeds) || length(seeds) < 1L || any(!is.finite(seeds)) ||
      any(seeds < 0 | seeds != floor(seeds)) || anyDuplicated(seeds))
    stop("Seeds must be distinct nonnegative integers")
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) caller_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    if (had_seed) assign(".Random.seed", caller_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
      rm(".Random.seed", envir = .GlobalEnv)
  })
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

run_capacity_sensitivity <- function(capacity_values, rate, inputs,
                                     seeds = 1001:1100) {
  if (!is.numeric(capacity_values) || length(capacity_values) < 1L ||
      any(!is.finite(capacity_values)) ||
      any(capacity_values < max(1, inputs$settings$reassignment_units)) ||
      any(capacity_values != floor(capacity_values)) || anyDuplicated(capacity_values))
    stop("Assembly capacities must be distinct feasible positive whole units")
  results <- lapply(capacity_values, function(capacity) {
    varied <- inputs
    varied$capacities["assembly"] <- capacity
    run_replications(rate, varied, seeds)
  })
  summary <- do.call(rbind, Map(function(capacity, result)
    data.frame(assembly_capacity = capacity, result$summary),
    capacity_values, results))
  daily <- do.call(rbind, Map(function(capacity, result)
    data.frame(assembly_capacity = capacity, result$daily),
    capacity_values, results))
  rownames(summary) <- rownames(daily) <- NULL
  list(rate = rate, capacities = capacity_values, daily = daily, summary = summary)
}
