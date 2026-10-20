import argparse
from dataclasses import dataclass


@dataclass
class Settings:
    format: str = "text"


def parse_args(argv: list[str]) -> Settings:
    parser = argparse.ArgumentParser()
    parser.add_argument("--format", choices=["text"], default="text")
    args = parser.parse_args(argv)
    return Settings(format=args.format)
