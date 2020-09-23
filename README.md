# Docker image template

Description, intent, variants (if any).

## Usage

Base images should provide examples on how they can be extended:

```plaintext
FROM flywheel/image:tag
...
```

Utility images should include examples of running them instead:

```bash
docker run --rm -it flywheel/image ...
```

## Development

Install the `pre-commit` hooks before committing changes:

```bash
pre-commit install
```

To build the image locally:

```bash
docker build -t flywheel/image .
```

## Publishing

Images are published on every successful CI build to
[dockerhub](https://hub.docker.com/repository/docker/flywheel/image/tags?page=1&ordering=last_updated).

## License

Include the following license badge only for open source projects:

[![MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
