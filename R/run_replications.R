source("R/decision_model.R")
source("R/dashboard_data.R")
source("R/replications.R")

result <- run_replications(0.12, load_dashboard_inputs(), seeds = 1001:1100)
dir.create("output", showWarnings = FALSE)
write.csv(result$daily, "output/replication_daily.csv", row.names = FALSE)
write.csv(result$summary, "output/replication_summary.csv", row.names = FALSE)
print(result$summary, row.names = FALSE)
