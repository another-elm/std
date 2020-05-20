#! /usr/bin/env python3

import fileinput
import re
import sys

HELP = """

Usage: generate-globals FILE ...

Parse the imports of a kernel file and write suitable eslint global
comments to stdout. See
<https://eslint.org/docs/user-guide/configuring#specifying-globals>.

Options:
-h, --help     display this help and exit

""".strip()

import_re = (r"import\s+((?:[.\w]+\.)?(\w+))\s+(?:as (\w+)\s+)?"
             r"exposing\s+\((\w+(?:,\s+\w+)*)\)")


def processFile(file):
    globals = []

    with fileinput.input(file) as f:
        for line in f:
            importMatch = re.search(import_re, line)

            if importMatch is not None:
                # Use alias if it is there, otherwise use last part of import.
                try:
                    moduleAlias = importMatch[3]
                except KeyError:
                    moduleAlias = importMatch[2]

                vars = map(
                    lambda defName: "__{}_{}".format(moduleAlias,
                                                     defName.strip()),
                    importMatch[4].split(","),
                )

                globals.append("/* global {} */".format(", ".join(vars)))

    return "\n".join(globals)


def main():
    if len(sys.argv) != 2:
        print("check-kernel-imports: error! path to file required",
              file=sys.stderr)
        exit(1)

    if "-h" in sys.argv or "--help" in sys.argv:
        print(HELP)
        exit(0)

    globals = processFile(sys.argv[1])
    print("/* global F2, F3, F4 */")
    print("/* global A2, A3, A4 */")
    print(globals)


main()
