#!/usr/bin/env python3
"""Build, sign and install locally on explicitly selected paired Apple devices."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--iphone', required=True, help='UDID of the paired iPhone')
parser.add_argument('--watch', help='UDID of the paired Apple Watch')
parser.add_argument('--team', default='SZ36PWDB9C', help='Apple Developer team ID')
parser.add_argument('--configuration', choices=['Debug', 'Release'], default='Debug')
parser.add_argument('--derived-data', type=Path, default=Path(tempfile.gettempdir()) / 'walkuno-device')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent

def run(command):
    subprocess.run(command, cwd=root, check=True)

run(['xcodebuild', '-project', 'Walkuno.xcodeproj', '-scheme', 'Walkuno',
     '-configuration', args.configuration, '-destination', 'generic/platform=iOS',
     '-derivedDataPath', str(args.derived_data), '-allowProvisioningUpdates',
     '-allowProvisioningDeviceRegistration', 'DEVELOPMENT_TEAM=' + args.team, 'build'])

products = args.derived_data / 'Build/Products'
phone_app = products / (args.configuration + '-iphoneos') / 'Walkuno.app'
watch_app = products / (args.configuration + '-watchos') / 'WalkunoWatch.app'

# Check every requested bundle before changing either device.
for bundle in [phone_app] + ([watch_app] if args.watch else []):
    if not (bundle / 'embedded.mobileprovision').exists():
        raise SystemExit('A signed development provisioning profile is required: ' + str(bundle))
    run(['codesign', '--verify', '--deep', '--strict', str(bundle)])

run(['xcrun', 'devicectl', 'device', 'install', 'app', '--device', args.iphone, str(phone_app)])
if args.watch:
    run(['xcrun', 'devicectl', 'device', 'install', 'app', '--device', args.watch, str(watch_app)])
run(['xcrun', 'devicectl', 'device', 'process', 'launch', '--device', args.iphone, 'fr.orbelio.walkuno'])
if args.watch:
    run(['xcrun', 'devicectl', 'device', 'process', 'launch', '--device', args.watch, 'fr.orbelio.walkuno.watchkitapp'])
print('Walkuno installed and launched on the requested devices. No demo arguments, no App Store upload.')
