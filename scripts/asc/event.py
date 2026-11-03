#!/usr/bin/env python3
"""Team Radio in-app events — App Store Connect REST API.

  status                 the app's events and their states
  create SPEC.json       create the event from a spec (fastlane/events/*.json): texts per
                         locale, the card and details-page videos ("media") or images
                         ("images"), every territory the app is sold in; prints the event id
  submit EVENT_ID        submit the event for review on its own (no app version needed)

Credentials and helpers: scripts/asc/release.py.
"""
import hashlib, json, os, sys, time, urllib.request

sys.path.insert(0, os.path.dirname(__file__))
from release import APP, ROOT, call, log  # noqa: E402


def territories():
    avail = call("GET", f"/v1/apps/{APP}/appAvailabilityV2")["data"]["id"]
    ids, path = [], f"/v2/appAvailabilities/{avail}/territoryAvailabilities?fields[territoryAvailabilities]=available,territory&include=territory&limit=200"
    while path:
        page = call("GET", path)
        ids += [t["relationships"]["territory"]["data"]["id"] for t in page["data"] if t["attributes"].get("available")]
        nxt = page.get("links", {}).get("next")
        path = nxt.replace("https://api.appstoreconnect.apple.com", "") if nxt else None
    return ids


def upload_video(loc_id, kind, path, preview):
    data = open(os.path.join(ROOT, path), "rb").read()
    res = call("POST", "/v1/appEventVideoClips", {"data": {"type": "appEventVideoClips",
               "attributes": {"fileName": os.path.basename(path), "fileSize": len(data),
                              "appEventAssetType": kind, "previewFrameTimeCode": preview},
               "relationships": {"appEventLocalization": {"data": {"type": "appEventLocalizations", "id": loc_id}}}}})
    for op in res["data"]["attributes"]["uploadOperations"]:
        up = urllib.request.Request(op["url"], method=op["method"], data=data[op["offset"]:op["offset"] + op["length"]])
        for h in op.get("requestHeaders", []):
            up.add_header(h["name"], h["value"])
        urllib.request.urlopen(up).read()
    clip = res["data"]["id"]
    call("PATCH", f"/v1/appEventVideoClips/{clip}", {"data": {"type": "appEventVideoClips", "id": clip,
         "attributes": {"uploaded": True}}})
    return clip


def upload_image(loc_id, kind, path):
    data = open(os.path.join(ROOT, path), "rb").read()
    res = call("POST", "/v1/appEventScreenshots", {"data": {"type": "appEventScreenshots",
               "attributes": {"fileName": os.path.basename(path), "fileSize": len(data), "appEventAssetType": kind},
               "relationships": {"appEventLocalization": {"data": {"type": "appEventLocalizations", "id": loc_id}}}}})
    for op in res["data"]["attributes"]["uploadOperations"]:
        up = urllib.request.Request(op["url"], method=op["method"], data=data[op["offset"]:op["offset"] + op["length"]])
        for h in op.get("requestHeaders", []):
            up.add_header(h["name"], h["value"])
        urllib.request.urlopen(up).read()
    shot = res["data"]["id"]
    call("PATCH", f"/v1/appEventScreenshots/{shot}", {"data": {"type": "appEventScreenshots", "id": shot,
         "attributes": {"uploaded": True}}})
    return "screenshot:" + shot


def wait_processed(clips):
    def state(c):
        kind, _, cid = c.rpartition(":")
        path = f"/v1/appEventScreenshots/{cid}" if kind == "screenshot" else f"/v1/appEventVideoClips/{cid}"
        return call("GET", path)["data"]["attributes"]["assetDeliveryState"]["state"]
    for _ in range(60):
        states = {c: state(c) for c in clips}
        if all(s == "COMPLETE" for s in states.values()):
            return
        if any(s == "FAILED" for s in states.values()):
            sys.exit(f"video processing failed: {states}")
        time.sleep(10)
    sys.exit(f"videos still processing: {states}")


def create(spec_path):
    spec = json.load(open(spec_path))
    schedule = {"territories": territories(), "publishStart": spec["publishStart"],
                "eventStart": spec["eventStart"], "eventEnd": spec["eventEnd"]}
    event = call("POST", "/v1/appEvents", {"data": {"type": "appEvents",
                 "attributes": {k: spec[k] for k in ("referenceName", "badge", "deepLink", "purpose", "priority")}
                 | {"primaryLocale": "en-US", "territorySchedules": [schedule],
                    "purchaseRequirement": spec.get("purchaseRequirement", "NO_COST_ASSOCIATED")},
                 "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
    log("event", event, "in", len(schedule["territories"]), "territories")
    clips = []
    for locale, text in spec["localizations"].items():
        loc = call("POST", "/v1/appEventLocalizations", {"data": {"type": "appEventLocalizations",
                   "attributes": {"locale": locale, **text},
                   "relationships": {"appEvent": {"data": {"type": "appEvents", "id": event}}}}})["data"]["id"]
        for kind, path in spec.get("media", {}).items():
            clips.append(upload_video(loc, kind, path, spec["previewFrame"]))
        for kind, path in spec.get("images", {}).items():
            clips.append(upload_image(loc, kind, path))
        log(locale, "texts and media uploaded")
    wait_processed(clips)
    log("media processed; event", event, "is ready for review")
    print(event)


def submit(event):
    open_states = "READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES"
    existing = call("GET", f"/v1/reviewSubmissions?filter[app]={APP}&filter[platform]=IOS&filter[state]={open_states}")["data"]
    if existing:
        sys.exit("another review submission is open: " + ", ".join(f"{s['id']} {s['attributes']['state']}" for s in existing))
    sub = call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
               "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
    call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
         "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub}},
         "appEvent": {"data": {"type": "appEvents", "id": event}}}}})
    call("PATCH", f"/v1/reviewSubmissions/{sub}", {"data": {"type": "reviewSubmissions", "id": sub, "attributes": {"submitted": True}}})
    log("submitted", event, "in review submission", sub)


def status():
    for e in call("GET", f"/v1/apps/{APP}/appEvents?fields[appEvents]=referenceName,eventState,territorySchedules")["data"]:
        a = e["attributes"]
        when = (a.get("territorySchedules") or [{}])[0]
        log(e["id"], a["eventState"], a["referenceName"], when.get("eventStart"), "→", when.get("eventEnd"))


if __name__ == "__main__":
    cmd, *args = sys.argv[1:] or ["status"]
    {"status": status, "create": create, "submit": submit}[cmd](*args)
