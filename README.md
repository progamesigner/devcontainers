# Development Containers

A development container allows you to use a container as a full-featured development environment. It can be used to run an application, to separate tools, libraries, or runtimes needed for working with a codebase, and to aid in continuous integration and testing. Dev containers can be run locally or remotely, in a private or public cloud.

## Images

```json
{
    "image": "ghcr.io/progamesigner/devcontainers/images/ubuntu:jammy"
}
```

| OS     | Version       | Image                                                   |
| ------ | ------------- | ------------------------------------------------------- |
| Ubuntu | Jammy (22.04) | ghcr.io/progamesigner/devcontainers/images/ubuntu:jammy |

## Features

To reference an image from this repository, add the desired features to a `devcontainer.json`.

All features are built from source as much as possible.

```json
{
    "features": {
        "ghcr.io/progamesigner/devcontainers/features/<feature>:latest": {}
    }
}

```
