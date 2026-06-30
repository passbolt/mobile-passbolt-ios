# Network response fixtures

Standardized JSON dumps of Passbolt API responses, used to drive realistic
fixture-based mocking and benchmarks. Files here are bundled into `MockData`
(`resources: [.copy("Fixtures")]`) and read at runtime via `Bundle.module`
through `NetworkResponseFixture`.

## Layout

```
Fixtures/
├── Benchmark/
│   ├── small/                      # committed to git
│   │   ├── users.json              # GET /users.json                  (10 users)
│   │   ├── groups.json             # GET /groups.json                  (3 groups)
│   │   ├── folders.json            # GET /folders.json                 (6 folders)
│   │   ├── resources.json          # GET /resources.json             (75 v5 resources)
│   │   ├── resource-types.json     # GET /resource-types.json
│   │   ├── metadata-keys.json      # GET /metadata/keys.json
│   │   ├── metadata-keys-settings.json   # GET /metadata/keys/settings.json
│   │   ├── metadata-types-settings.json  # GET /metadata/types/settings.json
│   │   └── metadata-session-keys.json    # GET /metadata/session-keys.json
│   ├── medium/                     # NOT committed (.gitkeep only) — 150 users / 25 groups / 64 folders / 1550 resources
│   │   └── .gitkeep                #   regenerate locally; same file names as small/
│   └── large/                      # NOT committed (.gitkeep only) — 2000 users / 300 groups / 660 folders
│       └── .gitkeep                #   resources PAGINATED: resources.json + resources-<n>.json (5 × 5000 = 25 000)
└── keys/                           # private key material — NEVER committed (see keys/README.md)
    ├── ada.private.asc
    └── ada.passphrase
```

- **`small/`** — committed. A real Proxyman capture of a seeded `passbolt.local`
  server. Always present, so its benchmark always runs.
- **`medium/`** / **`large/`** — **git-ignored** (only a `.gitkeep` keeps the folder).
  They're large captures kept locally / regenerated from a Proxyman export. Their
  benchmarks `XCTSkipUnless` the fixtures are present, so a fresh checkout skips them.
  All three tiers share the same crypto identity (ada / metadata key), so any present
  tier works with the integration benchmark
  (`SessionDataRefreshIntegrationBenchmarkTests`).
- **Paginated resources** (`large`): the converter splits a multi-page
  `/resources.json` by `header.pagination.page` into `resources.json` (page 1) +
  `resources-<n>.json`. The benchmark executor serves the page matching the request's
  `page` query item, so the real paginated fetch (`ResourcesFetchNetworkOperation`
  walking `totalPages`) is exercised end to end.
- **`keys/`** — private key material for the integration benchmark, which really
  decrypts the v5 resource metadata. Git-ignored; see `keys/README.md`. Benchmark
  `XCTSkip`s when absent.

## Regenerating from a Proxyman capture

The converter (`proxyman-to-fixtures.py`) is **kept outside the repo** (it's
`.gitignore`d under `Tools/fixtures/`). Point it at a Proxyman response export to
rebuild a tier — it maps endpoint slugs to file names, splits paginated responses,
validates JSON, and skips auth/secrets:

```
proxyman-to-fixtures.py <proxyman_export_dir> Sources/MockData/Fixtures/Benchmark/medium
```

## File format

Each file is a verbatim Passbolt API response envelope:

```json
{ "header": { ... }, "body": [ ... ] }
```

so a real server capture can be dropped in unmodified. `NetworkResponseFixture`
exposes the raw bytes (`data(_:)`) and a convenience that decodes only `body`
(`decodeBody(_:as:)`) using the app's `.iso8601` `JSONDecoder`. ISO8601 date
strings and the API's snake_case keys are therefore required.

## Mocking with fixtures

Prefer mocking at the network executor seam so the production decoder runs and
memory/CPU metrics account for the raw payload, not just the decoded models.
Register the real operation and have `SessionNetworkRequestExecutor` answer with
the fixture's raw bytes:

```swift
register({ $0.usePassboltUsersFetchNetworkOperation() }, for: UsersFetchNetworkOperation.self)

let users: Array<UInt8> = Array(try NetworkResponseFixture.data("Benchmark/small/users.json"))
patch(\SessionNetworkRequestExecutor.execute, with: { mutation in
  let request: HTTPRequest = mutation.instantiate()  // route by request.urlComponents.path
  return HTTPResponse(url: …, statusCode: 200, headers: .empty, body: Data(users))
})
```

For a pure decode benchmark (no operation), decode the body directly:

```swift
let resources: Array<ResourceDTO> = try NetworkResponseFixture.decodeBody(
  "Benchmark/small/resources.json",
  as: Array<ResourceDTO>.self
)
```

See `SessionDataRefreshIntegrationBenchmarkTests` for the full (page-aware) routing executor.
