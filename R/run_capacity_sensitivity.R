source("R/decision_model.R")
source("R/dashboard_data.R")
source("R/replications.R")

inputs <- load_dashboard_inputs()
capacities <- 4:8
result <- run_capacity_sensitivity(capacities, 0.12, inputs, seeds = 1001:1100)
dir.create("output", showWarnings = FALSE)
write.csv(result$summary, "output/capacity_sensitivity.csv", row.names = FALSE)
write.csv(result$daily, "output/capacity_sensitivity_daily.csv", row.names = FALSE)

selected <- matrix(result$summary$selected_days, nrow = length(capacities), byrow = TRUE)
png("output/capacity_sensitivity.png", width = 1100, height = 700, res = 140)
matplot(capacities, selected, type = "b", pch = 16, lty = 1, lwd = 2,
        col = c("#89969d", "#db8b46", "#26758a"), ylim = c(0, 105),
        xlab = "Assembly capacity (units per 30 minutes)",
        ylab = "Days selected out of 100",
        main = "Sensitivity to assembly capacity")
abline(v = inputs$capacities["assembly"], lty = 3, col = "#53676f")
legend("right", c("Continue", "Flex", "Reassign + OT"),
       col = c("#89969d", "#db8b46", "#26758a"), lty = 1, pch = 16, bty = "n")
dev.off()

print(result$summary[, c("assembly_capacity", "scenario", "mean_on_time_orders",
                         "mean_cost_usd", "selected_days")], row.names = FALSE)
