#!/usr/bin/env python3
"""iPhone Duo screenshots for a version: fastlane/screenshots/duo/*.png
(2853 × 2007, the inner display) go to the app's asset library and are
placed as the version's iPhone Duo screenshots (en-US; other languages fall
back to them). iPhone Duo screenshots have no screenshot set of their own:
they're asset library images placed with the IPHONE_DUO_PROFILE group.

  scripts/asc/duo_screenshots.py VERSION
"""
import glob
import hashlib
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))
from release import APP, ROOT, call, en_us, log, version_id  # noqa: E402

GROUP = "IPHONE_DUO_PROFILE"


def upload(library, path, known):
    data = open(path, "rb").read()
    # Reference names are unique in the library: the content's hash in the
    # name reuses a panel already there and gives a changed one its own.
    name = "iPhone Duo · " + os.path.splitext(os.path.basename(path))[0] + " · " + hashlib.sha1(data).hexdigest()[:7]
    if name in known:
        return known[name]
    res = call("POST", "/v1/appAssetLibraryImages", {"data": {"type": "appAssetLibraryImages",
               "attributes": {"category": "APP_SCREENSHOTS_AND_PREVIEWS", "fileName": os.path.basename(path), "fileSize": len(data),
                              "referenceName": name},
               "relationships": {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": library}}}}})
    image = res["data"]
    for op in image["attributes"].get("uploadOperations") or []:
        up = urllib.request.Request(op["url"], method=op["method"], data=data[op["offset"]:op["offset"] + op["length"]])
        for h in op.get("requestHeaders", []):
            up.add_header(h["name"], h["value"])
        urllib.request.urlopen(up).read()
    call("PATCH", f"/v1/appAssetLibraryImages/{image['id']}", {"data": {"type": "appAssetLibraryImages", "id": image["id"],
         "attributes": {"uploaded": True}}})
    return image["id"]


def main(version):
    vid, state = version_id(version)
    if not vid:
        sys.exit(f"version {version} not found")
    log("version", version, state)
    loc = en_us(vid)
    library = call("GET", f"/v1/apps/{APP}/assetLibrary")["data"]["id"]
    files = sorted(glob.glob(os.path.join(ROOT, "fastlane", "screenshots", "duo", "*.png")))
    if not files:
        sys.exit("no files in fastlane/screenshots/duo")
    known = {i["attributes"].get("referenceName"): i["id"]
             for i in call("GET", f"/v1/appAssetLibraries/{library}/images?limit=200")["data"]}
    for path in files:
        image = upload(library, path, known)
        # the image has to finish processing before it can be placed
        for _ in range(40):
            st = call("GET", f"/v1/appAssetLibraryImages/{image}?fields[appAssetLibraryImages]=state")["data"]["attributes"]["state"]
            if st not in ("AWAITING_UPLOAD", "UPLOAD_COMPLETE", "PROCESSING", "ASSET_PROCESSING"):
                break
            time.sleep(3)
        call("POST", "/v1/appAssetLibraryPlacements", {"data": {"type": "appAssetLibraryPlacements",
             "attributes": {"placementType": "APP_SCREENSHOT", "placementGroup": GROUP},
             "relationships": {"image": {"data": {"type": "appAssetLibraryImages", "id": image}},
                               "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc}}}}})
        log("placed", os.path.basename(path), "(image", st + ")")
    log("DONE", len(files), "iPhone Duo screenshots on", version)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
