#!/usr/bin/env python3
"""Verify only rd-engine's schema-2 rustdesk-ohrs HAR, before or after installation.

Archive mode checks safe members, the real adjacent sidecar and the HAR digest.
Both modes check package metadata, fixed engine provenance, AArch64 ELF libraries
and their recorded hashes. Installed mode cannot prove archive/sidecar identity.
These are static package checks, not NAPI ABI, module-loading or runtime evidence.
Dirty development packages are reported as dirty; CI passes --require-clean.
"""

import argparse
import hashlib
import json
import re
import sys
import tarfile
from pathlib import Path

PROVENANCE_VERSION = 2
EXPECTED_REPOSITORY = "https://github.com/FrankHan052176/rd-engine"
EXPECTED_PACKAGE = "rustdesk-ohrs"
EXPECTED_TARGET = "aarch64-unknown-linux-ohos"
EXPECTED_LIBRARY = "librd_engine_native_har.so"
LIBCXX_NAME = "libc++_shared.so"
PACKAGE_PREFIX = "package/"
VERSION_PATTERN = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?"
REQUIRED_FILES = {
    "oh-package.json5",
    "index.ets",
    "libs/index.d.ts",
    "src/main/module.json",
    "release-provenance.json",
    "libs/arm64-v8a/" + EXPECTED_LIBRARY,
    "libs/arm64-v8a/" + LIBCXX_NAME,
}


class Failure(Exception):
    pass


def sha256_bytes(payload):
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json_bytes(payload, label):
    try:
        value = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise Failure("{} is not readable JSON: {}".format(label, error)) from error
    if not isinstance(value, dict):
        raise Failure("{} must be a JSON object".format(label))
    return value


def matches(pattern, value):
    return isinstance(value, str) and re.fullmatch(pattern, value) is not None


def check_provenance(provenance, engine_sha=None, package_version=None, require_clean=False):
    if type(provenance.get("provenance_version")) is not int or provenance["provenance_version"] != PROVENANCE_VERSION:
        raise Failure("expected rd-engine provenance_version=2")
    for field, expected in (
        ("kind", "har"),
        ("engine_repository", EXPECTED_REPOSITORY),
        ("package_name", EXPECTED_PACKAGE),
        ("target", EXPECTED_TARGET),
    ):
        if provenance.get(field) != expected:
            raise Failure("provenance {} must be {}".format(field, expected))
    if not matches(r"[0-9a-f]{40}", provenance.get("engine_sha")):
        raise Failure("provenance carries no full rd-engine commit")
    if engine_sha is not None and provenance["engine_sha"] != engine_sha:
        raise Failure("expected engine SHA {}, got {}".format(engine_sha, provenance["engine_sha"]))
    if not matches(VERSION_PATTERN, provenance.get("package_version")):
        raise Failure("provenance carries no exact package version")
    if package_version is not None and provenance["package_version"] != package_version:
        raise Failure("expected version {}, got {}".format(package_version, provenance["package_version"]))
    if not isinstance(provenance.get("source_dirty"), bool):
        raise Failure("provenance must record source_dirty as a boolean")
    if require_clean and provenance["source_dirty"]:
        raise Failure("CI requires a HAR built from clean rd-engine sources")
    for field in ("library_sha256", "libcxx_sha256"):
        if not matches(r"[0-9a-f]{64}", provenance.get(field)):
            raise Failure("provenance carries no {} digest".format(field))


def check_archive_members(archive):
    """Read only regular files at normalized package/ paths; never extract an archive."""
    members = {}
    seen = {}
    for member in archive.getmembers():
        name = member.name
        if "\\" in name:
            raise Failure("HAR member uses a backslash path separator: {}".format(name))
        canonical = name.rstrip("/")
        if canonical == "package":
            if not member.isdir():
                raise Failure("HAR package root is not a directory")
        else:
            if not canonical.startswith(PACKAGE_PREFIX):
                raise Failure("HAR member is outside package/: {}".format(name))
            relative = canonical[len(PACKAGE_PREFIX):]
            if any(component in ("", ".", "..") for component in relative.split("/")):
                raise Failure("HAR member path is not normalized: {}".format(name))
        if canonical in seen:
            raise Failure("HAR carries duplicate members: {}".format(canonical))
        if member.islnk() or member.issym():
            raise Failure("HAR member is a link: {}".format(name))
        if not (member.isreg() or member.isdir()):
            raise Failure("HAR member is neither a regular file nor a directory: {}".format(name))
        if member.isreg() and name != canonical:
            raise Failure("HAR regular file has a directory name: {}".format(name))
        seen[canonical] = member.isdir()
        if member.isreg():
            payload = archive.extractfile(member)
            if payload is None:
                raise Failure("HAR member cannot be read: {}".format(name))
            members[canonical[len(PACKAGE_PREFIX):]] = payload.read()
    for name in seen:
        for parent in Path(name).parents:
            if seen.get(parent.as_posix()) is False:
                raise Failure("HAR member has a regular-file parent: {}".format(name))
    return members


