source("R/baseline.R")

# Hand check: two units released in each of buckets 1-3; one unit leaves test
# in buckets 3-5. Three ship and three remain in the line after bucket 5.
orders <- data.frame(order_id = c("late", "early"), quantity_units = c(1L, 2L), due_bucket = c(3L, 4L))
releases <- data.frame(bucket = 1:5, units = c(2L, 2L, 2L, 0L, 0L))
result <- simulate_baseline(orders, releases, c(processing = 2L, assembly = 2L, test = 1L))
reordered <- simulate_baseline(orders, releases, c(test = 1L, processing = 2L, assembly = 2L))
stopifnot(identical(result, reordered))
stopifnot(result$shipped_units == 3L)
stopifnot(sum(result$wip_units) == 3L)
stopifnot(result$orders$completed_bucket[result$orders$order_id == "late"] == 3L)
stopifnot(result$orders$completed_bucket[result$orders$order_id == "early"] == 5L)
stopifnot(result$orders$on_time[result$orders$order_id == "late"])
stopifnot(!result$orders$on_time[result$orders$order_id == "early"])
stopifnot(sum(releases$units) == result$shipped_units + sum(result$wip_units))
cat("baseline tests passed\n")
