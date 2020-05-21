#! /usr/bin/env python3

import argparse
import subprocess

YAPF_VERSION = '0.30.'
FLAKE8_VERSION = '3.8.'


def remove_prefix(text, prefix):
    return text[text.startswith(prefix) and len(prefix):]


def install():
    print("Installing xo...")
    code = subprocess.run(['npm', 'install']).returncode

    if code != 0:
        exit(code)

    print("Checking for yapf")
    output = subprocess.run(['yapf', '--version'],
                            stdout=subprocess.PIPE,
                            encoding='utf8')

    if output.returncode != 0:
        print("** Please install yapf")
        print("** https://github.com/google/yapf#installation")
        exit(output.returncode)

    yapf_version = remove_prefix(output.stdout, "yapf").strip()
    if not yapf_version.startswith(YAPF_VERSION):
        print("** yapf version {}x required, found: {}".format(
            YAPF_VERSION, yapf_version))
        exit(1)

    print("Checking for flake8")
    output = subprocess.run(['flake8', '--version'],
                            stdout=subprocess.PIPE,
                            encoding='utf8')

    if output.returncode != 0:
        print("** Please install flake8")
        print("** https://flake8.pycqa.org/en/latest/index.html#installation")
        exit(output.returncode)

    if not output.stdout.startswith(FLAKE8_VERSION):
        print("** flake8 version {}x required found: {}".format(
            FLAKE8_VERSION, output.stdout))
        exit(1)

    exit(0)


def tidy():
    print("Running xo...")
    code = subprocess.run(['npx', 'xo', '--fix']).returncode

    if code != 0:
        exit(code)

    print("Running yapf...")
    code = subprocess.run(['yapf', '.', '--in-place',
                           '--recursive']).returncode

    if code != 0:
        exit(code)

    print("Running generate-globals...")
    code = subprocess.run(
        ['./tests/generate-globals.py', "./core/src/**/*.js"]).returncode

    if code != 0:
        exit(code)

    exit(0)


def check():
    print("Checking xo...")
    code = subprocess.run(['npx', 'xo']).returncode

    if code != 0:
        print("xo failed!")
        exit(code)

    print("Checking yapf...")
    code = subprocess.run(['yapf', '.', '--diff', '--recursive']).returncode

    if code != 0:
        print("yapf wants to make changes!")
        exit(code)

    print("Checking flake8...")
    code = subprocess.run(['flake8', '.']).returncode

    if code != 0:
        print("flake8 failed")
        exit(code)

    print("Running check-kernel-imports...")
    code = subprocess.run(
        ['./tests/check-kernel-imports.js', "core", "browser",
         "json"]).returncode

    if code != 0:
        print("There are kernel import issues")
        exit(code)

    exit(0)


parser = argparse.ArgumentParser(description='Hack on anther-elm')

subparsers = parser.add_subparsers()

tidy_parser = subparsers.add_parser('install',
                                    help='install required programs')
tidy_parser.set_defaults(func=install)
tidy_parser = subparsers.add_parser('tidy', help='tidy files')
tidy_parser.set_defaults(func=tidy)
check_parser = subparsers.add_parser('check', help='check files are tidy')
check_parser.set_defaults(func=check)

args = parser.parse_args()

args.func()

parser.print_help()