def check_package(members, engine_sha=None, package_version=None, require_clean=False):
    missing = sorted(REQUIRED_FILES - members.keys())
    if missing:
        raise Failure("package is missing regular files: {}".format(", ".join(missing)))
    provenance = load_json_bytes(members["release-provenance.json"], "package provenance")
    check_provenance(provenance, engine_sha, package_version, require_clean)
    metadata = load_json_bytes(members["oh-package.json5"], "package metadata")
    for field, expected in (
        ("name", EXPECTED_PACKAGE),
        ("version", provenance["package_version"]),
        ("main", "index.ets"),
        ("types", "libs/index.d.ts"),
    ):
        if metadata.get(field) != expected:
            raise Failure("package metadata {} must be {}".format(field, expected))
    expected_libraries = {
        "libs/arm64-v8a/" + EXPECTED_LIBRARY: "library_sha256",
        "libs/arm64-v8a/" + LIBCXX_NAME: "libcxx_sha256",
    }
    unexpected = sorted(name for name in members if name.endswith(".so") and name not in expected_libraries)
    if unexpected:
        raise Failure("package carries unexpected native libraries: {}".format(", ".join(unexpected)))
    for name, field in expected_libraries.items():
        library = members[name]
        # ELF64, little-endian, ET_DYN, EM_AARCH64. A host-built .so is not an OHOS library.
        if (len(library) < 64 or library[:6] != b"\x7fELF\x02\x01"
                or library[16:20] != b"\x03\x00\xb7\x00"):
            raise Failure("{} is not an AArch64 shared ELF".format(name))
        if sha256_bytes(library) != provenance[field]:
            raise Failure("{} does not match its recorded digest".format(name))
    return provenance


def verify_archive(path, sidecar_path=None, engine_sha=None, package_version=None, require_clean=False):
    path = Path(path)
    sidecar_path = Path(sidecar_path) if sidecar_path else path.with_name("release-provenance.json")
    if not path.is_file():
        raise Failure("missing native HAR: {}".format(path))
    if not sidecar_path.is_file():
        raise Failure("missing real sidecar provenance: {}".format(sidecar_path))
    sidecar = load_json_bytes(sidecar_path.read_bytes(), sidecar_path)
    with tarfile.open(path, "r:gz") as archive:
        members = check_archive_members(archive)
    provenance = check_package(members, engine_sha, package_version, require_clean)
    result = dict(provenance, har_sha256=sha256_file(path))
    if sidecar != result:
        raise Failure("HAR bytes and embedded provenance do not match the release sidecar")
    return result


def verify_installed(directory, engine_sha=None, package_version=None, require_clean=False):
    root = Path(directory)
    if not root.is_dir():
        raise Failure("installed package not found: {}".format(root))
    # OHPM may expose its package root through an alias. Links inside the package are refused.
    root = root.resolve()
    members = {}
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise Failure("installed package contains a link: {}".format(path))
        if path.is_file():
            members[path.relative_to(root).as_posix()] = path.read_bytes()
        elif not path.is_dir():
            raise Failure("installed package contains a special file: {}".format(path))
    return check_package(members, engine_sha, package_version, require_clean)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--har", help="HAR produced by rd-engine/native/ohos_napi")
    source.add_argument("--installed", help="installed rustdesk-ohrs package directory")
    parser.add_argument("--sidecar", help="real release sidecar (default: adjacent to --har)")
    parser.add_argument("--expected-engine-sha", help="exact full rd-engine commit")
    parser.add_argument("--expected-package-version", help="exact immutable package version")
    parser.add_argument("--require-clean", action="store_true", help="refuse dirty development packages")
    args = parser.parse_args()
    if args.sidecar and not args.har:
        parser.error("--sidecar requires --har; installed mode does not verify an archive")
    if args.expected_engine_sha is not None and not matches(r"[0-9a-f]{40}", args.expected_engine_sha):
        parser.error("--expected-engine-sha must be a full lowercase Git SHA")
    if args.expected_package_version is not None and not matches(VERSION_PATTERN, args.expected_package_version):
        parser.error("--expected-package-version must be an exact semantic version")
    if args.har:
        result = verify_archive(args.har, args.sidecar, args.expected_engine_sha,
                                args.expected_package_version, args.require_clean)
    else:
        result = verify_installed(args.installed, args.expected_engine_sha,
                                  args.expected_package_version, args.require_clean)
    print(json.dumps(result, indent=2, sort_keys=True))
    print("Source: {} ({}); static package checks only, runtime/ABI not verified".format(
        result["engine_sha"], "DIRTY development build" if result["source_dirty"] else "clean"), file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (Failure, OSError, tarfile.TarError) as error:
        print("error: {}".format(error), file=sys.stderr)
        sys.exit(1)
