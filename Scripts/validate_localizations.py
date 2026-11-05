#!/usr/bin/env python3
"""Check translations, format arguments and resources shipped by all four targets.

Usage: python3 Scripts/validate_localizations.py [--app-bundle /path/to/Walkuno.app]
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
LANGUAGES = {"en", "fr", "de", "es", "it", "pt", "ja"}
RESOURCES = ROOT / "Walkuno/Resources"
FORMAT = re.compile(r"%(?:\d+\$)?(?:lld|ld|@|d|f)")


def load(path):
    return json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)]))


def check(condition, message):
    if not condition:
        raise SystemExit(message)


def validate_sources():
    check({p.stem for p in RESOURCES.glob("*.lproj")} == LANGUAGES, "Unexpected set of languages")
    reference = load(RESOURCES / "en.lproj/Localizable.strings")
    info = load(RESOURCES / "en.lproj/InfoPlist.strings")
    for language in sorted(LANGUAGES):
        directory = RESOURCES / f"{language}.lproj"
        for name, expected in [("Localizable.strings", reference), ("InfoPlist.strings", info)]:
            path = directory / name
            data = load(path)
            # plutil accepts duplicate keys; check the source declarations as well.
            declarations = re.findall(r'^\s*("(?:[^"\\]|\\.)*")\s*=', path.read_text(), re.M)
            check(len(declarations) == len(data), f"{path}: duplicate key")
            check(data.keys() == expected.keys(), f"{path}: missing/extra keys {data.keys() ^ expected.keys()}")
            for key, value in data.items():
                check(value.strip(), f"{path}: empty translation for {key}")
                check(Counter(FORMAT.findall(value)) == Counter(FORMAT.findall(expected[key])),
                      f"{path}: format arguments differ for {key}")

    prefixes = {key.split(".")[0] for key in reference}
    # Direct lookups and literal SwiftUI labels. Interpolated keys are covered by
    # the table parity above and the UI tests (periods, metrics, themes, etc.).
    literal = re.compile(r'(?:\b(?:Text|Label|Button|Section|Toggle|Picker|L|NSLocalizedString)|\bString\(localized:)\s*\(?\s*"([^"\\]*)"')
    for directory in ["Walkuno", "AppShared", "WatchApp", "Widgets"]:
        for path in (ROOT / directory).rglob("*.swift"):
            for key in literal.findall(path.read_text()):
                if "." in key and key.split(".")[0] in prefixes:
                    check(key in reference, f"{path}: untranslated literal {key}")

    project = load(ROOT / "Walkuno.xcodeproj/project.pbxproj")
    objects = project["objects"]
    settings = objects[project["rootObject"]]
    check(settings["developmentRegion"] == "en", "Fallback language must be English")
    check(set(settings["knownRegions"]) == LANGUAGES | {"Base"}, "Xcode knownRegions are incomplete")
    groups = {key: value for key, value in objects.items() if value["isa"] == "PBXVariantGroup"}
    for group in groups.values():
        check({objects[key]["name"] for key in group["children"]} == LANGUAGES,
              f"{group['name']}: missing Xcode resource language")
    for target in (v for v in objects.values() if v["isa"] == "PBXNativeTarget" and v["name"] != "WalkunoUITests"):
        resources = [objects[key] for key in target["buildPhases"] if objects[key]["isa"] == "PBXResourcesBuildPhase"]
        references = {objects[key]["fileRef"] for phase in resources for key in phase["files"]}
        expected = {key for key, group in groups.items() if group["name"] == "Localizable.strings" or "Widgets" not in target["name"]}
        check(expected <= references, f"{target['name']}: translations are not included in target")
    for name in ["Walkuno", "WalkunoWatch"]:
        plist = load(ROOT / f"Config/{name}-Info.plist")
        check(plist["NSHealthShareUsageDescription"] == info["NSHealthShareUsageDescription"],
              f"{name}: unlocalized Health description must be English")
    store = json.loads((ROOT / "Config/Walkuno.storekit").read_text())
    products = store["products"] + [p for group in store["subscriptionGroups"] for p in group["subscriptions"]]
    for product in products:
        check({item["locale"].split("_")[0] for item in product["localizations"]} == LANGUAGES,
              f"{product['productID']}: StoreKit test translations are incomplete")
    print(f"Source validation passed: {len(reference)} texts + Health permission in all 7 languages, 4 targets, English fallback.")


def validate_bundles(app):
    bundles = [app] + sorted(p for p in app.rglob("*") if p.suffix in {".app", ".appex"})
    check(len(bundles) == 4, f"Expected all four compiled bundles, found {len(bundles)}")
    for bundle in bundles:
        check(load(bundle / "Info.plist")["CFBundleDevelopmentRegion"] == "en", f"{bundle}: fallback is not English")
        for language in sorted(LANGUAGES):
            names = ["Localizable.strings"] + (["InfoPlist.strings"] if bundle.suffix == ".app" else [])
            for name in names:
                relative = Path(f"{language}.lproj") / name
                check(load(bundle / relative) == load(RESOURCES / relative), f"{bundle / relative}: differs from source")
        print(f"Compiled bundle verified: {bundle.name} (7 languages, English fallback)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-bundle", type=Path)
    args = parser.parse_args()
    validate_sources()
    if args.app_bundle:
        validate_bundles(args.app_bundle)
