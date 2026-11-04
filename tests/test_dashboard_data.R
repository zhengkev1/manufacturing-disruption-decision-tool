source("R/decision_model.R")
source("R/dashboard_data.R")

inputs <- load_dashboard_inputs()
original_settings <- inputs$settings
at_12 <- compare_at_defect_rate(0.12, inputs)
saved <- read.csv("output/comparison.csv", stringsAsFactors = FALSE)
fields <- c("scenario", "good_units_shipped", "on_time_orders", "end_wip_units",
            "overtime_hours", "reworked_units", "scrap_units", "total_cost_usd")
stopifnot(isTRUE(all.equal(at_12$comparison[fields], saved[fields])))
stopifnot(at_12$recommended == "reassign_overtime")
at_6 <- compare_at_defect_rate(0.06, inputs)
stopifnot(at_6$recommended == "continue")
stopifnot(identical(inputs$settings, original_settings))
cat("dashboard data tests passed\n")
