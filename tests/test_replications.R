source("R/decision_model.R")
source("R/dashboard_data.R")
source("R/replications.R")

inputs <- load_dashboard_inputs()
set.seed(42)
caller_seed <- .Random.seed
invisible(run_replications(0.12, inputs, seeds = 501:503))
stopifnot(identical(.Random.seed, caller_seed))
failed_run <- tryCatch(run_replications(-0.1, inputs, seeds = 501),
                       error = function(e) e)
stopifnot(inherits(failed_run, "error"), identical(.Random.seed, caller_seed))
rm(".Random.seed", envir = .GlobalEnv)
invisible(run_replications(0.12, inputs, seeds = 501))
stopifnot(!exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
a <- run_replications(0.12, inputs, seeds = 501:503)
b <- run_replications(0.12, inputs, seeds = 501:503)
stopifnot(identical(a, b))
stopifnot(nrow(a$daily) == 9L, nrow(a$summary) == 3L)
stopifnot(sum(a$summary$selected_days) == 3L)
stopifnot(all(a$summary$synthetic_days == 3L))
stopifnot(all(a$daily$on_time_orders >= 0 & a$daily$on_time_orders <= 3L))
stopifnot(a$summary$mean_cost_usd[1] ==
          mean(a$daily$total_cost_usd[a$daily$scenario == "continue"]))

# Rebuild one synthetic day independently from its documented seed.
set.seed(501)
inputs$draws$defect_draw <- runif(nrow(inputs$draws))
inputs$draws$repair_draw <- runif(nrow(inputs$draws))
one_day <- compare_at_defect_rate(0.12, inputs)
stopifnot(isTRUE(all.equal(a$daily$good_units_shipped[1:3],
                           one_day$comparison$good_units_shipped)))
stopifnot(identical(a$daily$selected[1:3], one_day$comparison$recommended))

capacity_check <- run_capacity_sensitivity(c(6, 7), 0.12, load_dashboard_inputs(),
                                           seeds = 501:503)
stopifnot(nrow(capacity_check$summary) == 6L,
          nrow(capacity_check$daily) == 18L,
          all(tapply(capacity_check$summary$selected_days,
                     capacity_check$summary$assembly_capacity, sum) == 3L))
at_seven <- capacity_check$summary[capacity_check$summary$assembly_capacity == 7, ]
at_six <- capacity_check$summary[capacity_check$summary$assembly_capacity == 6, ]
stopifnot(identical(at_seven$selected_days, a$summary$selected_days),
          isTRUE(all.equal(at_seven$mean_cost_usd, a$summary$mean_cost_usd)),
          identical(at_six$selected_days, c(1L, 2L, 0L)),
          identical(at_seven$selected_days, c(1L, 0L, 2L)))
bad_capacity <- tryCatch(run_capacity_sensitivity(c(0, 7), 0.12,
                                                   load_dashboard_inputs(), seeds = 501),
                         error = function(e) e)
stopifnot(inherits(bad_capacity, "error"))
cat("replication tests passed\n")
