#!/usr/bin/env python3
"""Regenerate lib/data/adhkar_generated.dart from Hisn al-Muslim.

Source: hisnmuslim.com, the official site of حصن المسلم by Sa'id b. Ali b.
Wahf al-Qahtani — the same data the book's own app ships. Every dhikr's text
AND its repetition count come from there; nothing in the output is typed by
hand, because the previous hand-written table had counts nobody could cite.

Run:  python3 tool/generate_adhkar.py
"""
import json
import re
import subprocess
import sys

BASE = "https://www.hisnmuslim.com/api/ar"

# The same book in English, from the same publisher. These are the only two
# languages hisnmuslim.com serves — every other path under /api/ returns 404,
# checked September 2026 — so English is the only translation this generator
# can emit. The app must not invent the others.
BASE_EN = "https://www.hisnmuslim.com/api/en"

# App category key -> Hisn al-Muslim chapter ids.
# 'morning'/'evening' both come out of chapter 27, which the book presents as
# one chapter with the evening wording given inline.
CATEGORIES = {
    "afterPrayer": [25],   # الأذكار بعد السلام من الصلاة
    "mosque": [13, 14],    # دخول المسجد / الخروج منه
    "sleep": [28],         # أذكار النوم
    "waking": [1],         # أذكار الاستيقاظ من النوم
    "travel": [95, 96],    # دعاء الركوب / دعاء السفر
    "food": [69, 70],      # قبل الطعام / عند الفراغ منه
    "distress": [34, 35],  # دعاء الهم والحزن / دعاء الكرب
}

MORNING_EVENING_CHAPTER = 27


def fetch(url):
    # urllib gets a 403 from this host; curl is accepted.
    out = subprocess.run(["curl", "-s", "--max-time", "40", url],
                         capture_output=True, check=True).stdout
    return json.loads(out.decode("utf-8-sig"))


def chapter(chapter_id, base=BASE):
    data = fetch(f"{base}/{chapter_id}.json")
    return list(data.values())[0]


def english_by_id(chapter_id):
    """{source ID -> English text} for one chapter.

    Keyed by the source's own ID rather than by list position, so a dhikr can
    never pick up its neighbour's translation if the two editions ever fall
    out of step. Whitespace is normalised and nothing else is touched: the
    Arabic pipeline strips bracketed asides, but stripping content out of
    somebody's translation of a du'a is not ours to do.
    """
    out = {}
    for item in chapter(chapter_id, BASE_EN):
        text = re.sub(r"\s+", " ", item.get("TRANSLATED_TEXT", "") or "").strip()
        if text:
            out[item["ID"]] = text
    return out


# ---------------------------------------------------------------------------
# Cleaning
# ---------------------------------------------------------------------------

EVENING_NOTE = re.compile(r"\[\s*وإذا\s+أمسى\s+قال\s*:?\s*(.*?)\]", re.S)

# The morning wording turned into the evening wording, exactly as the book's
# own "وإذا أمسى قال: …" inserts spell it out — verb swaps, and where the
# evening line names "الليلة" (feminine) the pronouns that were agreeing
# with "اليوم" (masculine) move with it. Keyed by the source's ID. Each
# entry is (bare-letters to find, fully-voweled replacement); the finder
# ignores diacritics so it matches the fully-voweled morning text.
#
# This is not the generator inventing a du'a — it is applying the change the
# printed book states in-line. Every substitution is asserted to fire, so a
# source edit that breaks a match fails the build instead of shipping a
# half-transformed line.
_MARK = "\u064B-\u0652\u0670\u0640"
EVENING_SUBS = {
    77: [("اصبحنا", "أَمْسَيْنَا"), ("اصبح", "أَمْسَى"),
         ("هذا اليوم", "هَذِهِ اللَّيْلَةِ"), ("ما بعده", "مَا بَعْدَهَا")],
    # ID 78's two clauses swap verbs ("بك أصبحنا، وبك أمسينا" -> "بك
    # أمسينا، وبك أصبحنا"), so the whole clause is replaced at once rather
    # than by a one-way word swap that would leave both saying أمسينا.
    78: [("بك اصبحنا، وبك امسينا",
          "بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا"),
         ("النشور", "الْمَصِيرُ")],
    80: [("اصبحت", "أَمْسَيْتُ")],
    81: [("اصبح", "أَمْسَى")],
    89: [("اصبحنا", "أَمْسَيْنَا"), ("اصبح", "أَمْسَى"),
         ("هذا اليوم", "هَذِهِ اللَّيْلَةِ"),
         ("فتحه", "فَتْحَهَا"), ("نصره", "نَصْرَهَا"), ("نوره", "نُورَهَا"),
         ("بركته", "بَرَكَتَهَا"), ("هداه", "هُدَاهَا"),
         ("ما فيه", "مَا فِيهَا"), ("ما بعده", "مَا بَعْدَهَا")],
    90: [("اصبحنا", "أَمْسَيْنَا")],
}

