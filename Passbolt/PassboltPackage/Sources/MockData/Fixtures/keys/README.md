# Benchmark key material (not committed)

The end-to-end integration benchmark `SessionDataRefreshIntegrationBenchmarkTests`
actually decrypts the captured v5 resource metadata, so it needs the private key
that the dump was encrypted to. Private keys are **never committed** — everything
in this directory except this README is git-ignored.

To run the benchmark, drop these two files here:

```
keys/
├── ada.private.asc    # ada's ARMORED PGP private key
└── ada.passphrase     # the passphrase on a single line
```

Requirements:

- The key must match the capture: fingerprint **03F60E958F4CB29723ACDF761353B5B15D9B054F**
  (the standard Passbolt `ada@passbolt.com` test key). The metadata key in
  `Benchmark/small/metadata-keys.json` is encrypted to this key, and every
  resource's `metadata` is encrypted to that metadata key — so this key unlocks
  the whole chain.
- The passphrase for the standard ada test key is `ada@passbolt.com`.

Without these files the benchmark calls `XCTSkip` rather than failing.

> Source the key from your own secure location or a private git-lfs submodule
> mounted at this path. Do not paste real production keys here.
