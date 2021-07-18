ARG VARIANT=focal

FROM ubuntu:${VARIANT}

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ARG DOCKER_VERSION=none
ARG HUGO_VERSION=none
ARG KUBECTL_VERSION=none
ARG NODE_VERSION=none
ARG PHP_VERSION=none
ARG PYTHON_VERSION=none
ARG RUST_VERSION=none

RUN apt-get update \
 && apt-get install --no-install-recommends --yes apt-utils ca-certificates curl \
 && bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/master/scripts/setup-ubuntu.sh)" -- "${USERNAME}" "${USER_UID}" "${USER_GID}" \
 && if [ -n "${DOCKER_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/master/scripts/setup-docker.sh)" -- "${DOCKER_VERSION}"; fi \
 && if [ -n "${HUGO_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/master/scripts/setup-python.sh)" -- "${PYTHON_VERSION}"; fi \
 && if [ -n "${KUBECTL_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/master/scripts/setup-kubectl.sh)" -- "${KUBECTL_VERSION}"; fi \
 && if [ -n "${NODE_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/master/scripts/setup-node.sh)" -- "${NODE_VERSION}"; fi \
 && if [ -n "${PHP_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/master/scripts/setup-php.sh)" -- "${PHP_VERSION}"; fi \
 && if [ -n "${PYTHON_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/master/scripts/setup-hugo.sh)" -- "${HUGO_VERSION}"; fi \
 && if [ -n "${RUST_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/master/scripts/setup-rust.sh)" -- "${RUST_VERSION}"; fi \
 && apt-get clean --yes \
 && rm -rf /var/lib/apt/lists/*

USER ${USERNAME}