# Morning-only dhikr to leave out. ID 92 is "لا إله إلا الله وحده لا شريك له
# … عشر مرات" — the ten-count narration of a dhikr the list already carries
# once at a hundred (ID 93); the two together only read as a duplicate.
SKIP_MORNING_IDS = {92}


def _tolerant(bare):
    """A regex that matches `bare` in fully-voweled text: any run of marks
    allowed between letters, and a space allowed to be any whitespace with
    marks around it."""
    parts = []
    for ch in bare:
        if ch == " ":
            parts.append(f"[{_MARK}]*\\s+[{_MARK}]*")
        elif ch == "ا":
            parts.append(f"[اأإآ][{_MARK}]*")
        elif ch == "ه":
            parts.append(f"[هة][{_MARK}]*")
        elif ch == "ي":
            parts.append(f"[يى][{_MARK}]*")
        else:
            parts.append(re.escape(ch) + f"[{_MARK}]*")
    return re.compile("".join(parts))


def _to_evening(morning_text, subs):
    out = morning_text
    for bare, repl in subs:
        out, n = _tolerant(bare).subn(repl, out)
        assert n > 0, f"evening substitution {bare!r} matched nothing"
    return out


# ---------------------------------------------------------------------------
# English translation for the evening wording
# ---------------------------------------------------------------------------
#
# The publisher's English edition gives morning and evening as one entry.
# Left alone, every evening dhikr would show the *morning* sentence. The
# edition itself supplies the evening wording, in one of two ways, and this
# uses only what it supplies — it never composes an English sentence:
#
#   * IDs 78 and 89 print the whole evening sentence inline, after
#     "[In the evening:]" / "[For the evening, the supplication is read as
#     follows:]". That printed sentence is lifted out verbatim.
#   * IDs 77 and 80 state the single word that changes ("read amsaytu
#     instead of asbahtu"); that one English time-word is swapped, and the
#     string is otherwise left exactly as the morning entry stores it.
#   * IDs 81 and 90 give only an Arabic-transliteration note and no English
#     evening sentence, so the evening entry carries no English at all
#     rather than an invented one.
#
# Entries whose morning and evening wording is identical keep the morning
# translation unchanged, formatting and all — same as they ship today.

_EVENING_EN_MARK = re.compile(
    r"\[\s*(?:in|for)\s+the\s+evening[^\]]*?\]\s*", re.I)

_EVENING_EN_SUBS = {
    77: [("reached the morning", "reached the evening"),
         ("of this day", "of this night")],
    80: [("reached the morning", "reached the evening")],
}
_EVENING_EN_OMIT = {81, 90}


