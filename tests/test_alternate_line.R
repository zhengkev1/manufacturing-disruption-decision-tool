source("R/run_analysis.R")

alternate <- tempfile("alternate-line-")
dir.create(file.path(alternate, "data"), recursive = TRUE)
stopifnot(all(file.copy(list.files("data", full.names = TRUE),
                        file.path(alternate, "data"))))
write.csv(data.frame(order_id = "O1", quantity_units = 10L, due_bucket = 16L),
          file.path(alternate, "data", "orders.csv"), row.names = FALSE)
releases <- data.frame(bucket = 1:20, units = c(rep(1L, 12), rep(0L, 8)))
write.csv(releases, file.path(alternate, "data", "releases.csv"), row.names = FALSE)
stations <- read.csv(file.path(alternate, "data", "stations.csv"))
stations$capacity_units_per_bucket <- c(processing = 2L, assembly = 2L,
                                        test = 2L, rework = 1L)[stations$station]
write.csv(stations, file.path(alternate, "data", "stations.csv"), row.names = FALSE)
write.csv(data.frame(unit_id = 1:12, defect_draw = rep(0.99, 12),
                     repair_draw = rep(0.5, 12)),
          file.path(alternate, "data", "unit_draws.csv"), row.names = FALSE)
settings_file <- file.path(alternate, "data", "settings.csv")
settings <- read.csv(settings_file)
settings$value[settings$key == "reassignment_units"] <- 0
write.csv(settings, settings_file, row.names = FALSE)

original_dir <- getwd()
setwd(alternate)
result <- run_analysis(file.path(alternate, "output"))
setwd(original_dir)
stopifnot(all(result$comparison$good_units_shipped == 10L),
          all(result$comparison$end_wip_units == 0L),
          file.exists(file.path(alternate, "output", "comparison.png")),
          file.exists(file.path(alternate, "output", "decision_memo.md")))
cat("alternate line tests passed\n")
