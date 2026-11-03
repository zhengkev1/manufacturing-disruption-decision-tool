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
          file.exists(file.path(out, "sensitivity.csv")))
stopifnot(nrow(read.csv(file.path(out, "sensitivity.csv"))) == 3L)
stopifnot(result$recommended == result$comparison$scenario[
  order(-result$comparison$on_time_orders, result$comparison$total_cost_usd)[1]])
stopifnot(identical(result$runs$continue$bucket_log[1:8, ],
                    result$runs$flex$bucket_log[1:8, ]))
stopifnot(identical(result$runs$continue$bucket_log[1:8, ],
                    result$runs$reassign_overtime$bucket_log[1:8, ]))
for (run in result$runs) {
  stopifnot(sum(result$releases$units) == run$summary$good_units_shipped +
              run$summary$scrap_units + run$summary$end_wip_units +
              run$summary$finished_goods_units)
}
cat("analysis tests passed\n")
