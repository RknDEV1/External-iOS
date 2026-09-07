#!/usr/bin/env python3

from __future__ import annotations



import shutil

import sys

import tempfile

import zipfile

from pathlib import Path



BUILD_FILE_ID = "3105Z001"

FILE_REF_ID = "3105Z002"

EMBED_PHASE_ID = "3105Z003"





def safe_extract(archive: Path, destination: Path) -> None:

    with zipfile.ZipFile(archive) as zf:

        for info in zf.infolist():

            raw = info.filename.replace("\\", "/")

            relative = Path(raw)

            if relative.is_absolute() or ".." in relative.parts:

                raise RuntimeError(f"unsafe archive path: {raw}")

            if relative.parts and relative.parts[0] == ".github":

                continue

            if relative.name in {"CHZSecrets.h", ".env"}:

                continue

            target = (destination / relative).resolve()

            if destination.resolve() not in target.parents and target != destination.resolve():

                raise RuntimeError(f"unsafe destination path: {raw}")

            if info.is_dir():

                target.mkdir(parents=True, exist_ok=True)

            else:

                target.parent.mkdir(parents=True, exist_ok=True)

                with zf.open(info) as source, target.open("wb") as output:

                    shutil.copyfileobj(source, output)





def unpack_layers(source: Path, destination: Path) -> None:

    safe_extract(source, destination)

    for _ in range(3):

        nested = list(destination.rglob("*.xcframework.zip"))

        if not nested:

            break

        for archive in nested:

            layer = archive.with_suffix("").with_suffix("")

            layer.mkdir(parents=True, exist_ok=True)

            safe_extract(archive, layer)





def find_framework(root: Path) -> Path:

    candidates = [p for p in root.rglob("ChzLogin.xcframework") if p.is_dir()]

    for candidate in candidates:

        binary = candidate / "ios-arm64" / "ChzLogin.framework" / "ChzLogin"

        if binary.is_file():

            return candidate

    raise RuntimeError("ChzLogin.xcframework with ios-arm64 slice was not found")





def patch_project(project_file: Path) -> None:

    text = project_file.read_text()

    if FILE_REF_ID in text and EMBED_PHASE_ID in text:

        return



    build_file = f'\t\t{BUILD_FILE_ID} /* ChzLogin.xcframework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {FILE_REF_ID}; settings = {{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }};\n'

    file_ref = f'\t\t{FILE_REF_ID} /* ChzLogin.xcframework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = "Frameworks/ChzLogin.xcframework"; sourceTree = "<group>"; }};\n'

    embed_phase = f'''\t\t{EMBED_PHASE_ID} /* Embed Frameworks */ = {{

\t\t\tisa = PBXCopyFilesBuildPhase;

\t\t\tbuildActionMask = 2147483647;

\t\t\tdstPath = "";

\t\t\tdstSubfolderSpec = 10;

\t\t\tfiles = (

\t\t\t\t{BUILD_FILE_ID} /* ChzLogin.xcframework in Frameworks */,

\t\t\t);

\t\t\tname = "Embed Frameworks";

\t\t\trunOnlyForDeploymentPostprocessing = 0;

\t\t}};\n'''



    text = text.replace("/* End PBXBuildFile section */", build_file + "/* End PBXBuildFile section */", 1)

    text = text.replace("/* End PBXFileReference section */", file_ref + "/* End PBXFileReference section */", 1)

    text = text.replace("/* Begin PBXFrameworksBuildPhase section */", "/* Begin PBXCopyFilesBuildPhase section */\n" + embed_phase + "/* End PBXCopyFilesBuildPhase section */\n\n/* Begin PBXFrameworksBuildPhase section */", 1)

    text = text.replace("\t\t\t\t\t3105A401 /* ThreeOneOSFive */,", "\t\t\t\t\t3105A401 /* ThreeOneOSFive */,\n\t\t\t\t\t" + FILE_REF_ID + " /* ChzLogin.xcframework */,", 1)

    text = text.replace("\t\t\t\t3105A300 /* Frameworks */,\n", "\t\t\t\t3105A300 /* Frameworks */,\n\t\t\t\t" + EMBED_PHASE_ID + " /* Embed Frameworks */,\n", 1)

    text = text.replace("\t\t\t\tfiles = (\n\t\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXFrameworksBuildPhase section */", "\t\t\t\tfiles = (\n\t\t\t\t\t" + BUILD_FILE_ID + " /* ChzLogin.xcframework in Frameworks */,\n\t\t\t\t);\n\t\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXFrameworksBuildPhase section */", 1)



    project_file.write_text(text)





def main() -> None:

    if len(sys.argv) != 3:

        raise SystemExit("usage: integrate_chzlogin_xcframework.py ARCHIVE_OR_DIRECTORY PROJECT_ROOT")

    source = Path(sys.argv[1]).resolve()

    project_root = Path(sys.argv[2]).resolve()

    project_file = project_root / "ThreeOneOSFive.xcodeproj" / "project.pbxproj"

    if not project_file.is_file():

        raise SystemExit(f"project file not found: {project_file}")



    with tempfile.TemporaryDirectory(prefix="chzlogin-integrate-") as temp:

        staging = Path(temp)

        if source.is_dir():

            framework = source

        else:

            unpack_layers(source, staging)

            framework = find_framework(staging)

        destination = project_root / "Frameworks" / "ChzLogin.xcframework"

        destination.parent.mkdir(parents=True, exist_ok=True)

        if destination.exists():

            shutil.rmtree(destination)

        shutil.copytree(framework, destination)



    patch_project(project_file)

    print(f"Integrated: {destination}")

    print(f"Patched: {project_file}")





if __name__ == "__main__":

    main()

