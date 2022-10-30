ARG DISTRO=ubuntu
ARG VARIANT=jammy

FROM ${DISTRO}:${VARIANT}

ARG SCRIPT_VERSION=master

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ARG ENABLE_DEVTOOLS=true

ARG ACT_VERSION=none
ARG BUF_VERSION=none
ARG STEP_VERSION=none

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y apt-utils ca-certificates curl \
 && bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/images/ubuntu/setup.sh)" -- "${USERNAME}" "${USER_UID}" "${USER_GID}" \
 && if [[ -n ${ENABLE_DEVTOOLS} ]]; bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/devtools/install.sh)"; fi \
 && apt-get autoremove -y \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

ARG CRD2PULUMI_VERSION=none
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
ARG PYTHON_VERSION=none
ARG RUST_VERSION=none

ENV CARGO_HOME=/usr/local/cargo
ENV GOPATH=/opt/go
ENV GOROOT=/usr/local/go
ENV NPM_HOME=/usr/local/npm

ENV PATH=${CARGO_HOME}/bin:${GOROOT}/bin:${GOPATH}/bin:${NPM_HOME}/bin:${PATH}

RUN apt-get update \
 && if [ -n "${DOCKER_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/docker/install.sh)" -- "${DOCKER_VERSION}" "${DOCKER_COMPOSE_VERSION}"; fi \
 && if [ -n "${GO_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/go/install.sh)" -- "${GO_VERSION}"; fi \
 && if [ -n "${HUGO_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/hugo/install.sh)" -- "${HUGO_VERSION}"; fi \
 && if [ -n "${KUBECTL_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/kubectl/install.sh)" -- "${KUBECTL_VERSION}"; fi \
 && if [ -n "${NODE_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/node/install.sh)" -- "${NODE_VERSION}"; fi \
 && if [ -n "${PHP_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/php/install.sh)" -- "${PHP_VERSION}" "${PHP_COMPOSER_VERSION}" "${PHP_XDEBUG_VERSION}"; fi \
 && if [ -n "${PULUMI_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/pulumi/install.sh)" -- "${PULUMI_VERSION}" "${CRD2PULUMI_VERSION}"; fi \
 && if [ -n "${PYTHON_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/python/install.sh)" -- "${PYTHON_VERSION}"; fi \
 && if [ -n "${RUST_VERSION}" ]; then bash -c "$(curl -fsSL https://raw.githubusercontent.com/progamesigner/vscode-dev-containers/${SCRIPT_VERSION}/features/rust/install.sh)" -- "${RUST_VERSION}"; fi \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

USER ${USERNAME}
