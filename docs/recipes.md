# Recipes

Worked examples. Full input lists are in [actions.md](actions.md).

---

## Gradle plugin, default everything

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
      actions-ref: "v1"
    secrets: inherit
```

## Gradle plugin that publishes to Maven on the default branch

```yaml
jobs:
  build:
    uses: GroupeZ-dev/actions/.github/workflows/build.yml@v1
    with:
      project-name: "zMenu"
      publish: true
      project-to-publish: "API:publish"
    secrets:
      WEBHOOK_URL: ${{ secrets.WEBHOOK_URL }}
      MAVEN_USERNAME: ${{ secrets.MAVEN_USERNAME }}
      MAVEN_PASSWORD: ${{ secrets.MAVEN_PASSWORD }}
```

On the default branch this runs `./gradlew API:publish -Drepository.name=releases`; elsewhere it
appends `-Darchive.classifier=DEV -Dgithub.sha=<short>` instead.

## Multi-module Maven library

`auto` detection picks Maven from `pom.xml` / `mvnw`, and the default JDK 25 already covers a
project built against a Java 25 `paper-api`, so usually nothing needs saying. A project that
attaches sources and javadoc jars gets them excluded from the artifact search by default:

```yaml
jobs:
  build:
    uses: GroupeZ-dev/actions/.github/workflows/build.yml@v1
    with:
      project-name: "paper-dispatch"
      build-command: "./mvnw -B --no-transfer-progress verify"
      artifact-glob: "Lib/src/target/*.jar"
    secrets: inherit
```

## Keep dependency bumps out of the changelog

```yaml
with:
  project-name: "zMenu"
  changelog-exclude-pattern: '^[a-f0-9]+\s+(build|chore)\(deps\)'
  changelog-budget: 2500
```

## Your own Discord look

Copy the [built-in templates](../.github/actions/discord-notify/templates) into your repository,
edit them, and point the workflow at the directory:

```yaml
with:
  project-name: "zMenu"
  discord-templates-dir: ".github/discord"
```

The directory must contain `start.json`, `success.json` and `failure.json`. Keep
`"flags": 32768` in each: it marks the message as Components V2, and every template has to be
independently postable for the POST fallback to work when an edit fails.

### Placing the attached jar

Put a File component with `"url": "{attachment}"` wherever you want the jar to appear — the
position is entirely yours, including after the button row:

```json
{
  "type": 13,
  "file": { "url": "{attachment}" },
  "spoiler": false
}
```

The action fills the URL in when there is a file and **deletes the component** when there is not
— a build with no jar, `discord-attach-jar: false`, or a jar over `discord-file-max-bytes`. That
is why it has to be a placeholder rather than a hard-coded `attachment://…`: Discord rejects a
File component pointing at an attachment that was never uploaded.

Omit the component entirely and the action inserts one for you, immediately before the first
ActionRow.

Do not include `proxy_url`: Discord sets that on the response, and sending it does nothing.

For a smaller change, stay on the built-ins and override just the heading and colour:

```yaml
- uses: GroupeZ-dev/actions/.github/actions/discord-notify@v1
  with:
    webhook: ${{ secrets.WEBHOOK_URL }}
    status: success
    title: "🚀 Deployed to production"
    accent: "5793266"
```

## Quieter notifications

```yaml
with:
  project-name: "zMenu"
  discord-lifecycle: "result-only"   # no "build running" message, one message at the end
  discord-notify-on: "push"          # nothing on pull requests (the default)
  discord-attach-jar: false          # link to the run instead of uploading the jar
```

## Upload the jar to GitHub artifacts on every run

```yaml
with:
  project-name: "zMenu"
  upload-artifact: "always"
  artifact-retention-days: 30
```

---

## Composing the actions yourself

Reach for this when the reusable workflow cannot express what you need — most often extra
`permissions`, which a reusable workflow cannot take as an input.

