#!/usr/bin/env python3
"""Recover only the numeric window from the known sub-millisecond deadline bug.

Preserves summary.json as failed. Never invents missing SQL or disk snapshots.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('resource_metrics', HERE/'measure-resources.py')
metrics = importlib.util.module_from_spec(spec); spec.loader.exec_module(metrics)


def recovered_duration(rows, required, target):
    if {row['group'] for row in rows} != required:
        raise ValueError('Missing sample groups')
    spans = [max(row['elapsed_seconds'] for row in rows if row['group'] == group) for group in required]
    elapsed = min(spans)
    if max(spans)-elapsed > .000001 or not 0 <= target-elapsed <= .001:
        raise ValueError('Counter span does not cover the nominal window within one millisecond')
    if any(min(row['elapsed_seconds'] for row in rows if row['group'] == group) != 0 for group in required):
        raise ValueError('A starting endpoint is missing')
    return elapsed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--failure-log', type=Path, required=True)
    parser.add_argument('--fixed-retest', type=Path, required=True)
    args = parser.parse_args()
    original = args.run/'summary.json'
    source = json.loads(original.read_text())
    if source.get('complete') or 'ValueError: sleep length must be non-negative' not in args.failure_log.read_text():
        parser.error('Only the explicitly identified failed deadline-finalization run can be recovered')
    with (args.run/'samples.csv').open(newline='') as handle:
        rows = [{key: value if key == 'group' else float(value) for key, value in row.items()} for row in csv.DictReader(handle)]
    required = {prefix+suffix for prefix in ['installed', 'active', 'idle'] for suffix in ['-app','-helper','-native-total']} | {'observer'}
    try:
        elapsed = recovered_duration(rows, required, source['duration_requested_seconds'])
    except ValueError as error:
        parser.error(str(error))
    archived = args.run/'measurement-harness-at-run.py'
    if hashlib.sha256(archived.read_bytes()).hexdigest() != source['measurement_script_sha256']:
        parser.error('Archived executed harness does not match its recorded digest')
    retest = json.loads((args.fixed_retest/'summary.json').read_text())
    if not retest.get('complete') or retest.get('actual_measured_seconds',0) < 30 or not retest.get('storage_end'):
        parser.error('Require a successful fixed-harness deadline/end-snapshot retest')
    source['actual_measured_seconds'] = elapsed
    source['results'] = metrics.summarize(rows, elapsed)
    source['storage_start'] = None
    source['storage_end'] = None
    source['process_events'] = None
    source['resource_counter_recovery'] = {
        'status': 'deadline-counter-window-recovered',
        'original_run_complete': False,
        'original_summary_sha256': hashlib.sha256(original.read_bytes()).hexdigest(),
        'nominal_window_shortfall_seconds': source['duration_requested_seconds']-elapsed,
        'failure': 'Negative sleep at final deadline; resource counter samples preserved',
        'unavailable_checks': ['database file sizes at start/end', 'post-run synthetic SQL totals', 'final process-event list'],
        'fixed_harness_retest': {'complete': True, 'actual_measured_seconds': retest['actual_measured_seconds'], 'end_storage_captured': True},
    }
    output = args.run/'recovered-summary.json'
    output.write_text(json.dumps(source,indent=2)+'\n')
    print(f'Recovered counter span: {elapsed:.6f}s; shortfall {source["duration_requested_seconds"]-elapsed:.6f}s. Original failed summary retained; missing checks remain null.')


if __name__ == '__main__':
    main()
