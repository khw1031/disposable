#!/usr/bin/env python3
"""Create and validate private voice records; never generate or send messages."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import tempfile
import os

CONTEXTS = {"casual", "work-peer", "work-superior", "unknown"}
STATUSES = {"hypothesis", "observed", "confirmed", "rejected"}
KINDS = {"user-authored", "user-roleplay"}


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def validate(data):
    errors = []
    if not isinstance(data, dict):
        return ["profile must be a JSON object"]
    if set(data) != {"schema_version", "user_id", "samples", "traits"}:
        errors.append("profile keys must be schema_version, user_id, samples, traits")
    if type(data.get("schema_version")) is not int or data["schema_version"] != 1:
        errors.append("schema_version must be 1")
    if not nonempty(data.get("user_id")):
        errors.append("user_id must be a nonempty string")
    samples, traits = data.get("samples"), data.get("traits")
    if not isinstance(samples, list) or not isinstance(traits, list):
        return errors + ["samples and traits must be arrays"]
    sample_map = {}
    for index, row in enumerate(samples):
        label = f"samples[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{label} must be an object")
            continue
        if set(row) != {"id", "recorded_at", "source_ref", "context", "kind", "text"}:
            errors.append(f"{label} has missing or unknown keys")
        for key in ("id", "source_ref", "text"):
            if not nonempty(row.get(key)):
                errors.append(f"{label}.{key} must be a nonempty string")
        sample_id = row.get("id")
        if isinstance(sample_id, str):
            if sample_id in sample_map:
                errors.append(f"{label}.id duplicates {sample_id}")
            sample_map[sample_id] = row
        if row.get("context") not in CONTEXTS:
            errors.append(f"{label}.context must be one of {sorted(CONTEXTS)}")
        if row.get("kind") not in KINDS:
            errors.append(f"{label}.kind must be user-authored or user-roleplay")
        try:
            stamp = datetime.fromisoformat(row.get("recorded_at", ""))
            if stamp.utcoffset() is None:
                raise ValueError("timezone missing")
        except (ValueError, TypeError):
            errors.append(f"{label}.recorded_at must be ISO 8601 with timezone")
    trait_ids = set()
    for index, row in enumerate(traits):
        label = f"traits[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{label} must be an object")
            continue
        keys = set(row)
        required = {"id", "pattern", "context", "status", "evidence"}
        if not required <= keys or keys - required - {"confirmation_ref"}:
            errors.append(f"{label} has missing or unknown keys")
        for key in ("id", "pattern"):
            if not nonempty(row.get(key)):
                errors.append(f"{label}.{key} must be a nonempty string")
        trait_id = row.get("id")
        if isinstance(trait_id, str):
            if trait_id in trait_ids:
                errors.append(f"{label}.id duplicates {trait_id}")
            trait_ids.add(trait_id)
        if row.get("context") not in CONTEXTS - {"unknown"}:
            errors.append(f"{label}.context must be known before deriving a trait")
        if row.get("status") not in STATUSES:
            errors.append(f"{label}.status must be one of {sorted(STATUSES)}")
        evidence = row.get("evidence")
        if not isinstance(evidence, list) or not evidence or not all(isinstance(e, str) for e in evidence):
            errors.append(f"{label}.evidence must contain sample IDs")
            continue
        if len(evidence) != len(set(evidence)):
            errors.append(f"{label}.evidence must not duplicate sample IDs")
        refs = set()
        for sample_id in evidence:
            sample = sample_map.get(sample_id)
            if sample is None:
                errors.append(f"{label}.evidence references missing sample {sample_id}")
                continue
            if sample.get("context") != row.get("context"):
                errors.append(f"{label}.evidence context differs for {sample_id}")
            if nonempty(sample.get("source_ref")):
                refs.add(sample["source_ref"])
        if row.get("status") == "observed" and len(refs) < 2:
            errors.append(f"{label}: observed requires two distinct source_ref values")
        if row.get("status") == "confirmed" and not nonempty(row.get("confirmation_ref")):
            errors.append(f"{label}: confirmed requires confirmation_ref")
    return errors


def read_profile(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    errors = validate(data)
    if errors:
        raise ValueError("; ".join(errors))
    return data


def write_profile(path, data):
    errors = validate(data)
    if errors:
        raise ValueError("; ".join(errors))
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, tmp = tempfile.mkstemp(prefix=".voice-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            json.dump(data, output, ensure_ascii=False, indent=2)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(tmp, path)
        path.chmod(0o600)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("init", "check", "add-sample"):
        command_parser = sub.add_parser(command)
        command_parser.add_argument("--profile", type=Path, required=True)
        if command == "add-sample":
            command_parser.add_argument("--context", choices=sorted(CONTEXTS), required=True)
            command_parser.add_argument("--source-ref", required=True)
            command_parser.add_argument("--text", required=True)
            command_parser.add_argument("--kind", choices=sorted(KINDS), default="user-authored")
    args = parser.parse_args(argv)
    try:
        if args.command == "init":
            if args.profile.exists():
                raise ValueError("profile already exists; init never overwrites it")
            data = {"schema_version": 1, "user_id": "default", "samples": [], "traits": []}
            write_profile(args.profile, data)
        else:
            data = read_profile(args.profile)
            if args.command == "add-sample":
                # Use an ID that does not collide with a current sample.
                counter = 1
                used = {row["id"] for row in data["samples"]}
                while f"s{counter:03d}" in used:
                    counter += 1
                data["samples"].append({
                    "id": f"s{counter:03d}",
                    "recorded_at": datetime.now(timezone.utc).isoformat(),
                    "source_ref": args.source_ref,
                    "context": args.context,
                    "kind": args.kind,
                    "text": args.text,
                })
                write_profile(args.profile, data)
        print(json.dumps({"ok": True, "command": args.command, "profile": str(args.profile),
                          "samples": len(data["samples"]), "traits": len(data["traits"])}, ensure_ascii=False))
        return 0
    except (OSError, ValueError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
