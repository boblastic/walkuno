#!/usr/bin/env python3
"""Generate the dependency-free Xcode project. Re-run after adding source files."""
import hashlib
import json
from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parent.parent
objects = {}

def ident(key):
    return hashlib.sha256(key.encode()).hexdigest()[:24].upper()

def add(key, **value):
    uid = ident(key)
    objects[uid] = value
    return uid

def ref(path, file_type=None):
    value = dict(isa='PBXFileReference', path=path, sourceTree='<group>')
    if file_type:
        value['lastKnownFileType'] = file_type
    return add('file:' + path, **value)

def configurations(key, settings):
    entries = []
    for name in ['Debug', 'Release']:
        merged = dict(settings)
        merged.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if name == 'Debug' else '-O',
                      DEBUG_INFORMATION_FORMAT='dwarf' if name == 'Debug' else 'dwarf-with-dsym',
                      SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' if name == 'Debug' else '')
        entries.append(add(key + name, isa='XCBuildConfiguration', name=name, buildSettings=merged))
    return add(key + 'configurations', isa='XCConfigurationList', buildConfigurations=entries,
               defaultConfigurationIsVisible=0, defaultConfigurationName='Release')

def build_file(target, path):
    return add('build:' + target + ':' + path, isa='PBXBuildFile', fileRef=ref(path))

core = sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'Sources/WalkunoCore').glob('*.swift'))
shared = ['AppShared/' + p for p in ['LocalStore.swift', 'Design.swift']]
health = ['AppShared/HealthService.swift', 'AppShared/WatchBridge.swift']
languages = ['en', 'fr', 'de', 'es', 'it', 'pt', 'ja']
locales = [ref('Walkuno/Resources/' + lang + '.lproj/Localizable.strings', 'text.plist.strings') for lang in languages]
translations = add('translations', isa='PBXVariantGroup', name='Localizable.strings', children=locales, sourceTree='<group>')
for lang, uid in zip(languages, locales):
    objects[uid]['name'] = lang
info_locales = [ref('Walkuno/Resources/' + lang + '.lproj/InfoPlist.strings', 'text.plist.strings') for lang in languages]
info_translations = add('info_translations', isa='PBXVariantGroup', name='InfoPlist.strings', children=info_locales, sourceTree='<group>')
for lang, uid in zip(languages, info_locales):
    objects[uid]['name'] = lang

