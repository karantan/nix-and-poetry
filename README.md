# nix-and-poetry ![gha build](https://github.com/karantan/nix-and-poetry/workflows/nixbuild/badge.svg)
Sandbox for playing with nix, niv, nix2poetry and python app.

## Theory (expressions, derivations and attribute sets)

First let's start with some theory. You will need this knowledge to understand things
like why we have `(import ./default.nix).shell` in the `shell.nix` and not
`(import ./default.nix {}).shell` or `import ./default.nix {}`.

Also sometimes you will see nix package that starts with `{}:` and sometimes it starts
with `let`. E.g.

```
let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  shell = pkgs.mkShell {
    ...
  };
in
{
  inherit shell;
}
```

Is basically the same as

```
{ ... }:
let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  shell = pkgs.mkShell {
    ...
  };
in
{
  inherit shell;
}
```

except this one is a function so you need to call it first in order to access the
attribute set. The first one you don't.

A piece of Nix language code is a **Nix expression**.

Nix expressions are used to describe packages and how to build them. This typically mean
the definition of a function with multiple inputs which as a result in a derivation.

However a Nix expression can be everything, from a simple string, to a function to
a set of expressions.

**Derivations** are the building blocks of a Nix system, from a file system view point.
They define a build, which takes some inputs and produces an output. The inputs are
almost always in a `src` attribute, and outputs are almost always some
`/nix/store/some-hash-pkg-name` path. That's why we can do [string interpolations](https://nix.dev/tutorials/nix-language#string-interpolation)
on them (e.g. ${pkgs.nix} => "/nix/store/...-nix-2.11.0").

Whenever you see `mkDerivation`, it denotes something that Nix will eventually build.

Example

```
{ lib, stdenv, fetchgit }:

stdenv.mkDerivation {
  name = "hello";
  src = fetchgit {
    url = "https://...";
    sha256 = lib.fakeHash;
  };
}
```