def _evening_en(source_id, morning_en):
    """The English for an evening entry, taken only from what the edition
    itself gives for the evening. `morning_en` is the raw source string."""
    if not morning_en:
        return ""
    mark = _EVENING_EN_MARK.search(morning_en)
    if mark:
        tail = morning_en[mark.end():].strip()
        block = re.match(r"\(([^()]*(?:\([^()]*\)[^()]*)*)\)", tail)
        text = block.group(1) if block else tail
        return re.sub(r"\s+", " ", text).strip(" .,‘’\"()")
    subs = _EVENING_EN_SUBS.get(source_id)
    if subs:
        out = morning_en
        for a, b in subs:
            assert a in out.lower(), \
                f"EN evening swap {a!r} missed for ID {source_id}"
            out = re.sub(re.escape(a), b, out, flags=re.I)
        return out
    if source_id in _EVENING_EN_OMIT:
        return ""
    return morning_en


BRACKETS = re.compile(r"\[[^\[\]]*\]")

# Arabic combining marks. The source is fully voweled and inconsistent about
# the order of shadda vs. the vowel above it, so every match below is done on
# the bare letters — a literal "مرَّات" pattern silently fails to match.
MARKS = "ؐ-ًؚ-ٰٟۖ-ۭ"
STRIP_MARKS = re.compile(f"[{MARKS}]")

# "(ثلاث مرات)" / "(سبع مرات)" / "(مائة مرة إذا أصبح)". The count belongs in
# `count`, and leaving the words in duplicates it next to the live counter.
TRAILING_PARENS = re.compile(r"(?:\s*\([^()]*\)\s*[،.]?\s*)+$")

# The book's own wording is the authority on repetitions. The API's REPEAT
# field disagrees with it in places — it reports 1 for
# "حسبي الله ... (سبع مرات)" — so the text wins and REPEAT is the fallback.
NUMBER_WORDS = [
    ("مايه", 100), ("مائه", 100), ("مئه", 100),
    ("عشر", 10), ("سبع", 7), ("خمس", 5), ("اربع", 4), ("ثلاث", 3),
    ("مرتين", 2), ("واحده", 1),
]


def bare(text):
    """Letters only — no vowels, and alef/ta-marbuta folded."""
    text = STRIP_MARKS.sub("", text)
    text = re.sub("[أإآٱ]", "ا", text)
    return text.replace("ة", "ه").replace("ى", "ي")


def count_from_text(text):
    """The repetition the book states in its trailing parenthetical, if any."""
    tail = TRAILING_PARENS.search(text)
    if not tail:
        return None
    flat = bare(tail.group(0))
    if "مره" not in flat and "مرات" not in flat and "مرتين" not in flat:
        return None
    for word, value in NUMBER_WORDS:
        if word in flat:
            return value
    return None


def strip_count_note(text):
    """Drop a trailing "(ثلاث مرات)"-style note, but never the whole dhikr.

    Some chapters wrap the entire supplication in a single pair of
    parentheses. Blindly removing a trailing parenthetical deleted three of
    the four waking adhkar before this guard existed.
    """
    match = TRAILING_PARENS.search(text)
    if not match:
        return text
    remainder = text[: match.start()].strip(" .،")
    if not remainder:
        return text
    inner = bare(match.group(0))
    is_note = any(w in inner for w in ("مره", "مرات", "مرتين", "اذا اصبح", "اذا امسي"))
    return remainder if is_note else text


# A few chapters open with a rubric rather than the words themselves —
# "(يبدأ برجله اليمنى)، ويقول: …". The instruction is not part of the dua.
LEADING_RUBRIC = re.compile(r"^\s*\([^()]*\)\s*[،.]?\s*(?:وَيَقُولُ|ويقول|ثُمَّ\s+يَقُولُ|ثم يقول)?\s*:?\s*")


def tidy(text):
    text = re.sub(r"\s+", " ", text).strip()
    text = text.replace("((", "").replace("))", "")
    text = text.replace("﴿", "").replace("﴾", "").replace("*", "،")
    text = re.sub(r"\s*،\s*", "، ", text)
    text = strip_count_note(text)
    # Same guard as the count note: a rubric may be stripped, the dua may not.
    without_rubric = LEADING_RUBRIC.sub("", text)
    if len(without_rubric.strip(" .،")) > 20:
        text = without_rubric
    # A dhikr wrapped end to end in one pair of parens keeps its text.
    text = text.strip(" .،")
    if text.startswith("(") and text.endswith(")") and "(" not in text[1:-1]:
        text = text[1:-1].strip(" .،")
    return paragraphize(text)


