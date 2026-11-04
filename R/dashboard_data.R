load_dashboard_inputs <- function(data_dir = "data") {
  orders <- read.csv(file.path(data_dir, "orders.csv"), stringsAsFactors = FALSE)
  releases <- read.csv(file.path(data_dir, "releases.csv"))
  stations <- read.csv(file.path(data_dir, "stations.csv"), stringsAsFactors = FALSE)
  draws <- read.csv(file.path(data_dir, "unit_draws.csv"))
  settings_data <- read.csv(file.path(data_dir, "settings.csv"), stringsAsFactors = FALSE)
  costs_data <- read.csv(file.path(data_dir, "costs.csv"), stringsAsFactors = FALSE)
  list(orders = orders, releases = releases, draws = draws,
       capacities = setNames(stations$capacity_units_per_bucket, stations$station),
       settings = as.list(setNames(settings_data$value, settings_data$key)),
       costs = as.list(setNames(costs_data$value, costs_data$key)))
}

compare_at_defect_rate <- function(rate, inputs) {
  if (!is.numeric(rate) || length(rate) != 1L || !is.finite(rate) ||
      rate < 0 || rate > 1) stop("Post-shock defect rate must be between 0 and 1")
  settings <- inputs$settings
  settings$post_defect_rate <- rate
  scenarios <- c("continue", "flex", "reassign_overtime")
  runs <- setNames(lapply(scenarios, function(s)
    simulate_day(inputs$orders, inputs$releases, inputs$capacities,
                 inputs$draws, s, inputs$costs, settings)), scenarios)
  comparison <- do.call(rbind, lapply(runs, function(x) x$summary))
  rownames(comparison) <- NULL
  recommended <- comparison$scenario[order(-comparison$on_time_orders,
                                             comparison$total_cost_usd)[1]]
  comparison$recommended <- comparison$scenario == recommended
  list(comparison = comparison, recommended = recommended, runs = runs)
}
