#! /usr/bin/env python3

import argparse
import subprocess

YAPF_VERSION = '0.30.'
FLAKE8_VERSION = '3.8.'
ELM_VERSION = '0.19.1'
ELM_FORMAT_VERSION = '0.8.3'


def remove_prefix(text, prefix):
    return text[text.startswith(prefix) and len(prefix):]


def get_runner():
    output = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                            stdout=subprocess.PIPE,
                            encoding='utf8')

    if output.returncode != 0:
        print("Error finding root dir:")
        print("     maybe you ran ./x.py outside a git directory?")
        exit(1)

    root_dir = output.stdout.strip()

    return lambda args: subprocess.run(args, cwd=root_dir).returncode


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

    print("Running xo...")
    code = run(['npx', 'xo', '--fix'])

    if code != 0:
        exit(code)

    print("Running yapf...")
    code = run(['yapf', '.', '--in-place', '--recursive'])

    if code != 0:
        exit(code)

    print("Running generate-globals...")
    code = run(['./tests/generate-globals.py', "./core/src/**/*.js"])

    if code != 0:
        exit(code)

    print("Running elm-format...")
    code = run(['elm-format', "./core/src", "--yes"])

    if code != 0:
        exit(code)

    exit(0)


def check():
    run = get_runner()

    print("Checking xo...")
    code = run(['npx', 'xo'])

    if code != 0:
        print("xo failed!")
        exit(code)

    print("Checking yapf...")
    code = run(['yapf', '.', '--diff', '--recursive'])

    if code != 0:
        print("yapf wants to make changes!")
        exit(code)

    print("Checking flake8...")
    code = run(['flake8', '.'])

    if code != 0:
        print("flake8 failed")
        exit(code)

    print("Running check-kernel-imports...")
    code = run(['./tests/check-kernel-imports.js', "core", "browser", "json"])

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

try:
    func = args.func
except AttributeError:
    func = parser.print_help

func()
