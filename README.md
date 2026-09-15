# Reusable Actions for GroupeZ

Build, publish and announce Java projects - Gradle or Maven - from one place.

This repository ships two layers, and you pick the one that fits:

| Layer                  | Use it when                                                            | Entry point                                                                                |
|------------------------|------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| **Reusable workflows** | You want the whole pipeline in four lines                              | [`build.yml`](.github/workflows/build.yml), [`publish.yml`](.github/workflows/publish.yml) |
| **Composite actions**  | You need to reorder steps, add your own, or set `permissions` yourself | [`.github/actions/*`](.github/actions)                                                     |

Full input reference: **[docs/actions.md](docs/actions.md)** · Worked examples: **[docs/recipes.md](docs/recipes.md)**

---

## Quick start — the whole pipeline

```yaml
name: Build

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    uses: GroupeZ-dev/actions/.github/workflows/build.yml@v1
    with:
      project-name: "zMenu"
    secrets: inherit
```

That gets you:

- build-tool detection (Gradle or Maven) and a JDK with dependency caching
- a development build off the default branch, tagged `-DEV` with the short SHA
- a JUnit test summary in the job summary
- a Discord message that posts as **build running** and is edited in place into **passed** or
  **failed**, carrying the commit changelog, test counts, duration and the built jar

<details>
<summary>What the Discord message looks like</summary>

```
🔨 Build running                                    ← posted when the build starts
GroupeZ-dev/zMenu · Build · attempt 1 · JDK 25
─────────────────────────────────────────────
`fix: correct the inventory click handler`
push on main · abc1234 by robie · triggered by robie
[ View run ] [ Commit ]

                    ↓ the same message is edited when the build finishes

✅ Build passed
GroupeZ-dev/zMenu · Build · attempt 1 · JDK 25
─────────────────────────────────────────────
`fix: correct the inventory click handler`
Tests 38 tests, all passing
Duration 1m 3s
─────────────────────────────────────────────
4 commit(s) in this build
```diff
+ abc1234: fix: correct the inventory click handler
+ 9f2e1a0: feat: add /zmenu reload
```
📎 zMenu-1.0.0.jar
[ View run ] [ Commit ]
```

</details>

## Quick start — composing it yourself

Every step above is an action you can call directly. This is the escape hatch when the workflow
is too opinionated — you control the job, the `permissions`, and anything you want to slot in
between:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write          # the reusable workflow cannot grant this; here you can
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0       # required by the changelog action

      - uses: GroupeZ-dev/actions/.github/actions/setup-build@v1

      - uses: GroupeZ-dev/actions/.github/actions/run-build@v1

      - run: ./scripts/my-own-step.sh    # anything you like, anywhere in the job

      - id: jar
        uses: GroupeZ-dev/actions/.github/actions/find-artifacts@v1

      - uses: GroupeZ-dev/actions/.github/actions/discord-notify@v1
        with:
          webhook: ${{ secrets.WEBHOOK_URL }}
          status: success
          file: ${{ steps.jar.outputs.path }}
          values: '{"repo": "${{ github.repository }}", "subject": "done"}'
```

---

## Actions

| Action | What it does |
|---|---|
| [`setup-build`](.github/actions/setup-build) | Detects Gradle or Maven, installs a JDK, configures caching |
| [`run-build`](.github/actions/run-build) | Runs the build, appending release or `-DEV` arguments by branch |
| [`find-artifacts`](.github/actions/find-artifacts) | Locates the output jar, excluding sources and javadoc |
| [`commit-metadata`](.github/actions/commit-metadata) | Commit subject, author, short SHA, PR link |
| [`changelog`](.github/actions/changelog) | Size-budgeted commit list for a notification |
| [`test-summary`](.github/actions/test-summary) | Parses Surefire or Gradle JUnit XML into counts |
| [`discord-notify`](.github/actions/discord-notify) | Renders a Components V2 template and posts, edits or attaches to a message |

---

## Customising the Discord message

Three levels, in increasing order of control:

**1. Change the wording and colour** — the built-in templates expose `{title}` and `{accent}`:

```yaml
with:
  status: success
  title: "🚀 Shipped"
  accent: "5793266"