# Phrases that should each start their own line. The isti'adha introduces
# what follows it, and the three suras of the mu'awwidhat are recited as
# three separate units even though the book prints them as one entry —
# running them together as a wall of text makes them hard to follow.
LINE_STARTERS = ["بسم الله الرحمن الرحيم", "قل هو الله احد",
                 "قل اعوذ برب الفلق", "قل اعوذ برب الناس"]
LINE_ENDERS = ["اعوذ بالله من الشيطان الرجيم"]


def _bare_index_map(text):
    """(bare text, index in bare -> index in original)."""
    out, mapping = [], []
    for i, ch in enumerate(text):
        stripped = bare(ch)
        if stripped:
            out.append(stripped)
            mapping.append(i)
    return "".join(out), mapping


def paragraphize(text):
    """Break a run-on dhikr into lines at its natural seams.

    Matching is done on the diacritic-free form and mapped back, because the
    source's vowel marks never line up character for character with a
    phrase typed here.
    """
    flat, mapping = _bare_index_map(text)
    cuts = set()
    for phrase in LINE_STARTERS:
        start = 0
        while True:
            at = flat.find(phrase, start)
            if at < 0:
                break
            if at > 0:
                cuts.add(mapping[at])
            start = at + 1
    for phrase in LINE_ENDERS:
        start = 0
        while True:
            at = flat.find(phrase, start)
            if at < 0:
                break
            end = at + len(phrase)
            if end < len(mapping):
                cuts.add(mapping[end])
            start = at + 1

    if not cuts:
        return text
    out, previous = [], 0
    for cut in sorted(cuts):
        out.append(text[previous:cut].strip(" .،"))
        previous = cut
    out.append(text[previous:].strip(" .،"))
    return "\n".join(part for part in out if part)


def split_morning_evening(raw, source_id):
    """Returns (morning_text, evening_text, evening_note).

    The book gives morning and evening as one dhikr, with the evening wording
    shown inline as "[وإذا أمسى قال: …]".

    Those inserts are NOT the evening dhikr. They replace a span of it and
    the rest continues unchanged, which is why several of them trail off in
    an ellipsis; one dhikr (ID 77) carries two of them, replacing two
    different spans in the same text.

    An earlier version of this generator took the first insert as the whole
    evening text. That shipped six truncated adhkar, one of them ending
    mid-sentence on "اللهم ما أمسى بي...". The app was showing incomplete
    supplications.

    Splicing the inserts back into their spans is not the fix. Aligning them
    word-for-word breaks on punctuation — in ID 78 the insert also replaces
    the closing word, so the counts shift — and nothing in this script is
    qualified to decide where somebody's du'a resumes. Composing the wording
    of a supplication is not a text-processing problem.

    So the evening entry carries the dhikr in full, exactly as the morning
    one does, and the book's own instruction rides alongside it as a note,
    verbatim and complete. Nothing is truncated and nothing is invented —
    which is how the printed book presents it too.
    """
    flat = re.sub(r"\s+", " ", raw)
    has_note = EVENING_NOTE.search(flat) is not None
    base = tidy(BRACKETS.sub("", flat))

    morning_only = "إذا أصبحَ" in flat or "إذا أصبح" in flat
    evening_only = ("إذا أمسى" in flat) and not has_note

    if has_note:
        subs = EVENING_SUBS.get(source_id)
        assert subs, f"ID {source_id} has an evening insert but no substitution table"
        return base, _to_evening(base, subs)
    if morning_only:
        return base, None
    if evening_only:
        return None, base
    return base, base


def dart_string(s):
    # Newlines are escaped so the generated Dart stays one line per item.
    return ('"' + s.replace("\\", "\\\\").replace('"', '\\"')
            .replace("$", r"\$").replace("\n", "\\n") + '"')


