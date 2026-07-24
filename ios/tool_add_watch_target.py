#!/usr/bin/env python3
"""
Ajoute la cible app watchOS « LexDayWatchApp » au projet Runner.xcodeproj.

Idempotent : si une cible nommée LexDayWatchApp existe déjà, ne fait rien.
Crée : file refs, build files, build phases, 3 configs (Debug/Release/Profile),
la cible native, l'embed « Embed Watch Content » + la dépendance dans Runner.
"""
import sys
from pbxproj import XcodeProject
from pbxproj.PBXKey import PBXKey

PROJECT = "Runner.xcodeproj/project.pbxproj"

# IDs existants (relevés dans le projet)
PROJ_ID = "97C146E61CF9000F007C117D"
MAIN_GROUP = "97C146E51CF9000F007C117D"
PRODUCTS_GROUP = "97C146EF1CF9000F007C117D"
RUNNER_TARGET = "97C146ED1CF9000F007C117D"
TEAM = "9WN55FN2D3"

TARGET_NAME = "LexDayWatchApp"
DIR = "LexDayWatchApp"
BUNDLE_ID = "fr.lexday.app.watchkitapp"

p = XcodeProject.load(PROJECT)
o = p.objects

# Idempotence
for tid in o[PROJ_ID]["targets"]:
    if o[tid].get("name", None) == TARGET_NAME if hasattr(o[tid], "get") else False:
        pass
existing = [tid for tid in o[PROJ_ID]["targets"]
            if (o[tid]["name"] if "name" in o[tid].get_keys() else None) == TARGET_NAME]
if existing:
    print("Cible déjà présente, rien à faire.")
    sys.exit(0)


def add(isa, **fields):
    content = {"isa": isa}
    content.update(fields)
    obj = o._get_instance(isa, content)
    oid = PBXKey(o._generate_id(), o)  # PBXKey(value, parent) : repr propre + commentaire
    obj["_id"] = oid
    o[oid] = obj
    return oid


# --- File references ---
fr_app = add("PBXFileReference", lastKnownFileType="sourcecode.swift",
             path="LexDayWatchApp.swift", sourceTree="<group>")
fr_content = add("PBXFileReference", lastKnownFileType="sourcecode.swift",
                 path="ContentView.swift", sourceTree="<group>")
fr_wsm = add("PBXFileReference", lastKnownFileType="sourcecode.swift",
             path="WatchSessionManager.swift", sourceTree="<group>")
fr_assets = add("PBXFileReference", lastKnownFileType="folder.assetcatalog",
                path="Assets.xcassets", sourceTree="<group>")
fr_info = add("PBXFileReference", lastKnownFileType="text.plist.xml",
              path="Info.plist", sourceTree="<group>")
fr_ent = add("PBXFileReference", lastKnownFileType="text.plist.entitlements",
             path="LexDayWatch.entitlements", sourceTree="<group>")
fr_product = add("PBXFileReference", explicitFileType="wrapper.application",
                 includeInIndex="0", path=f"{TARGET_NAME}.app",
                 sourceTree="BUILT_PRODUCTS_DIR")

# --- Build files ---
bf_app = add("PBXBuildFile", fileRef=fr_app)
bf_content = add("PBXBuildFile", fileRef=fr_content)
bf_wsm = add("PBXBuildFile", fileRef=fr_wsm)
bf_assets = add("PBXBuildFile", fileRef=fr_assets)
bf_embed = add("PBXBuildFile", fileRef=fr_product,
               settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})

# --- Build phases (watch target) ---
ph_sources = add("PBXSourcesBuildPhase", buildActionMask="2147483647",
                 files=[bf_app, bf_content, bf_wsm],
                 runOnlyForDeploymentPostprocessing="0")
ph_frameworks = add("PBXFrameworksBuildPhase", buildActionMask="2147483647",
                    files=[], runOnlyForDeploymentPostprocessing="0")
ph_resources = add("PBXResourcesBuildPhase", buildActionMask="2147483647",
                   files=[bf_assets], runOnlyForDeploymentPostprocessing="0")

# --- Group ---
grp = add("PBXGroup", path=DIR, sourceTree="<group>",
          children=[fr_app, fr_content, fr_wsm, fr_assets, fr_info, fr_ent])
o[MAIN_GROUP]["children"].append(grp)
o[PRODUCTS_GROUP]["children"].append(fr_product)

# --- Build configurations ---
base_settings = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_ENTITLEMENTS": f"{DIR}/LexDayWatch.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": TEAM,
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": f"{DIR}/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SDKROOT": "watchos",
    "SKIP_INSTALL": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "4",
    "WATCHOS_DEPLOYMENT_TARGET": "10.0",
}


def mk_config(name, extra):
    s = dict(base_settings)
    s.update(extra)
    return add("XCBuildConfiguration", name=name, buildSettings=s)


cfg_debug = mk_config("Debug", {
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
})
cfg_release = mk_config("Release", {
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
})
cfg_profile = mk_config("Profile", {
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
})

cfg_list = add("XCConfigurationList",
               buildConfigurations=[cfg_debug, cfg_release, cfg_profile],
               defaultConfigurationIsVisible="0",
               defaultConfigurationName="Release")

# --- Native target ---
nt = add("PBXNativeTarget",
         buildConfigurationList=cfg_list,
         buildPhases=[ph_sources, ph_frameworks, ph_resources],
         buildRules=[],
         dependencies=[],
         name=TARGET_NAME,
         productName=TARGET_NAME,
         productReference=fr_product,
         productType="com.apple.product-type.application")

o[PROJ_ID]["targets"].append(nt)

# Note : pas de TargetAttributes ici. CODE_SIGN_STYLE=Automatic dans les build
# settings suffit ; Xcode complétera TargetAttributes à la première ouverture.

# --- Embed Watch Content dans Runner ---
embed_phase = add("PBXCopyFilesBuildPhase",
                  buildActionMask="2147483647",
                  dstPath="$(CONTENTS_FOLDER_PATH)/Watch",
                  dstSubfolderSpec="16",
                  files=[bf_embed],
                  name="Embed Watch Content",
                  runOnlyForDeploymentPostprocessing="0")
o[RUNNER_TARGET]["buildPhases"].append(embed_phase)

# --- Dépendance Runner -> watch ---
proxy = add("PBXContainerItemProxy",
            containerPortal=PROJ_ID,
            proxyType="1",
            remoteGlobalIDString=nt,
            remoteInfo=TARGET_NAME)
dep = add("PBXTargetDependency", target=nt, targetProxy=proxy)
o[RUNNER_TARGET]["dependencies"].append(dep)

p.save()
print("OK : cible", TARGET_NAME, "ajoutée.")
print("  native target:", nt)
print("  product:", fr_product)
