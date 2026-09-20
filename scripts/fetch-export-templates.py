#!/usr/bin/env python3
"""Fetch the pinned Godot desktop export templates from the official TPZ by range."""

from __future__ import annotations

import argparse
import binascii
import pathlib
import struct
import tempfile
import urllib.request
import zlib


EOCD = struct.Struct("<4s4H2IH")
CENTRAL = struct.Struct("<4s6H3I5H2I")
LOCAL = struct.Struct("<4s5H3I2H")
TARGETS = ("linux_release.x86_64", "windows_release_x86_64.exe")


def ranged(url: str, first: int, last: int) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"Range": f"bytes={first}-{last}", "User-Agent": "FLUX2-release-tooling/1"},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        payload = response.read()
        expected = last - first + 1
        if response.status != 206 or len(payload) != expected:
            raise RuntimeError(f"Server did not honor range {first}-{last}: HTTP {response.status}, {len(payload)} bytes")
        return payload


def remote_size(url: str) -> int:
    request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "FLUX2-release-tooling/1"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return int(response.headers["Content-Length"])


def central_entries(url: str, size: int) -> dict[str, tuple[int, int, int, int, int]]:
    tail_size = min(size, 65_557)
    tail = ranged(url, size - tail_size, size - 1)
    marker = tail.rfind(b"PK\x05\x06")
    if marker < 0:
        raise RuntimeError("Official TPZ has no ZIP end-of-central-directory record")
    signature, _, _, _, entry_count, directory_size, directory_offset, comment_size = EOCD.unpack_from(tail, marker)
    if signature != b"PK\x05\x06" or comment_size != len(tail) - marker - EOCD.size:
        raise RuntimeError("Official TPZ central-directory footer is malformed")
    directory = ranged(url, directory_offset, directory_offset + directory_size - 1)
    entries: dict[str, tuple[int, int, int, int, int]] = {}
    cursor = 0
    for _ in range(entry_count):
        values = CENTRAL.unpack_from(directory, cursor)
        if values[0] != b"PK\x01\x02":
            raise RuntimeError("Official TPZ central directory is malformed")
        method = values[4]
        crc = values[7]
        compressed_size = values[8]
        plain_size = values[9]
        name_size, extra_size, comment_size = values[10:13]
        local_offset = values[16]
        name_start = cursor + CENTRAL.size
        name = directory[name_start : name_start + name_size].decode("utf-8")
        entries[name] = (local_offset, method, crc, compressed_size, plain_size)
        cursor = name_start + name_size + extra_size + comment_size
    if cursor != len(directory):
        raise RuntimeError("Official TPZ central directory has trailing or missing data")
    return entries


def extract_entry(url: str, entry: tuple[int, int, int, int, int]) -> bytes:
    local_offset, method, expected_crc, compressed_size, plain_size = entry
    header = ranged(url, local_offset, local_offset + LOCAL.size - 1)
    values = LOCAL.unpack(header)
    if values[0] != b"PK\x03\x04":
        raise RuntimeError("Official TPZ local entry is malformed")
    name_size, extra_size = values[-2:]
    data_start = local_offset + LOCAL.size + name_size + extra_size
    compressed = ranged(url, data_start, data_start + compressed_size - 1)
    if method == 0:
        payload = compressed
    elif method == 8:
        payload = zlib.decompress(compressed, -zlib.MAX_WBITS)
    else:
        raise RuntimeError(f"Unsupported TPZ compression method: {method}")
    if len(payload) != plain_size or (binascii.crc32(payload) & 0xFFFFFFFF) != expected_crc:
        raise RuntimeError("Official TPZ entry failed size/CRC validation")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--size", required=True, type=int)
    parser.add_argument("--destination", required=True, type=pathlib.Path)
    args = parser.parse_args()
    actual_size = remote_size(args.url)
    if actual_size != args.size:
        raise RuntimeError(f"Pinned TPZ size mismatch: expected {args.size}, received {actual_size}")
    entries = central_entries(args.url, actual_size)
    args.destination.mkdir(parents=True, exist_ok=True)
    for target in TARGETS:
        archive_name = next((name for name in entries if name.rsplit("/", 1)[-1] == target), "")
        if not archive_name:
            raise RuntimeError(f"Official TPZ is missing {target}")
        payload = extract_entry(args.url, entries[archive_name])
        with tempfile.NamedTemporaryFile(dir=args.destination, prefix=f".{target}.", delete=False) as temporary:
            temporary.write(payload)
            temporary_path = pathlib.Path(temporary.name)
        temporary_path.replace(args.destination / target)
        print(f"PASS: installed {target} ({len(payload)} bytes, CRC verified)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
