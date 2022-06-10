ARG DISTRO=ubuntu
ARG VARIANT=jammy

FROM ${DISTRO}:${VARIANT}

ARG SCRIPT_VERSION=master

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ARG ENABLE_DEVTOOLS=true

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y apt-utils ca-certificates curl \
 && bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-debian.sh)" -- "${USERNAME}" "${USER_UID}" "${USER_GID}" \
 && if [[ -n ${ENABLE_DEVTOOLS} ]]; bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-devtools.sh)" -- "${ENABLE_DEVTOOLS}"; fi \
 && apt-get autoremove -y \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

ARG ACT_VERSION=none
ARG BUF_VERSION=none
ARG DOCKER_COMPOSE_VERSION=none
ARG DOCKER_VERSION=none
ARG GO_VERSION=none
ARG HUGO_VERSION=none
ARG KUBECTL_VERSION=none
ARG NODE_VERSION=none
ARG PHP_COMPOSER_VERSION=none
ARG PHP_VERSION=none
ARG PHP_XDEBUG_VERSION=none
ARG PULUMI_VERSION=none
ARG PYPY_PYTHON_VERSION=none
ARG PYPY_VERSION=none
ARG PYTHON_VERSION=none
ARG RUST_VERSION=none

ENV CARGO_HOME=/usr/local/cargo
ENV NPM_HOME=/usr/local/npm
ENV SHELL=/bin/bash

ENV PATH=${CARGO_HOME}/bin:${NPM_HOME}/bin:${PATH}

RUN apt-get update \
 && if [ -n "${ACT_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-act.sh)" -- "${ACT_VERSION}"; fi \
 && if [ -n "${BUF_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-buf.sh)" -- "${BUF_VERSION}"; fi \
 && if [ -n "${DOCKER_COMPOSE_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-docker-compose.sh)" -- "${DOCKER_COMPOSE_VERSION}"; fi \
 && if [ -n "${DOCKER_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-docker.sh)" -- "${DOCKER_VERSION}"; fi \
 && if [ -n "${GO_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-go.sh)" -- "${GO_VERSION}"; fi \
 && if [ -n "${HUGO_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-hugo.sh)" -- "${HUGO_VERSION}"; fi \
 && if [ -n "${KUBECTL_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-kubectl.sh)" -- "${KUBECTL_VERSION}"; fi \
 && if [ -n "${NODE_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-node.sh)" -- "${NODE_VERSION}" "${NPM_HOME}"; fi \
 && if [ -n "${PHP_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-php.sh)" -- "${PHP_VERSION}" "${PHP_COMPOSER_VERSION}" "${PHP_XDEBUG_VERSION}"; fi \
 && if [ -n "${PULUMI_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-pulumi.sh)" -- "${PULUMI_VERSION}"; fi \
 && if [ -n "${PYPY_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-pypy.sh)" -- "${PYPY_VERSION}" "${PYPY_PYTHON_VERSION}"; fi \
 && if [ -n "${PYTHON_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-python.sh)" -- "${PYTHON_VERSION}"; fi \
 && if [ -n "${RUST_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/scripts/setup-rust.sh)" -- "${RUST_VERSION}" "${CARGO_HOME}"; fi \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

USER ${USERNAME}
