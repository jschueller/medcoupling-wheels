import hashlib
import base64
import sys
from pathlib import Path


def main(base_folder: str, package_name: str, version: str, tag: str):
    """
Creates a dist-info directory in the current working directory,
Copies the METADATA.in file in the dist-info directory,
replaces @PACKAGE_VERSION@ by version and @PACKAGE_NAME@ by name
Creates RECORD and WHEEL files
    """
    base_folder_path = Path(base_folder)

    if not base_folder_path.exists():
        raise NotADirectoryError(f"base_folder {base_folder} is not a directory")

    version_file = base_folder_path / "__init__.py"

    with version_file.open("a") as f:
        f.write(f"__version__=\"{version}\"")

    dist_info_folder = base_folder_path / f"{package_name}-{version}.dist-info"
    if not dist_info_folder.exists():
        dist_info_folder.mkdir()

    metadata_file = Path("METADATA.in")
    if not metadata_file.exists():
        raise FileNotFoundError(f"Missing {metadata_file}")

    copy_metadata_file = dist_info_folder / metadata_file
    with metadata_file.open("r") as forigin:
        with copy_metadata_file.open("w") as ftarget:
            for line in forigin:
                ftarget.write(
                    line
                    .replace("@PACKAGE_VERSION@", version)
                    .replace("@PACKAGE_NAME@", package_name)
                )

    path = dist_info_folder / "RECORD"
    with path.open("w") as record:
        for subdir in [base_folder_path, path]:
            for fpath in subdir.iterdir():
                if not fpath.is_file():
                    continue

                if fpath.name == "RECORD":
                    record.write(f"{str(fpath)},,\n")
                    continue

                with fpath.open("rb") as file_tmp:
                    data = file_tmp.read()

                digest = hashlib.sha256(data).digest()
                size = len(data)

                checksum = base64.urlsafe_b64encode(digest).decode()
                record.write(f"{fpath},sha256={checksum},{size}\n")

    path = dist_info_folder / "WHEEL"
    with path.open("w") as wheel:
        wheel.write("Wheel-Version: 1.0\n")
        wheel.write("Generator: custom\n")
        wheel.write("Root-Is-Purelib: false\n")
        wheel.write(f"Tag: {tag}\n")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise ValueError("no name/version/tag")
    base_folder, name, version, tag = sys.argv[1:]
    main(base_folder=base_folder, package_name=name, version=version, tag=tag)

