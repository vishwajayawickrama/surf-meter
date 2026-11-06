# Resource dataset · Apple M4 · 2026-11-06

See [the performance report](../../performance.md) for hardware, workload, results, interpretation, and limitations.

| File | Contents |
| --- | --- |
| [summary.json](summary.json) | Allowlisted metadata, resource aggregates, growth calculations, source/binary/harness digests, and explicit recovery status. |
| [samples.csv](samples.csv) | 361 sampled endpoints per group, ten numeric process/aggregate groups, 3,610 rows. CPU means use actual interval durations. |
| [resource-usage.png](resource-usage.png) / [SVG](resource-usage.svg) | Plots generated from these samples with pinned Matplotlib. |
| [environment-check.json](environment-check.json) | Post-run browser/tool versions and helper binary hashes; installed and bundled helpers were not byte-identical. |
| [independent-footprint-check.json](independent-footprint-check.json) | Separate Apple `footprint` confirmation of the installed helper's charged memory. |
| [post-run-storage-check.json](post-run-storage-check.json) | Separate later file-size observation; not substituted for the missing benchmark endpoints. |
| [measurement-harness-at-run.py](measurement-harness-at-run.py) | Exact executed historical harness, matching the digest recorded before measurement. **Contains the final-deadline defect; use the current script for future runs.** |

## Finalizer failure and recovery

The retained resource span is **1,799.999718 seconds**, 0.000282 seconds short of the nominal 30-minute deadline, after 30 seconds of warmup. The harness took the final scheduled counter sample and then raised `ValueError: sleep length must be non-negative` while waiting for the remaining fraction of a millisecond. Its cleanup terminated only the disposable workloads.

The original local manifest remains failed. The published summary also keeps `complete: false` and records `resource_counter_recovery`; it does not pretend the normal finalization path succeeded. CPU, RSS, charged footprint, and kernel-I/O aggregates are recomputed from the retained CSV. Database-size snapshots, end-of-run synthetic SQL totals, and the final process-event list were not persisted and remain null. No missing values are fabricated.

The recovery utility requires the identified error, all expected endpoint groups covering the nominal window within one millisecond, the exact archived harness digest, and a successful fixed-harness retest. After correcting the negative-delay guard and early metadata persistence, a separate 35-second regression completed and captured end-of-run storage information. This does not substitute for a fresh long run after the app's resource issues are fixed.

## Publication scope

The files contain numeric resource data and public build/hardware metadata. No real tab URL, page title/content, browsing-domain record, process ID, precise local timestamp, account setting, or machine home path is published. Synthetic platform names in the archived code are predetermined test inputs. The installed helper was already approximately 9.4 hours old at the start; its initial footprint was not created entirely during these 30 minutes.
