#! /usr/bin/env python3

import argparse
import os
import subprocess

YAPF_VERSION = '0.30.'
FLAKE8_VERSION = '3.8.'
ELM_VERSION = '0.19.1'
ELM_FORMAT_VERSION = '0.8.3'


def remove_prefix(text, prefix):
    return text[text.startswith(prefix) and len(prefix):]


def elm_make(run):
    print("Running elm make in core...")
    code = run(['elm', "make"], subdir='core')

    if code != 0:
        print("There are issues with elm make in core")

    print("Running elm make in browser...")

    # TODO(harry) make this work on mac.
    assert run([
        'find', './', '-type', 'f', '-exec', 'sed', '-i', '-e',
        "s/^import Elm.Kernel./-- UNDO import Elm.Kernel./g", '{}', ';'
    ],
               subdir='browser/src') == 0

    code = run(['another-elm', "make"], subdir='browser')

    run([
        'find', './', '-type', 'f', '-exec', 'sed', '-i', '-e',
        "s/-- UNDO import Elm.Kernel./import Elm.Kernel./g", '{}', ';'
    ],
        subdir='browser/src') == 0

    if code != 0:
        print("There are issues with elm make in browser")

    return bool(code)


def check_kernel_imports(run):
    print("Running check-kernel-imports...")
    code = run([
        './tests/check-kernel-imports.js', "core", "browser", "json", "test",
        "markdown"
    ])

    if code != 0:
        print("There are kernel import issues")

    return bool(code)


def flake8(run):
    print("Checking flake8...")
    code = run(['flake8', '.'])

    if code != 0:
        print("flake8 failed")

    return bool(code)


def get_runner():
    output = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                            stdout=subprocess.PIPE,
                            encoding='utf8')

    if output.returncode != 0:
        print("Error finding root dir:")
        print("     maybe you ran ./x.py outside a git directory?")
        exit(1)

    root_dir = output.stdout.strip()

    def run(args, subdir=None):
        if subdir is not None:
            cwd = os.path.join(root_dir, subdir)
        else:
            cwd = root_dir

        return subprocess.run(args, cwd=cwd).returncode

    return run


def install():
    def xo():
        print("Installing xo...")
        code = subprocess.run(['npm', 'install']).returncode

        if code != 0:
            exit(code)

    def yapf():
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

    def flake8():
        print("Checking for flake8")
        output = subprocess.run(['flake8', '--version'],
                                stdout=subprocess.PIPE,
                                encoding='utf8')

        if output.returncode != 0:
            print("** Please install flake8")
            print(
                "** https://flake8.pycqa.org/en/latest/index.html#installation"
            )
            exit(output.returncode)

        if not output.stdout.startswith(FLAKE8_VERSION):
            print("** flake8 version {}x required found: {}".format(
                FLAKE8_VERSION, output.stdout))
            exit(1)

    def git():
        print("Checking for git")
        output = subprocess.run(['git', '--version'],
                                stdout=subprocess.PIPE,
                                encoding='utf8')

        if output.returncode != 0:
            print("** Please install git")
            print(
                "** https://git-scm.com/book/en/v2/Getting-Started-Installing-Git"  # noqa: E501
            )

            exit(output.returncode)

    def elm():
        print("Checking for elm")
        output = subprocess.run(['elm', '--version'],
                                stdout=subprocess.PIPE,
                                encoding='utf8')

        if output.returncode != 0:
            print("** Please install elm")
            exit(output.returncode)

        if not output.stdout.strip() == ELM_VERSION:
            print("** elm version {} required found: {}".format(
                ELM_VERSION, output.stdout))
            exit(1)

    def elm_format():
        print("Checking for elm-format")
        output = subprocess.run(['elm-format', '--help'],
                                stdout=subprocess.PIPE,
                                encoding='utf8')

        if output.returncode != 0:
            print("** Please install elm-format")
            exit(output.returncode)

        elm_format_version = remove_prefix(
            output.stdout.split('\n')[0], "elm-format").strip()
        if not elm_format_version.startswith(ELM_FORMAT_VERSION):
            print("** elm-format version {} required found: {}".format(
                ELM_FORMAT_VERSION, output.stdout))
            exit(1)

    xo()
    yapf()
    flake8()
    git()
    elm()
    elm_format()

    exit(0)


def tidy():
    run = get_runner()

    def xo():
        print("Running xo...")
        code = run(['npx', 'xo', '--fix'])

        return bool(code)

    def yapf():
        print("Running yapf...")
        code = run(['yapf', '.', '--in-place', '--recursive'])

        return bool(code)

    def generate_globals():
        print("Running generate-globals...")
        code = run(['./tests/generate-globals.py', "./core/src/**/*.js"])

        return bool(code)

    def elm_format():
        print("Running elm-format...")
        code = run(['elm-format', "./core/src", "--yes"])

        return bool(code)

    # Call generate_globals first as sometime xo only passes after
    # generate_globals runs.
    code = False
    code |= elm_make(run)
    code |= generate_globals()
    code |= xo()
    code |= yapf()
    code |= flake8(run)
    code |= check_kernel_imports(run)
    code |= elm_format()

    exit(code)


def check():
    run = get_runner()

    def xo():
        print("Checking xo...")
        code = run(['npx', 'xo'])

        if code != 0:
            print("xo failed!")

        return bool(code)

    def yapf():
        print("Checking yapf...")
        code = run(['yapf', '.', '--diff', '--recursive'])

        if code != 0:
            print("yapf wants to make changes!")

        return bool(code)

    def elm_format():
        print("Running elm-format validation...")
        code = run(['elm-format', "./core/src", "--validate"])

        return bool(code)

    fail_fast = args.fail_fast
    code = False
    code |= (fail_fast and code) or elm_make(run)
    code |= (fail_fast and code) or xo()
    code |= (fail_fast and code) or yapf()
    code |= (fail_fast and code) or flake8(run)
    code |= (fail_fast and code) or check_kernel_imports(run)
    code |= (fail_fast and code) or elm_format()

    exit(code)


parser = argparse.ArgumentParser(description='Hack on anther-elm')

subparsers = parser.add_subparsers()

install_parser = subparsers.add_parser(
    'install',
    help='install required programs',
)
install_parser.set_defaults(func=install)

tidy_parser = subparsers.add_parser(
    'tidy',
    help='tidy files',
)
tidy_parser.set_defaults(func=tidy)

check_parser = subparsers.add_parser(
    'check',
    help='check files are tidy',
)
check_parser.set_defaults(func=check)
check_parser.add_argument('--fail-fast', action=argparse.BooleanOptionalAction)

args = parser.parse_args()

try:
    func = args.func
except AttributeError:
    func = parser.print_help

func()
