#!/usr/bin/env python3
"""Team Radio release tool — App Store Connect REST API, no fastlane.

  status                       live / pending versions and the latest builds
  prepare VERSION [options]    create VERSION (manual release), set release notes,
                               keywords, subtitle; replace both screenshot sets
  submit VERSION BUILD         wait for BUILD to process, attach it, submit for review
  release VERSION              release an approved version (Pending Developer Release)

Options for prepare:
  --notes FILE        release notes (default fastlane/metadata/en-US/release_notes.txt)
  --keywords "a,b"    version keywords (≤100 chars)
  --subtitle TEXT     app subtitle (≤30 chars)
  --no-screenshots    keep the screenshots already on the version

Credentials: fastlane/asc_key.json (gitignored). Screenshots: fastlane/screenshots/en-US
(iPhone 6.7") and fastlane/screenshots/ipad (iPad Pro 12.9" 3rd gen), sorted by name.
"""
import argparse, glob, hashlib, json, os, sys, time
import jwt, urllib.request, urllib.error

APP = "6804406860"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
key = json.load(open(os.path.join(ROOT, "fastlane", "asc_key.json")))
log = lambda *a: print(*a, flush=True)


def token():
    return jwt.encode({"iss": key["issuer_id"], "iat": int(time.time()), "exp": int(time.time()) + 900,
                       "aud": "appstoreconnect-v1"}, key["key"], algorithm="ES256", headers={"kid": key["key_id"]})


def call(method, path, body=None):
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path, method=method,
                                 headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, json.dumps(body).encode() if body is not None else None) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} {method} {path}\n{e.read().decode()[:1500]}")


def version_id(version):
    data = call("GET", f"/v1/apps/{APP}/appStoreVersions?filter[versionString]={version}&fields[appStoreVersions]=appStoreState")["data"]
    return (data[0]["id"], data[0]["attributes"]["appStoreState"]) if data else (None, None)


def en_us(vid):
    locs = call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations?fields[appStoreVersionLocalizations]=locale")["data"]
    return next(l["id"] for l in locs if l["attributes"]["locale"] == "en-US")


