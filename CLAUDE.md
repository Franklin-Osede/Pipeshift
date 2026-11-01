# pipeshift: project brief

pipeshift is a public portfolio project: a Go CLI that helps teams migrate Jenkins pipelines to GitHub Actions safely. It converts what it can deterministically, uses an LLM only for ambiguous parts, validates the result, and produces an evidence-backed report of what is verified, what needs human review and what is unsupported.

## Core question
"How much of a Jenkins → GitHub Actions migration can be converted and verified automatically, and how reliably can a tool distinguish verified conversions from those that still need a human?"

## Positioning
GitHub Actions Importer already converts pipelines and produces audit reports. pipeshift's difference is per-element traceability and explicit evidence for every "verified" claim. Never claim superiority without measured evidence.

## Definitions (apply everywhere)
- verified: converted by a deterministic rule with explicit semantic test coverage for that mapping AND the output passes validation. Means "verified within documented test coverage", never guaranteed runtime equivalence.
- needs-review: convertible, but without sufficient evidence of equivalence (AI-assisted, partial mapping, credentials, environment-specific behavior). Always includes the reason.
- unsupported: no reliable translation in v1. Includes the reason and a suggested manual approach.
- Passing static validation never proves runtime equivalence.

## v1 scope (strict; anything else goes to "v2 ideas")
- Input: declarative Jenkinsfiles only. Scripted pipelines, shared libraries and arbitrary Groovy are detected and reported as unsupported, never guessed.
- Parsing: do NOT write a Groovy parser. Use the Pipeline Model Definition plugin's converter (ModelConverterAction, Jenkinsfile → JSON) and validator, running Jenkins in a pinned container with minimal privileges, resource limits and no Docker socket access. Never execute steps of the analyzed pipelines.
- IR: typed Go representation (agent, environment, stages, parallel, steps, when, post, triggers, credentials, tools, options).
- Conversion: deterministic rules for common constructs (sh, stages, parallel, environment, when/branch, post, cron triggers). Pay special attention to post, when and parallel semantics.
- Credentials: never resolved, exported or sent to the LLM. Generate secret references plus a list of secrets the user must configure; always "needs-review".
- AI (optional): provider-agnostic interface, used only where no deterministic rule exists. The LLM returns structured, schema-validated proposals (mapping, explanation, assumptions), never raw YAML inserted directly. All AI-assisted mappings are "needs-review". The CLI works fully with `--no-ai`.
- Validation: actionlint for workflow correctness, zizmor for security (permissions, unpinned actions, injection patterns). Report these separately from semantic verification.
- Treat Jenkinsfile content and model responses as untrusted input. Never execute AI-generated commands.

## Report (Markdown + JSON per pipeline)
- Per element: source location, IR element, rule applied, generated workflow location, validation results, status and reason.
- Nothing silently disappears: unrecognized or partially parsed constructs stay in the output and in the coverage denominator.
- Summary (e.g. "12 elements: 9 verified, 2 needs review, 1 unsupported") plus detected risks and required manual setup.

## Evaluation
- Unit tests and golden files per rule live in internal/ and are separate from evaluation.
- eval/dataset/: 20–30 synthetic Jenkinsfiles with hand-labeled expected status per element, written and labeled BEFORE implementing conversion rules and not modified afterwards. Include straightforward, ambiguous, unsupported and adversarial cases (embedded Groovy, complex conditions, unknown plugins, malformed credentials).
- A frozen v1 construct list is written before labeling. Wrong labels are never edited: corrections go in a dated eval/ERRATA.md and results are reported with and without it. About a quarter of the dataset is a sealed holdout, unseen during rule development and scored once at the end.
- Metrics: status accuracy vs labels; coverage measured separately from correctness (marking everything needs-review must not score well); actionlint and zizmor results; false-verified rate = false-verified elements / all elements classified verified, reporting numerator and denominator (N/A if zero). Compare `--no-ai` vs AI-assisted.
- AI runs log model, prompt version, parameters and token usage. CI runs only the deterministic evaluation; AI evaluation is explicit and optional.
- Stretch (optional): compare against GitHub Actions Importer on a small compatible subset. If setup is impractical, document why instead.
- `make eval` writes results to eval/results/ as JSON + markdown table.

## Constraints
- Go for all application logic, Cobra for the CLI.
- Commands: `pipeshift analyze <Jenkinsfile>` (report only), `pipeshift convert <Jenkinsfile> -o <dir>` (workflow + report).
- Only synthetic or public pipelines; nothing from any employer or client.
- No web UI, PR creation, batch mode or scripted pipelines in v1.
- Pin the Jenkins image, plugins, actionlint, zizmor and Go dependencies. API keys via environment variables only.
- Repo CI: build, test, lint, deterministic eval. No API keys in CI.

## Repo structure (adjust only with a stated reason)
pipeshift/
  cmd/pipeshift/
  internal/jenkins/   # sandboxed container client: Jenkinsfile → JSON
  internal/ir/
  internal/convert/   # deterministic rules + golden tests
  internal/ai/        # structured proposals, schema validation
  internal/validate/  # actionlint + zizmor wrappers
  internal/report/
  eval/dataset/       # frozen labeled cases
  eval/results/
  docs/               # architecture, decisions.md, supported-constructs.md
  Makefile
  README.md

## README sections
1. Core question. 2. Positioning. 3. Architecture diagram. 4. Example: Jenkinsfile → workflow → report. 5. Evaluation results (with and without AI). 6. What "verified" means and doesn't. 7. Supported / unsupported constructs. 8. Quickstart. 9. Limitations and v2 ideas.

## Integrity
Never invent evaluation results, coverage numbers or conclusions. Anything not executed is marked PENDING. Never relabel elements or edit the frozen dataset to improve results.

## How to work on this project
- Milestones: scaffold → converter spike → eval dataset → IR → deterministic rules → validation → report and CLI → AI assist → README.
- Stop after each milestone, summarize what is done and how to verify it, and wait for approval before starting the next.
- Keep docs/decisions.md updated: each decision, alternatives considered and why.
