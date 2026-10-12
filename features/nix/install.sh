#!/usr/bin/env bash

NIX_VERSION=${VERSION:-${1:-latest}}
NIX_FILE=${FILE:-${2:-.devcontainer/dev.nix}}
NIX_DEV_SHELL=${DEVSHELL:-${3:-default}}
NIX_CHANNEL=${CHANNEL:-${4:-stable-26.05}}
NIX_ALLOW_UNFREE=${ALLOWUNFREE:-${5:-false}}
NIX_AUTO_REBUILD=${AUTOREBUILD:-${6:-true}}

NIX_USER=${_REMOTE_USER:-root}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    ca-certificates \
    curl \
    git \
    jq \
    xz-utils \
"

if [[ ${NIX_VERSION} != none ]]; then
    echo "Setup Nix v${NIX_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64;;
        arm64) ARCHITECTURE=aarch64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${NIX_VERSION} = latest ]]; then
        NIX_VERSION=$(curl -fsSL https://nixos.org/nix/install | sed -n 's|^tarball=.*nix-\([0-9.]*\)-.*|\1|p')
    fi

    NIX_VERSION=${NIX_VERSION#v}

    if [[ ! ${NIX_VERSION} =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Invalid Nix version: ${NIX_VERSION}" >&2
        exit 1
    fi

    NIX_RELEASE=nix-${NIX_VERSION}-${ARCHITECTURE}-linux

    curl -fsSL -o /tmp/nix.tar.xz https://releases.nixos.org/nix/nix-${NIX_VERSION}/${NIX_RELEASE}.tar.xz

    SHA256=$(curl -fsSL https://releases.nixos.org/nix/nix-${NIX_VERSION}/${NIX_RELEASE}.tar.xz.sha256)
    echo "${SHA256}  /tmp/nix.tar.xz" | sha256sum --check --status

    mkdir -p /tmp/nix
    tar -xJf /tmp/nix.tar.xz -C /tmp/nix

    # Single-user install owned by the remote user, no daemon and no build users
    NIX_STORE_PATH=$(sed -n 's/^nix="\(.*\)"$/\1/p' /tmp/nix/${NIX_RELEASE}/install)

    mkdir -p /etc/nix /nix/store /nix/var/devnix
    cp -RPp /tmp/nix/${NIX_RELEASE}/store/* /nix/store/

    cat << 'EOF' > /etc/nix/nix.conf
build-users-group =
experimental-features = nix-command flakes
max-jobs = auto
sandbox = false
EOF

    ${NIX_STORE_PATH}/bin/nix-store --load-db < /tmp/nix/${NIX_RELEASE}/.reginfo
    ${NIX_STORE_PATH}/bin/nix-env --profile /nix/var/nix/profiles/default --install ${NIX_STORE_PATH}

    chown -R "${NIX_USER}:" /nix

    rm -rf /tmp/nix /tmp/nix.tar.xz

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*
else
    printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/devnix
    chmod +x /usr/local/bin/devnix
    exit 0
fi

mkdir -p /usr/local/share/devnix

# Quote option values because this configuration is sourced by bash.
{
    printf 'DEVNIX_FILE=${DEVNIX_FILE:-%s}\n' "$(printf '%q' "${NIX_FILE}")"
    printf 'DEVNIX_CHANNEL=${DEVNIX_CHANNEL:-%s}\n' "$(printf '%q' "${NIX_CHANNEL}")"
    printf 'DEVNIX_ALLOW_UNFREE=${DEVNIX_ALLOW_UNFREE:-%s}\n' "$(printf '%q' "${NIX_ALLOW_UNFREE}")"
    printf 'DEVNIX_AUTO_REBUILD=${DEVNIX_AUTO_REBUILD:-%s}\n' "$(printf '%q' "${NIX_AUTO_REBUILD}")"
    printf 'DEVNIX_DEV_SHELL=${DEVNIX_DEV_SHELL:-%s}\n' "$(printf '%q' "${NIX_DEV_SHELL}")"
} > /usr/local/share/devnix/config

cat << 'EOF' > /usr/local/share/devnix/eval.nix
{
  file,
  channel,
  allowUnfree ? false,
  system ? builtins.currentSystem,
}:

let
  module = import file;
  call = args:
    if builtins.isFunction module then
      module (builtins.intersectAttrs (builtins.functionArgs module) args)
    else
      module;

  # `channel` is read before nixpkgs is known, so it must not depend on pkgs
  probe = call {
    pkgs = throw "devnix: `channel` in ${file} must not depend on pkgs";
    lib = throw "devnix: `channel` in ${file} must not depend on lib";
  };

  selected = probe.channel or channel;
  stable = builtins.match "stable-(.+)" selected;
  branch =
    if selected == "unstable" then
      "nixos-unstable"
    else if stable != null then
      "nixos-${builtins.head stable}"
    else
      selected;

  pkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/${branch}.tar.gz") {
    inherit system;
    config.allowUnfree = allowUnfree;
  };
  inherit (pkgs) lib;

  cfg = call { inherit pkgs lib; };

  # Accept both Project IDX (`idx.workspace`) and plain (`workspace`) hooks
  workspace = (cfg.idx.workspace or { }) // (cfg.workspace or { });
  hooks = name: lib.filterAttrs (_: builtins.isString) (workspace.${name} or { });

  env = lib.concatStrings (
    lib.mapAttrsToList (
      name: value:
      if builtins.match "[A-Za-z_][A-Za-z0-9_]*" name == null then
        throw "devnix: invalid environment variable name `${name}`"
      else
        let
          text = if builtins.isList value then lib.concatStringsSep ":" value else toString value;
          suffix = if name == "PATH" then ":\"$PATH\"" else "";
        in
        "export ${name}=${lib.escapeShellArg text}${suffix}\n"
    ) (cfg.env or { })
  );
in
pkgs.buildEnv {
  name = "devnix-environment";
  paths = (cfg.packages or [ ]) ++ [
    (pkgs.writeTextDir "share/devnix/env.sh" env)
    (pkgs.writeTextDir "share/devnix/hooks.json" (
      builtins.toJSON {
        onCreate = hooks "onCreate";
        onStart = hooks "onStart";
      }
    ))
  ];
}
EOF

# Turn a flake devShell into plain exports that bash, zsh and sh can source,
# like direnv does for `use flake`
cat << 'EOF' > /usr/local/share/devnix/capture.sh
#!/usr/bin/env bash

set -e

DEVNIX_PROFILE=$1
DEVNIX_INSTALLABLE=$2

DEVNIX_SKIP=" _ HOME NIX_BUILD_TOP NIX_LOG_FD OLDPWD PWD SHELL SHLVL TEMP TEMPDIR TERM TMP TMPDIR USER "

quote() {
    printf "'%s'" "${1//\'/\'\\\'\'}"
}

declare -A DEVNIX_BEFORE
while IFS= read -r -d '' kv; do
    DEVNIX_BEFORE[${kv%%=*}]=${kv#*=}
done < <(env -0)

DEVNIX_SCRIPT=$(nix print-dev-env ${3:+--refresh} --print-build-logs --profile "${DEVNIX_PROFILE}" "${DEVNIX_INSTALLABLE}") || exit 1
eval "${DEVNIX_SCRIPT}" < /dev/null >&2

declare -A DEVNIX_AFTER
while IFS= read -r -d '' kv; do
    name=${kv%%=*}
    value=${kv#*=}
    DEVNIX_AFTER[${name}]=${value}
    old=${DEVNIX_BEFORE[${name}]-}

    [[ ${DEVNIX_SKIP} = *" ${name} "* ]] && continue
    [[ ${name} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    [[ -v DEVNIX_BEFORE[${name}] && ${old} = "${value}" ]] && continue

    # Keep the value of the shell for list variables such as PATH
    if [[ -n ${old} && ${value} = *":${old}" ]]; then
        printf '%s\n' "export ${name}=$(quote "${value%":${old}"}"):\"\${${name}}\""
    elif [[ -n ${old} && ${value} = "${old}:"* ]]; then
        printf '%s\n' "export ${name}=\"\${${name}}\":$(quote "${value#"${old}:"}")"
    else
        printf '%s\n' "export ${name}=$(quote "${value}")"
    fi
done < <(env -0)

for name in "${!DEVNIX_BEFORE[@]}"; do
    [[ ${DEVNIX_SKIP} = *" ${name} "* ]] && continue
    [[ ${name} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    if [[ ! -v DEVNIX_AFTER[${name}] ]]; then
        printf 'unset %s\n' "${name}"
    fi
done
EOF
chmod +x /usr/local/share/devnix/capture.sh

cat << 'EOF' > /usr/local/bin/devnix
#!/usr/bin/env bash

set -e

. /usr/local/share/devnix/config

DEVNIX_STATE=/nix/var/devnix
DEVNIX_PROFILE=${DEVNIX_STATE}/profile
DEVNIX_BUILD_PROFILE=${DEVNIX_STATE}/build-profile

export PATH=/nix/var/nix/profiles/default/bin:${PATH}
export NIX_SSL_CERT_FILE=${NIX_SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}

usage() {
    cat << USAGE
Usage: devnix <command>

Commands:
  build      Build the environment when dev.nix or flake.nix changed since the last build
  rebuild    Build the environment even when nothing changed
  start      Build when autoRebuild is enabled, then run the onStart hooks
  run STAGE  Run the hooks of STAGE (onCreate or onStart)
  status     Show the environment file and the current environment
USAGE
}

# The lifecycle commands run in the workspace folder. Remember the resolved
# path so later commands work from any directory.
resolve_file() {
    if [[ -n ${DEVNIX_WORKSPACE_FILE:-} ]]; then
        echo "${DEVNIX_WORKSPACE_FILE}"
    elif [[ -f ${DEVNIX_FILE} ]]; then
        realpath "${DEVNIX_FILE}"
    elif [[ -f ${DEVNIX_STATE}/workspace ]]; then
        local workspace
        workspace=$(cat "${DEVNIX_STATE}/workspace")
        if [[ -f ${workspace}/${DEVNIX_FILE} ]]; then
            realpath "${workspace}/${DEVNIX_FILE}"
        fi
    fi
    return 0
}

# Hash the file, lock, helpers and options that change the result
checksum() {
    local file=$1
    {
        printf '%s\n' "${file}"
        cat "${file}" /usr/local/share/devnix/eval.nix /usr/local/share/devnix/capture.sh
        if [[ $(basename "${file}") = flake.nix ]]; then
            cat "$(dirname "${file}")/flake.lock" 2> /dev/null || true
        fi
        echo "${DEVNIX_CHANNEL} ${DEVNIX_ALLOW_UNFREE} ${DEVNIX_DEV_SHELL}"
    } | sha256sum | cut -d' ' -f1
}

build_devnix() {
    nix build \
        ${2:+--refresh} \
        --no-link \
        --impure \
        --print-build-logs \
        --profile "${DEVNIX_BUILD_PROFILE}" \
        --file /usr/local/share/devnix/eval.nix \
        --argstr file "$1" \
        --argstr channel "${DEVNIX_CHANNEL}" \
        --arg allowUnfree "${DEVNIX_ALLOW_UNFREE}"

    cp "${DEVNIX_BUILD_PROFILE}/share/devnix/env.sh" "${DEVNIX_STATE}/env.sh.new"
}

build_flake() {
    /usr/local/share/devnix/capture.sh "${DEVNIX_BUILD_PROFILE}" "$(dirname "$1")#${DEVNIX_DEV_SHELL}" "$2" > "${DEVNIX_STATE}/env.sh.new"
}

# A persistent volume can retain the old UID after updateRemoteUserUID.
prepare_store() {
    if [[ ! -w ${DEVNIX_STATE} || ! -w /nix/var/nix/db ]]; then
        if command -v sudo > /dev/null 2>&1; then
            sudo -n chown -R "$(id -u):$(id -g)" /nix
        else
            echo "devnix: /nix belongs to another user. Run chown -R $(id -u):$(id -g) /nix as root." >&2
            exit 1
        fi
    fi
}

build() {
    local file sum
    prepare_store
    file=$(resolve_file)

    if [[ -z ${file} || ! -f ${file} ]]; then
        echo "devnix: ${DEVNIX_FILE} not found, skip preparing the environment"
        rm -f "${DEVNIX_PROFILE}" "${DEVNIX_STATE}/env.sh" "${DEVNIX_STATE}/checksum" "${DEVNIX_STATE}/file"
        return 0
    fi

    if [[ -f ${DEVNIX_FILE} ]]; then
        pwd -P > "${DEVNIX_STATE}/workspace"
    fi
    sum=$(checksum "${file}")

    if [[ $1 != force && -e ${DEVNIX_PROFILE} && ${sum} = $(cat "${DEVNIX_STATE}/checksum" 2> /dev/null) ]]; then
        echo "devnix: environment is up to date"
        return 0
    fi

    echo "devnix: building environment from ${file} ..."
    if [[ -f ${DEVNIX_STATE}/workspace ]]; then
        cd "$(cat "${DEVNIX_STATE}/workspace")"
    fi
    if [[ $(basename "${file}") = flake.nix ]]; then
        build_flake "${file}" "$1"
    else
        build_devnix "${file}" "$1"
    fi

    # Publish the profile only after environment capture succeeds.
    nix-store --add-root "${DEVNIX_PROFILE}" --indirect --realise "$(readlink -f "${DEVNIX_BUILD_PROFILE}")" > /dev/null
    echo "${file}" > "${DEVNIX_STATE}/file"
    mv "${DEVNIX_STATE}/env.sh.new" "${DEVNIX_STATE}/env.sh"
    # Hash again, the build can create or update flake.lock
    checksum "${file}" > "${DEVNIX_STATE}/checksum"
    echo "devnix: environment is ready, open a new terminal to load it"
}

run() {
    local stage=$1 hooks=${DEVNIX_PROFILE}/share/devnix/hooks.json failed=0 name

    [[ -f ${hooks} ]] || return 0
    [[ $(resolve_file) = "$(cat "${DEVNIX_STATE}/file" 2> /dev/null)" ]] || return 0

    if [[ -f ${DEVNIX_STATE}/workspace ]]; then
        cd "$(cat "${DEVNIX_STATE}/workspace")"
    fi

    [[ -r ${DEVNIX_STATE}/env.sh ]] && . "${DEVNIX_STATE}/env.sh"
    export PATH=${DEVNIX_PROFILE}/bin:${PATH}

    while IFS= read -r -d '' name; do
        echo "devnix: running ${stage} hook '${name}' ..."
        if ! bash -c "$(jq -r --arg stage "${stage}" --arg name "${name}" '.[$stage][$name]' "${hooks}")"; then
            echo "devnix: ${stage} hook '${name}' failed" >&2
            failed=1
        fi
    done < <(jq -j --arg stage "${stage}" '.[$stage] | keys[] | . + "\u0000"' "${hooks}")

    return ${failed}
}

status() {
    echo "file:    $(resolve_file || true)"
    echo "channel: ${DEVNIX_CHANNEL} (default for dev.nix)"
    echo "shell:   ${DEVNIX_DEV_SHELL}"
    if [[ -e ${DEVNIX_PROFILE} ]]; then
        echo "profile: $(readlink -f "${DEVNIX_PROFILE}")"
    else
        echo "profile: (not built)"
    fi
}

case "$1" in
    build) build ;;
    rebuild) build force ;;
    start)
        if [[ ${DEVNIX_AUTO_REBUILD} = true ]]; then
            build
        fi
        run onStart
        ;;
    run)
        [[ $2 = onCreate || $2 = onStart ]] || { usage; exit 1; }
        run "$2"
        ;;
    status) status ;;
    *) usage; [[ $1 = help || $1 = -h || $1 = --help ]] ;;
esac
EOF
chmod +x /usr/local/bin/devnix

# Load the env of the environment in login, interactive and zsh shells
cat << 'EOF' > /etc/profile.d/devnix.sh
for devnix_bin in /nix/var/nix/profiles/default/bin /nix/var/devnix/profile/bin; do
    case ":${PATH}:" in
        *:"${devnix_bin}":*) ;;
        *) export PATH=${devnix_bin}:${PATH} ;;
    esac
done
unset devnix_bin

if [ -r /nix/var/devnix/env.sh ]; then
    . /nix/var/devnix/env.sh
fi
EOF

for rc in /etc/bash.bashrc /etc/zsh/zshenv; do
    if [[ -d $(dirname ${rc}) ]] && ! grep -qs devnix.sh ${rc}; then
        echo ". /etc/profile.d/devnix.sh" >> ${rc}
    fi
done

echo "Done!"
