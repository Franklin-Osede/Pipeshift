# pipeshift

**Status: milestone 1 (converter spike) is done. The converter does not exist yet, `analyze` and `convert` return "not implemented yet", and all evaluation results are PENDING.**

pipeshift will be a Go CLI that migrates declarative Jenkinsfiles to GitHub Actions. It converts what it can with deterministic rules, uses an LLM only for the ambiguous parts, validates the generated workflow, and reports for every element whether it is verified, needs review or is unsupported, and why.

**Core question:** how much of a Jenkins to GitHub Actions migration can be converted and verified automatically, and how reliably can a tool tell verified conversions apart from those that still need a human?

GitHub Actions Importer already converts pipelines and produces audit reports. pipeshift's intended difference is per-element traceability and explicit evidence behind every "verified" claim. There is no measured comparison yet.

## What works today

- A pinned, parser-only Jenkins image (`2.580.2-lts-jdk21` by digest, 54 plugins with a full transitive lock) in [internal/jenkins/image/](internal/jenkins/image/).
- A spike that runs 13 Jenkinsfile fixtures through the Pipeline Model Definition plugin inside a container with no network, a read-only root, no capabilities, uid 1000 and resource limits. Results and raw output are in [docs/spike/report.md](docs/spike/report.md).
- A Cobra CLI skeleton with the planned `analyze` and `convert` commands. Neither is implemented.

## What the spike found

The plugin parses declarative Jenkinsfiles accurately, but its `toJson` endpoint alone is not enough:

| Problem with `toJson` | Example fixture | Shim result |
| --- | --- | --- |
| No source locations | all | every element located (`line:column`) |
| One environment-specific error fails the whole file | unknown `when`, unconfigured `tools` | AST kept, errors located |
| Top-level Groovy silently dropped | `@Library`, `def`, `class` | reported with line numbers |
| Rejected annotations return empty errors | `@ASTTest`, `@Grab` | `SecurityException` naming the annotation |

A short Groovy shim around the plugin's `ModelParser` fixes all four. Using it instead of the `toJson` endpoint is a proposed decision ([D-007](docs/decisions.md#d-007-parse-through-a-shim-around-modelparser-not-the-tojson-endpoint)) awaiting approval. Two compile-time execution probes were blocked; that is not a security proof, and the container remains the real boundary.

## Planned

| Milestone | Scope |
| --- | --- |
| Eval dataset | 20 to 30 synthetic Jenkinsfiles, hand-labeled per element before any rule is written, with a sealed holdout |
| IR | typed Go representation of agent, environment, stages, parallel, steps, when, post, triggers, credentials, tools, options |
| Deterministic rules | `sh`, stages, parallel, environment, `when`/branch, post, cron triggers, with golden tests |
| Validation | actionlint and zizmor, reported separately from semantic verification |
| Report and CLI | Markdown and JSON report per pipeline; `analyze` and `convert` |
| AI assist | optional, schema-validated proposals only, always needs-review; the CLI works with `--no-ai` |

Scripted pipelines, shared libraries and arbitrary Groovy are out of scope for v1. They will be detected and reported as unsupported, never guessed. Credentials are never resolved or sent to an LLM.

## What "verified" will mean

- **verified:** converted by a deterministic rule that has explicit test coverage for that mapping, and the output passes validation. It does not mean guaranteed runtime equivalence.
- **needs-review:** convertible, but without enough evidence of equivalence (AI-assisted, partial mapping, credentials, environment-specific behaviour). Always includes the reason.
- **unsupported:** no reliable translation in v1. Includes the reason and a suggested manual approach.

## Quickstart

Requires Go 1.26, make and golangci-lint. The spike also needs Docker, bash, jq and python3.

```bash
make build      # builds bin/pipeshift (commands are stubs for now)
make test       # no tests exist yet
make lint
make spike      # builds the Jenkins image and writes results to docs/spike/results/
```

The spike was run on Colima (arm64) with 2 CPUs and 2 GiB for the container. `pipeshift` will need Docker access on the host; the parser container itself has no Docker socket and no network ([D-003](docs/decisions.md#d-003-no-network-in-the-parser-container-reach-jenkins-through-docker-exec)).

## Docs

- [Decisions](docs/decisions.md)
- [Spike report](docs/spike/report.md)
