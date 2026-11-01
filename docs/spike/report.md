# Milestone 1 spike: Jenkins converter

Date: 2026-11-01. Every result below came from `make spike`. Raw output is in [results/](results/), and the driver is [run.sh](run.sh).

## Verdict

**The approach works, but not through the HTTP converter alone.** The plugin parses declarative Jenkinsfiles accurately and safely. The `toJson` endpoint on its own cannot meet the brief: it has no source locations, it fails a whole file over one environment-specific problem, and it silently drops top-level Groovy.

A roughly 100-line shim calls the same `ModelParser` under the same hardened compiler configuration and fixes all three. This departs from the brief's "ModelConverterAction", so it needs approval (D-007 in [decisions.md](../decisions.md)).

## Setup

| Item | Value |
|---|---|
| Jenkins | `2.580.2-lts-jdk21`, pinned by digest |
| Plugins | 54, full transitive lock in `internal/jenkins/image/plugins.txt` |
| Image size | 813 MB |
| Startup | 3.2 s, one run, 2 CPU limit, Colima arm64 |
| Converter latency | 2–255 ms per file, slowest on the first requests |
| Memory | 475–596 MiB, sampled once at the end of each run, not a true peak |

Sandbox checks, run from inside the container:

| Check | Result |
|---|---|
| User | uid 1000 |
| Capabilities | `CapEff` and `CapBnd` both zero |
| `no-new-privileges` | set |
| Root filesystem | read-only, write attempt refused |
| Docker socket | absent |
| Network interfaces | `lo` only; outbound request failed |
| Limits | 2 GiB memory, 2 CPUs, 512 pids |

Requests reach Jenkins through `docker exec` over loopback, so no port is published.

## Results by fixture

"Shim" shows what the shim recovered. Line numbers are `line:column`.

| Fixture | `toJson` | Shim |
|---|---|---|
| 01-simple | success | AST, all elements located |
| 02-medium | success | AST, all elements located |
| 03-complex | success, `def helper` silently gone | AST, plus `def helper` at line 2 |
| p1 unknown step | success, step kept | same, with locations |
| p2 unknown `when` | **failure, whole file** | AST kept with the condition, plus error at 5:20 |
| p3 tools not configured | **failure, whole file** | AST kept with both tools, plus errors at 4:15 and 5:13 |
| p4 scripted | failure, clear message | no AST, no error, `node('linux') {` reported at line 1 |
| p5 malformed | failure at 9:1 | same |
| p6 `@Library` | success, **`@Library` silently gone** | AST, plus `@Library` statement at line 1 |
| p7 several errors | failure, 3 errors | AST plus the 3 errors; `bogusSection` appears only in the errors |
| p8 `@ASTTest` | failure, **empty `errors:[{}]`** | no AST, `SecurityException` naming the annotation |
| p9 `@Grab` | failure, **empty `errors:[{}]`** | no AST, `SecurityException` naming the annotation |
| p10 static initializer | success, **class silently gone** | AST, plus class `Marker` at line 2 |

All 13 JSON outputs were byte-identical across two runs.

`03-complex` first failed with `Invalid agent type "docker"` because `docker-workflow` was not installed. The validator's accepted vocabulary depends on the installed plugins, so plugin choice is part of the tool's behaviour.

## How the four risks turned out

| Risk | Outcome |
|---|---|
| No source locations | **Confirmed for `toJson`.** Solved by the shim. Every element has a location except 4 synthetic argument nodes, across 03 and p7, that can inherit their parent's location. Spot checks of lines in 02 matched the source. |
| All-or-nothing failure | **Partly confirmed.** Unknown steps pass. Unknown `when` conditions, unconfigured tools and missing agent types fail the whole file. Solved by the shim, which keeps the AST and gives located errors. |
| Compile-time execution | **Blocked for the two cases tested.** The `@ASTTest` probe left no marker through the converter or the shim. Positive control: the same file under a plain `GroovyShell` did write the marker, so the probe works and the protection is what stopped it. A static initializer does not run either, because parsing stops at the CONVERSION phase. |
| Embedded Groovy | **Preserved as text, never interpreted.** See below. |

Two probes are not a security proof. The container restrictions remain the real boundary, and each run should use a new container.

## JSON shape

The top level of `pipeline` has `agent`, `environment`, `stages`, `post`, `triggers`, `options`, `parameters`, `tools` and `libraries`.

- **Values:** `{"isLiteral": bool, "value": ...}`.
- **Interpolated strings:** `isLiteral:false` and the value is raw source including the quotes, for example `"\"Built ${APP_NAME}\""`. Triple quotes are kept too.
- **Single-quoted shell variables:** `'login "$U" "$P"'` is literal, so shell expansion and Groovy interpolation can be told apart.
- **`arguments` has several shapes:** a list of key/value pairs, a list of positional values, one object (`branch 'main'`), nested method calls (`buildDiscarder(logRotator(...))`) or `[]`. The IR needs a tagged union.
- **Credentials:** `credentials('id')` in `environment` is structured. The list in `withCredentials([...])` is **one opaque string**: `${[usernamePassword(credentialsId: 'db', ...)]}`.
- **Block steps:** `retry`, `timeout` and `withCredentials` nest through `children`.
- **Wrapper:** stages carry `branches:[{name:"default", steps:[...]}]`.
- **Kept semantics:** `failFast`, `beforeAgent`, per-stage `agent`, `post` and `environment`, `matrix` axes and excludes, `input`, nested `stages`.

## What is lost or misleading

| Item | Detail | Consequence |
|---|---|---|
| Source locations | absent from `toJson` | shim |
| Top-level Groovy | `def`, `class`, `@Library` absent from `toJson` | shim, reported as unsupported |
| Comments and formatting | absent | no semantic effect; the report can link to source lines |
| `isLiteral:true` on Groovy | `script` and `expression` bodies are marked literal although they are code | **dangerous**: dispatch on step name first, never trust this flag for those |
| Post-condition order | array follows source order, which may differ from Jenkins' fixed execution order | rules must not rely on array order; confirm the real order in M4 |
| Empty errors | `errors:[{}]` for rejected annotations | shim gives the reason |
| `toJenkinsfile` round trip | 03's own JSON failed with `Expected a when condition @ line 91`; cause not investigated | do not use round trip as a correctness check |

## Limitations of the shim

- It uses plugin internals (`ModelParser`, `Converter.makeCompilerConfiguration`), so plugin upgrades can break it. The lock file and a contract test on these fixtures manage that.
- It uses the script console, which the converter does not need. The console is reachable only on loopback in a container with no network. The Jenkinsfile travels as base64 and is decoded to a string, so it is never spliced into the script as code.
- `p4` returns no AST and no error. "No AST, no errors" must therefore be classified as "not a declarative pipeline".
- Telling environment errors from real ones means matching message text, for example `does not have an install of`. Versions are pinned, but the mapping needs tests.
- Shim latency was not measured separately.

## Not tested

- `pipeline {}` nested inside other Groovy, such as `node { pipeline { } }` or `if (x) { pipeline { } }`
- Files with several `pipeline` blocks
- Large Jenkinsfiles and hostile input sizes
- Other `@ASTTest`-style transforms, and any bypass attempts

The first three belong in the M2 adversarial cases.
