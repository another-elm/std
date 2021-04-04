#! /usr/bin/env python3

import argparse
import fileinput
import os
import random
import shutil
import subprocess
import sys
from fileinput import FileInput
from pathlib import Path

version = 0

parser = argparse.ArgumentParser(description='Initialise/install another-elm')

parser.add_argument('--dir',
                    type=Path,
                    help="Directory to install another-elm into",
                    default=Path.home() / ".local" / "bin")

args = parser.parse_args()

elm_std_dir = Path(__file__).resolve().parent
binary_path = args.dir / "another-elm"
xdg_data_home = os.environ.get(
    "XDG_DATA_HOME",
    Path.home() / ".local" / "share",
)
customised_dir = xdg_data_home / "another-elm" / "packages"


def copy_file_with_replacement(src, dest, random_suffix, another_elm_version):
    def on_line(line):
        return line.replace(
            "Platform.Unstable.",
            f"Platform.Unstable{random_suffix}.",
        ).replace(
            'ANOTHER-ELM-VERSION',
            another_elm_version,
        )

    with dest.open(mode='w') as dest_file:
        with FileInput(src, inplace=False) as src_reader:
            for line in src_reader:
                print(on_line(line), end='', file=dest_file)


def copy_dir_with_replacement(src, dest, random_suffix, another_elm_version):
    dest.mkdir(exist_ok=True)
    for entry in os.scandir(src):
        file_suffix = random_suffix if entry.name == 'Unstable' else ''
        dest_name = dest / f"{entry.name}{file_suffix}"
        if entry.is_dir():
            copy_dir_with_replacement(
                src / entry.name,
                dest_name,
                random_suffix,
                another_elm_version,
            )
        else:
            copy_file_with_replacement(
                src / entry.name,
                dest_name,
                random_suffix,
                another_elm_version,
            )


def reset_package(
    packages_roots,
    author,
    package,
    random,
    another_elm_version,
):
    local_package_dir = elm_std_dir / package
    local_src_dir = local_package_dir / "src"
    local_json_file = local_package_dir / "elm.json"

    custom_package_dir = customised_dir / author / package
    custom_src_dir = custom_package_dir / "src"
    custom_json_file = custom_package_dir / "elm.json"

    custom_package_dir.mkdir(parents=True, exist_ok=True)
    copy_dir_with_replacement(
        local_src_dir,
        custom_src_dir,
        random,
        another_elm_version,
    )
    copy_file_with_replacement(
        local_json_file,
        custom_json_file,
        random,
        another_elm_version,
    )
    with open(custom_package_dir / 'custom', 'w'):
        pass

    for packages_root in packages_roots:
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


def create_executable(path):
    raw_fd = os.open(path,
                     flags=os.O_CREAT | os.O_WRONLY | os.O_TRUNC,
                     mode=0o777)
    return os.fdopen(raw_fd, "w")


def version_string():
    try:
        hash = subprocess.run(["git", "rev-parse", "HEAD"],
                              stderr=subprocess.PIPE,
                              stdout=subprocess.PIPE,
                              check=True).stdout.decode("utf-8").strip()
        return f"git-{hash}"
    except subprocess.CalledProcessError:
        return f"v{version}"


def install_exe(binary, random_suffix, another_elm_version):
    bin_dir = binary.parent

    if bin_dir not in map(Path, os.getenv("PATH").split(":")):
        print("WARNING: {} is not in PATH. Please add it!".format(bin_dir),
              file=sys.stderr)

    with create_executable(binary) as f:

        def print_to_file(s):
            print(s, file=f, end='')

        for line in fileinput.input(elm_std_dir / "another-elm"):
            if line == "random_suffix = None  # REPLACE ME\n":
                print_to_file(f'random_suffix = "{random_suffix}"\n')
            elif line == "another_elm_version = None  # REPLACE ME\n":
                print_to_file(
                    f'another_elm_version = "{another_elm_version}"\n', )
            else:
                print_to_file(line)


def update_packages(random, another_elm_version):
    elm_home_dir = Path(os.getenv('ELM_HOME', default=Path.home() / '.elm'))
    another_elm_home = elm_home_dir / 'another'

    try:
        elm_versions = os.listdir(another_elm_home)
    except FileNotFoundError:
        elm_versions = []

    packages_roots = list(
        map(lambda elm_version: another_elm_home / elm_version / 'packages',
            elm_versions))

    try:
        shutil.rmtree(customised_dir)
    except FileNotFoundError:
        pass
    for (author, pkg) in [('elm', 'core'), ('elm', 'json'), ('elm', 'browser'),
                          ('elm-explorations', 'test'),
                          ('elm-explorations', 'markdown')]:
        reset_package(packages_roots, author, pkg, random, another_elm_version)


def main():
    r = f"{random.SystemRandom().getrandbits(64):08X}"
    another_elm_version = version_string()
    update_packages(r, another_elm_version)

    exists = binary_path.exists()
    install_exe(binary_path, r, another_elm_version)

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
