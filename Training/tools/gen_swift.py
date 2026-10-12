"""Turns data.py (the approved training reset) into Swift source and bundled photos for Cairn.

    python3 gen_swift.py            # writes Sources/Cairn/Model/LibraryBands.swift and ios/Resources/photos/*

Photos are flattened to photos/<db id>-<frame>.jpg (extras: photos/extra-<name>.jpg), because Xcode's
synchronized folders may flatten resources. The app finds them by file name, wherever they land.
"""
import json, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import data as D

CAIRN = os.environ.get("CAIRN_DIR", os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
IMG = f"{CAIRN}/Training/img"
PHOTOS = f"{CAIRN}/ios/Resources/photos"
OUT = f"{CAIRN}/Sources/Cairn/Model/LibraryBands.swift"

def S(x):
    return json.dumps(x, ensure_ascii=False)

def L(xs):
    return "[" + ", ".join(S(x) for x in xs) + "]"

# data id -> (swift id, group, starting band kg or None, SF symbol); None swift id = already in the library (overlay only)
NEW = {
    "chest-press": ("band-floor-press", "push", 31, "figure.strengthtraining.functional"),
    "ohp": ("band-ohp", "push", 22, "figure.strengthtraining.functional"),
    "low-high-fly": ("band-low-high-fly", "push", 13, "figure.strengthtraining.functional"),
    "lateral-raise": ("band-lateral-raise", "push", 4, "figure.arms.open"),
    "oh-triceps": ("band-oh-triceps", "push", 13, "figure.strengthtraining.functional"),
    "rear-fly": ("band-rear-fly", "pull", 4, "figure.arms.open"),
    "pushdown": ("band-pushdown", "push", 13, "figure.strengthtraining.functional"),
    "hammer-curl": ("band-hammer-curl", "pull", 13, "figure.strengthtraining.functional"),
    "band-crunch": ("band-crunch", "core", 22.7, "figure.core.training"),
    "pallof": ("pallof", "core", 9, "figure.core.training"),
    "calf-raise": ("band-calf-raise", "legs", 22, "figure.step.training"),
    "lat-pulldown": ("band-lat-pulldown", "pull", 31, "figure.play"),
    "row": ("band-row", "pull", 36, "figure.rower"),
    "one-arm-row": ("band-one-arm-row", "pull", 22, "figure.rower"),
    "straight-arm": ("band-straight-arm", "pull", 13, "figure.play"),
    "face-pull": ("band-face-pull", "pull", 13, "figure.play"),
    "inverted-row": ("inverted-row", "pull", None, "figure.rower"),
    "band-squat": ("band-squat", "legs", 45, "figure.cross.training"),
    "good-morning": ("band-good-morning", "legs", 31, "figure.cross.training"),
    "split-squat": ("split-squat", "legs", None, "figure.cross.training"),
    "hamstring-slide": ("hamstring-slide", "legs", None, "figure.cross.training"),
    "ecc-wrist": ("ecc-wrist", "prehab", None, "hand.raised"),
    "pronator": ("pronator", "prehab", None, "hand.raised"),
}
OVERLAY = {  # data id -> existing swift id
    "pushup": "pushup", "side-plank": "side-plank", "pull-apart": "pull-apart", "pullup-ladder": "pullup",
    "db-row": "db-row", "glute-bridge": "glute-bridge", "pre-pull-apart": "pull-apart", "ext-rot": "external-rotation",
    "rev-wrist": "reverse-wrist", "finger-ext": "finger-ext",
}
DUP = {"lateral-raise-2": "lateral-raise"}  # same movement, different day

BAND_KEYS = {"band-floor-press", "band-ohp", "band-low-high-fly", "band-lateral-raise", "band-oh-triceps", "band-rear-fly",
             "band-pushdown", "band-hammer-curl", "band-crunch", "pallof", "band-calf-raise", "band-lat-pulldown", "band-row",
             "band-one-arm-row", "band-straight-arm", "band-face-pull", "band-squat", "band-good-morning"}

everything = D.PUSH + D.AESTHETIC + D.PULL + D.PULL_GYM + D.LEGS + D.PREHAB
byid = {e["id"]: e for e in everything}

def photo_ids(e):
    return [e["img"]] if e.get("img") else []

def exinfo(e):
    sid, group, start, sym = NEW[e["id"]]
    band = sid in BAND_KEYS
    muscles = ", ".join(e["m"]) + (f". Also {', '.join(e['m2']).lower()}." if e["m2"] else ".")
    watch = (e.get("mistakes") or [""])[0]
    loadstep = "up one rung of your band ladder" if band else None
    parts = [f'id: {S(sid)}', f'name: {S(e["name"])}', f'group: .{group}']
    if loadstep:
        parts.append(f'loadStep: {S(loadstep)}')
    parts += [f'cues: {L(e["steps"])}', f'watch: {S(watch)}', f'why: {S(muscles)}', f'symbol: {S(sym)}']
    parts += [f'photos: {L(photo_ids(e))}', f'photoNote: {S(e.get("note",""))}', f'muscles: {L(e["m"])}', f'alsoMuscles: {L(e["m2"])}',
              f'setup: {S(e.get("setup",""))}', f'mistakes: {L(e.get("mistakes", []))}', f'elbowNote: {S(e.get("elbow",""))}',
              f'gymSwap: {S(e.get("gym","") if e.get("gym") != "—" else "")}']
    if band:
        parts.append("isBand: true")
        parts.append(f"bandStart: {start}")
    return "        ExerciseInfo(" + ",\n                     ".join(parts) + ")"

def overlay(did):
    e = byid[did]
    muscles = ", ".join(e["m"]) + (f". Also {', '.join(e['m2']).lower()}." if e["m2"] else ".")
    return (f'        {S(OVERLAY[did])}: Overlay(photos: {L(photo_ids(e))}, photoNote: {S(e.get("note",""))}, muscles: {L(e["m"])}, '
            f'alsoMuscles: {L(e["m2"])}, setup: {S(e.get("setup",""))}, cues: {L(e["steps"])}, mistakes: {L(e.get("mistakes", []))}, '
            f'elbowNote: {S(e.get("elbow",""))}, gymSwap: {S(e.get("gym","") if e.get("gym") != "—" else "")})')

GROUP = {"pushup": "push", "pullup": "pull", "row": "pull", "dip": "push", "hollow": "core", "lsit": "core",
         "handstand": "push", "pistol": "legs", "crow": "push", "legraise": "core"}
SYMBOL = {"pushup": "figure.strengthtraining.functional", "pullup": "figure.play", "row": "figure.rower", "dip": "figure.strengthtraining.functional",
          "hollow": "figure.core.training", "lsit": "figure.core.training", "handstand": "figure.gymnastics", "pistol": "figure.cross.training",
          "crow": "figure.gymnastics", "legraise": "figure.core.training"}
START = {"pushup": 1, "pullup": 2}

def skill(s):
    photos = list(s["img"]) + [f"extra-{f.split('.')[0]}" for f, _ in s.get("extra", [])]
    steps = ",\n                ".join(f'.init(name: {S(n)}, goal: {S(g)}, cue: {S(c)})' for n, g, c in s["steps"])
    return (f'        Skill(id: {S(s["id"])}, name: {S(s["name"])}, group: .{GROUP[s["id"]]},\n'
            f'              why: {S(s["why"])},\n              watch: {S(s["watch"])},\n'
            f'              steps: [\n                {steps},\n              ], symbol: {S(SYMBOL[s["id"]])}, start: {START.get(s["id"], 0)},\n'
            f'              photos: {L(photos)}, day: {S(s["day"])}, rank: {s["n"]})')

def main():
    swift = ["// Generated by Training/tools/gen_swift.py from Training/tools/data.py (the approved training reset).",
             "// Edit the data and regenerate; don't edit this file by hand.", "import Foundation", "",
             "extension Library {", "    /// What the split-week reset adds to exercises the library already had.",
             "    static let overlays: [String: Overlay] = ["]
    seen_o, ov = set(), []
    for d in OVERLAY:
        if d in byid and OVERLAY[d] not in seen_o:
            seen_o.add(OVERLAY[d]); ov.append(overlay(d))
    swift.append(",\n".join(ov))
    swift.append("    ]")
    swift.append("")
    swift.append("    /// The band and gym exercises of the split week.")
    swift.append("    static let bandExercises: [ExerciseInfo] = [")
    seen, items = set(), []
    for e in everything:
        if e["id"] in NEW and NEW[e["id"]][0] not in seen:
            seen.add(NEW[e["id"]][0]); items.append(exinfo(e))
    swift.append(",\n".join(items))
    swift.append("    ]")
    swift.append("")
    swift.append("    /// The ten skills to learn first, in order.")
    swift.append("    static let topSkills: [Skill] = [")
    swift.append(",\n".join(skill(s) for s in D.SKILLS))
    swift.append("    ]")
    swift.append("}")
    open(OUT, "w").write("\n".join(swift) + "\n")
    print("wrote", OUT, len(items), "exercises,", len(D.SKILLS), "skills,", len(OVERLAY), "overlays")

    # photos, flat
    os.makedirs(PHOTOS, exist_ok=True)
    used = set()
    for e in everything:
        if e.get("img"): used.add(e["img"])
    for s in D.SKILLS:
        used.update(s["img"])
    n = 0
    for i in sorted(used):
        for k in (0, 1):
            src = f"{IMG}/{i}/{k}.jpg"
            if os.path.exists(src):
                shutil.copyfile(src, f"{PHOTOS}/{i}-{k}.jpg"); n += 1
    for f in ("lsit.jpg", "crow.jpg"):
        shutil.copyfile(f"{IMG}/extra/{f}", f"{PHOTOS}/extra-{f}"); n += 1
    print("photos copied:", n)

main()
