"""Pure admission-policy tests. No real job, lock, GPU or meminfo is used."""
from pathlib import Path
import importlib.machinery
import importlib.util
import unittest
from unittest import mock

PATH=Path(__file__).resolve().parents[1]/'scripts/zk60_resource_guard.py'
loader=importlib.machinery.SourceFileLoader('guard_s8_installed',str(PATH))
spec=importlib.util.spec_from_loader(loader.name,loader)
guard=importlib.util.module_from_spec(spec);loader.exec_module(guard)

class SwapAdmission(unittest.TestCase):
    def verdict(self,available,swap,need=8.5,kind='cpu',live=(),ahead=(),gpu=(0,8192)):
        values={'MemTotal':16*guard.GIB,'MemAvailable':int(available*guard.GIB),
                'SwapTotal':16*guard.GIB,'SwapFree':int((16-swap)*guard.GIB)}
        # `gpu` simulates nvidia-smi on the 8 GB card; naming a non-default source
        # keeps the 8 GB thresholds on a Mac too (the Apple GPU has its own; no-op on Linux).
        with mock.patch.object(guard,'meminfo',return_value=values), \
             mock.patch.object(guard,'_live_jobs',return_value=list(live)), \
             mock.patch.object(guard,'NVIDIA_SMI','/simulated/nvidia-smi'), \
             mock.patch.object(guard,'gpu_used_mib',return_value=gpu):
            return guard._admission_reasons(kind,need,Path('/unused/private-fixture'),ahead)

    def test_observed_stale_swap_allows_both_waiting_jobs(self):
        self.assertEqual(self.verdict(13.42,1.29),[])
        self.assertEqual(self.verdict(13.42,1.29,need=1.7,kind='build'),[])

    def test_swap_requires_room_to_restore_all_swapped_pages(self):
        reasons=self.verdict(10,2)
        self.assertEqual([kind for kind,_ in reasons],['swap'])
        self.assertIn('full swap reserve 2.00',reasons[0][1])

    def test_exact_full_swap_headroom_is_admitted(self):
        self.assertEqual(self.verdict(11.5,2),[])
        self.assertEqual([kind for kind,_ in self.verdict(11.5-1/1024,2)],['swap'])

    def test_normal_memory_floor_is_unchanged_below_swap_threshold(self):
        self.assertEqual([kind for kind,_ in self.verdict(9,0)],['mem'])
        self.assertEqual(self.verdict(9.5,1),[])
        self.assertEqual(self.verdict(12,0),[])

    def test_large_swap_is_still_refused_when_total_reserve_cannot_fit(self):
        self.assertEqual([kind for kind,_ in self.verdict(12,10,need=4)],['swap'])

    def test_budget_and_exclusive_heavy_admission_remain_load_bearing(self):
        jobs=[{'need_gib':10,'class':'light','label':'fixture'}]
        self.assertIn('budget',[kind for kind,_ in self.verdict(13,2,need=4,live=jobs)])
        jobs=[{'need_gib':1,'class':'cpu','label':'fixture'}]
        self.assertIn('heavy',[kind for kind,_ in self.verdict(13,2,need=4,live=jobs)])

    def test_gpu_telemetry_and_idle_vram_checks_are_unchanged(self):
        self.assertIn('gpu',[kind for kind,_ in self.verdict(13,2,need=4,kind='gpu',gpu=None)])
        self.assertIn('gpu',[kind for kind,_ in self.verdict(13,2,need=4,kind='gpu',gpu=(4096,8192))])

    def test_fifo_budget_reservations_are_still_enforced(self):
        ahead=[{'need_gib':10,'class':'light','label':'older'}]
        self.assertIn('fifo-budget',[kind for kind,_ in self.verdict(13,2,need=4,ahead=ahead)])

    def test_missing_swap_counters_do_not_disable_the_memory_floor(self):
        values={'MemTotal':16*guard.GIB,'MemAvailable':8*guard.GIB}
        with mock.patch.object(guard,'meminfo',return_value=values),mock.patch.object(guard,'_live_jobs',return_value=[]):
            reasons=guard._admission_reasons('cpu',8.5,Path('/unused/private-fixture'))
        self.assertEqual([kind for kind,_ in reasons],['mem'])

if __name__=='__main__':unittest.main(verbosity=2)