### A build with a signing step in the middle

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - id: meta
        uses: GroupeZ-dev/actions/.github/actions/commit-metadata@v1

      - id: changelog
        uses: GroupeZ-dev/actions/.github/actions/changelog@v1

      - id: start
        uses: GroupeZ-dev/actions/.github/actions/discord-notify@v1
        continue-on-error: true
        with:
          webhook: ${{ secrets.WEBHOOK_URL }}
          status: start
          values: |
            {
              "repo": ${{ toJSON(github.repository) }},
              "subject": ${{ toJSON(steps.meta.outputs.subject) }},
              "sha": ${{ toJSON(steps.meta.outputs.sha-short) }},
              "url": ${{ toJSON(steps.meta.outputs.run-url) }}
            }

      - uses: GroupeZ-dev/actions/.github/actions/setup-build@v1

      - uses: GroupeZ-dev/actions/.github/actions/run-build@v1

      - id: jar
        uses: GroupeZ-dev/actions/.github/actions/find-artifacts@v1

      - name: Sign the jar
        run: cosign sign-blob --yes "${{ steps.jar.outputs.path }}"

      - id: tests
        if: always()
        uses: GroupeZ-dev/actions/.github/actions/test-summary@v1

      - if: always()
        uses: GroupeZ-dev/actions/.github/actions/discord-notify@v1
        continue-on-error: true
        with:
          webhook: ${{ secrets.WEBHOOK_URL }}
          status: ${{ job.status == 'success' && 'success' || 'failure' }}
          message-id: ${{ steps.start.outputs.message-id }}
          file: ${{ steps.jar.outputs.path }}
          values: |
            {
              "repo": ${{ toJSON(github.repository) }},
              "subject": ${{ toJSON(steps.meta.outputs.subject) }},
              "sha": ${{ toJSON(steps.meta.outputs.sha-short) }},
              "tests": ${{ toJSON(steps.tests.outputs.summary) }},
              "changelog": ${{ toJSON(steps.changelog.outputs.block) }},
              "commits": ${{ toJSON(steps.changelog.outputs.count) }},
              "url": ${{ toJSON(steps.meta.outputs.run-url) }}
            }
```

Points worth copying:

- **`fetch-depth: 0`.** `changelog` walks a commit range, and checkout's default shallow clone
  cannot resolve one. The action warns when it detects a shallow clone, but the changelog will be
  empty.
- **Both notify steps are `continue-on-error: true`.** A Discord outage or a rotated webhook must
  never fail a build. Steps that fail this way do not mark the job failed, so `job.status` stays
  meaningful for the result template.
- **The result step is `if: always()`** and picks its template from `job.status`, so one step
  covers success and failure.
- **Pass `message-id`** from the start step and the running message is edited into the result
  rather than a second message appearing.

### Notify only, no build

`discord-notify` stands alone — use it to announce a deploy, a release, anything:

```yaml
- uses: GroupeZ-dev/actions/.github/actions/discord-notify@v1
  with:
    webhook: ${{ secrets.WEBHOOK_URL }}
    template-json: |
      {
        "flags": 32768,
        "components": [{
          "type": 17,
          "accent_color": "{accent}",
          "components": [
            {"type": 10, "content": "### 🚀 {project} {version} released"},
            {"type": 1, "components": [
              {"type": 2, "label": "Release notes", "style": 5, "url": "{url}"}
            ]}
          ]
        }]
      }
    accent: "5763719"
    values: |
      {
        "project": "zMenu",
        "version": ${{ toJSON(github.ref_name) }},
        "url": ${{ toJSON(github.event.release.html_url) }}
      }
```

---

## Troubleshooting

**The Discord message never arrives, and the step is green.** The webhook is empty. That is the
deliberate no-op path for forked pull requests, which never receive secrets. Check the secret name
— `WEBHOOK_URL` or `DISCORD_WEBHOOK_URL` — and that you passed `secrets: inherit` or listed it.

**`Cannot send an empty message` (error 50006).** Discord discarded the components array. Every
template needs `"flags": 32768`, and the action always sends `with_components=true`; if you
replaced the template, check the flag.

**The changelog is empty.** `fetch-depth: 0` is missing on checkout.

**The wrong jar is attached.** Adjust `artifact-glob`, or add to `artifact-exclude`. The defaults
drop `*-sources.jar`, `*-javadoc.jar` and `original-*.jar`; among what remains the newest file
wins.

**The build ran with the wrong tool.** A repository containing both `pom.xml` and `build.gradle`
resolves to Maven, with a notice in the log. Set `build-tool` explicitly.

**A second message appears instead of the first being edited.** The edit failed and the action
fell back to posting. The log carries a warning naming the cause — usually a deleted message or a
stale id.
