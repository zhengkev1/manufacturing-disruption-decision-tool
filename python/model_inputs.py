"""Input contract for the synthetic event model. Clock fields use seconds."""
import csv
import math
from dataclasses import dataclass
from pathlib import Path

STATIONS = ("processing", "assembly", "test", "rework")
COST_KEYS = {"base_labor_usd", "floater_usd_per_hour", "overtime_usd_per_hour",
             "rework_usd_per_unit", "scrap_usd_per_unit", "late_usd_per_order",
             "end_wip_usd_per_unit"}


@dataclass(frozen=True)
class ModelInputs:
    orders: tuple
    releases: tuple
    workers: tuple
    draws: tuple
    costs: dict
    shock: int
    shift: int
    horizon: int
    pre: float
    post: float
    repair: float
    transfer: int
    flex_seconds: int
    moved_seconds: int


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load_inputs(data_dir=Path("data"), event_settings_path=None):
    base = Path(data_dir)

    def read(name):
        with (base / name).open(newline="") as handle:
            return list(csv.DictReader(handle))

    def mapping(name, key, field, cast):
        rows = read(name)
        result = {r[key]: cast(r[field]) for r in rows}
        require(len(rows) == len(result), f"duplicate key in {name}")
        return result

    caps = mapping("stations.csv", "station", "capacity_units_per_bucket", int)
    require(set(caps) == set(STATIONS), "station names")
    conf = mapping("settings.csv", "key", "value", float)
    costs = mapping("costs.csv", "key", "value", float)
    require(set(costs) == COST_KEYS and all(math.isfinite(v) and v >= 0 for v in costs.values()), "cost rates")
    for key in ("shock_bucket", "shift_end_bucket", "horizon_buckets"):
        require(conf[key].is_integer(), key)
    shock, shift, horizon = (int(conf[k]) for k in ("shock_bucket","shift_end_bucket","horizon_buckets"))
    require(1 <= shock <= shift < horizon, "clock boundaries")
    rates = [conf[k] for k in ("pre_defect_rate","post_defect_rate","repair_success_rate")]
    require(all(0 <= p <= 1 for p in rates), "probabilities")
    orders = tuple((r["order_id"], int(r["quantity_units"]), int(r["due_bucket"]) * 1800)
                   for r in read("orders.csv"))
    require(orders and len({o[0] for o in orders}) == len(orders) and all(i and q > 0 and 0 < d <= horizon*1800 for i,q,d in orders), "orders")
    rows = read("releases.csv")
    require([int(r["bucket"]) for r in rows] == list(range(1,horizon+1)), "release calendar")
    releases = tuple((i*1800,int(r["units"])) for i,r in enumerate(rows))
    require(all(q >= 0 for _,q in releases), "release quantities")
    rows = read("unit_draws.csv")
    require([int(r["unit_id"]) for r in rows] == list(range(1,sum(q for _,q in releases)+1)), "draw IDs")
    draws = tuple((float(r["defect_draw"]),float(r["repair_draw"])) for r in rows)
    require(all(0 <= v < 1 for pair in draws for v in pair), "invalid draw")
    with Path(event_settings_path or base/"event_settings.csv").open(newline="") as handle:
        workers = tuple((r["worker"],r["station"],int(r["service_seconds"])) for r in csv.DictReader(handle))
    require(len({w for w,_,_ in workers}) == len(workers) and all(w and w != "floater" and s in STATIONS and t > 0 for w,s,t in workers), "worker roster")
    require(any(w == "movable" and s == "assembly" for w,s,_ in workers), "qualified movable worker")
    for s in STATIONS:
        require(caps[s] > 0 and math.isclose(sum(1800/t for _,station,t in workers if station == s), caps[s]), f"capacity mismatch at {s}")
    moved = next(t for w,_,t in workers if w == "movable")
    require(math.isclose(1800/moved, conf["reassignment_units"]), "reassignment capacity")
    require(conf["flex_test_units"] == conf["flex_rework_units"] == 1, "starter floater calendar supports one slot per half")
    return ModelInputs(orders,releases,workers,draws,costs,(shock-1)*1800,shift*1800,horizon*1800,*rates,60,900,moved)
