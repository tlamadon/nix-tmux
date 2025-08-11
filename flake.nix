{
  description = "Light tmux config with a nice theme + fzf session manager (no TPM)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));

    # Theme & behavior shared by both the module and the runner.
    tmuxConfBase = ''
      # ----- General -----
      set -g mouse on
      set -g history-limit 10000
      set -g base-index 1
      set -g renumber-windows on
      setw -g pane-base-index 1
      set -g escape-time 0

      # ----- Prefix -----
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix

      # ----- Theme (light, clean) -----
      set -g status-interval 5
      set -g status-justify centre
      set -g status-bg colour254
      set -g status-fg colour236
      set -g status-left-length 40
      set -g status-right-length 80

      set -g status-left "#[fg=colour236,bold] #S #[default]"
      set -g status-right "#[fg=colour236]%Y-%m-%d #[fg=colour240]%H:%M #[default]"

      setw -g window-status-format "#[fg=colour240] #I:#W "
      setw -g window-status-current-format "#[fg=colour236,bold] #I:#W "

      set -g pane-border-style fg=colour244
      set -g pane-active-border-style fg=colour31
      set -g message-style bg=colour254,fg=colour31
    '';

    sessionizerScript = ''
      #!/usr/bin/env bash
      set -euo pipefail
      SESSION="$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --prompt="Select session> " || true)"
      if [ -n "${SESSION:-}" ]; then
        tmux switch-client -t "$SESSION" 2>/dev/null || tmux attach -t "$SESSION"
      else
        read -rp "New session name: " NEWS
        if [ -n "${NEWS:-}" ]; then
          tmux new-session -s "$NEWS"
        fi
      fi
    '';
  in
  {
    # Quick sandbox with tmux + fzf
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell { packages = [ pkgs.tmux pkgs.fzf ]; };
    });

    # Home Manager module: enable with `tmux-light.enable = true;`
    homeManagerModules.tmux-light = { config, lib, pkgs, ... }:
    let
      cfg = config.tmux-light;
      tmuxConf = tmuxConfBase + ''
        # ----- Session Manager (fzf) -----
        bind-key s run-shell "$HOME/.local/bin/tmux-sessionizer"
      '';
    in {
      options.tmux-light.enable = lib.mkEnableOption "Install a light tmux config + fzf session manager";

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.tmux pkgs.fzf ];

        xdg.configFile."tmux/tmux.conf".text = tmuxConf;

        home.file.".local/bin/tmux-sessionizer" = {
          text = sessionizerScript;
          executable = true;
        };
      };
    };

    # Runnable package: `nix run .#run-tmux-light`
    packages = forAllSystems (pkgs: {
      run-tmux-light = pkgs.writeShellApplication {
        name = "run-tmux-light";
        runtimeInputs = [ pkgs.tmux pkgs.fzf ];
        text = ''
          set -euo pipefail
          TMP_DIR="$(mktemp -d)"
          TMP_CONF="$TMP_DIR/tmux.conf"
          TMP_SESS="$TMP_DIR/tmux-sessionizer"

          # Write sessionizer to temp path so Prefix+s works in run mode
          cat > "$TMP_SESS" <<'EOS'
${sessionizerScript}
EOS
          chmod +x "$TMP_SESS"

          # Write tmux config + bind that points to the temp sessionizer
          cat > "$TMP_CONF" <<'EOF'
${tmuxConfBase}
# ----- Session Manager (fzf) -----
bind-key s run-shell "'"$TMP_SESS"'"
EOF

          tmux -f "$TMP_CONF" "$@"
        '';
      };
    });

    # Make the runner the default package/output
    defaultPackage = nixpkgs.lib.genAttrs systems (system: self.packages.${system}.run-tmux-light);

    # Optional example HM config (commented). Copy, adjust, then:
    # home-manager switch --flake .#thibaut@host
    homeConfigurations = let
      mkHome = { system, username, homeDirectory }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { inherit system; };
          modules = [
            self.homeManagerModules.tmux-light
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              programs.home-manager.enable = true;
              tmux-light.enable = true;
            }
          ];
        };
    in {
      # "thibaut@host" = mkHome {
      #   system = "x86_64-linux";
      #   username = "thibaut";
      #   homeDirectory = "/home/thibaut";
      # };
    };
  };
}

