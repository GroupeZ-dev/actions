# Reusable Actions for GroupeZ

This repository contains a collection of [reusable actions](https://docs.github.com/en/actions/using-workflows/reusing-workflows) for GroupeZ.

## Available Actions

- [Build](./.github/workflows/build.yml)

This action is used to automatically build and send the jar on discord.

### Usage

```yaml
build:
  uses: GroupeZ-dev/actions/.github/workflows/build.yml@main
  with:
     project-name: "zMenu"
      java-version: "21" # Optional
      java-distribution: "temurin" # Optional
      publish: false # Optional
      project-to-publish: "publish" # Optional
      build-command: ./gradlew build # Optional
      discord-avatar-url: "https://minecraft-inventory-builder.com/storage/images/9UgcfGZyrmbVrXw5lbj5kXq6fW8F4nhwj6Cx4nVG.png" # Optional
      runs-on: "['ubuntu-latest']" # Optional
  secrets: inherit
  # or
  secrets:
    WEBHOOK_URL: ${{ secrets.WEBHOOK_URL }}
```
