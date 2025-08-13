# nix-tmux
tmux flake with home manager module

## Run locally 

```shell
nix run .#run-tmux-light
```

## Use in homemanager

```nix
{
  inputs.mods.url = "github:you/nix-modules-repo";

  outputs = { self, nixpkgs, home-manager, mods, ... }: {
    homeConfigurations.t = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      modules = [
        mods.homeManagerModules.tmux-light
        { home.username = "t"; home.homeDirectory = "/home/t"; programs.home-manager.enable = true;
          dot.tmux-light.enable = true;
        }
      ];
    };
  };
}
```
