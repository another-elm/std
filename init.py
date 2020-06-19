#! /usr/bin/env python3

import fileinput
import os
import sys
from pathlib import Path

elm_std_dir = Path(__file__).resolve().parent
binary_path = Path.home() / ".local" / "bin" / "another-elm"


def is_update_needed(package_root, relevant_custom_paths):
    last_updated_time = None

    try:
        last_updated_time = os.path.getmtime(
            os.path.join(package_root, 'custom'))
    except (FileNotFoundError, ValueError):
        return True

    for relevant_custom_path in relevant_custom_paths:
        if os.path.getmtime(relevant_custom_path) > last_updated_time:
            return True
        for dirpath, _, files in os.walk(relevant_custom_path):
            if os.path.getmtime(dirpath) > last_updated_time:
                return True
            for file in files:
                if os.path.getmtime(os.path.join(dirpath,
                                                 file)) > last_updated_time:
                    return True


def reset_package(packages_root, author, package):
    versions_dir = os.path.join(packages_root, author, package)
    custom_package_dir = os.path.join(elm_std_dir, package)

    custom_src_dir = os.path.join(custom_package_dir, "src")
    custom_json_file = os.path.join(custom_package_dir, "elm.json")

    try:
        dirs = os.listdir(versions_dir)
    except FileNotFoundError:
        dirs = []

    any_modified = False
    for v in dirs:
        package_root = os.path.join(versions_dir, v)

        if is_update_needed(package_root, [custom_src_dir, custom_json_file]):
            any_modified = True

            try:
                os.remove(os.path.join(package_root, 'custom'))
            except FileNotFoundError:
                pass

    return any_modified


def create_executable(path):
    raw_fd = os.open(path,
                     flags=os.O_CREAT | os.O_WRONLY | os.O_TRUNC,
                     mode=0o777)
    return os.fdopen(raw_fd, "w")


def install_exe(binary):
    bin_dir = binary.parent

    if bin_dir not in map(Path, os.getenv("PATH").split(":")):
        print("WARNING: {} is not in PATH. Please add it!".format(bin_dir),
              file=sys.stderr)

    with create_executable(binary) as f:
        def print_to_file(s):
            print(s, file=f, end='')

        for line in fileinput.input(elm_std_dir / "another-elm"):
            if line == "elm_std_dir = None  # REPLACE ME\n":
                print_to_file('elm_std_dir = Path("{}")\n'.format(elm_std_dir))
            else:
                print_to_file(line)


def main():
    elm_home_dir = os.getenv('ELM_HOME', default=os.path.expanduser('~/.elm'))
    another_elm_home_dir = os.path.join(elm_home_dir, 'another')

    try:
        elm_versions = os.listdir(another_elm_home_dir)
    except FileNotFoundError:
        print("""
        Warning: nothing reset as elm home is empty (just run `another-elm`).
        """.strip(),
              file=sys.stderr)

        return 0

    some_packages_reset = False
    for elm_version in elm_versions:
        packages_root = os.path.join(another_elm_home_dir, elm_version,
                                     'packages')

        for (author, pkg) in [('elm', 'core'), ('elm', 'json'),
                              ('elm', 'browser'), ('elm-explorations', 'test'),
                              ('elm-explorations', 'markdown')]:
            if reset_package(packages_root, author, pkg):
                some_packages_reset = True

    if not some_packages_reset:
        print("""
        Warning: nothing reset as source is no newer than linked packages.
        """.strip(),
              file=sys.stderr)

    install_exe(binary_path)

    print("Success!", end=' ')
    if binary_path.exists():
        print('Reinstalled another-elm to "{}" and reset std packages.'.format(
            binary_path))
    else:
        print('Installed another-elm to "{}".'.format(binary_path))

    print('Note: Moving "{}" will break another-elm'.format(elm_std_dir))
    print('      (run ./init.py again to fix)')

    return 0


if __name__ == '__main__':
    exit(main())