def upload_screenshots(loc_id):
    sets = call("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?fields[appScreenshotSets]=screenshotDisplayType")["data"]
    for s in sets:
        kind, set_id = s["attributes"]["screenshotDisplayType"], s["id"]
        folder = "en-US" if kind == "APP_IPHONE_67" else "ipad" if kind.startswith("APP_IPAD") else None
        if not folder:
            continue
        files = sorted(glob.glob(os.path.join(ROOT, "fastlane", "screenshots", folder, "*.png")))
        if not files:
            log(kind, "skipped — no files in fastlane/screenshots/" + folder)
            continue
        for shot in call("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots?fields[appScreenshots]=fileName&limit=50")["data"]:
            call("DELETE", f"/v1/appScreenshots/{shot['id']}")
        for path in files:
            data = open(path, "rb").read()
            res = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
                   "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
                   "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
            for op in res["data"]["attributes"]["uploadOperations"]:
                up = urllib.request.Request(op["url"], method=op["method"], data=data[op["offset"]:op["offset"] + op["length"]])
                for h in op.get("requestHeaders", []):
                    up.add_header(h["name"], h["value"])
                urllib.request.urlopen(up).read()
            call("PATCH", f"/v1/appScreenshots/{res['data']['id']}", {"data": {"type": "appScreenshots", "id": res["data"]["id"],
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        log(kind, "->", len(files), "screenshots")


def cmd_status(_):
    for v in call("GET", f"/v1/apps/{APP}/appStoreVersions?fields[appStoreVersions]=versionString,appStoreState&limit=5")["data"]:
        log("version", v["attributes"]["versionString"], v["attributes"]["appStoreState"])
    builds = call("GET", f"/v1/builds?filter[app]={APP}&sort=-uploadedDate&limit=5&fields[builds]=version,processingState,preReleaseVersion&include=preReleaseVersion&fields[preReleaseVersions]=version")
    trains = {i["id"]: i["attributes"]["version"] for i in builds.get("included", [])}
    for b in builds["data"]:
        train = trains.get(((b.get("relationships") or {}).get("preReleaseVersion") or {}).get("data", {}).get("id"))
        log("build", b["attributes"]["version"], b["attributes"]["processingState"], "train", train)


def cmd_prepare(a):
    vid, state = version_id(a.version)
    if vid:
        log("version", a.version, "exists:", state)
    else:
        vid = call("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions",
               "attributes": {"platform": "IOS", "versionString": a.version, "releaseType": "MANUAL"},
               "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
        log("version", a.version, "created")
    loc = en_us(vid)
    attrs = {}
    notes_path = a.notes or os.path.join(ROOT, "fastlane", "metadata", "en-US", "release_notes.txt")
    if os.path.exists(notes_path):
        attrs["whatsNew"] = open(notes_path).read().strip()
    if a.keywords:
        assert len(a.keywords) <= 100, "keywords over 100 characters"
        attrs["keywords"] = a.keywords
    if attrs:
        call("PATCH", f"/v1/appStoreVersionLocalizations/{loc}", {"data": {"type": "appStoreVersionLocalizations", "id": loc, "attributes": attrs}})
        log("set", ", ".join(attrs))
    if a.subtitle:
        assert len(a.subtitle) <= 30, "subtitle over 30 characters"
        infos = call("GET", f"/v1/apps/{APP}/appInfos?fields[appInfos]=appStoreState")["data"]
        editable = [i for i in infos if i["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
        if editable:
            il = call("GET", f"/v1/appInfos/{editable[0]['id']}/appInfoLocalizations?fields[appInfoLocalizations]=locale")["data"]
            en = next(l for l in il if l["attributes"]["locale"] == "en-US")
            call("PATCH", f"/v1/appInfoLocalizations/{en['id']}", {"data": {"type": "appInfoLocalizations", "id": en["id"], "attributes": {"subtitle": a.subtitle}}})
            log("subtitle set")
        else:
            log("subtitle skipped — no editable app info")
    if not a.no_screenshots:
        upload_screenshots(loc)
    log("PREPARED", a.version)


def cmd_submit(a):
    vid, state = version_id(a.version)
    if not vid:
        sys.exit(f"version {a.version} not found — run prepare first")
    for _ in range(80):
        b = call("GET", f"/v1/builds?filter[app]={APP}&filter[version]={a.build}&fields[builds]=version,processingState")["data"]
        st = b[0]["attributes"]["processingState"] if b else "NOT_YET"
        log("build", a.build, st)
        if st == "VALID":
            break
        if st in ("FAILED", "INVALID"):
            sys.exit("build processing failed")
        time.sleep(45)
    else:
        sys.exit("timed out waiting for the build")
    call("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": b[0]["id"]}})
    log("attached build", a.build)
    subs = call("GET", f"/v1/reviewSubmissions?filter[app]={APP}&filter[state]=READY_FOR_REVIEW&fields[reviewSubmissions]=state")["data"]
    sid = subs[0]["id"] if subs else call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions",
          "attributes": {"platform": "IOS"}, "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
    items = call("GET", f"/v1/reviewSubmissions/{sid}/items?fields[reviewSubmissionItems]=state,appStoreVersion")["data"]
    if not any(((i.get("relationships") or {}).get("appStoreVersion") or {}).get("data") for i in items):
        call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    call("PATCH", f"/v1/reviewSubmissions/{sid}", {"data": {"type": "reviewSubmissions", "id": sid, "attributes": {"submitted": True}}})
    log("SUBMITTED", a.version, "->", version_id(a.version)[1])


def cmd_release(a):
    vid, state = version_id(a.version)
    if state != "PENDING_DEVELOPER_RELEASE":
        sys.exit(f"{a.version} is {state}, not PENDING_DEVELOPER_RELEASE")
    call("POST", "/v1/appStoreVersionReleaseRequests", {"data": {"type": "appStoreVersionReleaseRequests",
         "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    log("RELEASE requested for", a.version)


p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
sub = p.add_subparsers(dest="cmd", required=True)
sub.add_parser("status").set_defaults(fn=cmd_status)
pp = sub.add_parser("prepare"); pp.add_argument("version"); pp.add_argument("--notes"); pp.add_argument("--keywords")
pp.add_argument("--subtitle"); pp.add_argument("--no-screenshots", action="store_true"); pp.set_defaults(fn=cmd_prepare)
ps = sub.add_parser("submit"); ps.add_argument("version"); ps.add_argument("build"); ps.set_defaults(fn=cmd_submit)
pr = sub.add_parser("release"); pr.add_argument("version"); pr.set_defaults(fn=cmd_release)
args = p.parse_args(); args.fn(args)
