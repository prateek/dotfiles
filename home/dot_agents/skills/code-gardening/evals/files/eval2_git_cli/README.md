# myapp

A tiny demo CLI.

## Install

```
pip install -e .
```

## Usage

Basic:

```
myapp input.txt
```

Skip slow validation with `--quick`:

```
myapp --quick input.txt
```

## Notes

The `--quick` flag was added in v0.2. It is safe to use on trusted inputs only.
