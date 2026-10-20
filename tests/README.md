# MQL5 indicator regression checks

Run from the repository root:

```bash
python3 -m unittest discover -s tests -v
```

Requires Python 3 and g++ with C++17 support. The tests extract actual MQL5
function bodies into an adapter with terminal stubs and bounds-checked arrays.
Reference volume averages, CCI and RSI slopes are computed independently.
Woodies tests also compare signals with an independent eager reference.
C7CB tests cover metric cache parity/bounds, signal publication times and
lifetimes, and deferred multi-timeframe replay. Array-access counts check work
growth without depending on machine-specific timing.

These tests exercise calculation logic; they do not validate MQL5 compilation,
terminal-managed plot rendering, broker data quality, or trading profitability.
Compile the changed indicators with MetaEditor and test chart behavior separately.
