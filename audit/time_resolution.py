"""Independent synthetic queue audit at 30- and 15-minute time steps."""

import csv
import random
from collections import deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = ("continue", "flex", "reassign_overtime")


def rows(name):
    with (ROOT / "data" / name).open(newline="") as handle:
        return list(csv.DictReader(handle))


def key_values(name):
    return {row["key"]: float(row["value"]) for row in rows(name)}


def inputs():
    return {
        "orders": [(r["order_id"], int(r["quantity_units"]), int(r["due_bucket"]))
                   for r in rows("orders.csv")],
        "releases": [int(r["units"]) for r in rows("releases.csv")],
        "capacities": {r["station"]: int(r["capacity_units_per_bucket"])
                       for r in rows("stations.csv")},
        "settings": key_values("settings.csv"),
        "costs": key_values("costs.csv"),
        "draws": [(float(r["defect_draw"]), float(r["repair_draw"]))
                  for r in rows("unit_draws.csv")],
    }


def capacity(base, scenario, step, half_steps, settings):
    half_bucket = (step - 1) // half_steps + 1
    substep = (step - 1) % half_steps
    shift_end = int(settings["shift_end_bucket"]) * half_steps
    if step > shift_end and (scenario != "reassign_overtime" or
                             step > shift_end + 4 * half_steps):
        return {station: 0 for station in base}
    cap = {station: base[station] // half_steps +
           (substep >= half_steps - base[station] % half_steps)
           for station in base}
    if half_bucket >= settings["shock_bucket"]:
        if scenario == "flex" and step <= shift_end:
            # One worker spends the first quarter-hour on test, then rework.
            if half_steps == 1 or substep == 0:
                cap["test"] += int(settings["flex_test_units"])
            if substep == half_steps - 1:
                cap["rework"] += int(settings["flex_rework_units"])
        elif scenario == "reassign_overtime":
            moved = int(settings["reassignment_units"]) // half_steps
            moved += substep >= half_steps - int(settings["reassignment_units"]) % half_steps
            cap["assembly"] -= moved
            cap["test"] += moved
    if min(cap.values()) < 0:
        raise ValueError("Reassignment exceeds assembly capacity in a substep")
    return cap


