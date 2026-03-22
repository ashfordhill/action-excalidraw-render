# action-excalidraw-render

Recursively scan a repository for `.excalidraw` files and auto-render them to `.svg` and/or `.png` — fully offline, no excalidraw.com required.

![test](./test.svg)



### Inputs

| Input | Description | Required | Default |
|---|---|---|---|
| `format` | Output format: `svg`, `png`, or `both` | No | `svg` |

## Workflow example

This workflow triggers on any push that modifies a `.excalidraw` file, then commits the rendered output.

```yaml
# .github/workflows/excalidraw-render.yml
name: Render Excalidraw

on:
  push:
    paths:
      - '**/*.excalidraw'

permissions:
  contents: write

jobs:
  render:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: ashfordhill/action-excalidraw-render@main
        with:
          format: 'svg'

      - name: Commit rendered files
        run: |
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git config user.name "github-actions[bot]"
          git add -A
          git diff --staged --quiet || git commit -m "chore: render excalidraw files [skip ci]"
          git push
```

## How it works

The action runs a local, self-hosted Excalidraw instance in Docker. It uses a headless browser (Playwright) to load each `.excalidraw` file, export it to the desired format, and save it next to the original. This all happens offline on the runner.

## Local testing

```sh
INPUT_FORMAT=both docker compose run --rm renderer
```

The included `docker-compose.yml` starts both containers locally. The rendered files are written to the current directory.

## Security

- No calls to `excalidraw.com` or any external service.
- No data leaves your runner.
- Suitable for air-gapped or enterprise environments.
