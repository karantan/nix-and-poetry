let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  poetry2nix = import sources.poetry2nix {
    inherit pkgs;
    inherit (pkgs) poetry;
  };
  commonPoetryArgs = {
    projectDir = ./.;
  };
  app = poetry2nix.mkPoetryApplication (commonPoetryArgs // { });
  appEnv = poetry2nix.mkPoetryEnv (commonPoetryArgs // { });
  shell = pkgs.mkShell {
    name = "nix-and-python";
    buildInputs = [
      pkgs.poetry
      app
    ];
  };
in
{
  inherit app shell;
}