The evaluation result of `mkDerivation` is an [`attribute set`](https://nix.dev/tutorials/nix-language#attrset)
with a certain structure and a special property: It can be used in string interpolation,
and in that case evaluates to the Nix store path of its build result.

In this project we won't use `mkDerivation` but we will use:
- `mkShell` (specialized `stdenv.mkDerivation`),
- `mkPoetryApplication` ("mkDerivation" for python applications) and
- `mkPoetryEnv` ("mkDerivation" for seting up python environment).

Other languages might have different conviniance functions to build derivations like
[`buildGoModule`](https://ryantm.github.io/nixpkgs/languages-frameworks/go/#ex-buildGoModule)

Ref:
- [nix.dev](https://nix.dev/tutorials/nix-language#derivations)
- [nixos wiki](https://nixos.wiki/wiki/Overview_of_the_Nix_Language#Expressions)

### Nix Anti-patterns

A cheatsheat of [nix anti-patterns](https://nix.dev/anti-patterns/):

1. Don't use `rec { ... }`. Use `let ... in`
2. Don't use `with attrset; ...`. Use `let ... in` combined with `inherit`
3. Don't use `./.` for referencing top-level directory. Use `builtins.path`


## Niv
Use [niv](https://github.com/nmattia/niv) for easy dependency management for Nix projects.

To get started read [README.md](https://github.com/nmattia/niv#install)

```
nix-shell -p niv
niv init --no-nixpkgs
```

Next, find the branch name in [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) (search for
it in the branch dropdown element).

It's a good idea to also look at [Nix Channel Status](https://status.nixos.org/) to
make sure you add the channel you want.

Example for nixpkgs 23.11:

```
niv add NixOS/nixpkgs --name nixpkgs --version 23.11 --branch release-23.11 --rev 057f9aecfb71c4437d2b27d3323df7f93c010b7e
```

or nixos-unstable-small:

```
niv add NixOS/nixpkgs --name nixpkgs --version nixos-unstable-small --branch master --rev d307dfa20b1873b46615253b44b837d54143a82d
```

I strongly recommend to always add `--version <version>` tag when adding packages. This
will make projects much easier to maintain.

Lastly, we add poetry2nix:

```
niv add nix-community/poetry2nix --branch master --rev 528d500ea826383cc126a9be1e633fc92b19ce5d --version 2023.12.2614813 --name poetry2nix
```

This concludes our nix dependencies and nix.

## Configuring default.nix and shell.nix

Create `default.nix` file with the following content:

```
let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  shell = pkgs.mkShell {
    name = "nix-and-python";
    buildInputs = [
      pkgs.poetry
    ];
  };
in
{
  inherit shell;
}
```

Here we tell nix where is the source for nixpkgs and how to build poetry2nix package.
We add `pkgs.niv` so that we'll be able to update nix `source.json` in the future.

We also export `shell` attribute and because it is the only one exported the `nix-shell`
will pick it up (otherwise you will need to specify it e.g. `nix-shell --attr shell`).

At this point, we can enter `nix-shell` and we'll have access to `poetry`.

```
[nix-shell:~/nix-and-poetry]$ poetry --version
Poetry (version 1.7.1)
```

Bootstraps a poetry project with `poetry init`. Poetry will generate `pyproject.toml`
with the following content:

```
[tool.poetry]
name = "nix-and-poetry"
version = "0.1.0"
description = ""
authors = ["Your Name <you@example.com>"]
readme = "README.md"
packages = [{include = "nix_and_poetry"}]

[tool.poetry.dependencies]
python = "^3.10"


[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
```

Enter python shell by running:

```
[nix-shell:~/nix-and-poetry]$ poetry run python
Creating virtualenv nix-and-poetry-DUo2HHHU-py3.10 in /Users/karantan/Library/Caches/pypoetry/virtualenvs
Python 3.10.9 (main, Feb  7 2023, 22:22:12) [Clang 11.1.0 ] on darwin
Type "help", "copyright", "credits" or "license" for more information.
```

Next, we can add a few dependencies and our code:

```
poetry add requests
poetry add toml
poetry add humanize==4.4.0
poetry add click
```

Now we can run our simple script.

```
[nix-shell:~/nix-and-poetry]$ poetry run python src/main.py
Hello World!
2.28.2
4.4.0
0.10.2
8.1.3
```

We also want to be able to run our script as an app, so we need to add the following
to the pyproject.toml:

```
[tool.poetry.scripts]
myapp = "nix_and_poetry.main:cli"
```

Once we package this script to an app we'll be able to run it directly in the shell by
executing `myapp` command.

Read more about poetry scripts [here](https://python-poetry.org/docs/pyproject/#scripts).

## Direnv

[`direnv`](https://direnv.net/) is an extension for your shell. It augments existing
shells with a new feature that can load and unload environment variables depending on
the current directory.

We will use it to enter our nix environment without having to do `nix-shell`. Exit
`nix-shell` and do the following:

```
echo "use nix" > .envrc
direnv allow
```

Now every time you `cd` into this directory, your nix env will automatically load.

## Poetry2Nix

So far, we haven't really used poetry2nix library. Technically we haven't even installed it
into our env.

We need it to package our python script into an app (so that we'll be able to execute it
by running `myapp`).

Before we add it to our env, let's read the docs first: [README](https://github.com/nix-community/poetry2nix#api).

The most important attributes are `mkPoetryApplication` and `mkPoetryEnv` (which also
allows package sources of an application to be installed in editable mode for fast
development). We will use both.

Add the following to the `default.nix`:

```
poetry2nix = import sources.poetry2nix { pkgs = pkgs; };
commonPoetryArgs = {
  projectDir = ./.;
};
app = pkgs.poetry2nix.mkPoetryApplication (commonPoetryArgs // { });
appEnv = pkgs.poetry2nix.mkPoetryEnv (commonPoetryArgs // { });
```

Add `appEnv` to `pkgs.mkShell` build inputs, and export `app` (`inherit app shell;`).
You need to export `app` so the app can be built (see the build section).

The whole `default.nix` file should look like this:

```
let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  poetry2nix = import sources.poetry2nix { pkgs = pkgs; };
  commonPoetryArgs = {
    projectDir = ./.;
  };
  app = pkgs.poetry2nix.mkPoetryApplication (commonPoetryArgs // { });
  appEnv = pkgs.poetry2nix.mkPoetryEnv (commonPoetryArgs // { });
  shell = pkgs.mkShell {
    name = "nix-and-python";
    buildInputs = [
      pkgs.poetry
      appEnv
    ];
  };
in
{
  inherit app shell;
}
```

Because we are now exporting `app` and `shell` the `nix-shell` won't work anymore.
We can fix this by specifying which attr to build by providing the `--attr` flag. E.g.

```
nix-shell --attr shell
```

The other option is to make `shell.nix` file with the following content:

```
(import ./default.nix).shell
```

## Build

Now that everything is wired up, we can build the app. By default `nix-build` will
try to build all attributes. In our case we have `app` and `shell`.

Because `shell` is poetry environment that is meant to be editable, it doesn't make
sense to build it, so let's only build the `app`:

```bash
➜  nix-and-poetry git:(master) ✗ nix-build --attr app                                                                                                                 ~/github/nix-and-poetry
/nix/store/14dfyi0pxzsfqs33bvpisdb5ajghdzx5-python3.10-nix-and-poetry-0.1.0
➜  nix-and-poetry git:(master) ✗ ./result/bin/myapp                                                                                                                   ~/github/nix-and-poetry
Hello World!
2.28.2
4.4.0
0.10.2
8.1.3
```

## Importing the package

Usually you'll want to import the package in your NixOS configuration so that you can
use it.

```
...
  packageRepo = fetchGit {
    url = "git@github.com:teamniteo/ebn-nixos";
    ref = "master";
    rev = "...";
  };
  myPackage = (import packageRepo).app

  environment.systemPackages = [
    myPackage
    ...
  ];
...
```

## Troubleshooting

If you install a broken python package (e.g. `humanize==4.6.0`) you won't be able to enter
nix-shell (or direnv reload will break). For example, you might get the following error
if you install humanize v4.6.0 (with poetry) and then run `direnv reload` (or re-enter
`nix-shell`):

```
  File "<frozen importlib._bootstrap>", line 1027, in _find_and_load
  File "<frozen importlib._bootstrap>", line 1004, in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1004, in _find_and_load_unlocked
ModuleNotFoundError: No module named 'hatchling'
ModuleNotFoundError: No module named 'hatchling'




builder for '/nix/store/7pri0f0hcbyww01gn2z2gsrlm036b3kb-python3.10-humanize-4.6.0.drv' failed with exit code 2
cannot build derivation '/nix/store/xca681yxsm8w3gqfvccvfdk0ri9qc3nd-python3-3.10.9-env.drv': 1 dependencies couldn't be built
error: build of '/nix/store/xca681yxsm8w3gqfvccvfdk0ri9qc3nd-python3-3.10.9-env.drv' failed
```

To fix this you will need to:
1. remove mkPoetryEnv app from `pkgs.mkShell.buildInputs` (so that poetry2nix doesn't run)
2. remove/update the broken package (this will probably be the hard part because it might be hard to find it)
3. run `poetry lock && poetry install` to lock the `poetry.lock` file and install the new package(s)
4. add mkPoetryEnv app back to `pkgs.mkShell.buildInputs` and enter `nix-shell` (or run `direnv reload`)

Another option would be to manage `poetry.lock` and `pyproject.toml` with an outside `poetry`
package. E.g.

```bash
cd ..
nix-shell -p poetry
cd -
# make changes to python packages ...
poetry lock
poetry install
# exit nix-shell
```

### No module named 'PACKAGENAME'

At times, you might encounter an error `ModuleNotFoundError: No module named 'setuptools'` when attempting to access nix-shell. This issue arises because poetry2nix requires an additional package for building the Python package. You can provide the needed package through buildInputs in default.nix, as shown in the example below:

```
humanize = super.humanize.overridePythonAttrs (old: {
  buildInputs = old.buildInputs or [ ] ++ [ super.hatchling super.hatch-vcs ];
});
```

For more information on why this happens, visit: https://github.com/nix-community/poetry2nix/blob/master/docs/edgecases.md

If you discover these packages and fix them in your project, please consider creating a pull request to update this file: https://github.com/nix-community/poetry2nix/blob/master/overrides/build-systems.json. Doing so will save other developers from having to address the same issue.

### Problems unpacking wheels

I've encountered a problem with `bcrypt` with `preferWheels = true;` option in `poetry2nix.mkPoetryEnv`
configuration. I have macos (M2) and bcrypt had only wheels compiled with cpython 37 but
I needed them with cphython 310.

This was the package content in poetry.lock:

```
[[package]]
name = "bcrypt"
version = "4.1.1"
description = "Modern password hashing for your software and your servers"
optional = false
python-versions = ">=3.7"
files = [
    {file = "bcrypt-4.1.1-cp37-abi3-macosx_10_12_universal2.whl", hash = "sha256:196008d91201bbb1aa4e666fee5e610face25d532e433a560cabb33bfdff958b"},
    {file = "bcrypt-4.1.1-cp37-abi3-macosx_13_0_universal2.whl", hash = "sha256:2e197534c884336f9020c1f3a8efbaab0aa96fc798068cb2da9c671818b7fbb0"},
    {file = "bcrypt-4.1.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl", hash = "sha256:d573885b637815a7f3a3cd5f87724d7d0822da64b0ab0aa7f7c78bae534e86dc"},
    {file = "bcrypt-4.1.1-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl", hash = "sha256:bab33473f973e8058d1b2df8d6e095d237c49fbf7a02b527541a86a5d1dc4444"},
    {file = "bcrypt-4.1.1-cp37-abi3-manylinux_2_28_aarch64.whl", hash = "sha256:fb931cd004a7ad36a89789caf18a54c20287ec1cd62161265344b9c4554fdb2e"},
    {file = "bcrypt-4.1.1-cp37-abi3-manylinux_2_28_x86_64.whl", hash = "sha256:12f40f78dcba4aa7d1354d35acf45fae9488862a4fb695c7eeda5ace6aae273f"},
    {file = "bcrypt-4.1.1-cp37-abi3-musllinux_1_1_aarch64.whl", hash = "sha256:2ade10e8613a3b8446214846d3ddbd56cfe9205a7d64742f0b75458c868f7492"},
    {file = "bcrypt-4.1.1-cp37-abi3-musllinux_1_1_x86_64.whl", hash = "sha256:f33b385c3e80b5a26b3a5e148e6165f873c1c202423570fdf45fe34e00e5f3e5"},
    {file = "bcrypt-4.1.1-cp37-abi3-musllinux_1_2_aarch64.whl", hash = "sha256:755b9d27abcab678e0b8fb4d0abdebeea1f68dd1183b3f518bad8d31fa77d8be"},
    {file = "bcrypt-4.1.1-cp37-abi3-musllinux_1_2_x86_64.whl", hash = "sha256:a7a7b8a87e51e5e8ca85b9fdaf3a5dc7aaf123365a09be7a27883d54b9a0c403"},
    {file = "bcrypt-4.1.1-cp37-abi3-win32.whl", hash = "sha256:3d6c4e0d6963c52f8142cdea428e875042e7ce8c84812d8e5507bd1e42534e07"},
    {file = "bcrypt-4.1.1-cp37-abi3-win_amd64.whl", hash = "sha256:14d41933510717f98aac63378b7956bbe548986e435df173c841d7f2bd0b2de7"},
    {file = "bcrypt-4.1.1-pp310-pypy310_pp73-manylinux_2_28_aarch64.whl", hash = "sha256:24c2ebd287b5b11016f31d506ca1052d068c3f9dc817160628504690376ff050"},
    {file = "bcrypt-4.1.1-pp310-pypy310_pp73-manylinux_2_28_x86_64.whl", hash = "sha256:476aa8e8aca554260159d4c7a97d6be529c8e177dbc1d443cb6b471e24e82c74"},
    {file = "bcrypt-4.1.1-pp39-pypy39_pp73-manylinux_2_28_aarch64.whl", hash = "sha256:12611c4b0a8b1c461646228344784a1089bc0c49975680a2f54f516e71e9b79e"},
    {file = "bcrypt-4.1.1-pp39-pypy39_pp73-manylinux_2_28_x86_64.whl", hash = "sha256:c6450538a0fc32fb7ce4c6d511448c54c4ff7640b2ed81badf9898dcb9e5b737"},
    {file = "bcrypt-4.1.1.tar.gz", hash = "sha256:df37f5418d4f1cdcff845f60e747a015389fa4e63703c918330865e06ad80007"},
]

```

I removed all wheels except the one built with `pp310-pypy310` and kept the source
(`bcrypt-4.1.1.tar.gz`) so that we can build locally from source.

This was what I kept:


```
[[package]]
name = "bcrypt"
version = "4.1.1"
description = "Modern password hashing for your software and your servers"
optional = false
python-versions = ">=3.7"
files = [
    {file = "bcrypt-4.1.1-pp310-pypy310_pp73-manylinux_2_28_aarch64.whl", hash = "sha256:24c2ebd287b5b11016f31d506ca1052d068c3f9dc817160628504690376ff050"},
    {file = "bcrypt-4.1.1-pp310-pypy310_pp73-manylinux_2_28_x86_64.whl", hash = "sha256:476aa8e8aca554260159d4c7a97d6be529c8e177dbc1d443cb6b471e24e82c74"},
    {file = "bcrypt-4.1.1.tar.gz", hash = "sha256:df37f5418d4f1cdcff845f60e747a015389fa4e63703c918330865e06ad80007"},
]
```

Nix was then forced to build bcrypt from the source:

```
$ nix-shell --attr shell
...

building '/nix/store/jm383pp89mds8nvibgcbcpkycwqvmrb0-bcrypt-4.1.1-vendor.tar.gz.drv'...
Running phase: unpackPhase
unpacking source archive /nix/store/xwd23rdn9sc2lf441xdzam7jfjqqin1g-bcrypt-4.1.1.tar.gz
source root is bcrypt-4.1.1/src/_bcrypt
setting SOURCE_DATE_EPOCH to timestamp 1701185840 of file bcrypt-4.1.1/src/_bcrypt/src/lib.rs
Running phase: patchPhase
Running phase: updateAutotoolsGnuConfigScriptsPhase
Running phase: configurePhase
no configure script, doing nothing
Running phase: buildPhase
    Updating crates.io index
 Downloading crates ...
  Downloaded windows-targets v0.48.5
...
Running phase: installPhase
Running phase: fixupPhase
checking for references to /private/tmp/nix-build-bcrypt-4.1.1-vendor.tar.gz.drv-0/ in /nix/store/w2x0gvq916zqwc32m9mbrg2mqj7crn65-bcrypt-4.1.1-vendor.tar.gz...
patching script interpreter paths in /nix/store/w2x0gvq916zqwc32m9mbrg2mqj7crn65-bcrypt-4.1.1-vendor.tar.gz
...

```
### Nuking nix env

Sometimes you'll need to delete the whole nix store and start over (i.e. nuking the dev env).

Example:
```
➜  nix-and-poetry git:(master) ✗ nix-shell
error: list index 2 is out of bounds

       at /nix/store/1924yaibwnbbkgkdp8xhij576p8hyd35-poetry2nix-src/shell-scripts.nix:10:12:

            9|       module = elem 0;
           10|       fn = elem 2;
             |            ^
           11|     in
(use '--show-trace' to show detailed location information)

➜  nix-and-poetry git:(master) ✗ nix store delete /nix/store/1924yaibwnbbkgkdp8xhij576p8hyd35-poetry2nix-src
finding garbage collector roots...
removing stale link from '/nix/var/nix/gcroots/auto/9wb874rj1n16brhik5pzz9gsf9yzpl70' to '/private/tmp/nix-build-43846-0/result'
removing stale link from '/nix/var/nix/gcroots/auto/ik19hyliml7ay2r9brz33xbnkhyqcs51' to '/Users/karantan/github/nix-and-poetry/.direnv/nix/shell.drv'
deleting '/nix/store/1924yaibwnbbkgkdp8xhij576p8hyd35-poetry2nix-src'
deleting '/nix/store/trash'
deleting unused links...
note: currently hard linking saves 0.00 MiB
1 store paths deleted, 1.94 MiB freed

```

Ref: https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-store.html

### Nuking poetry env

Poetry uses virtualenv, and sometimes it's a bit too sticky, so you might want to remove
everything and start over.

First, list all envs and then remove it. Example:

```
[nix-shell:~/github/nix-and-poetry]$ poetry env info

Virtualenv
Python:         3.10.9
Implementation: CPython
Path:           /Users/karantan/Library/Caches/pypoetry/virtualenvs/nix-and-poetry-DUo2HHHU-py3.10
Executable:     /Users/karantan/Library/Caches/pypoetry/virtualenvs/nix-and-poetry-DUo2HHHU-py3.10/bin/python
Valid:          True

System
Platform:   darwin
OS:         posix
Python:     3.10.9
Path:       /nix/store/byzcml7gf80m6h41371wvcwm5rb06swr-python3-3.10.9
Executable: /nix/store/byzcml7gf80m6h41371wvcwm5rb06swr-python3-3.10.9/bin/python3.10

[nix-shell:~/github/nix-and-poetry]$ poetry env remove nix-and-poetry-DUo2HHHU-py3.10
Deleted virtualenv: /Users/karantan/Library/Caches/pypoetry/virtualenvs/nix-and-poetry-DUo2HHHU-py3.10

[nix-shell:~/github/nix-and-poetry]$ poetry install
Creating virtualenv nix-and-poetry-DUo2HHHU-py3.10 in /Users/karantan/Library/Caches/pypoetry/virtualenvs
Installing dependencies from lock file

Package operations: 8 installs, 0 updates, 0 removals

  • Installing certifi (2022.12.7)
  • Installing charset-normalizer (3.0.1)
  • Installing idna (3.4)
  • Installing urllib3 (1.26.14)
  • Installing click (8.1.3)
  • Installing humanize (4.4.0)
  • Installing requests (2.28.2)
  • Installing toml (0.10.2)

Installing the current project: nix-and-poetry (0.1.0)

[nix-shell:~/github/nix-and-poetry]$ poetry run python
Python 3.10.9 (main, Feb  7 2023, 22:22:12) [Clang 11.1.0 ] on darwin
Type "help", "copyright", "credits" or "license" for more information.

```

Ref: https://python-poetry.org/docs/managing-environments/
