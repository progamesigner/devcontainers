# Nix

This feature installs Nix and sets up the tools your project needs each time the container is created or started. You describe the tools in a `dev.nix` file, the way Project IDX and Firebase Studio do, or in the `devShells` of a `flake.nix`.

```json
{
    "features": {
        "ghcr.io/progamesigner/devcontainers/features/nix:latest": {}
    }
}
```

## dev.nix

By default the feature reads `.devcontainer/dev.nix` from the workspace. The file uses the same format as `.idx/dev.nix` in Project IDX, so an existing IDX project can set `"file": ".idx/dev.nix"` and keep its file where it is.

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
    PATH = [ "/workspace/bin" ];
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

Environment values can be strings or lists of strings. Lists are joined with colons; `PATH` entries are prepended to the existing path.

You can write `workspace.onCreate` and `workspace.onStart` without the `idx.` prefix. The feature ignores the other IDX settings, including `idx.extensions` and `idx.previews`. Put extensions in `customizations.vscode.extensions` of `devcontainer.json` instead.

## flake.nix

If the project already has a flake, point `file` at it. The feature loads `devShells.<system>.default`, or the shell named in `devShell`.

```json
{
    "features": {
        "ghcr.io/progamesigner/devcontainers/features/nix:latest": {
            "file": "flake.nix",
            "devShell": "default"
        }
    }
}
```

The feature runs `nix print-dev-env`, keeps the exported variables the shell sets or unsets (its `shellHook` included), and writes them to a shell script. Login shells, interactive bash and zsh load it automatically. Other shells can source `/etc/profile.d/devnix.sh` explicitly. The flake decides its own nixpkgs, so `channel` and `allowUnfree` have no effect here, and there are no `onCreate` or `onStart` hooks. Use `postCreateCommand` and `postStartCommand` in `devcontainer.json` for those.

Nix only sees files that Git tracks when the flake is in a Git repository. Run `git add flake.nix` before you open the container. The first build writes `flake.lock`; commit it to pin nixpkgs.

## Lifecycle

| Stage               | Command               | Action                                                            |
| ------------------- | --------------------- | ----------------------------------------------------------------- |
| `onCreateCommand`   | `devnix build`        | Build the environment                                             |
| `postCreateCommand` | `devnix run onCreate` | Run the `onCreate` hooks of `dev.nix`                             |
| `postStartCommand`  | `devnix start`        | Rebuild if anything changed (`autoRebuild`), run `onStart` hooks  |

Feature hooks run alongside any commands configured for the same lifecycle stage in `devcontainer.json`. Keep dependent commands together in `dev.nix`, or run them explicitly after `devnix` finishes.

A rebuild happens when the environment file, its path, its `flake.lock`, a feature option or the environment helper changes. When a build finds no environment file, it clears the previous environment and skips its hooks. For `dev.nix`, every process sees the packages on `PATH`. Variables, and everything from a flake, load when a shell starts. After a rebuild, open a new terminal, and reload the window if an extension needs the new tools.

`devnix rebuild` builds again even when nothing changed and refreshes Nix's download cache. Use it when `dev.nix` follows a branch and you want its newest packages, or when the flake imports other files. `devnix status` prints the file, the default channel and the current build.

## Store

Nix uses a single-user store owned by the remote user, without a daemon. If the user's UID changes, `devnix build` repairs the volume ownership with passwordless `sudo`. Images without `sudo` need to run `chown -R <uid>:<gid> /nix` as root before building.

`/nix` lives in a named volume, `nix-${devcontainerId}`, so the store and the last build are still there after you rebuild the container. Delete the volume to start from an empty store. A newer Nix from a newer feature version also only arrives with a new volume.

## Options

| Option        | Default                 | Description                                              |
| ------------- | ----------------------- | -------------------------------------------------------- |
| `version`     | `latest`                | Nix version, or `none`                                   |
| `file`        | `.devcontainer/dev.nix` | `dev.nix` or `flake.nix`, relative to the workspace      |
| `devShell`    | `default`               | devShell to load from `flake.nix`                        |
| `channel`     | `stable-26.05`          | Channel for a `dev.nix` that does not set `channel`      |
| `allowUnfree` | `false`                 | Allow packages with an unfree license in `dev.nix`       |
| `autoRebuild` | `true`                  | Rebuild on start when something changed                  |
