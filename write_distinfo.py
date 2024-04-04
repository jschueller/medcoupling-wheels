#!/usr/bin/env python

import os
import hashlib
import base64
import sys

if len(sys.argv) != 4:
    raise ValueError("no name/version/tag")
name, version, tag = sys.argv[1:]


path = os.path.join(f"{name}-{version}.dist-info", "WHEEL")
with open(path, "w") as wheel:
    wheel.write("Wheel-Version: 1.0\n")
    wheel.write("Generator: custom\n")
    wheel.write("Root-Is-Purelib: false\n")
    wheel.write(f"Tag: {tag}\n")

path = os.path.join(f"{name}-{version}.dist-info", "RECORD")
with open(path, "w") as record:
    #for subdir in [f"{name}-{version}.dist-info"]:
    for subdir in ["."]:
        for fn in os.listdir(subdir):
            fpath = os.path.join(subdir, fn)
            if os.path.isfile(fpath):
                if fn == "RECORD":
                    record.write(f"{fpath},,\n")
                else:
                    data = open(fpath, "rb").read()
                    digest = hashlib.sha256(data).digest()
                    checksum = base64.urlsafe_b64encode(digest).decode()
                    size = len(data)
                    record.write(f"{fpath},sha256={checksum},{size}\n")

