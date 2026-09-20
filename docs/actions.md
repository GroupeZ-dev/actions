# Action reference

Generated from the `action.yml` files — if this disagrees with them, they win.

Every input is optional unless marked **required**. Every action that can be a no-op (no webhook,
no artifacts, no test reports) succeeds quietly rather than failing, so a forked pull request or a
partial setup degrades instead of breaking the build.

## Contents

- [`setup-build`](#setup-build)
- [`run-build`](#run-build)
- [`find-artifacts`](#find-artifacts)
- [`commit-metadata`](#commit-metadata)
- [`changelog`](#changelog)
- [`test-summary`](#test-summary)
- [`discord-notify`](#discord-notify)
- [Reusable workflows](#reusable-workflows)
- [Template placeholders](#template-placeholders)

---

## `setup-build`

Detect the build tool, install a JDK and configure dependency caching for either Gradle or Maven.

```yaml
uses: GroupeZ-dev/actions/.github/actions/setup-build@v1
```

### Inputs

| Input | Default | Description |
|---|---|---|
| `build-tool` | `auto` | `auto`, `gradle` or `maven`. |
| `java-version` | `25` | JDK version to install. 25 is a *build* requirement for projects compiled against a Java 25 artifact such as a recent paper-api; the jar a project produces can still target an older release via its own compiler settings. |
| `java-distribution` | `temurin` | JDK distribution. |
| `cache` | `true` | Enable dependency caching. Gradle caches through gradle/actions/setup-gradle, Maven through actions/setup-java's own cache. |
| `gradle-opts` | `-Dorg.gradle.caching=true -Dorg.gradle.para…` | Value for GRADLE_OPTS. Applies to the whole job, not just this step. |
| `server-id` | `github` | Maven server id written into the generated settings.xml. |
| `settings-path` | — | Where actions/setup-java writes settings.xml. Empty uses its default. |
| `working-directory` | `.` | Directory to detect the build tool in. |

### Outputs

| Output | Description |
|---|---|
| `build-tool` | The resolved build tool, `gradle` or `maven`. |
| `java-version` | The JDK version that was installed. |
| `wrapper` | Path to the detected wrapper script, empty when there is none. |

---

## `run-build`

Run a Gradle or Maven command, appending release or development arguments depending on whether the run is on the default branch.

```yaml
uses: GroupeZ-dev/actions/.github/actions/run-build@v1
```

### Inputs

| Input | Default | Description |
|---|---|---|
| `build-tool` | `auto` | `auto`, `gradle` or `maven`. Only used to pick the default command. |
| `command` | — | Command to run. Empty resolves per build tool: Gradle `./gradlew build`, Maven `./mvnw -B --no-transfer-progress verify`. Set this to escape the abstraction entirely. |
| `tasks` | — | Appended to the resolved command. Lets a caller keep the default command and just name the tasks, e.g. `API:publish`. |
| `dev-args` | `-Darchive.classifier=DEV -Dgithub.sha={sha}` | Arguments appended off the default branch. {sha} is substituted with the short SHA. The -D syntax is identical for Gradle and Maven, so the same convention covers both. |
| `release-args` | — | Arguments appended on the default branch. {sha} is substituted. |
| `default-branch` | `main` | Branch treated as the release branch. |
| `working-directory` | `.` | Directory to run the command in. |
| `chmod-wrapper` | `true` | Run chmod +x on the wrapper script first. |

### Outputs

| Output | Description |
|---|---|
| `is-default-branch` | `true` when the current ref is the default branch. |
| `sha-short` | Abbreviated commit SHA. |
| `command` | The command that was actually executed. |

---

## `find-artifacts`

Locate build output jars for either a Maven or a Gradle layout, excluding the sources and javadoc jars that would otherwise be picked first.

```yaml
uses: GroupeZ-dev/actions/.github/actions/find-artifacts@v1
```

### Inputs

| Input | Default | Description |
|---|---|---|
| `build-tool` | `auto` | `auto`, `gradle` or `maven`. Only used to pick the default glob. |
| `glob` | — | Glob for build output, relative to the working directory. Empty resolves per build tool: Maven `**/target/*.jar`, Gradle `**/build/libs/*.jar`. |
| `exclude` | `*-sources.jar,*-javadoc.jar,original-*.jar` | Comma-separated filename patterns to drop. The defaults matter: a project that attaches sources and javadoc jars would otherwise have one of those selected first. |
| `max-files` | `1` | Maximum number of paths to return. 0 means unlimited. |
| `working-directory` | `.` | Directory to search from. |
| `fail-if-none` | `false` | Fail when nothing matched, instead of returning empty outputs. |

### Outputs

| Output | Description |
|---|---|
| `path` | First matching file, empty when nothing matched. |
| `paths` | All matching files, newline separated. |
| `name` | Basename of the first match. |
| `count` | Number of matches. |
| `total-bytes` | Combined size of the returned files. |

---

## `commit-metadata`

Collect the commit subject, author, short SHA and a pre-rendered pull request link for use in notifications and job summaries.

```yaml
uses: GroupeZ-dev/actions/.github/actions/commit-metadata@v1
```

### Inputs

| Input | Default | Description |
|---|---|---|
| `subject-source` | `auto` | Where the subject comes from. `auto` prefers the pull request title, because on a PR the checked-out HEAD is a synthetic merge commit whose subject is "Merge <sha> into <sha>" and is useless in a notification. `commit` always reads the commit, `pr` fails over to the commit only when there is no PR. |
| `avatar-size` | `64` | Pixel size for the actor avatar URL. |

### Outputs

| Output | Description |
|---|---|
| `subject` | Commit subject or pull request title, newlines collapsed. |
| `author` | Commit author name. |
| `sha-short` | Abbreviated commit SHA. |
| `pr-number` | Pull request number, empty on a push. |
| `pr-url` | Pull request URL, empty on a push. |
| `pr-suffix` | Pre-rendered markdown fragment such as " · [#12](https://…)", empty on a push. Notification templates are static JSON, so a conditional link is far simpler as a string that is simply empty than as a component that must be added or removed. |
| `actor-avatar` | Avatar URL for the triggering actor. |
| `commit-url` | URL of the commit. |
| `run-url` | URL of this workflow run. |

---

## `changelog`

Build a size-budgeted list of the commits in this build, ready to drop into a Discord message or a job summary.

```yaml
uses: GroupeZ-dev/actions/.github/actions/changelog@v1
```

### Inputs

| Input | Default | Description |
|---|---|---|
| `budget` | `1500` | Maximum characters for the rendered block. Discord publishes a 40-component cap but no total character budget; 1500 stays safe even against the legacy 2000-character message limit. Raise it if your server accepts more. |
| `fallback-count` | `10` | How many commits to list when no usable range can be determined. |
| `format` | `diff` | `diff` (fenced diff block), `markdown` (bullet list) or `plain`. |
| `line-template` | `{sha}: {subject}` | Per-commit line. {sha} and {subject} are substituted. |
| `include-merges` | `false` | Include merge commits. |
| `exclude-pattern` | — | Extended regex; matching subjects are dropped. Useful for filtering dependency bumps, e.g. '^build\(deps\)'. |
| `empty-text` | `-# No commits in range.` | Rendered when the range contains no commits. |

### Outputs

| Output | Description |
|---|---|
| `block` | The rendered changelog block. |
| `count` | Total commits in range. |
| `shown` | Commits that fit inside the budget. |
| `range` | The git range that was used. |

---

## `test-summary`

Parse JUnit XML test reports from Maven Surefire or Gradle and produce a one-line summary plus per-category counts.

```yaml
uses: GroupeZ-dev/actions/.github/actions/test-summary@v1
```

### Inputs

| Input | Default | Description |
|---|---|---|
| `build-tool` | `auto` | `auto`, `gradle` or `maven`. Only used to pick the default report glob. |
| `report-glob` | — | Glob for the JUnit XML reports. Empty resolves per build tool: Maven `**/target/surefire-reports/TEST-*.xml`, Gradle `**/build/test-results/**/TEST-*.xml`. Gradle writes the same schema, so one parser covers both. |
| `write-job-summary` | `false` | Append a small table to the GitHub job summary. |
| `working-directory` | `.` | Directory to search from. |

### Outputs

| Output | Description |
|---|---|
| `summary` | Human-readable summary, e.g. '38 tests, all passing'. |
| `tests` | Total tests. |
| `failures` | Assertion failures. |
| `errors` | Errors. |
| `skipped` | Skipped tests. |
| `passed` | true when at least one test ran and none failed or errored. |

---

## `discord-notify`

Render a Discord Components V2 payload from a template and post it, edit an existing message, or attach a build artifact to it.

```yaml
uses: GroupeZ-dev/actions/.github/actions/discord-notify@v1
```

### Inputs

| Input | Default | Description |
|---|---|---|
| `webhook` | — | Discord webhook URL. When empty the action does nothing and succeeds. |
| `status` | — | Selects one of the built-in templates: start, success or failure. Ignored when `template` or `template-json` is set. |
| `template` | — | Path to a JSON template containing {placeholder} tokens, relative to the workspace. Overrides `status`, so a consumer can supply their own house style. |
| `template-json` | — | Raw inline JSON template. Overrides both `template` and `status`. |
| `values` | `{}` | JSON object of placeholder name to replacement value. |
| `title` | — | Heading for the {title} placeholder. Defaults per `status` when empty. |
| `accent` | — | Accent colour for the {accent} placeholder, as a decimal integer. Defaults per `status`. |
| `message-id` | — | Existing message to edit. When empty, a new message is posted. |
| `username` | — | Display name to post under, overriding the webhook's configured name. Applied only when creating a message: Discord does not accept username on an edit, so a message that is later edited keeps the name it was posted with. Empty uses the webhook's own name. |
| `avatar-url` | — | Avatar image URL to post with, overriding the webhook's configured avatar. Same create-only restriction as `username`. Empty uses the webhook's own avatar. |
| `file` | — | Path to a file to attach. A File component referencing it is injected into the payload, because Discord discards an attachment no component references once the Components V2 flag is set. Empty attaches nothing. |
| `file-max-bytes` | `9437184` | Skip the attachment when the file exceeds this size, rather than failing. Discord's webhook limit is 10 MiB on an unboosted guild. |
| `strip-unknown-placeholders` | `true` | Blank out any {placeholder} the values object did not supply. |
| `fail-on-error` | `true` | Exit non-zero when Discord rejects the message. The step still goes red either way. |

### Outputs

| Output | Description |
|---|---|
| `message-id` | The id of the posted or edited message, empty if nothing was sent. |

---

## Reusable workflows

### `build.yml`

```yaml
uses: GroupeZ-dev/actions/.github/workflows/build.yml@v1
```

| Input | Default | Description |
|---|---|---|
| `project-name` **required** | — | Project Name (e.g. zMenu) |
| `java-version` | `25` | Optional java version |
| `java-distribution` | `temurin` | Optional java distribution |
| `default-branch` | `main` | Default branch to check for releases |
| `runs-on` | `['ubuntu-latest']` | Optional label for the runner to run on |
| `build-tool` | `auto` | `auto`, `gradle` or `maven`. `auto` detects from the repository layout. |
| `build-command` | — | Optional build command to run. Empty resolves per build tool: Gradle `./gradlew build`, Maven `./mvnw -B --no-transfer-progress verify`. |
| `dev-args` | `-Darchive.classifier=DEV -Dgithub.sha={sha}` | Arguments appended off the default branch. {sha} is substituted. |
| `release-args` | — | Arguments appended on the default branch. {sha} is substituted. |
| `working-directory` | `.` | Directory to build in |
| `gradle-opts` | `-Dorg.gradle.caching=true -Dorg.gradle.para…` | Value for GRADLE_OPTS |
| `cache` | `True` | Enable dependency caching |
| `timeout-minutes` | `20` | Job timeout. A hung build would otherwise burn the full 6 hour default. |
| `fetch-depth` | `0` | Checkout depth. The changelog walks a commit range and cannot resolve one from a shallow clone, so 0 is the default. |
| `publish` | `False` | If a package should be published to maven |
| `project-to-publish` | `publish` | Name of the project to publish (e.g. API:publish) |
| `publish-command` | — | Command used for publishing. Empty resolves per build tool, with `project-to-publish` appended as the task. |
| `publish-release-args` | `-Drepository.name=releases` | Arguments appended to the publish command on the default branch. |
| `artifact-glob` | — | Glob for build output. Empty resolves per build tool: Maven `**/target/*.jar`, Gradle `**/build/libs/*.jar`. |
| `artifact-exclude` | `*-sources.jar,*-javadoc.jar,original-*.jar` | Comma-separated filename patterns to exclude from the artifact search. |
| `upload-artifact` | `pr-only` | `pr-only`, `always` or `never`. |
| `artifact-path` | — | Path uploaded to GitHub Actions artifacts. Empty uses the build output directory. |
| `artifact-retention-days` | `7` | Retention for uploaded artifacts. |
| `publish-on-discord` | `True` | If a message should be sent to discord on build completion |
| `discord-notify-on` | `push` | `push` notifies only outside pull requests (the historical behaviour), `always` notifies everywhere, `never` disables notifications. |
| `discord-lifecycle` | `edit` | `edit` posts a "build running" message and edits it into the result, so one message transitions in place. `result-only` posts a single message at the end. |
| `discord-username` | — | Webhook display name. Empty uses the project name. |
| `discord-avatar-url` | `https://github.com/GroupeZ-dev.png` | Webhook avatar. Defaults to the GroupeZ-dev GitHub organisation avatar, which is always reachable; Discord silently falls back to the webhook's own picture when a URL 404s. |
| `discord-templates-dir` | — | Directory in the calling repository holding start.json, success.json and failure.json. Empty uses the templates shipped with this action. |
| `discord-attach-jar` | `True` | Attach the built jar to the Discord message. |
| `discord-file-max-bytes` | `9437184` | Skip the attachment above this size rather than failing. |
| `changelog-enabled` | `True` | Include a commit changelog in the notification. |
| `changelog-budget` | `1500` | Maximum characters for the rendered changelog. |
| `changelog-format` | `diff` | `diff`, `markdown` or `plain`. |
| `changelog-exclude-pattern` | — | Extended regex; matching commit subjects are dropped. |
| `run-tests-summary` | `True` | Parse JUnit reports and report test counts. |
| `actions-ref` | `main` | Ref of GroupeZ-dev/actions to load the composite actions from. Pin this to the same tag you call this workflow with. |

**Secrets** (all optional): `WEBHOOK_URL`, `DISCORD_WEBHOOK_URL`, `MAVEN_USERNAME`, `MAVEN_PASSWORD`

**Outputs**: `artifact-path`, `artifact-name`, `test-summary`, `is-default-branch`, `discord-message-id`

### `publish.yml`

```yaml
uses: GroupeZ-dev/actions/.github/workflows/publish.yml@v1
```

| Input | Default | Description |
|---|---|---|
| `project-name` **required** | — | Project Name (e.g. zMenu) |
| `java-version` | `25` | Optional java version |
| `java-distribution` | `temurin` | Optional java distribution |
| `default-branch` | `main` | Default branch to check for releases |
| `runs-on` | `['ubuntu-latest']` | Optional label for the runner to run on |
| `publish` | `True` | If a package should be published to maven |
| `project-to-publish` | `publish` | Name of the project to publish (e.g. API:publish) |
| `publish-command` | — | Command used for publishing. Empty resolves per build tool, with `project-to-publish` appended as the task. |
| `release-args` | `-Drepository.name=releases` | Arguments appended on the default branch. {sha} is substituted. |
| `dev-args` | `-Darchive.classifier=DEV -Dgithub.sha={sha}` | Arguments appended off the default branch. {sha} is substituted. |
| `build-tool` | `auto` | `auto`, `gradle` or `maven`. |
| `working-directory` | `.` | Directory to publish from |
| `gradle-opts` | `-Dorg.gradle.caching=true -Dorg.gradle.para…` | Value for GRADLE_OPTS |
| `cache` | `True` | Enable dependency caching |
| `timeout-minutes` | `20` | Job timeout |
| `fetch-depth` | `0` | Checkout depth. 0 is required for the changelog. |
| `artifact-glob` | — | Glob for build output. Empty resolves per build tool. |
| `artifact-exclude` | `*-sources.jar,*-javadoc.jar,original-*.jar` | Comma-separated filename patterns to exclude. |
| `publish-on-discord` | `True` | If a message should be sent to discord on completion |
| `discord-notify-on` | `always` | `always`, `push` or `never`. |
| `discord-lifecycle` | `edit` | `edit` or `result-only`. |
| `discord-username` | — | Webhook display name. Empty uses the project name. |
| `discord-avatar-url` | `https://github.com/GroupeZ-dev.png` | Webhook avatar. Defaults to the GroupeZ-dev GitHub organisation avatar, which is always reachable; Discord silently falls back to the webhook's own picture when a URL 404s. |
| `discord-templates-dir` | — | Directory in the calling repository holding the JSON templates. |
| `discord-attach-jar` | `True` | Attach the published jar to the Discord message. |
| `discord-file-max-bytes` | `9437184` | Skip the attachment above this size rather than failing. |
| `changelog-enabled` | `True` | Include a commit changelog in the notification. |
| `changelog-budget` | `1500` | Maximum characters for the rendered changelog. |
| `changelog-format` | `diff` | `diff`, `markdown` or `plain`. |
| `changelog-exclude-pattern` | — | Extended regex; matching commit subjects are dropped. |
| `actions-ref` | `main` | Ref of GroupeZ-dev/actions to load the composite actions from. |

**Secrets** (all optional): `WEBHOOK_URL`, `DISCORD_WEBHOOK_URL`, `MAVEN_USERNAME`, `MAVEN_PASSWORD`

**Outputs**: `artifact-path`, `is-default-branch`, `discord-message-id`

---

## Template placeholders

The values both reusable workflows supply to `discord-notify`. Any of these can be used in a
custom template; anything a template asks for that is not supplied is blanked rather than shipped
as literal braces.

| Placeholder | Example | Notes |
|---|---|---|
| **Presentation** | | |
| `{title}` | `✅ Build passed` | Override with the `title` input |
| `{accent}` | `3066993` | Override with `accent`. Renders as a **number**, not a string |
| **Project** | | |
| `{project}` | `zMenu` | The `project-name` input |
| `{repo}` | `GroupeZ-dev/zMenu` | |
| `{repo_name}` | `zMenu` | Repository without the owner |
| `{repo_owner}` | `GroupeZ-dev` | |
| `{repo_url}` | `https://github.com/GroupeZ-dev/zMenu` | |
| **Run** | | |
| `{workflow}` | `Build` | |
| `{event}` | `push` | |
| `{attempt}` | `1` | |
| `{run_id}` | `17420962` | |
| `{run_number}` | `128` | |
| `{url}` | Run URL | |
| `{status}` | `running`, `success`, `failure` | |
| `{runner_os}` | `Linux` | |
| **Branch and commit** | | |
| `{ref}` | `main` | Branch or tag name |
| `{ref_type}` | `branch` | |
| `{default_branch}` | `main` | |
| `{sha}` | `abc1234` | Abbreviated |
| `{sha_full}` | `abc1234def…` | Full 40 characters |
| `{subject}` | `fix: correct the click handler` | PR title on a pull request |
| `{author}` | `1robie` | Commit author |
| `{commit_url}` | Commit URL | |
| `{compare_url}` | Compare link for the range | Empty when there is no base to compare |
| `{commit_range}` | `9f2e1a0..HEAD` | |
| **Pull request** | | |
| `{pr}` | ` · [#12](…)` | Pre-rendered markdown, empty on a push |
| `{pr_number}` | `12` | Empty on a push |
| `{pr_url}` | PR URL | Empty on a push |
| **Actor** | | |
| `{actor}` | `1robie` | Who triggered the run |
| `{actor_url}` | `https://github.com/1robie` | |
| `{avatar}` | Avatar URL | Supplied, but the built-ins no longer render it — see below |
| **Build** | | |
| `{java}` | `25` | |
| `{build_tool}` | `gradle` or `maven` | Resolved, even when `auto` |
| **Tests** | | |
| `{tests}` | `38 tests, all passing` | Human summary |
| `{tests_total}` | `38` | |
| `{tests_failed}` | `0` | |
| `{tests_errors}` | `0` | |
| `{tests_skipped}` | `0` | |
| `{tests_passed}` | `true` | |
| **Timing** | | |
| `{duration}` | `1m 3s` | |
| `{duration_seconds}` | `63` | |
| `{started_at}` / `{finished_at}` | `2026-09-15T10:04:00Z` | ISO 8601 UTC |
| `{started_epoch}` / `{finished_epoch}` | `1789200240` | Unix seconds |
| `{started_at_discord}` / `{finished_at_discord}` | `<t:1789200240:F>` | Discord renders this in each viewer's own timezone |
| `{started_relative}` / `{finished_relative}` | `<t:1789200240:R>` | Renders as a live "3 minutes ago" |
| **Artifacts** | | |
| `{artifact}` | `zMenu-1.0.0.jar` | Filename of the primary artifact |
| `{artifact_size}` | `3.4 MiB` | Pre-formatted |
| `{artifact_bytes}` | `3565158` | |
| `{artifact_count}` | `1` | |
| `{attachment}` | `attachment://zMenu-1.0.0.jar` | Empty when nothing is attached — see **Attachments** |
| **Changelog** | | |
| `{changelog}` | Fenced diff block | |
| `{commits}` | `4` | Total in range |
| `{commits_shown}` | `4` | How many fitted in the budget |

The "build running" message supplies everything above except the test, timing, artifact and
`finished_*` values, which do not exist yet — those render empty there.

A string that is *exactly* one placeholder keeps the value's JSON type, which is how
`"accent_color": "{accent}"` renders as a number. Everywhere else the value is interpolated as
text.

### Pictures

`avatar-url` sets the **webhook's** picture — the one beside the bot name at the top of the
message. A broken value here is invisible: Discord silently falls back to the picture configured
on the webhook itself rather than reporting an error, so check the URL actually serves an image
before blaming the payload.

`{avatar}` is separate — the GitHub avatar of whoever triggered the run. The built-in templates
**no longer display it**, because a Thumbnail is rendered at a fixed size by the Discord client
(type 11 has no `size`, `width` or `height` field) and it dominated the message. The person is
still credited by name in the footer line. The value is still passed, so a custom template can
show it by putting the heading in a Section with a Thumbnail accessory:

```json
{
  "type": 9,
  "components": [{ "type": 10, "content": "### {title}" }],
  "accessory": { "type": 11, "media": { "url": "{avatar}" }, "description": "{actor}" }
}
```

### Attachments

Set `file` and the action injects a File component (type `13`) pointing at `attachment://<name>`
plus the matching `attachments` entry, then sends the request as multipart. This is required:
Discord discards an attachment that no component references once the Components V2 flag is set.
Files above `file-max-bytes` (9 MiB by default) are skipped with a note in the message instead of
failing the build, because the webhook limit is 10 MiB on an unboosted guild.

A template can place the File component **anywhere** — first, between two text blocks, or after
the buttons — as long as its url is the `{attachment}` placeholder:

```json
{ "type": 13, "file": { "url": "{attachment}" }, "spoiler": false }
```

The action fills it in when a file is being sent and deletes it when there is not, wherever it
sits. Use the placeholder rather than a literal `attachment://name.jar`: Discord rejects a File
component pointing at an attachment that was never uploaded, which is what happens on any build
that produced no jar.

Omit the component entirely and one is inserted for you immediately before the first ActionRow.

### Editing versus posting

Pass `message-id` and the action PATCHes that message; leave it empty and it POSTs a new one. If
an edit fails — the message was deleted, the id is stale, or the secret only appeared mid-run —
it falls back to posting, because a fresh message beats reporting nothing.

`username` and `avatar-url` are Execute Webhook parameters and are **not** in Edit Webhook
Message's editable set, so they apply only when a message is created. A message keeps the identity
it was posted with.
