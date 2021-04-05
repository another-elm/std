#! /usr/bin/env python3

import argparse
import os
import subprocess

YAPF_VERSION = '0.31.'
FLAKE8_VERSION = '3.9.'
ELM_VERSION = '0.19.1'
ELM_FORMAT_VERSION = '0.8.'
ELM_TEST_RS_VERSION = '1.'

NON_CORE_PACKAGES = ["browser", "json", "test", "markdown", "html", "svg"]

PACKAGES = ["core", *NON_CORE_PACKAGES]


def remove_prefix(text, prefix):
    return text[text.startswith(prefix) and len(prefix):]


def elm_make_core(run):
    print("Running elm make in core...")
    code = run(['elm', "make"], subdir='core')

    if code != 0:
        print("There are issues with elm make in core")

    return code


def elm_make(dir, run):
    print(f"Running elm make in {dir}...")
    code = run(['../make-pkg.sh'], subdir=dir)

    if code != 0:
        print(f"There are issues with elm make in {dir}")

    return code


def check_kernel_imports(run):
    print("Running check-kernel-imports...")
    code = run(['./tests/check-kernel-imports.js', *PACKAGES])

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

    def run(args, *, subdir=None, env=None):
        if subdir is not None:
            cwd = os.path.join(root_dir, subdir)
        else:
            cwd = root_dir

        return subprocess.run(args, cwd=cwd, env=env).returncode

    return run


def install():
    def xo():
        print("Installing xo...")
        code = subprocess.run(['npm', 'install']).returncode

        if code != 0:
            exit(code)

        xo_version = subprocess.run(
            ['npx', 'xo', '--version'],
            check=True,
        ).stdout
        print(f"Found xo: {xo_version}")

    def vdom_test_infra(run):
        print("Installing vdom test infra...")
        code = run(['npm', 'install'], subdir="tests/vdom-tests")

        if code != 0:
            exit(code)

        print("Done vdom test infra...")

    def elm_test_rs():
        print("Checkinf for elm-test-rs...")
        output = subprocess.run(['elm-test-rs', '--version'],
                                stdout=subprocess.PIPE,
                                encoding='utf8')

        if output.returncode != 0:
            print("** Please install elm-test-rs")
            print("** https://github.com/mpizenberg/elm-test-rs#install")
            exit(output.returncode)

        elm_test_rs_version = remove_prefix(output.stdout,
                                            "elm-test-rs").strip()
        if not elm_test_rs_version.startswith(ELM_TEST_RS_VERSION):
            print("** elm-test-rs version {}x required, found: {}".format(
                ELM_TEST_RS_VERSION, elm_test_rs_version))
            exit(1)
        print(f"Found elm-test-rs: {output.stdout}")

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
        print(f"Found yapf: {output.stdout}")

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
        print(f"Found flake8: {output.stdout}")

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
        print(f"Found git: {output.stdout}")

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
        print(f"Found elm: {output.stdout}")

    def elm_format():
        print("Checking for elm-format")
        output = subprocess.run(['elm-format', '--help'],
                                stdout=subprocess.PIPE,
                                encoding='utf8')

        if output.returncode != 0:
            print("** Please install elm-format")
            exit(output.returncode)

        first_line = output.stdout.split('\n')[0]
        elm_format_version = remove_prefix(first_line, "elm-format").strip()
        if not elm_format_version.startswith(ELM_FORMAT_VERSION):
            print("** elm-format version {} required found: {}".format(
                ELM_FORMAT_VERSION, first_line))
            exit(1)
        print(f"Found elm-format: {first_line}")

    xo()
    elm_test_rs()
    yapf()
    flake8()
    git()
    elm()
    elm_format()

    # Do this _after_ git install
    run = get_runner()

    vdom_test_infra(run)

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
        code = run([
            './tests/generate-globals.py',
            *map(lambda p: f"./{p}/src/**/*.js", PACKAGES)
        ])

        return bool(code)

    def elm_format():
        print("Running elm-format...")
        code = run(['elm-format', "./core/src", "./json/src", "--yes"])

        return bool(code)

    # Call generate_globals first as sometime xo only passes after
    # generate_globals runs.
    code = False
    code |= elm_make_core(run)

    for ncp in NON_CORE_PACKAGES:
        code |= elm_make(ncp, run)

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
    code |= (fail_fast and code) or elm_make_core(run)

    for ncp in NON_CORE_PACKAGES:
        code |= (fail_fast and code) or elm_make(ncp, run)

    code |= (fail_fast and code) or xo()
    code |= (fail_fast and code) or yapf()
    code |= (fail_fast and code) or flake8(run)
    code |= (fail_fast and code) or check_kernel_imports(run)
    code |= (fail_fast and code) or elm_format()

    exit(code)


def test():
    run = get_runner()

    def elm_test():
        print("Running unit tests with elm-test")
        code = run(['npx', 'elm-test', '--compiler', 'another-elm'],
                   subdir="tests")

        if code != 0:
            print("elm-test failed!")

        return bool(code)

    def elm_test_rs():
        print("Running unit tests with elm-test-ts")
        code = run(['elm-test-rs', '--compiler', 'another-elm'],
                   subdir="tests")

        if code != 0:
            print("elm-test-rs failed!")

        return bool(code)

    def sscce_tests():
        print("Running sscce tests")
        code = run([
            'cargo', 'run', '--', '--suites', 'suite', '--config',
            'config.json', '--elm-compilers', 'another-elm', '--opt-levels',
            'dev,optimize'
        ],
                   subdir="tests/sscce-tests")

        if code != 0:
            print("Running sscce tests failed!")

        return bool(code)

    def vdom_tests():
        print("Running sscce tests")
        code = run(['npx', 'jest'],
                   subdir="tests/vdom-tests",
                   env={
                       "TEST_OFFICIAL_VDOM": True,
                       "ELM_COMPILER": "another-elm",
                   })

        if code != 0:
            print("Running sscce tests failed!")

        return bool(code)

    run(["./init.py"])

    fail_fast = args.fail_fast
    code = False
    code |= (fail_fast and code) or elm_test()
    code |= (fail_fast and code) or elm_test_rs()
    code |= (fail_fast and code) or sscce_tests()

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

test_parser = subparsers.add_parser(
    'test',
    help='Run all tests',
)
test_parser.set_defaults(func=test)
test_parser.add_argument('--fail-fast', action=argparse.BooleanOptionalAction)

args = parser.parse_args()

try:
    func = args.func
except AttributeError:
    func = parser.print_help

func()