targets = {}
specs = [
    ('Walkuno', 'fr.orbelio.walkuno', 'iphoneos', 'com.apple.product-type.application',
     core + shared + health + ['Widgets/WalkunoWidgets.swift'] + sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'Walkuno').rglob('*.swift')),
     ['Walkuno/Assets.xcassets', 'Config/PrivacyInfo.xcprivacy']),
    ('WalkunoWidgets', 'fr.orbelio.walkuno.widgets', 'iphoneos', 'com.apple.product-type.app-extension',
     core + shared + ['Widgets/WalkunoWidgets.swift', 'Widgets/WalkunoWidgetBundle.swift'], ['Config/PrivacyInfo.xcprivacy']),
    ('WalkunoWatch', 'fr.orbelio.walkuno.watchkitapp', 'watchos', 'com.apple.product-type.application',
     core + shared + health + ['WatchApp/WalkunoWatchApp.swift', 'Walkuno/Views/StepCounterView.swift', 'Walkuno/Views/CounterStarlight.swift'], ['WatchApp/Assets.xcassets', 'Config/PrivacyInfo.xcprivacy']),
    ('WalkunoWatchWidgets', 'fr.orbelio.walkuno.watchkitapp.widgets', 'watchos', 'com.apple.product-type.app-extension',
     core + shared + ['Widgets/WalkunoWidgets.swift', 'Widgets/WalkunoWidgetBundle.swift'], ['Config/PrivacyInfo.xcprivacy'])
]
products = []
for name, bundle_id, sdk, product_type, sources, resources in specs:
    extension = product_type.endswith('app-extension')
    watch = sdk == 'watchos'
    product = add('product:' + name, isa='PBXFileReference', explicitFileType='wrapper.app-extension' if extension else 'wrapper.application',
                  path=name + ('.appex' if extension else '.app'), sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product)
    resource_files = [build_file(name, p) for p in resources]
    resource_files.append(add('build:translations:' + name, isa='PBXBuildFile', fileRef=translations))
    if not extension:
        resource_files.append(add('build:info_translations:' + name, isa='PBXBuildFile', fileRef=info_translations))
    sources_phase = add(name + 'sources', isa='PBXSourcesBuildPhase', buildActionMask=2147483647,
                        files=[build_file(name, p) for p in sources], runOnlyForDeploymentPostprocessing=0)
    resources_phase = add(name + 'resources', isa='PBXResourcesBuildPhase', buildActionMask=2147483647,
                          files=resource_files, runOnlyForDeploymentPostprocessing=0)
    frameworks = add(name + 'frameworks', isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
    settings = dict(PRODUCT_BUNDLE_IDENTIFIER=bundle_id, PRODUCT_NAME='$(TARGET_NAME)', SDKROOT=sdk,
                    INFOPLIST_FILE='Config/' + name + '-Info.plist', GENERATE_INFOPLIST_FILE='NO',
                    CODE_SIGN_ENTITLEMENTS='Config/' + name + '.entitlements', CODE_SIGN_STYLE='Automatic',
                    CURRENT_PROJECT_VERSION='20', MARKETING_VERSION='1.0.0', SWIFT_VERSION='5.0',
                    SWIFT_EMIT_LOC_STRINGS='YES', ENABLE_USER_SCRIPT_SANDBOXING='YES',
                    TARGETED_DEVICE_FAMILY='4' if watch else '1',
                    SUPPORTED_PLATFORMS='watchos watchsimulator' if watch else 'iphoneos iphonesimulator',
                    SKIP_INSTALL='YES' if extension or watch else 'NO',
                    LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
                    APPLICATION_EXTENSION_API_ONLY='YES' if extension else 'NO')
    settings['WATCHOS_DEPLOYMENT_TARGET' if watch else 'IPHONEOS_DEPLOYMENT_TARGET'] = '10.0' if watch else '17.0'
    if not extension:
        settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
    if name == 'Walkuno':
        settings['ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES'] = [
            'AppIcon-' + theme for theme in ['coral', 'glacier', 'sunshine', 'lime', 'rose', 'violet', 'indigo', 'turquoise']
        ]
    if not watch:
        settings['SUPPORTS_MACCATALYST'] = 'NO'
        settings['SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
    targets[name] = add('target:' + name, isa='PBXNativeTarget', name=name, productName=name,
                        productReference=product, productType=product_type,
                        buildConfigurationList=configurations(name, settings),
                        buildPhases=[sources_phase, frameworks, resources_phase], buildRules=[], dependencies=[])

project_id = ident('project')
test_name = 'WalkunoUITests'
test_product = add('product:' + test_name, isa='PBXFileReference', explicitFileType='wrapper.cfbundle', path=test_name + '.xctest', sourceTree='BUILT_PRODUCTS_DIR')
products.append(test_product)
test_source = add(test_name + 'sources', isa='PBXSourcesBuildPhase', buildActionMask=2147483647,
                  files=[build_file(test_name, 'Tests/WalkunoUITests/WalkunoUITests.swift')], runOnlyForDeploymentPostprocessing=0)
test_settings = dict(PRODUCT_BUNDLE_IDENTIFIER='fr.orbelio.walkuno.uitests', PRODUCT_NAME='$(TARGET_NAME)',
                     SDKROOT='iphoneos', SUPPORTED_PLATFORMS='iphoneos iphonesimulator', TARGETED_DEVICE_FAMILY='1',
                     IPHONEOS_DEPLOYMENT_TARGET='17.0', SWIFT_VERSION='5.0', GENERATE_INFOPLIST_FILE='YES',
                     TEST_TARGET_NAME='Walkuno', CODE_SIGN_STYLE='Automatic', SKIP_INSTALL='YES',
                     LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks'])
test_proxy = add('testproxy', isa='PBXContainerItemProxy', containerPortal=project_id, proxyType=1,
                 remoteGlobalIDString=targets['Walkuno'], remoteInfo='Walkuno')
test_dependency = add('testdependency', isa='PBXTargetDependency', target=targets['Walkuno'], targetProxy=test_proxy)
targets[test_name] = add('target:' + test_name, isa='PBXNativeTarget', name=test_name, productName=test_name,
                        productReference=test_product, productType='com.apple.product-type.bundle.ui-testing',
                        buildConfigurationList=configurations(test_name, test_settings),
                        buildPhases=[test_source], buildRules=[], dependencies=[test_dependency])
for parent, child, destination in [('Walkuno', 'WalkunoWidgets', 'plugins'), ('Walkuno', 'WalkunoWatch', 'watch'),
                                   ('WalkunoWatch', 'WalkunoWatchWidgets', 'plugins')]:
    proxy = add(parent + child + 'proxy', isa='PBXContainerItemProxy', containerPortal=project_id,
                proxyType=1, remoteGlobalIDString=targets[child], remoteInfo=child)
    dependency = add(parent + child + 'dependency', isa='PBXTargetDependency', target=targets[child], targetProxy=proxy)
    embed_file = add(parent + child + 'embedfile', isa='PBXBuildFile', fileRef=objects[targets[child]]['productReference'],
                     settings=dict(ATTRIBUTES=['RemoveHeadersOnCopy']))
    embed = add(parent + child + 'embed', isa='PBXCopyFilesBuildPhase', name='Embed ' + child,
                buildActionMask=2147483647, dstPath='$(CONTENTS_FOLDER_PATH)/Watch' if destination == 'watch' else '',
                dstSubfolderSpec=16 if destination == 'watch' else 13, files=[embed_file], runOnlyForDeploymentPostprocessing=0)
    objects[targets[parent]]['dependencies'].append(dependency)
    objects[targets[parent]]['buildPhases'].append(embed)

files = [key for key, value in objects.items() if value.get('isa') == 'PBXFileReference' and value.get('sourceTree') != 'BUILT_PRODUCTS_DIR' and key not in locales + info_locales]
for p in sorted((ROOT / 'Config').glob('*')):
    if p.suffix in ['.plist', '.entitlements', '.storekit']:
        files.append(ref(str(p.relative_to(ROOT))))
product_group = add('products', isa='PBXGroup', name='Products', children=products, sourceTree='<group>')
group = add('mainGroup', isa='PBXGroup', children=sorted(set(files)) + [translations, info_translations, product_group], sourceTree='<group>')
project_config = configurations('project', dict(CLANG_ENABLE_MODULES='YES', CLANG_ENABLE_OBJC_ARC='YES',
                                                SWIFT_VERSION='5.0', SWIFT_STRICT_CONCURRENCY='targeted',
                                                ENABLE_HARDENED_RUNTIME='YES', DEVELOPMENT_TEAM='SZ36PWDB9C'))
add('project', isa='PBXProject', attributes=dict(LastUpgradeCheck='2700', BuildIndependentTargetsInParallel='YES'),
    buildConfigurationList=project_config, compatibilityVersion='Xcode 14.0', developmentRegion='en',
    knownRegions=languages + ['Base'], mainGroup=group, productRefGroup=product_group,
    projectDirPath='', projectRoot='', targets=list(targets.values()))

def quote(value):
    if isinstance(value, dict):
        return '{ ' + ' '.join(quote(k) + ' = ' + quote(v) + ';' for k, v in value.items()) + ' }'
    if isinstance(value, list):
        return '(' + ', '.join(quote(v) for v in value) + ')'
    if isinstance(value, int):
        return str(value)
    return json.dumps(value, ensure_ascii=False)

directory = ROOT / 'Walkuno.xcodeproj'
directory.mkdir(exist_ok=True)
(directory / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + quote(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=project_id)) + '\n')
schemes = directory / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
for name in ['Walkuno', 'WalkunoWatch']:
    target = targets[name]
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:Walkuno.xcodeproj"/>'
    test_reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[test_name]}" BuildableName="{test_name}.xctest" BlueprintName="{test_name}" ReferencedContainer="container:Walkuno.xcodeproj"/>'
    testables = f'<Testables><TestableReference skipped="NO">{test_reference}</TestableReference></Testables>' if name == 'Walkuno' else ''
    (schemes / (name + '.xcscheme')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES">{testables}</TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated Walkuno.xcodeproj (4 app/extension targets, 1 UI test target, 2 shared schemes).')
