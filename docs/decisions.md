# Decisions

Status is `accepted` or `proposed`. Proposed decisions await the project owner's approval.

## D-001: Go module path uses the repository's exact casing
**Status:** accepted, 2026-11-01

Module path is `github.com/Franklin-Osede/Pipeshift`, matching the GitHub repository. Go module paths are case-sensitive.

**Alternative:** lowercase `pipeshift`. Rejected because it would not resolve against the repository name.

## D-002: Jenkins image files live in `internal/jenkins/image/`, spike material in `docs/spike/`
**Status:** accepted, 2026-11-01

This adds to the agreed repo structure. The image is what `internal/jenkins` will drive, so it belongs next to that client. Spike fixtures and output are evidence rather than application code, and must stay separate from the frozen `eval/dataset/`.

**Alternative:** a top-level `spike/`. Rejected because it would outlive its purpose at the repo root.

## D-003: No network in the parser container; reach Jenkins through `docker exec`
**Status:** accepted, 2026-11-01

The container runs with `--network none`, a read-only root, no capabilities, uid 1000 and resource limits. Requests go through `docker exec` to loopback.

**Alternatives:** an internal Docker network with a published port, which is not possible on an internal network and is a larger surface otherwise; a sidecar proxy, which adds a component for no gain.

**Cost:** `pipeshift` needs Docker access on the host. The container itself has no socket.

## D-004: Lock every transitive plugin version
**Status:** accepted, 2026-11-01

`plugins.in.txt` lists top-level plugins and `plugins.txt` is the generated lock.

**Why:** `--latest false` with only top-level pins resolved `script-security` 1373, which carries SECURITY-3977, a sandbox bypass. The build printed this as a warning. Sandbox plugins matter directly here, because parsing handles untrusted input.

**Alternative:** pin only top-level plugins. Rejected because resolution is then neither reproducible nor safe.

## D-005: Include `docker-workflow`
**Status:** accepted, 2026-11-01

`agent { docker }` is rejected without it.

**Why:** the validator's vocabulary depends on installed plugins, and Docker agents are common.

**Consequence:** the plugin set is part of the tool's behaviour and must be documented.

## D-006: Do not use `toJenkinsfile` round trip as a correctness check
**Status:** accepted, 2026-11-01

Fixture 03's own JSON failed to convert back, so a round-trip failure would not indicate a real problem.

**Alternative:** using it as a cheap fidelity check. Rejected on that evidence.

## D-007: Parse through a shim around `ModelParser`, not the `toJson` endpoint
**Status:** proposed, 2026-11-01

Run a short Groovy script on loopback that uses the plugin's `ModelParser` and `Converter.makeCompilerConfiguration()`, stops at CONVERSION, and returns the AST JSON, element locations, located errors and top-level Groovy.

**Why:** `toJson` has no locations, fails whole files on environment-specific validation and silently drops `@Library`, `class` and `def`. Each of these conflicts with a requirement in the brief. Evidence is in [spike/report.md](spike/report.md).

**Alternatives:**
- `toJson` plus a text scanner for line numbers and `@Library`. Stays closer to the brief, but needs a partial Groovy scanner, which the brief forbids in spirit, and every `tools` file would remain unparseable.
- `toJson` plus pre-seeding tool names. Requires knowing names in advance, or parsing error messages and retrying, and does not help with unknown `when` conditions.
- A custom Jenkins plugin exposing the same logic. Cleaner surface, but adds a Java/Groovy build for no behavioural gain.

**Costs:** depends on plugin internals, and needs the script console inside the container. See the report's limitations.

## D-008: One new container per run
**Status:** proposed, 2026-11-01

Compile-time protections were only tested against two probes, so state must not carry over between inputs. Startup was 3.2 s in one measurement, which is acceptable for a CLI.

**Alternative:** a long-running shared parser. Faster, but one hostile input could affect later results.
