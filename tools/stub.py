#! /usr/bin/env python3

import os
import sys
import shutil
import json
import random
import string

versions_dir = sys.argv[1]

for v in os.listdir(versions_dir):
    version = os.path.join(versions_dir, v)
    src_dir = os.path.join(version, "src")
    stub_file = os.path.join(version, "stub")
    elm_json_path = os.path.join(version, "elm.json")

    package_name = None
    with open(elm_json_path, 'r') as f:
        package_name = json.load(f)["name"]

    dummy_module = "P{}".format(''.join(
        [random.choice(string.ascii_letters) for n in range(32)]
    ))
    dummy_path = os.path.join(src_dir, "{}.elm".format(dummy_module))

    shutil.rmtree(version)
    os.makedirs(src_dir)

    with open(stub_file, 'w'):
        pass

    with open(dummy_path, 'w') as f:
        f.write("""module {} exposing (..)

a = 2
""".format(dummy_module))

    with open(elm_json_path, 'w') as f:
        f.write(""" {{
    "type": "package",
    "name": "{}",
    "summary": "Encode and decode JSON values",
    "license": "BSD-3-Clause",
    "version": "{}",
    "exposed-modules": [
        "{}"
    ],
    "elm-version": "0.19.0 <= v < 0.20.0",
    "dependencies": {{
        "elm/core": "1.0.0 <= v < 2.0.0"
    }},
    "test-dependencies": {{}}
}}""".format(package_name, v, dummy_module))
