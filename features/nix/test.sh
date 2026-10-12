#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "nix command" nix --version
check "devnix command" devnix status

TEST_WORKSPACE=$(mktemp -d)
trap 'rm -rf "${TEST_WORKSPACE}"' EXIT
cd "${TEST_WORKSPACE}"
mkdir -p .devcontainer

cat << 'NIX' > .devcontainer/dev.nix
{ pkgs }: {
  packages = [ pkgs.hello ];
  env = {
    DEVNIX_TEST_VALUE = "hello 'world'";
    DEVNIX_TEST_LIST = [ "one" "two" ];
    PATH = [ "/devnix-test/bin" ];
  };
  idx.workspace.onCreate = {
    a-first = "hello > created; printf a >> order";
    b-second = "printf b >> order";
    "c-\nthird" = "printf c >> order";
  };
  workspace.onStart.started = "printf started > started";
}
NIX

check "build dev.nix" devnix build
check "workspace stays clean" bash -c '[[ ! -e result ]]'
check "package on PATH" hello --version
check "login shell PATH" bash -lc 'nix --version && hello --version'
check "environment values and PATH" bash -c '. /etc/profile.d/devnix.sh; [[ $DEVNIX_TEST_VALUE = "hello '\''world'\''" && $DEVNIX_TEST_LIST = one:two && $PATH = /devnix-test/bin:* ]] && command -v bash'
check "onCreate hooks" devnix run onCreate
check "hook order and packages" bash -c '[[ $(cat order) = abc && $(cat created) = "Hello, world!" ]]'
check "unchanged environment" bash -c 'devnix build | grep -q "up to date"'
check "forced rebuild" bash -c 'devnix rebuild | grep -q "building environment"'
check "start hooks" devnix start
check "start hook result" test -f started

cp .devcontainer/dev.nix '.devcontainer/other file.nix'
check "changed file option" bash -c 'DEVNIX_FILE=".devcontainer/other file.nix" devnix build | grep -q "building environment"'
check "commands from another directory" bash -c 'cd /tmp; DEVNIX_FILE=".devcontainer/other file.nix" devnix build | grep -q "up to date"'
check "missing file clears environment" env DEVNIX_FILE=.devcontainer/missing.nix devnix build
check "old profile removed" bash -c '[[ ! -e /nix/var/devnix/profile && ! -e /nix/var/devnix/env.sh ]]'
check "restore dev.nix" devnix build

cat << 'NIX' >> .devcontainer/dev.nix
// { env.DEVNIX_TEST_REBUILD = "updated"; }
NIX
check "autoRebuild disabled" env DEVNIX_AUTO_REBUILD=false devnix start
check "disabled rebuild keeps environment" bash -c '. /etc/profile.d/devnix.sh; [[ -z ${DEVNIX_TEST_REBUILD:-} ]]'
check "autoRebuild enabled" devnix start
check "changed environment loaded" bash -c '. /etc/profile.d/devnix.sh; [[ $DEVNIX_TEST_REBUILD = updated ]]'

cat << 'NIX' >> .devcontainer/dev.nix
// { workspace.onStart = { a-failure = "exit 1"; z-after = "touch after-failure"; }; }
NIX
check "hook failure propagates" bash -c 'if devnix start; then exit 1; fi; test -f after-failure'

SYSTEM=$(nix eval --impure --raw --expr builtins.currentSystem)
NIXPKGS=$(nix eval --impure --raw --expr 'builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-26.05.tar.gz"')
cat << NIX > flake.nix
{
  inputs.nixpkgs.url = "path:${NIXPKGS}";
  outputs = { self, nixpkgs }: {
    devShells.${SYSTEM}.default = nixpkgs.legacyPackages.${SYSTEM}.mkShellNoCC {
      packages = [ nixpkgs.legacyPackages.${SYSTEM}.hello ];
      shellHook = "export DEVNIX_TEST_HOOK='flake hook'; unset DEVNIX_TEST_UNSET; echo hook-output; echo hook >> shell-hook-count";
    };
    devShells.${SYSTEM}.other = nixpkgs.legacyPackages.${SYSTEM}.mkShellNoCC {
      shellHook = "export DEVNIX_TEST_HOOK=other";
    };
    devShells.${SYSTEM}.failure = nixpkgs.legacyPackages.${SYSTEM}.mkShellNoCC {
      shellHook = "false; export DEVNIX_TEST_HOOK=incorrect";
    };
  };
}
NIX

check "build flake" env DEVNIX_FILE=flake.nix DEVNIX_TEST_UNSET=remove devnix build
check "flake lock created" test -f flake.lock
check "shellHook runs once" bash -c '[[ $(wc -l < shell-hook-count) = 1 ]]'
check "flake shellHook and package" bash -c '. /etc/profile.d/devnix.sh; [[ $DEVNIX_TEST_HOOK = "flake hook" ]] && hello --version'
check "flake environment unsets variables" bash -c 'export DEVNIX_TEST_UNSET=outside; . /etc/profile.d/devnix.sh; [[ ! -v DEVNIX_TEST_UNSET ]]'
check "portable flake environment" sh -c '. /etc/profile.d/devnix.sh; test "$DEVNIX_TEST_HOOK" = "flake hook"'
check "named devShell" env DEVNIX_FILE=flake.nix DEVNIX_DEV_SHELL=other devnix build
check "named shell environment" bash -c '. /etc/profile.d/devnix.sh; [[ $DEVNIX_TEST_HOOK = other ]]'
check "shellHook failure propagates" bash -c 'if DEVNIX_FILE=flake.nix DEVNIX_DEV_SHELL=failure devnix build; then exit 1; fi'
check "failed build preserves environment" bash -c '. /etc/profile.d/devnix.sh; [[ $DEVNIX_TEST_HOOK = other ]]'
check "failed build preserves profile" bash -c 'DEVNIX_FILE=flake.nix DEVNIX_DEV_SHELL=other devnix build | grep -q "up to date"'

reportResults