```

**2. Supply your own templates** — point at a directory in your repository holding
`start.json`, `success.json` and `failure.json`:

```yaml
uses: GroupeZ-dev/actions/.github/workflows/build.yml@v1
with:
  project-name: "zMenu"
  discord-templates-dir: ".github/discord"
```

Copy [the built-ins](.github/actions/discord-notify/templates) as a starting point. Any
`{placeholder}` is substituted from `values`; see [docs/actions.md](docs/actions.md) for the list
the workflows supply.

**3. Pass raw JSON** — `template-json` on the action takes a payload inline.

---

## Versioning

Pin `@v1`. It moves to each `v1.x.y` release, so patches arrive without a change in your
repository, and a `v2` will never arrive silently.

```yaml
uses: GroupeZ-dev/actions/.github/workflows/build.yml@v1
```

The reusable workflows load their composite actions from `GroupeZ-dev/actions` at the
`actions-ref` input, which defaults to `main`. **Pin it to the tag you call the workflow with**
so both halves move together:

```yaml
with:
  project-name: "zMenu"
  actions-ref: "v1"
```

---

## Secrets

All four are optional. Each consuming step no-ops when its secret is absent, so a repository that
only builds needs none of them, and a forked pull request — which never receives secrets — stays
green instead of failing.

| Secret | Used for |
|---|---|
| `WEBHOOK_URL` | Discord notifications |
| `DISCORD_WEBHOOK_URL` | Alias for the above, for repositories already using that name |
| `MAVEN_USERNAME` | Maven publishing |
| `MAVEN_PASSWORD` | Maven publishing |

---

## Upgrading from the previous version

Existing callers keep working: every input that existed before has the same name, type and
meaning, and the three secrets are now optional rather than required.

Two things to check:

- **`java-version` now defaults to `25` in `publish.yml`** (it was `21`; `build.yml` was already
  `25`). The two workflows disagreed; they are unified upward, because the JDK a project *builds*
  with is not the floor it *ships* for. A Paper plugin compiled against a `paper-api` built for
  Java 25 cannot be read by an older `javac` at all, while the jar it produces still targets
  whatever `maven.compiler.release` or the Gradle toolchain says. **If you were relying on
  `publish.yml` giving you JDK 21, set `java-version: "21"` explicitly.**
- **`upload-artifact` replaces the hard-coded pull-request-only upload.** The default `pr-only`
  is the previous behaviour; `always` and `never` are new.

Fixed in this release: the Discord jar attachment silently sent nothing (`JAR_PATH` was written
but `jar_path` was read, and `$GITHUB_OUTPUT` keys are case sensitive); `publish.yml` notified on
pull requests while `build.yml` did not; and the artifact search assumed a Maven `target/` layout
even for Gradle projects.

---

## Development

To see a notification before any of it reaches CI, [`test/preview-discord.sh`](test/preview-discord.sh)
runs the real action locally. It renders only — nothing is sent — until you pass `--send`:

```bash
./test/preview-discord.sh                                # preview, sends nothing
./test/preview-discord.sh --status failure               # the failure template
./test/preview-discord.sh --file build/libs/app.jar      # with the jar attached
./test/preview-discord.sh --send "$WEBHOOK" --lifecycle  # post, then edit it in place
```

On Windows use the wrapper — PowerShell cannot execute a `.sh` file, and bare `bash` there
usually resolves to WSL rather than Git Bash, so the script appears to do nothing at all:

```powershell
.\test\preview-discord.ps1 --status failure
```

It extracts the script straight out of `discord-notify/action.yml`, so the preview is exactly what
CI would send. Needs `jq` (`winget install jqlang.jq`), `curl` and Python with PyYAML.

[`self-test.yml`](.github/workflows/self-test.yml) runs `actionlint` over every workflow and
action, plus a job that exercises `discord-notify` for real: it checks the no-webhook no-op stays
green, and — where a `SELFTEST_WEBHOOK_URL` secret exists — posts a message and edits it in place
to confirm the lifecycle works end to end.

The build-tool actions are not covered by CI here; exercising them needs a real Java project, and
they are proven by the repositories that consume them.

Third-party actions are pinned to full SHAs with `# ratchet:` comments and updated by Renovate.

## License

[GPL-3.0](LICENSE)
