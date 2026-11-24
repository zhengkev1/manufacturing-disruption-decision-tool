"""Run from repository root: python3 -m python.event_sim"""
from collections import deque, Counter
from dataclasses import dataclass
from heapq import heappop, heappush
from itertools import count
from .model_inputs import load_inputs, STATIONS

POLICIES = ("continue", "flex", "reassign_overtime")


@dataclass
class DayResult:
    orders: dict
    states: dict
    log: list
    metrics: dict
    costs: dict


def simulate_day(inputs, policy, draws=None):
    if policy not in POLICIES:
        raise ValueError("unknown policy")
    draws = inputs.draws if draws is None else draws
    if len(draws) != sum(q for _, q in inputs.releases) or any(len(pair)!=2 or any(not 0<=v<1 for v in pair) for pair in draws):
        raise ValueError("invalid day draws")
    queue = {s: deque() for s in (*STATIONS, "retest")}
    events, trace, state, busy = [], [], {}, {}
    sequence = count()
    orders = sorted(inputs.orders, key=lambda o: (o[2], o[0]))
    remaining = {i:q for i,q,_ in orders}
    completion = dict.fromkeys(remaining)
    workers = list(inputs.workers)
    if policy == "flex":
        workers.append(("floater", "test", inputs.flex_seconds))
    def schedule(t, priority, kind, payload=None):
        heappush(events,(t,priority,next(sequence),kind,payload))
    def record(t,u,action,operation,worker=""):
        trace.append((t,u,action,operation,worker))
    uid = 0
    for t,qty in inputs.releases:
        for _ in range(qty):
            uid += 1
            schedule(t,1,"release",uid)
    limit = min(inputs.horizon, inputs.shift + (7200 if policy=="reassign_overtime" else 0))
    for t in {inputs.shock,inputs.shift,limit,*range(inputs.shock,inputs.shift,900)}:
        schedule(t,2,"clock")
    worked = 0
    stopped = limit
    while events:
        t = events[0][0]
        if t > limit:
            break
        while events and events[0][0] == t:
            _,_,_,kind,p = heappop(events)
            if kind == "clock":
                continue
            if kind in ("release","ready"):
                u,op = (p,"processing") if kind=="release" else p
                state[u] = ("waiting",op)
                queue[op].append(u)
                record(t,u,kind,op)
                continue
            w,u,op,start = p
            assert busy.pop(w) == u and state[u] == ("active",op)
            record(t,u,"finish",op,w)
            if op == "processing":
                dest = "assembly"
            elif op == "assembly":
                dest = "test"
            elif op == "rework":
                worked += 1
                dest = "retest" if draws[u-1][1] < inputs.repair else "scrap"
            elif op == "test" and draws[u-1][0] < (inputs.pre if start < inputs.shock else inputs.post):
                dest = "rework"
            else:
                dest = "good"
            if dest == "good":
                order = next((i for i,_,_ in orders if remaining[i]),None)
                state[u] = ("shipped",order) if order else ("stock",None)
                if order:
                    remaining[order] -= 1
                    record(t,u,"ship",order)
                    if remaining[order] == 0:
                        completion[order] = t
            elif dest == "scrap":
                state[u] = ("scrap",None)
            else:
                state[u] = ("transfer",dest)
                schedule(t+inputs.transfer,1,"ready",(u,dest))
        if t >= inputs.shift and not any(remaining.values()):
            stopped = t
            break
        if t == limit:
            break
        for w,station,duration in workers:
            if w in busy:
                continue
            if w == "floater":
                if not inputs.shock <= t < inputs.shift:
                    continue
                offset = (t-inputs.shock)%1800
                station = "test" if offset < 900 else "rework"
                if duration > 900-offset%900:
                    continue
            if w=="movable" and policy=="reassign_overtime" and t>=inputs.shock:
                station,duration = "test",inputs.moved_seconds
            op = "retest" if station=="test" and queue["retest"] else station
            if queue[op]:
                u = queue[op].popleft()
                assert state[u] == ("waiting",op)
                busy[w],state[u] = u,("active",op)
                schedule(t+duration,0,"done",(w,u,op,t))
                record(t,u,"start",op,w)
        assert len(state) == sum(len(q) for q in queue.values()) + len(busy) + sum(v[0] in ("transfer","shipped","stock","scrap") for v in state.values())
    # Scheduled arrivals after line shutdown still belong to horizon inventory.
    for t,_,_,kind,u in events:
        if kind=="release" and t <= inputs.horizon:
            state[u] = ("waiting","processing")
    totals = Counter(s for s,_ in state.values())
    wip = sum(totals[s] for s in ("waiting","active","transfer"))
    assert sum(q for _,q in inputs.releases) == totals["shipped"]+totals["stock"]+totals["scrap"]+wip
    ontime = sum(completion[i] is not None and completion[i]<=due for i,_,due in orders)
    ot = max(0,stopped-inputs.shift)/3600
    c = inputs.costs
    costs = dict(base=c["base_labor_usd"], floater=(inputs.shift-inputs.shock)/3600*c["floater_usd_per_hour"] if policy=="flex" else 0,
                 overtime=ot*c["overtime_usd_per_hour"], rework=worked*c["rework_usd_per_unit"], scrap=totals["scrap"]*c["scrap_usd_per_unit"],
                 late=(len(orders)-ontime)*c["late_usd_per_order"], wip=wip*c["end_wip_usd_per_unit"])
    metrics = dict(shipped=totals["shipped"],on_time=ontime,wip=wip,stock=totals["stock"],scrap=totals["scrap"],reworked=worked,overtime_hours=ot,total_cost=sum(costs.values()))
    return DayResult(completion,state,trace,metrics,costs)


if __name__ == "__main__":
    inputs = load_inputs()
    for name in POLICIES:
        print(name, simulate_day(inputs,name).metrics)
