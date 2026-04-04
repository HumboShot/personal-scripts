#!/usr/bin/env python3
"""
Flatten nested files into a single root directory.

Given a root directory, this script walks all subdirectories and moves every file
it finds into the root directory.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Move all files from nested subdirectories into the provided root folder."
        )
    )
    parser.add_argument(
        "directory",
        type=Path,
        help="Root folder to flatten (files from subfolders are moved here).",
    )
    parser.add_argument(
        "--on-conflict",
        choices=["rename", "skip", "overwrite"],
        default="rename",
        help=(
            "What to do when a file with the same name already exists in root. "
            "Default: rename"
        ),
    )
    parser.add_argument(
        "--remove-empty-dirs",
        action="store_true",
        help="Remove empty subdirectories after files are moved.",
    )
    return parser.parse_args()


def unique_destination(root: Path, filename: str) -> Path:
    candidate = root / filename
    if not candidate.exists():
        return candidate

    stem = candidate.stem
    suffix = candidate.suffix
    index = 1

    while True:
        candidate = root / f"{stem}_{index}{suffix}"
        if not candidate.exists():
            return candidate
        index += 1


def move_file(src: Path, root: Path, on_conflict: str) -> tuple[bool, str]:
    target = root / src.name

    if target.exists():
        if on_conflict == "skip":
            return False, f"SKIP  {src}"
        if on_conflict == "overwrite":
            target.unlink()
        else:
            target = unique_destination(root, src.name)

    shutil.move(str(src), str(target))
    return True, f"MOVE  {src} -> {target.name}"


def remove_empty_directories(root: Path) -> int:
    removed = 0
    # Reverse depth order so children are removed before their parents.
    subdirs = sorted((p for p in root.rglob("*") if p.is_dir()), key=lambda p: len(p.parts), reverse=True)

    for folder in subdirs:
        if folder == root:
            continue
        try:
            folder.rmdir()
            removed += 1
        except OSError:
            pass

    return removed


def main() -> int:
    args = parse_args()
    root = args.directory.resolve()

    if not root.exists() or not root.is_dir():
        print(f"Error: '{root}' is not a valid directory.")
        return 1

    files_to_move = [p for p in root.rglob("*") if p.is_file() and p.parent != root]

    if not files_to_move:
        print(f"No files found in subdirectories of '{root}'.")
        print("Nothing to move.")
        return 0

    moved = 0
    skipped = 0

    for src in files_to_move:
        did_move, message = move_file(src, root, args.on_conflict)
        print(message)
        if did_move:
            moved += 1
        else:
            skipped += 1

    removed_dirs = 0
    if args.remove_empty_dirs:
        removed_dirs = remove_empty_directories(root)

    print("\nDone")
    print(f"Moved: {moved}")
    print(f"Skipped: {skipped}")
    if args.remove_empty_dirs:
        print(f"Removed empty directories: {removed_dirs}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
