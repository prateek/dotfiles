#!/usr/bin/env python3
"""Tiny CLI for demo purposes."""

import argparse
import sys


def main() -> int:
    parser = argparse.ArgumentParser(prog="myapp")
    parser.add_argument(
        "--fast",
        action="store_true",
        help="Skip slow validation passes.",
    )
    parser.add_argument("input", help="Input file")
    args = parser.parse_args()
    mode = "fast" if args.fast else "default"
    print(f"Processing {args.input} in {mode} mode.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
