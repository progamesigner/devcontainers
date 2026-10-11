# Nix

Install Nix and prepare the development environment declared in a `dev.nix` file, similar to Project IDX / Firebase Studio.

```json
{
    "features": {
        "ghcr.io/progamesigner/devcontainers/features/nix:latest": {}
    }
}
```

## dev.nix

Put `.devcontainer/dev.nix` in the workspace. The format is compatible with the `.idx/dev.nix` file of Project IDX, so `"file": ".idx/dev.nix"` also works.

```nix
{ pkgs, ... }: {
  # stable-<release>, unstable, a nixpkgs branch or a nixpkgs commit
  channel = "stable-26.05";

  # Packages on PATH
  packages = [
    pkgs.go
    pkgs.nodejs_22
  ];

  # Variables exported in every shell and hook
  env = {
    GOFLAGS = "-mod=mod";
  };

  # Commands run in the workspace folder, in name order
  idx.workspace = {
    onCreate = {
      npm-install = "npm ci";
    };
    onStart = {
      go-mod = "go mod download";
    };
  };
}
```

`workspace.onCreate` / `workspace.onStart` work as a short form of `idx.workspace.*`. Other IDX settings, such as `idx.extensions` and `idx.previews`, are ignored. Use `customizations.vscode.extensions` in `devcontainer.json` for extensions.

## Lifecycle

| Stage               | Command               | Action                                                        |
| ------------------- | --------------------- | ------------------------------------------------------------- |
| `onCreateCommand`   | `devnix build`        | Build `dev.nix` into the profile `/nix/var/devnix/profile`    |
| `postCreateCommand` | `devnix run onCreate` | Run the `onCreate` hooks                                      |
| `postStartCommand`  | `devnix start`        | Rebuild when `dev.nix` changed (`autoRebuild`), run `onStart` |

The profile `bin` is on `PATH` of every process. The `env` variables load in new shells. After a rebuild, open a new terminal, or reload the window for extensions.

Run `devnix rebuild` to rebuild by hand, for example to pick up a newer `channel` revision. Run `devnix status` to show the current environment.

## Store

`/nix` is a named volume `nix-${devcontainerId}`. The store and the built environment survive a container rebuild. Remove the volume to start from a clean store, or to pick up a newer Nix from a newer feature version.

## Options

| Option        | Default                 | Description                                            |
| ------------- | ----------------------- | ------------------------------------------------------ |
| `version`     | `latest`                | Nix version, or `none`                                 |
| `file`        | `.devcontainer/dev.nix` | Path of `dev.nix`, relative to the workspace folder    |
| `channel`     | `stable-26.05`          | Default channel when `dev.nix` does not set `channel`  |
| `allowUnfree` | `false`                 | Allow packages with an unfree license                  |
| `autoRebuild` | `true`                  | Rebuild on start when `dev.nix` changed                |
