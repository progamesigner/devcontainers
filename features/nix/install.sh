#!/usr/bin/env bash

NIX_VERSION=${VERSION:-${1:-latest}}
NIX_FILE=${FILE:-${2:-.devcontainer/dev.nix}}
NIX_CHANNEL=${CHANNEL:-${3:-stable-26.05}}
NIX_ALLOW_UNFREE=${ALLOWUNFREE:-${4:-false}}
NIX_AUTO_REBUILD=${AUTOREBUILD:-${5:-true}}

NIX_USER=${_REMOTE_USER:-root}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${NIX_VERSION} = none ]]; then
    printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/devnix
    chmod +x /usr/local/bin/devnix
    exit 0
fi

echo "Setup Nix v${NIX_VERSION} ..."

apt-get update
apt-get install --no-install-recommends --yes ca-certificates curl jq xz-utils

ARCHITECTURE=""
case "$(dpkg --print-architecture)" in
    amd64) ARCHITECTURE=x86_64;;
    arm64) ARCHITECTURE=aarch64;;
    *) echo "unsupported architecture"; exit 1 ;;
esac

if [[ ${NIX_VERSION} = latest ]]; then
    NIX_VERSION=$(curl -sSL https://nixos.org/nix/install | grep -oE 'releases.nixos.org/nix/nix-[0-9.]+' | head -1 | sed 's|.*/nix-||')
fi

NIX_VERSION=${NIX_VERSION#v}

NIX_RELEASE=nix-${NIX_VERSION}-${ARCHITECTURE}-linux

curl -sSL -o /tmp/nix.tar.xz https://releases.nixos.org/nix/nix-${NIX_VERSION}/${NIX_RELEASE}.tar.xz

SHA256=$(curl -sSL https://releases.nixos.org/nix/nix-${NIX_VERSION}/${NIX_RELEASE}.tar.xz.sha256)
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

chown -R ${NIX_USER}: /nix

rm -rf /tmp/nix /tmp/nix.tar.xz

mkdir -p /usr/local/share/devnix

cat << EOF > /usr/local/share/devnix/config
DEVNIX_FILE=\${DEVNIX_FILE:-${NIX_FILE}}
DEVNIX_CHANNEL=\${DEVNIX_CHANNEL:-${NIX_CHANNEL}}
DEVNIX_ALLOW_UNFREE=\${DEVNIX_ALLOW_UNFREE:-${NIX_ALLOW_UNFREE}}
DEVNIX_AUTO_REBUILD=\${DEVNIX_AUTO_REBUILD:-${NIX_AUTO_REBUILD}}
EOF

cat << 'EOF' > /usr/local/share/devnix/eval.nix
{
  file,
  channel,
  allowUnfree ? false,
  system ? builtins.currentSystem,
}:

let
  module = import file;
  call = args: if builtins.isFunction module then module args else module;

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
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg (toString value)}\n") (
      cfg.env or { }
    )
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

cat << 'EOF' > /usr/local/bin/devnix
#!/usr/bin/env bash

set -e

. /usr/local/share/devnix/config

DEVNIX_STATE=/nix/var/devnix
DEVNIX_PROFILE=${DEVNIX_STATE}/profile

export PATH=/nix/var/nix/profiles/default/bin:${PATH}
export NIX_SSL_CERT_FILE=${NIX_SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}

usage() {
    cat << USAGE
Usage: devnix <command>

Commands:
  build      Build the environment when dev.nix changed since the last build
  rebuild    Build the environment even when dev.nix did not change
  start      Build when autoRebuild is enabled, then run the onStart hooks
  run STAGE  Run the hooks of STAGE (onCreate or onStart)
  status     Show the dev.nix file and the current environment
USAGE
}

# The lifecycle commands run in the workspace folder. Remember the resolved
# path so later commands work from any directory.
resolve_file() {
    if [[ -n ${DEVNIX_WORKSPACE_FILE:-} ]]; then
        echo "${DEVNIX_WORKSPACE_FILE}"
    elif [[ -f ${DEVNIX_FILE} ]]; then
        realpath "${DEVNIX_FILE}"
    elif [[ -f ${DEVNIX_STATE}/file ]]; then
        cat "${DEVNIX_STATE}/file"
    fi
}

checksum() {
    sha256sum "$1" | cut -d' ' -f1
}

build() {
    local file
    file=$(resolve_file)

    if [[ -z ${file} || ! -f ${file} ]]; then
        echo "devnix: ${DEVNIX_FILE} not found, skip preparing the environment"
        return 0
    fi

    echo "${file}" > "${DEVNIX_STATE}/file"

    if [[ $1 != force && -e ${DEVNIX_PROFILE} && $(checksum "${file}") = $(cat "${DEVNIX_STATE}/checksum" 2> /dev/null) ]]; then
        echo "devnix: environment is up to date"
        return 0
    fi

    echo "devnix: building environment from ${file} ..."
    nix build \
        --impure \
        --print-build-logs \
        --profile "${DEVNIX_PROFILE}" \
        --file /usr/local/share/devnix/eval.nix \
        --argstr file "${file}" \
        --argstr channel "${DEVNIX_CHANNEL}" \
        --arg allowUnfree "${DEVNIX_ALLOW_UNFREE}"

    checksum "${file}" > "${DEVNIX_STATE}/checksum"
    echo "devnix: environment is ready, open a new terminal to load it"
}

run() {
    local stage=$1 hooks=${DEVNIX_PROFILE}/share/devnix/hooks.json failed=0 name

    [[ -f ${hooks} ]] || return 0

    [[ -r ${DEVNIX_PROFILE}/share/devnix/env.sh ]] && . "${DEVNIX_PROFILE}/share/devnix/env.sh"
    export PATH=${DEVNIX_PROFILE}/bin:${PATH}

    while IFS= read -r name; do
        echo "devnix: running ${stage} hook '${name}' ..."
        if ! bash -c "$(jq -r --arg stage "${stage}" --arg name "${name}" '.[$stage][$name]' "${hooks}")"; then
            echo "devnix: ${stage} hook '${name}' failed" >&2
            failed=1
        fi
    done < <(jq -r --arg stage "${stage}" '.[$stage] | keys[]' "${hooks}")

    return ${failed}
}

status() {
    echo "file:    $(resolve_file || true)"
    echo "channel: ${DEVNIX_CHANNEL}"
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

# Load the env of dev.nix in login, interactive and zsh shells
cat << 'EOF' > /etc/profile.d/devnix.sh
if [ -r /nix/var/devnix/profile/share/devnix/env.sh ]; then
    . /nix/var/devnix/profile/share/devnix/env.sh
fi
EOF

for rc in /etc/bash.bashrc /etc/zsh/zshenv; do
    if [[ -d $(dirname ${rc}) ]] && ! grep -qs devnix.sh ${rc}; then
        echo ". /etc/profile.d/devnix.sh" >> ${rc}
    fi
done

echo "Done!"
