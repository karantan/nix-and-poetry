# nix-and-poetry ![gha build](https://github.com/karantan/nix-and-poetry/workflows/nixbuild/badge.svg)
Sandbox for playing with nix, niv, nix2poetry and python app.

## Niv
Use [niv](https://github.com/nmattia/niv) for easy dependency management for Nix projects.

To get started read [README.md](https://github.com/nmattia/niv#install)

Once niv is installed and we've know how to use it (i.e. we've read the docs) we can now
bootstraps a Nix project (I prefer to init it with no packages):

```
niv init --no-nixpkgs
```


Next, find the branch name in [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) (search for
it in the branch dropdown element).

Example for nixpkgs 22.11:

```
niv add NixOS/nixpkgs --name nixpkgs --version 22.11 --branch release-22.11
```

I strongly recommend to always add `--version <version>` tag when adding packages. This
will make projects much easiler to maintain.

Lastly we add poetry2nix:

```
niv add nix-community/poetry2nix --branch master --version 1.39.1 --name poetry2nix
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
We also export `shell` attribute and because it is the only one exported the `nix-shell`
will pick it up (otherwise you will need to specify it e.g. `nix-shell --attr shell`).

At this point we can enter `nix-shell` and we'll have access to `poetry`.

```
[nix-shell:~/nix-and-poetry]$ poetry --version
Poetry (version 1.3.0)
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

At this point we can enter python shell by running:

```
[nix-shell:~/nix-and-poetry]$ poetry run python
Creating virtualenv nix-and-poetry-DUo2HHHU-py3.10 in /Users/karantan/Library/Caches/pypoetry/virtualenvs
Python 3.10.9 (main, Feb  7 2023, 22:22:12) [Clang 11.1.0 ] on darwin
Type "help", "copyright", "credits" or "license" for more information.
```

Next we can add a few dependencies and our code:

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

We also want to be able to run our script as an app so we need to add the following
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

Now everytime you `cd` into this directory your nix env will automatically load.

## Poetry2Nix

So far we have't really used poetry2nix library. Technically we have't even installed it
into our env.

We need it to package our python script into an app (so that we'll be able to execute it
by running `myapp`).

Before we add it to our env, let's read the docs first: [README](https://github.com/nix-community/poetry2nix#api).

The most important attributes are `mkPoetryApplication` and `mkPoetryEnv` (which also
allows package sources of an application to be installed in editable mode for fast
development). We will use both.

Add the following to the `default.nix`:

```
poetry2nix = import sources.poetry2nix {
  inherit pkgs;
  inherit (pkgs) poetry;
};
commonPoetryArgs = {
  projectDir = ./.;
};
app = poetry2nix.mkPoetryApplication (commonPoetryArgs // { });
appEnv = poetry2nix.mkPoetryEnv (commonPoetryArgs // { });
```

Add `appEnv` to `pkgs.mkShell` build inputs, and export `app` (`inherit app shell;`).
You need to export `app` so that the app can be build (see the build section).

The whole `default.nix` file shold look like this:

```
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
      appEnv
    ];
  };
in
{
  inherit app shell;
}
```

Because we are now exporting `app` and `shell` the `nix-shell` won't work anymore.
We can fix this by specifiying which attr to build by providing the `--attr` flag. E.g.

```
nix-shell --attr shell
```

The other option is to make `shell.nix` file with the following content:

```
(import ./default.nix).shell
```

## Build

Now that everything is wired up we can easily build the app. By default `nix-build` will
try to build all attributes. In our case we have `app` and `shell`.

Because `shell` is poetry environment which is meant to be editable, it doesn't make
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
## Troubleshooting

If you install a broken python package (e.g. `humanize==4.6.0`) you won't be able to enter
nix-shell (or direnv reload will break). For example you might get the following error
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

### Nuking poetry env

Poetry uses virtualenv and sometimes it's a bit too sticky so you might want to remove
everything and start over.

First list all envs and then remove it. Example:

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
