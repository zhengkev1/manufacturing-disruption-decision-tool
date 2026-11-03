simulate_baseline <- function(orders, releases, capacities) {
  stopifnot(all(c("order_id", "quantity_units", "due_bucket") %in% names(orders)))
  stopifnot(all(c("bucket", "units") %in% names(releases)))
  stopifnot(identical(names(capacities), c("processing", "assembly", "test")))
  stopifnot(all(orders$quantity_units > 0), all(releases$units >= 0), all(capacities > 0))
  stopifnot(identical(releases$bucket, seq_len(nrow(releases))))

  queue <- c(processing = 0L, assembly = 0L, test = 0L)
  remaining <- as.integer(orders$quantity_units)
  completed <- rep(NA_integer_, nrow(orders))
  allocation_order <- order(orders$due_bucket, orders$order_id)
  shipped <- 0L
  finished_goods <- 0L
  bucket_log <- data.frame(bucket = integer(), released = integer(), processed = integer(), assembled = integer(), tested = integer(), shipped = integer())

  for (bucket in releases$bucket) {
    queue["processing"] <- queue["processing"] + releases$units[bucket]
    out_test <- min(queue["test"], capacities["test"])
    out_assembly <- min(queue["assembly"], capacities["assembly"])
    out_processing <- min(queue["processing"], capacities["processing"])
    queue["processing"] <- queue["processing"] - out_processing
    queue["assembly"] <- queue["assembly"] + out_processing - out_assembly
    queue["test"] <- queue["test"] + out_assembly - out_test

    finished_goods <- finished_goods + out_test
    shipped_this_bucket <- 0L
    for (i in allocation_order) {
      allocated <- min(finished_goods, remaining[i])
      remaining[i] <- remaining[i] - allocated
      finished_goods <- finished_goods - allocated
      shipped_this_bucket <- shipped_this_bucket + allocated
      if (remaining[i] == 0L && is.na(completed[i])) completed[i] <- bucket
    }
    shipped <- shipped + shipped_this_bucket
    bucket_log[nrow(bucket_log) + 1L, ] <- list(bucket, releases$units[bucket], out_processing, out_assembly, out_test, shipped_this_bucket)
  }

  result_orders <- orders
  result_orders$shipped_units <- orders$quantity_units - remaining
  result_orders$completed_bucket <- completed
  result_orders$on_time <- !is.na(completed) & completed <= orders$due_bucket
  list(orders = result_orders, shipped_units = shipped, wip_units = queue,
       finished_goods_units = finished_goods, bucket_log = bucket_log)
}

if (sys.nframe() == 0L) {
  orders <- read.csv("data/orders.csv", stringsAsFactors = FALSE)
  releases <- read.csv("data/releases.csv")
  stations <- read.csv("data/stations.csv", stringsAsFactors = FALSE)
  capacities <- setNames(stations$capacity_units_per_bucket[stations$station != "rework"],
                         stations$station[stations$station != "rework"])
  result <- simulate_baseline(orders, releases[releases$bucket <= 16L, ], capacities)
  print(result$orders, row.names = FALSE)
  cat("Good units shipped:", result$shipped_units, "\n")
  cat("End WIP:", sum(result$wip_units), "units\n")
  cat("Finished goods:", result$finished_goods_units, "units\n")
  stopifnot(sum(releases$units) == result$shipped_units + sum(result$wip_units) + result$finished_goods_units)
}
