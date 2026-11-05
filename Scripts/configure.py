#!/usr/bin/env python3
"""Create initial native target configuration without requiring a third-party generator."""
from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parent.parent
for name in ['Walkuno', 'WalkunoWidgets', 'WalkunoWatch', 'WalkunoWatchWidgets']:
    widget = 'Widgets' in name
    watch = 'Watch' in name
    info = dict(CFBundleDevelopmentRegion='$(DEVELOPMENT_LANGUAGE)', CFBundleDisplayName='Walkuno',
                CFBundleExecutable='$(EXECUTABLE_NAME)', CFBundleIdentifier='$(PRODUCT_BUNDLE_IDENTIFIER)',
                CFBundleInfoDictionaryVersion='6.0', CFBundleName='$(PRODUCT_NAME)',
                CFBundlePackageType='XPC!' if widget else 'APPL',
                CFBundleShortVersionString='$(MARKETING_VERSION)', CFBundleVersion='$(CURRENT_PROJECT_VERSION)',
                WalkunoAppGroup='group.fr.orbelio.walkuno')
    if widget:
        info['NSExtension'] = dict(NSExtensionPointIdentifier='com.apple.widgetkit-extension')
    else:
        info['NSHealthShareUsageDescription'] = 'Walkuno reads your steps, walking distance, active energy, exercise time and flights climbed to show your activity and progress. Your health data stays on your devices.'
        if watch:
            info.update(WKApplication=True, WKCompanionAppBundleIdentifier='fr.orbelio.walkuno', WKRunsIndependentlyOfCompanionApp=True)
        else:
            info.update(LSRequiresIPhoneOS=True, UILaunchScreen={}, UIUserInterfaceStyle='Dark', UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait'],
                        CFBundleURLTypes=[dict(CFBundleURLName='fr.orbelio.walkuno', CFBundleURLSchemes=['walkuno'])],
                        UIApplicationSceneManifest=dict(UIApplicationSupportsMultipleScenes=False))
    with open(ROOT / 'Config' / (name + '-Info.plist'), 'wb') as stream:
        plistlib.dump(info, stream)
    entitlements = {'com.apple.security.application-groups': ['group.fr.orbelio.walkuno'],
                    'com.apple.developer.default-data-protection': 'NSFileProtectionComplete'}
    if not widget:
        entitlements.update({'com.apple.developer.healthkit': True,
                             'com.apple.developer.healthkit.background-delivery': True})
    with open(ROOT / 'Config' / (name + '.entitlements'), 'wb') as stream:
        plistlib.dump(entitlements, stream)

privacy = dict(NSPrivacyTracking=False, NSPrivacyTrackingDomains=[], NSPrivacyCollectedDataTypes=[],
               NSPrivacyAccessedAPITypes=[dict(NSPrivacyAccessedAPIType='NSPrivacyAccessedAPICategoryUserDefaults',
                                              NSPrivacyAccessedAPITypeReasons=['CA92.1'])])
with open(ROOT / 'Config/PrivacyInfo.xcprivacy', 'wb') as stream:
    plistlib.dump(privacy, stream)
for lang, description in [
    ('fr', 'Walkuno lit vos pas, votre distance et votre énergie active pour afficher votre activité et vos progrès. Vos données restent sur vos appareils.'),
    ('en', 'Walkuno reads your steps, walking distance and active energy to show your activity and progress. Your health data stays on your devices.')]:
    (ROOT / 'Walkuno/Resources' / (lang + '.lproj') / 'InfoPlist.strings').write_text('"NSHealthShareUsageDescription" = "' + description + '";\n')