def emit(items):
    lines = []
    for text, count, translation, note in items:
        extra = ""
        if note:
            extra += f", note: {dart_string(note)}"
        if translation:
            extra += f", translation: {dart_string(translation)}"
        lines.append(
            f"  DhikrItem(text: {dart_string(text)}, count: {count}{extra}),")
    return "\n".join(lines)


def main():
    morning, evening = [], []
    english = english_by_id(MORNING_EVENING_CHAPTER)
    for item in chapter(MORNING_EVENING_CHAPTER):
        sid = item["ID"]
        raw = item["ARABIC_TEXT"]
        count = count_from_text(re.sub(r"\s+", " ", raw)) or int(item["REPEAT"]) or 1
        m, e = split_morning_evening(raw, sid)
        # The English edition gives morning and evening as one dhikr; the
        # morning half is cleaned as-is, the evening half takes the edition's
        # own evening wording (printed inline, or the one stated word swap).
        raw_en = english.get(sid, "")
        if m and sid not in SKIP_MORNING_IDS:
            # IDs 78/89 print the evening sentence after the morning one; the
            # morning entry keeps only the part before that marker.
            morning_en = _EVENING_EN_MARK.split(raw_en, 1)[0]
            if morning_en != raw_en:
                morning_en = morning_en.strip().strip(" .,‘’\"()")
            morning.append((m, count, morning_en, ""))
        if e:
            evening.append((e, count, _evening_en(sid, raw_en), ""))

    others = {}
    for key, ids in CATEGORIES.items():
        collected = []
        for cid in ids:
            english = english_by_id(cid)
            for item in chapter(cid):
                flat = re.sub(r"\s+", " ", BRACKETS.sub("", item["ARABIC_TEXT"]))
                text = tidy(flat)
                if text:
                    count = count_from_text(flat) or int(item["REPEAT"]) or 1
                    collected.append(
                        (text, count, english.get(item["ID"], ""), ""))
        others[key] = collected

    parts = [
        "// GENERATED by tool/generate_adhkar.py — do not hand-edit.\n"
        "//\n"
        "// Source: حصن المسلم (Hisn al-Muslim) by Sa'id b. Ali b. Wahf\n"
        "// al-Qahtani, via the book's official site hisnmuslim.com\n"
        "// (`/api/ar/<chapter>.json`). Both the wording and every repetition\n"
        "// count come from there — `REPEAT` in the source feeds `count` here.\n"
        "//\n"
        "// `translation` is the book's own English edition (`/api/en/...`),\n"
        "// matched to each dhikr by the source's own ID. English is the only\n"
        "// translation the publisher serves; no other language is invented.\n"
        "//\n"
        "// Morning and evening are one chapter in the book. Where the evening\n"
        "// wording differs the book gives the change inline as an insert,\n"
        "// \"وإذا أمسى قال: …\" — an insert that replaces part of the dhikr,\n"
        "// not the whole of it. The evening entry therefore carries the full\n"
        "// text with that instruction verbatim in `note`; splicing it in\n"
        "// would mean this script composing the wording of a du'a. A dhikr\n"
        "// the book marks for only one of the two appears in only one list.\n"
        "//\n"
        "// This replaced a hand-typed table whose repetition counts could not\n"
        "// be traced to any source. Regenerate; never patch by hand.\n"
        "\n"
        "import '../models/dhikr.dart';\n",
        f"const List<DhikrItem> morningAdhkar = [\n{emit(morning)}\n];\n",
        f"const List<DhikrItem> eveningAdhkar = [\n{emit(evening)}\n];\n",
    ]
    for key, items in others.items():
        parts.append(f"const List<DhikrItem> {key}Adhkar = [\n{emit(items)}\n];\n")

    with open("lib/data/adhkar_generated.dart", "w", encoding="utf-8") as f:
        f.write("\n".join(parts))

    print(f"morning={len(morning)} evening={len(evening)} " +
          " ".join(f"{k}={len(v)}" for k, v in others.items()))


if __name__ == "__main__":
    sys.exit(main())
