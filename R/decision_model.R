default_settings <- function() {
  list(shock_bucket = 9L, shift_end_bucket = 16L, horizon_buckets = 20L,
       pre_defect_rate = 0.02, post_defect_rate = 0.12,
       repair_success_rate = 0.75, flex_test_units = 1L,
       flex_rework_units = 1L, reassignment_units = 2L)
}

capacity_schedule <- function(base, scenario, bucket, settings = default_settings()) {
  stopifnot(identical(names(base), c("processing", "assembly", "test", "rework")))
  stopifnot(scenario %in% c("continue", "flex", "reassign_overtime"),
            bucket >= 1L, bucket <= settings$horizon_buckets)
  if (bucket > settings$shift_end_bucket && scenario != "reassign_overtime") return(setNames(rep(0L, 4), names(base)))
  cap <- base
  if (bucket >= settings$shock_bucket && bucket <= settings$shift_end_bucket && scenario == "flex") {
    # One floater spends half of each bucket on test and half on rework.
    cap["test"] <- cap["test"] + settings$flex_test_units
    cap["rework"] <- cap["rework"] + settings$flex_rework_units
  }
  if (bucket >= settings$shock_bucket && scenario == "reassign_overtime") {
    stopifnot(cap["assembly"] >= settings$reassignment_units)
    cap["assembly"] <- cap["assembly"] - settings$reassignment_units
    cap["test"] <- cap["test"] + settings$reassignment_units
  }
  cap
}

take_front <- function(queue, n) {
  list(taken = queue[seq_len(n)], left = if (n < length(queue)) queue[(n + 1L):length(queue)] else integer())
}

