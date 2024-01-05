let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  poetry2nix = import sources.poetry2nix { pkgs = pkgs; };
  # Fixing broken python packages
  pypkgs-build-requirements = {
    hammock = [ "setuptools" ];
    humanize = [ "hatchling" "hatch-vcs" ];
    ruamel-yaml-clib = [ "flit" ];
  };
  p2n-overrides = poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs (package: build-requirements:
      (builtins.getAttr package super).overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg: if builtins.isString pkg then builtins.getAttr pkg super else pkg) build-requirements);
      })
    ) pypkgs-build-requirements
  );
  commonPoetryArgs = {
    projectDir = ./.;
    preferWheels = true;
    overrides = p2n-overrides;
  };
  app = poetry2nix.mkPoetryApplication (commonPoetryArgs // { });
  appEnv = poetry2nix.mkPoetryEnv (commonPoetryArgs // { });
  shell = pkgs.mkShell {
    name = "nix-and-python";
    buildInputs = [
      pkgs.poetry
      app
    ];
    # install pre-commit hook
    shellHook = ''
      if [[ -d .git ]]; then
        pre-commit install -f --hook-type pre-commit
        pre-commit install -f --hook-type pre-push
      fi
    '';
  };
in
{
  inherit app shell;
}
