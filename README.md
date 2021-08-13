# flywheel/qa-ci

QA/CI image with a plethora of linters and tools for pre-commit hooks and GitLab
CI jobs defined in [tools/etc/qa-ci](https://gitlab.com/flywheel-io/tools/etc/qa-ci).

## Usage

### `test:flywheel-lint`

The `test:flywheel-lint` pre-commit hook / CI job contains a pre-defined set of
linters, style checkers and formatters aimed at the Flywheel stack.

To run the linting in debug mode on any project folder:

```bash
docker run --rm -tv $(pwd):/src -w /src -e TRACE=1 flywheel/qa-ci /lint/run.sh
```

#### Lint tools

- [`black`](https://github.com/psf/black)
- [`hadolint`](https://github.com/hadolint/hadolint)
- [`jsonlint`](https://www.npmjs.com/package/jsonlint)
- [`markdownlint`](https://github.com/DavidAnson/markdownlint)
- [`pydocstyle`](https://github.com/PyCQA/pydocstyle)
- [`safety`](https://github.com/pyupio/safety)
- [`shellcheck`](https://github.com/koalaman/shellcheck)
- [`yamllint`](https://github.com/adrienverge/yamllint)

#### Lint config

Arguments passed to the linters can be extended (or overridden) using environment
variables, which are read from a `.env` file at the project root if present. For
example, to ignore an error in `shellcheck`, add the following to your `.env`:

```bash
# add an extra exclude, leaving any default args intact
SHELLCHECK_EXTRA="--exclude=SC2061"
```

The default arguments passed to the tools are recommended to be kept as-is, but
can also be overridden by using the `_ARGS` envvars (instead of `_EXTRA`):

```bash
# override the default google convention (see defaults below)
PYDOCSTYLE_ARGS="--convention=pep257"
```

Finally, the individual tools may support loading further custom settings from a
default config location if it exists at the project root:

<!-- markdownlint-disable MD013 -->
| Tool           | Envvar in `.env`            | Default `ARGS`                      | Config file |
| :------------- | :-------------------------- | :---------------------------------- | :---------- |
| `black`        | `BLACK_EXTRA`/`ARGS`        | none                                | [`pyproject.toml`](https://github.com/psf/black#configuration-format)|
| `hadolint`     | `HADOLINT_EXTRA`/`ARGS`     | `--ignore DL3005 --ignore DL3059`   | [`.hadolint.yaml`](https://github.com/hadolint/hadolint#configure)|
| `jsonlint`     | `JSONLINT_EXTRA`/`ARGS`     | `--in-place --insert-final-newline` | none |
| `markdownlint` | `MARKDOWNLINT_EXTRA`/`ARGS` | `--fix`                             | [`.markdownlint.json`](https://github.com/DavidAnson/markdownlint#optionsconfig)|
| `pydocstyle`   | `PYDOCSTYLE_EXTRA`/`ARGS`   | `--convention=google`               | [`.pydocstyle.ini`](http://www.pydocstyle.org/en/stable/snippets/config.html)|
| `shellcheck`   | `SHELLCHECK_EXTRA`/`ARGS`   | `--external-sources --color=always` | [`.shellcheckrc`](https://github.com/koalaman/shellcheck/blob/master/shellcheck.1.md#rc-files)|
| `yamllint`     | `YAMLLINT_EXTRA`/`ARGS`     | `-f colored`                        | [`.yamllint.yml`](https://yamllint.readthedocs.io/en/stable/configuration.html#extending-the-default-configuration)|
<!-- markdownlint-enable -->

If not present, the following config files are auto-injected:

- [`.markdownlint.json`](qa_ci/lint/.markdownlint.json)
- [`.yamllint.yml`](qa_ci/lint/.yamllint.yml)

### `test:helm-check`

The `test:helm-check` pre-commit hook / CI job allows linting and validating
component Helm charts.

To run the helm checks in debug mode on any project folder with a helm chart:

```bash
docker run --rm -itv $(pwd):/src -w /src -e TRACE=1 flywheel/qa-ci /helm/run.sh
```

#### Helm checks

- Update the helm chart version to that of the poetry package or git repo
- Update the helm image tag to that same version
- Run `helm dep up` to make sure the dependencies are available and up-to-date
- Run [`helm-docs`](https://github.com/norwoodj/helm-docs) to get auto-generated
chart docs in `helm/<project>/README.md`
- Run [`helm lint`](https://helm.sh/docs/helm/helm_lint/)
- Run [`kubeval`](https://www.kubeval.com/)
- Run [`yamllint`](https://www.kubeval.com/) on the rendered tests

### `update:repo`

The `update:repo` pre-commit hook / CI job can update the project's

- `poetry.lock`
- `Dockerfile`
- `.gitlab-ci.yml`
- `.pre-commit-config.yaml`

To run the auto-update in debug mode on any project folder:

```bash
docker run --rm -itv $(pwd):/src -w /src -e TRACE=1 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    flywheel/qa-ci /ci/update_repo.sh
```

#### Update config

<!-- TODO refactor/unify the scripts and the envvars  -->
- `PIN_IMG` - set to `true` to skip updating the docker base image
- `GITLABCI_PIN` - set to `true` to skip gitlab-ci updates
- `PIN_PRECOMMIT_REFS` - set to `true` to skip pre-commit updates

## Development

```bash
pre-commit install
```

## Publishing

Images are published to [dockerhub](https://hub.docker.com/repository/docker/flywheel/qa-ci/tags?page=1&ordering=last_updated)
on every successful CI build:

## License

[![MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