def simulate(data, scenario, half_steps, draws):
    settings, costs = data["settings"], data["costs"]
    if half_steps not in (1, 2):
        raise ValueError("Only 30- and 15-minute steps are defined")
    queues = {name: deque() for name in ("processing", "assembly", "test", "rework", "retest")}
    finished = deque()
    orders = data["orders"]
    remaining = [quantity for _, quantity, _ in orders]
    completed = [None] * len(orders)
    priority = sorted(range(len(orders)), key=lambda i: (orders[i][2], orders[i][0]))
    released = shipped = scrap = reworked = overtime_steps = 0
    for step in range(1, int(settings["horizon_buckets"]) * half_steps + 1):
        substep = (step - 1) % half_steps
        n_new = data["releases"][(step - 1) // half_steps] if substep == 0 else 0
        queues["processing"].extend(range(released, released + n_new))
        released += n_new
        cap = capacity(data["capacities"], scenario, step, half_steps, settings)
        if step > settings["shift_end_bucket"] * half_steps and scenario == "reassign_overtime":
            if not any(remaining):
                cap = {station: 0 for station in cap}
            elif any(cap.values()):
                overtime_steps += 1

        def take(name, amount):
            return [queues[name].popleft() for _ in range(min(len(queues[name]), amount))]

        processed = take("processing", cap["processing"])
        assembled = take("assembly", cap["assembly"])
        worked = take("rework", cap["rework"])
        retested = take("retest", cap["test"])
        fresh = take("test", cap["test"] - len(retested))
        rate = settings["pre_defect_rate"] if step <= (settings["shock_bucket"] - 1) * half_steps else settings["post_defect_rate"]
        defective = [unit for unit in fresh if draws[unit][0] < rate]
        passed = [unit for unit in fresh if draws[unit][0] >= rate]
        repaired = [unit for unit in worked if draws[unit][1] < settings["repair_success_rate"]]
        scrap += len(worked) - len(repaired)
        reworked += len(worked)
        queues["assembly"].extend(processed)
        queues["test"].extend(assembled)
        queues["rework"].extend(defective)
        queues["retest"].extend(repaired)
        finished.extend(retested + passed)
        for i in priority:
            amount = min(len(finished), remaining[i])
            for _ in range(amount):
                finished.popleft()
            remaining[i] -= amount
            shipped += amount
            if remaining[i] == 0 and completed[i] is None:
                completed[i] = step
        assert released == shipped + scrap + len(finished) + sum(map(len, queues.values()))

    wip = sum(map(len, queues.values()))
    on_time = sum(done is not None and done <= due * half_steps
                  for done, (_, _, due) in zip(completed, orders))
    overtime_hours = overtime_steps / (2 * half_steps)
    floater_hours = ((settings["shift_end_bucket"] - settings["shock_bucket"] + 1) / 2
                     if scenario == "flex" else 0)
    total_cost = (costs["base_labor_usd"] + floater_hours * costs["floater_usd_per_hour"] +
                  overtime_hours * costs["overtime_usd_per_hour"] +
                  reworked * costs["rework_usd_per_unit"] + scrap * costs["scrap_usd_per_unit"] +
                  (len(orders) - on_time) * costs["late_usd_per_order"] +
                  wip * costs["end_wip_usd_per_unit"])
    assert overtime_hours <= 2
    return dict(scenario=scenario, good_units_shipped=shipped, on_time_orders=on_time,
                end_wip_units=wip, finished_goods_units=len(finished),
                overtime_hours=overtime_hours, reworked_units=reworked,
                scrap_units=scrap, total_cost_usd=total_cost)


def compare(data, half_steps, draws):
    results = [simulate(data, scenario, half_steps, draws) for scenario in SCENARIOS]
    selected = min(results, key=lambda row: (-row["on_time_orders"], row["total_cost_usd"]))["scenario"]
    return results, selected


def main():
    data = inputs()
    for scenario in SCENARIOS:
        for bucket in range(1, int(data["settings"]["horizon_buckets"]) + 1):
            coarse = capacity(data["capacities"], scenario, bucket, 1, data["settings"])
            fine_a = capacity(data["capacities"], scenario, 2 * bucket - 1, 2, data["settings"])
            fine_b = capacity(data["capacities"], scenario, 2 * bucket, 2, data["settings"])
            assert all(coarse[station] == fine_a[station] + fine_b[station]
                       for station in coarse), (scenario, bucket)
    original = list(csv.DictReader((ROOT / "output" / "comparison.csv").open(newline="")))
    fixed, selected = compare(data, 1, data["draws"])
    for result, saved in zip(fixed, original):
        for key, value in result.items():
            if key == "scenario":
                assert value == saved[key]
            else:
                assert float(value) == float(saved[key]), (key, value, saved[key])
    print("30-minute fixed day agrees with saved R comparison; selected:", selected)
    print("15-minute fixed day:", compare(data, 2, data["draws"]))
    selections = {1: {s: 0 for s in SCENARIOS}, 2: {s: 0 for s in SCENARIOS}}
    changes = {(old, new): 0 for old in SCENARIOS for new in SCENARIOS}
    for seed in range(1001, 1101):
        rng = random.Random(seed)
        draws = list(zip((rng.random() for _ in data["draws"]),
                         (rng.random() for _ in data["draws"])))
        choices = [compare(data, resolution, draws)[1] for resolution in (1, 2)]
        for resolution, choice in zip((1, 2), choices):
            selections[resolution][choice] += 1
        changes[tuple(choices)] += 1
    print("100 paired synthetic days (Python draws):", selections)
    print("Changed recommendations:", {pair: count for pair, count in changes.items()
                                       if pair[0] != pair[1] and count})


if __name__ == "__main__":
    main()
