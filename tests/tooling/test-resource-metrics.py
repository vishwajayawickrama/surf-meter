#!/usr/bin/env python3
"""Measurement math checks; no app launch or native process access required."""
import ctypes
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('resource_metrics', ROOT / 'scripts/measure-resources.py')
metrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metrics)
report_spec = importlib.util.spec_from_file_location('resource_report', ROOT / 'scripts/report-resources.py')
report = importlib.util.module_from_spec(report_spec)
report_spec.loader.exec_module(report)
recovery_spec = importlib.util.spec_from_file_location('resource_recovery', ROOT / 'scripts/recover-resource-run.py')
recovery = importlib.util.module_from_spec(recovery_spec)
recovery_spec.loader.exec_module(recovery)


def row(interval, cpu, rss):
    return {'group': 'app', 'interval_seconds': interval, 'cpu_delta_seconds': cpu,
            'cpu_percent': cpu / interval * 100 if interval else 0, 'rss_bytes': rss,
            'footprint_bytes': rss // 2, 'read_delta_bytes': 2, 'written_delta_bytes': 4,
            'wakeups_delta': 1, 'process_count': 1}


class ResourceMetricsTests(unittest.TestCase):
    def test_apple_silicon_timebase_converts_ticks_to_seconds(self):
        counters = metrics.Counters.__new__(metrics.Counters)
        counters.clock = metrics.Timebase(125, 3)
        def read(pid, flavor, pointer):
            self.assertEqual(flavor, 2)
            value = ctypes.cast(pointer, ctypes.POINTER(metrics.Usage)).contents
            value.user_time, value.system_time = 24_000_000, 12_000_000
            value.resident_size, value.phys_footprint = 1000, 700
            value.proc_start_abstime = 9
            return 0
        counters.lib = SimpleNamespace(proc_pid_rusage=read)
        result = counters.read(123)
        self.assertEqual(result['cpu_seconds'], 1.5)
        self.assertEqual(result['rss_bytes'], 1000)
        self.assertEqual(result['footprint_bytes'], 700)
        self.assertEqual(result['identity'], (123, 9))

    def test_cpu_is_time_weighted_not_mean_of_percentages(self):
        rows = [row(0, 0, 10), row(10, 6, 20), row(5, 4.5, 30)]
        result = metrics.summarize(rows, 15)['app']
        self.assertEqual(result['cpu_mean_percent_one_core'], 70)
        self.assertEqual(result['measured_seconds'], 15)
        self.assertEqual(result['kernel_written_bytes'], 8)
        self.assertEqual(result['rss_peak_sampled_bytes'], 30)

    def test_cpu_does_not_divide_by_machine_core_count(self):
        result = metrics.summarize([row(0, 0, 1), row(1, 2.4, 2)], 1)['app']
        self.assertEqual(result['cpu_mean_percent_one_core'], 240)

    def test_strict_resident_memory_budget_and_interpolated_percentile(self):
        result = metrics.summarize([row(0, 0, 100_000_000), row(5, .01, 90_000_000)], 5)['app']
        self.assertFalse(result['sampled_rss_below_100_MB'])
        self.assertTrue(result['cpu_mean_below_one_percent'])
        self.assertEqual(metrics.percentile([20, 0, 10], .95), 19)

    def test_ps_time_parsing_includes_days_and_fractional_seconds(self):
        with patch.object(metrics.subprocess, 'check_output', return_value='2-03:04:05.67\n'):
            self.assertAlmostEqual(metrics.ps_cpu_seconds(123), 183845.67)


class ResourceReportTests(unittest.TestCase):
    def test_report_rejects_arbitrary_sample_text_and_nonfinite_values(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'samples.csv'
            path.write_text('group,elapsed_seconds\nprivate-process-name,0\n')
            with self.assertRaises(ValueError):
                report.load_samples(path)
            path.write_text('group,elapsed_seconds\ninstalled-app,nan\n')
            with self.assertRaises(ValueError):
                report.load_samples(path)

    def test_document_updates_preserve_surrounding_content(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'README.md'
            path.write_text('intro\n'+report.MARKER_START+'\nold\n'+report.MARKER_END+'\nend\n')
            report.replace_section(path, 'new results')
            self.assertEqual(path.read_text(), 'intro\n'+report.MARKER_START+'\nnew results\n'+report.MARKER_END+'\nend\n')


class ResourceRecoveryTests(unittest.TestCase):
    def test_only_sub_millisecond_finalization_gap_is_accepted(self):
        rows = [{'group': group, 'elapsed_seconds': elapsed} for group in ['app','helper'] for elapsed in [0,1799.999718]]
        self.assertEqual(recovery.recovered_duration(rows, {'app','helper'}, 1800),1799.999718)
        for item in rows:
            if item['elapsed_seconds']:
                item['elapsed_seconds'] = 1795
        with self.assertRaises(ValueError):
            recovery.recovered_duration(rows, {'app','helper'}, 1800)

    def test_missing_endpoint_group_is_rejected(self):
        rows = [{'group':'app','elapsed_seconds':0},{'group':'app','elapsed_seconds':1799.999718}]
        with self.assertRaises(ValueError):
            recovery.recovered_duration(rows, {'app','helper'},1800)


if __name__ == '__main__':
    unittest.main()
