import unittest
from dataclasses import replace
from pathlib import Path
from tempfile import TemporaryDirectory
from shutil import copytree
from python.model_inputs import load_inputs
from python.event_sim import simulate_day, POLICIES


class EventTests(unittest.TestCase):
    def setUp(self):
        self.base = load_inputs()
        self.tiny = replace(self.base, orders=(("A",2,9),("B",2,15)), releases=((0,4),),
                            workers=(("p","processing",2),("movable","assembly",3),
                                     ("t","test",1),("r","rework",2)),
                            draws=((.5,.5),)*4, transfer=0, pre=0, post=0,
                            repair=1,shock=50,shift=60,horizon=7260)

    def test_pipeline(self):
        r = simulate_day(self.tiny,"continue")
        self.assertEqual([t for t,_,kind,_,_ in r.log if kind=="ship"],[6,9,12,15])
        self.assertEqual(r.orders,{"A":9,"B":15})
        self.assertEqual((r.metrics["on_time"],r.metrics["total_cost"]),(2,2400))

    def test_shock_and_quality(self):
        single = replace(self.tiny, releases=((0,1),), orders=(("A",1,9),),
                         draws=((.5,.5),),shock=5,post=1)
        self.assertEqual(simulate_day(single,"continue").orders["A"],9)
        self.assertEqual(simulate_day(replace(single,shock=6),"continue").orders["A"],6)
        self.assertEqual(simulate_day(replace(single,repair=0),"continue").metrics["scrap"],1)

    def test_worker_finishes_before_move(self):
        r = simulate_day(replace(self.tiny,shock=3),"reassign_overtime")
        actions = [(t,kind,op) for t,_,kind,op,w in r.log if w=="movable"]
        self.assertEqual(actions[:2],[(2,"start","assembly"),(5,"finish","assembly")])
        self.assertTrue(all(op in ("test","retest") for _,_,op in actions[2:]))

    def test_overtime(self):
        early = simulate_day(self.base,"reassign_overtime")
        self.assertEqual(early.metrics["overtime_hours"],0)
        late = simulate_day(replace(self.tiny,shift=10,shock=10,
                                    orders=(("A",100,7260),)), "reassign_overtime")
        self.assertEqual(late.metrics["overtime_hours"],2)
        self.assertEqual(late.costs["overtime"],900)

    def test_starter_balance(self):
        for policy in POLICIES:
            r = simulate_day(self.base,policy)
            m = r.metrics
            self.assertEqual(m["shipped"]+m["stock"]+m["scrap"]+m["wip"],128)
            self.assertEqual(m["total_cost"],sum(r.costs.values()))

    def test_bad_input(self):
        for file,old,new in [
            ("event_settings.csv","225","0"),("event_settings.csv","movable","unqualified"),
            ("stations.csv",'"assembly"','"processing"'),("settings.csv","0.75","1.2"),
            ("unit_draws.csv","1,","999,")]:
            with self.subTest(file=file), TemporaryDirectory() as tmp:
                directory = Path(tmp)/"data"
                copytree("data",directory)
                p = directory/file
                p.write_text(p.read_text().replace(old,new,1))
                with self.assertRaises(ValueError):
                    load_inputs(directory)
