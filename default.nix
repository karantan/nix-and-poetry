let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  poetry2nix = import sources.poetry2nix {
    inherit pkgs;
    inherit (pkgs) poetry;
  };
  # Fixing broken python packages
  poetryOverrides = self: super: {
    # Since poetry2nix prefers to build from source it requires the build tool.
    # That's why we need to explicitly add things like setuptools to the buildInputs.
    # See https://github.com/nix-community/poetry2nix/blob/master/docs/edgecases.md
    hammock = super.hammock.overridePythonAttrs
      (old: { buildInputs = old.buildInputs or [ ] ++ [ super.setuptools ]; });
    humanize = super.humanize.overridePythonAttrs (old: {
      buildInputs = old.buildInputs or [ ]
        ++ [ super.hatchling super.hatch-vcs ];
    });
  };
  commonPoetryArgs = {
    projectDir = ./.;
    overrides = [ pkgs.poetry2nix.defaultPoetryOverrides poetryOverrides ];
  };
  app = poetry2nix.mkPoetryApplication (commonPoetryArgs // { });
  appEnv = poetry2nix.mkPoetryEnv (commonPoetryArgs // { });
  shell = pkgs.mkShell {
    name = "nix-and-python";
    buildInputs = [
      pkgs.niv
      pkgs.poetry
      app
    ];
  };
in
{
  inherit app shell;
}