simulate_day <- function(orders, releases, capacities, draws, scenario, costs,
                         settings = default_settings()) {
  required_costs <- c("base_labor_usd", "floater_usd_per_hour",
                      "overtime_usd_per_hour", "rework_usd_per_unit",
                      "scrap_usd_per_unit", "late_usd_per_order",
                      "end_wip_usd_per_unit")
  valid_rate <- function(x) is.numeric(x) && length(x) == 1L &&
    is.finite(x) && x >= 0
  if (!setequal(names(costs), required_costs) ||
      !all(vapply(costs, valid_rate, logical(1))))
    stop("Cost inputs must contain every required finite nonnegative USD rate")
  if (!setequal(names(settings), names(default_settings())) ||
      !all(vapply(settings, valid_rate, logical(1))))
    stop("Settings must contain every required finite nonnegative value")
  whole_units <- function(x) is.numeric(x) && all(is.finite(x)) &&
    all(x >= 0) && all(x == floor(x))
  count_settings <- c("shock_bucket", "shift_end_bucket", "horizon_buckets",
                      "flex_test_units", "flex_rework_units", "reassignment_units")
  if (!all(vapply(settings[count_settings], whole_units, logical(1))) ||
      !whole_units(orders$quantity_units) || !whole_units(orders$due_bucket) ||
      !whole_units(releases$bucket) || !whole_units(releases$units) ||
      !whole_units(capacities))
    stop("Buckets, capacities, releases, and order quantities must be whole units")
  stopifnot(identical(releases$bucket, seq_len(settings$horizon_buckets)),
            all(releases$units >= 0L),
            all(orders$quantity_units > 0L), all(orders$due_bucket >= 1L),
            all(orders$due_bucket <= settings$horizon_buckets), !anyDuplicated(orders$order_id),
            sum(releases$units) == nrow(draws), identical(draws$unit_id, seq_len(nrow(draws))),
            all(draws$defect_draw >= 0 & draws$defect_draw < 1),
            all(draws$repair_draw >= 0 & draws$repair_draw < 1),
            all(capacities > 0),
            settings$shock_bucket >= 1L, settings$shock_bucket <= settings$shift_end_bucket,
            settings$shift_end_bucket < settings$horizon_buckets,
            all(unlist(settings[c("pre_defect_rate", "post_defect_rate", "repair_success_rate")]) >= 0),
            all(unlist(settings[c("pre_defect_rate", "post_defect_rate", "repair_success_rate")]) <= 1))
  queue <- list(processing = integer(), assembly = integer(), test = integer(),
                rework = integer(), retest = integer())
  finished_goods <- integer()
  remaining <- as.integer(orders$quantity_units)
  completed <- rep(NA_integer_, nrow(orders))
  order_priority <- order(orders$due_bucket, orders$order_id)
  shipped <- 0L
  scrap <- 0L
  reworked <- 0L
  released <- 0L
  overtime_buckets <- 0L
  log <- vector("list", settings$horizon_buckets)

  for (bucket in seq_len(settings$horizon_buckets)) {
    n_new <- releases$units[bucket]
    if (n_new > 0L) queue$processing <- c(queue$processing, released + seq_len(n_new))
    released <- released + n_new
    cap <- capacity_schedule(capacities, scenario, bucket, settings)
    if (bucket > settings$shift_end_bucket && scenario == "reassign_overtime") {
      if (all(remaining == 0L)) cap[] <- 0L
      else overtime_buckets <- overtime_buckets + 1L
    }

    processing <- take_front(queue$processing, min(length(queue$processing), cap["processing"]))
    assembly <- take_front(queue$assembly, min(length(queue$assembly), cap["assembly"]))
    rework <- take_front(queue$rework, min(length(queue$rework), cap["rework"]))
    retest <- take_front(queue$retest, min(length(queue$retest), cap["test"]))
    fresh <- take_front(queue$test, min(length(queue$test), cap["test"] - length(retest$taken)))

    defect_probability <- if (bucket < settings$shock_bucket) settings$pre_defect_rate else settings$post_defect_rate
    defective <- fresh$taken[draws$defect_draw[fresh$taken] < defect_probability]
    passed <- fresh$taken[draws$defect_draw[fresh$taken] >= defect_probability]
    repaired <- rework$taken[draws$repair_draw[rework$taken] < settings$repair_success_rate]
    scrapped <- rework$taken[draws$repair_draw[rework$taken] >= settings$repair_success_rate]

    queue$processing <- processing$left
    queue$assembly <- c(assembly$left, processing$taken)
    queue$test <- c(fresh$left, assembly$taken)
    queue$rework <- c(rework$left, defective)
    queue$retest <- c(retest$left, repaired)
    finished_goods <- c(finished_goods, retest$taken, passed)
    scrap <- scrap + length(scrapped)
    reworked <- reworked + length(rework$taken)

    shipped_now <- 0L
    for (i in order_priority) {
      n <- min(length(finished_goods), remaining[i])
      if (n > 0L) {
        finished_goods <- take_front(finished_goods, n)$left
        remaining[i] <- remaining[i] - n
        shipped_now <- shipped_now + n
      }
      if (remaining[i] == 0L && is.na(completed[i])) completed[i] <- bucket
    }
    shipped <- shipped + shipped_now
    stopifnot(released == shipped + scrap + length(finished_goods) +
                sum(lengths(queue)))
    log[[bucket]] <- data.frame(bucket = bucket, released = n_new,
      processing_capacity = cap["processing"], assembly_capacity = cap["assembly"],
      test_capacity = cap["test"], rework_capacity = cap["rework"],
      processed = length(processing$taken), assembled = length(assembly$taken),
      tested_fresh = length(fresh$taken), tested_rework = length(retest$taken),
      reworked = length(rework$taken), scrap = length(scrapped),
      shipped = shipped_now, wip = sum(lengths(queue)))
  }

  order_result <- orders
  order_result$shipped_units <- orders$quantity_units - remaining
  order_result$completed_bucket <- completed
  order_result$on_time <- !is.na(completed) & completed <= orders$due_bucket
  end_wip <- sum(lengths(queue))
  overtime_hours <- overtime_buckets / 2
  cost_detail <- c(base_labor = costs$base_labor_usd,
                   floater = if (scenario == "flex")
                     (settings$shift_end_bucket - settings$shock_bucket + 1) / 2 * costs$floater_usd_per_hour else 0,
                   overtime = overtime_hours * costs$overtime_usd_per_hour,
                   rework = reworked * costs$rework_usd_per_unit,
                   scrap = scrap * costs$scrap_usd_per_unit,
                   late_orders = sum(!order_result$on_time) * costs$late_usd_per_order,
                   end_wip = end_wip * costs$end_wip_usd_per_unit)
  summary <- data.frame(scenario = scenario, good_units_shipped = shipped,
    on_time_orders = sum(order_result$on_time), end_wip_units = end_wip,
    finished_goods_units = length(finished_goods), overtime_hours = overtime_hours,
    reworked_units = reworked, scrap_units = scrap,
    total_cost_usd = sum(cost_detail))
  list(orders = order_result, summary = summary, cost_detail = cost_detail,
       bucket_log = do.call(rbind, log), final_queues = queue)
}
