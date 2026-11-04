source("R/run_analysis.R")

out <- tempfile("decision-output-")
dir.create(out)
result <- run_analysis(out)
stopifnot(nrow(result$comparison) == 3L)
stopifnot(all(c("good_units_shipped", "on_time_orders", "end_wip_units",
                "overtime_hours", "reworked_units", "scrap_units",
                "total_cost_usd") %in% names(result$comparison)))
stopifnot(file.exists(file.path(out, "comparison.csv")),
          file.exists(file.path(out, "comparison.png")),
          file.exists(file.path(out, "decision_memo.md")),
          file.exists(file.path(out, "sensitivity.csv")),
          file.exists(file.path(out, "replication_sensitivity.csv")),
          file.exists(file.path(out, "replication_sensitivity_daily.csv")))
stopifnot(nrow(read.csv(file.path(out, "sensitivity.csv"))) == 3L)
robustness <- read.csv(file.path(out, "replication_sensitivity.csv"))
daily <- read.csv(file.path(out, "replication_sensitivity_daily.csv"))
stopifnot(nrow(robustness) == 9L)
stopifnot(nrow(daily) == 900L)
stopifnot(identical(sort(unique(robustness$post_defect_rate)), c(0.06, 0.12, 0.18)))
stopifnot(all(tapply(robustness$selected_days, robustness$post_defect_rate, sum) == 100L))
stopifnot(robustness$selected_days[robustness$post_defect_rate == 0.06 &
                                    robustness$scenario == "reassign_overtime"] == 82L)
stopifnot(result$recommended == result$comparison$scenario[
  order(-result$comparison$on_time_orders, result$comparison$total_cost_usd)[1]])
stopifnot(isTRUE(all.equal(result$runs$continue$bucket_log[1:8, ],
                           result$runs$flex$bucket_log[1:8, ])))
stopifnot(isTRUE(all.equal(result$runs$continue$bucket_log[1:8, ],
                           result$runs$reassign_overtime$bucket_log[1:8, ])))
for (run in result$runs) {
  stopifnot(sum(result$releases$units) == run$summary$good_units_shipped +
              run$summary$scrap_units + run$summary$end_wip_units +
              run$summary$finished_goods_units)
}

# The three-rate comparison stays fixed when the base case is edited.
other_case <- tempfile("edited-base-")
dir.create(file.path(other_case, "data"), recursive = TRUE)
stopifnot(all(file.copy(list.files("data", full.names = TRUE),
                        file.path(other_case, "data"))))
settings_file <- file.path(other_case, "data", "settings.csv")
edited_settings <- read.csv(settings_file, stringsAsFactors = FALSE)
edited_settings$value[edited_settings$key == "post_defect_rate"] <- 0.15
write.csv(edited_settings, settings_file, row.names = FALSE)
original_dir <- getwd()
setwd(other_case)
invisible(run_analysis(file.path(other_case, "output")))
setwd(original_dir)
other_rates <- read.csv(file.path(other_case, "output", "replication_sensitivity.csv"))
stopifnot(identical(sort(unique(other_rates$post_defect_rate)), c(0.06, 0.12, 0.18)))
cat("analysis tests passed\n")
