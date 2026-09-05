from pathlib import Path

path = Path('/home/ubuntu/3105_redesign/ThreeOneOSFive.xcodeproj/project.pbxproj')
s = path.read_text()

def replace_once(old: str, new: str) -> None:
    global s
    if old not in s:
        raise SystemExit(f'missing marker: {old[:80]!r}')
    s = s.replace(old, new, 1)

replace_once(
    '\t\t3105K200 /* SoundEffectManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = 3105K100; };\n',
    '\t\t3105K200 /* SoundEffectManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = 3105K100; };\n'
    '\t\t\t3105K201 /* PatchLoadingCoordinator.swift in Sources */ = {isa = PBXBuildFile; fileRef = 3105K101; };\n'
    '\t\t\t3105T200 /* ScrollAndLoadingTests.swift in Tests */ = {isa = PBXBuildFile; fileRef = 3105T100; };\n'
    '\t\t\t3105T201 /* XCTest.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 3105T102; };\n'
    '\t\t\t3105T202 /* PatchLoadingCoordinator.swift in Tests */ = {isa = PBXBuildFile; fileRef = 3105K101; };\n')
replace_once(
    '\t\t3105K100 /* SoundEffectManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SoundEffectManager.swift; sourceTree = "<group>"; };\n',
    '\t\t3105K100 /* SoundEffectManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SoundEffectManager.swift; sourceTree = "<group>"; };\n'
    '\t\t\t3105K101 /* PatchLoadingCoordinator.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PatchLoadingCoordinator.swift; sourceTree = "<group>"; };\n'
    '\t\t\t3105T100 /* ScrollAndLoadingTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ScrollAndLoadingTests.swift; sourceTree = "<group>"; };\n'
    '\t\t\t3105T101 /* ThreeOneOSFiveTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ThreeOneOSFiveTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };\n'
    '\t\t\t3105T102 /* XCTest.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = XCTest.framework; path = System/Library/Frameworks/XCTest.framework; sourceTree = SDKROOT; };\n')
replace_once('\t\t\t\t3105A402 /* Products */,\n', '\t\t\t\t3105A402 /* Products */,\n\t\t\t\t3105T400 /* ThreeOneOSFiveTests */,\n')
replace_once('\t\t\t\t3105K100 /* SoundEffectManager.swift */,\n', '\t\t\t\t3105K100 /* SoundEffectManager.swift */,\n\t\t\t\t3105K101 /* PatchLoadingCoordinator.swift */,\n')
replace_once('\t\t\tpath = helpers;\n\t\t\tsourceTree = "<group>";\n\t\t};\n\t\t3105A406 /* kexploit */ = {\n', '\t\t\tpath = helpers;\n\t\t\tsourceTree = "<group>";\n\t\t};\n\t\t3105T400 /* ThreeOneOSFiveTests */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t3105T100 /* ScrollAndLoadingTests.swift */,\n\t\t\t);\n\t\t\tpath = ThreeOneOSFiveTests;\n\t\t\tsourceTree = "<group>";\n\t\t};\n\t\t3105A406 /* kexploit */ = {\n')
replace_once('\t\t\tproductType = "com.apple.product-type.application";\n\t\t};\n/* End PBXNativeTarget section */\n', '\t\t\tproductType = "com.apple.product-type.application";\n\t\t};\n\t\t3105T500 /* ThreeOneOSFiveTests */ = {\n\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = 3105T600;\n\t\t\tbuildPhases = (\n\t\t\t\t3105T300 /* Tests Sources */,\n\t\t\t\t3105T301 /* Tests Frameworks */,\n\t\t\t);\n\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = ThreeOneOSFiveTests;\n\t\t\tproductName = ThreeOneOSFiveTests;\n\t\t\tproductReference = 3105T101;\n\t\t\tproductType = "com.apple.product-type.bundle.unit-test";\n\t\t};\n/* End PBXNativeTarget section */\n')
replace_once('\t\t\ttargets = (\n\t\t\t\t3105A500,\n\t\t\t);\n', '\t\t\ttargets = (\n\t\t\t\t3105A500,\n\t\t\t\t3105T500,\n\t\t\t);\n')
replace_once('\t\t\t\t3105I201,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase section */', '\t\t\t\t\t3105I201,\n\t\t\t\t\t3105K201,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n\t\t3105T300 /* Tests Sources */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t3105T200,\n\t\t\t\t3105T202,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase section */')
replace_once('/* Begin PBXVariantGroup section */', '\t\t3105T301 /* Tests Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t3105T201,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* Begin PBXVariantGroup section */')

# Add test target configurations before the existing configuration list.
marker = '/* Begin XCConfigurationList section */'
test_configs = '''\t\t3105T601 /* Debug Tests */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.chzpriv.ThreeOneOSFiveTests";\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/3105.app/3105";\n\t\t\t};\n\t\t\tname = Debug;\n\t\t};\n\t\t3105T602 /* Release Tests */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.chzpriv.ThreeOneOSFiveTests";\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/3105.app/3105";\n\t\t\t};\n\t\t\tname = Release;\n\t\t};\n'''
replace_once(marker, test_configs + marker)
replace_once('/* End XCConfigurationList section */', '\t\t3105T600 /* Build configuration list for PBXNativeTarget "ThreeOneOSFiveTests" */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t3105T601,\n\t\t\t\t3105T602,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t};\n/* End XCConfigurationList section */')

path.write_text(s)
print('registered XCTest target')
''
