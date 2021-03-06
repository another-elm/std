#! /usr/bin/env python3

import fileinput
import os
import shutil
import subprocess
import sys
from pathlib import Path

elm_std_dir = Path(__file__).resolve().parent
binary_path = Path.home() / ".local" / "bin" / "another-elm"
xdg_data_home = os.environ.get(
    "XDG_DATA_HOME",
    Path.home() / ".local" / "share",
)
customised_dir = xdg_data_home / "another-elm" / "packages"


def is_update_needed(custom_dir, relevant_local_paths):
    last_updated_time = None

    try:
        last_updated_time = (custom_dir / 'custom').stat().st_mtime
    except (FileNotFoundError, ValueError):
        return True

    for relevant_local_path in relevant_local_paths:
        if relevant_local_path.stat().st_mtime > last_updated_time:
            return True
        for dirpath, _, files in os.walk(relevant_local_path):
            dirpath = Path(dirpath)
            if dirpath.stat().st_mtime > last_updated_time:
                return True
            for file in files:
                if (dirpath / file).stat().st_mtime > last_updated_time:
                    return True


def reset_package(packages_root, author, package):
    local_package_dir = elm_std_dir / package
    local_src_dir = local_package_dir / "src"
    local_json_file = local_package_dir / "elm.json"

    custom_package_dir = customised_dir / author / package
    custom_src_dir = custom_package_dir / "src"
    custom_json_file = custom_package_dir / "elm.json"

    any_modified = False

    if is_update_needed(custom_package_dir, [local_src_dir, local_json_file]):
        any_modified = True

        try:
            shutil.rmtree(custom_package_dir)
        except FileNotFoundError:
            pass
        custom_package_dir.mkdir(parents=True, exist_ok=True)
        shutil.copytree(local_src_dir, custom_src_dir)
        shutil.copy(local_json_file, custom_json_file)
        with open(custom_package_dir / 'custom', 'w'):
            pass

        versions_dir = packages_root / author / package
        try:
            dirs = os.listdir(versions_dir)
        except FileNotFoundError:
            dirs = []

        for v in dirs:
            package_root = versions_dir / v

            try:
                (package_root / 'custom').unlink()
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

    hash = subprocess.run(["git", "rev-parse", "HEAD"],
                          stderr=subprocess.PIPE,
                          stdout=subprocess.PIPE,
                          check=True).stdout.decode("utf-8").strip()

    if bin_dir not in map(Path, os.getenv("PATH").split(":")):
        print("WARNING: {} is not in PATH. Please add it!".format(bin_dir),
              file=sys.stderr)

    with create_executable(binary) as f:

        def print_to_file(s):
            print(s, file=f, end='')

        for line in fileinput.input(elm_std_dir / "another-elm"):
            if line == "another_elm_version = None  # REPLACE ME\n":
                print_to_file(f'another_elm_version = "git-{hash}"\n')
            else:
                print_to_file(line)


def update_packages():
    elm_home_dir = os.getenv('ELM_HOME', default=Path.home() / '.elm')
    another_elm_home_dir = elm_home_dir / 'another'

    try:
        elm_versions = os.listdir(another_elm_home_dir)
    except FileNotFoundError:
        print("""
        Warning: nothing reset as elm home is empty (just run `another-elm`).
        """.strip(),
              file=sys.stderr)

        return

    some_packages_reset = False
    for elm_version in elm_versions:
        packages_root = another_elm_home_dir / elm_version / 'packages'

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


def main():
    update_packages()

    exists = binary_path.exists()
    install_exe(binary_path)

    print("Success!", end=' ')
    if exists:
        print('Reinstalled another-elm to "{}" and reset std packages.'.format(
            binary_path))
    else:
        print('Installed another-elm to "{}".'.format(binary_path))

    print('Note: Moving "{}" will break another-elm'.format(elm_std_dir))
    print('      (run ./init.py again to fix)')

    return 0


if __name__ == '__main__':
    exit(main())
