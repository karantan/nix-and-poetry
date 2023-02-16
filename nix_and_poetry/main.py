import requests
import humanize
import toml
import click


def cli():
    print("Hello World!")
    print(requests.__version__)
    print(humanize.__version__)
    print(toml.__version__)
    print(click.__version__)


if __name__ == "__main__":
    print("Executing the script directly")
    cli()
