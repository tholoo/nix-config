"""auto-mark-known — track consecutive Easy answers on French Mining notes.

After THRESHOLD consecutive Easy answers, the note's Lemma is appended to
~/.local/share/frdict/known.txt and the note's cards are suspended.

The same known.txt is read by frmine.lua in mpv, which uses it to refuse
re-mining words you've internalized.

Streak state is stored as a tag of the form `easy:N` on the note. Resetting
on any non-Easy answer keeps consecutive Easy as the criterion.
"""

from __future__ import annotations

import unicodedata
from pathlib import Path

import aqt
from aqt import gui_hooks

KNOWN_FILE = Path.home() / ".local" / "share" / "frdict" / "known.txt"
NOTE_TYPE = "French Mining"
EASE_EASY = 4  # 1=Again, 2=Hard, 3=Good, 4=Easy
THRESHOLD = 3
TAG_PREFIX = "easy:"


def _norm(s: str) -> str:
    return unicodedata.normalize("NFC", s).strip().lower()


def _read_known() -> set[str]:
    if not KNOWN_FILE.exists():
        return set()
    return {
        line.strip().lower()
        for line in KNOWN_FILE.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }


def _append_known(lemma: str) -> None:
    KNOWN_FILE.parent.mkdir(parents=True, exist_ok=True)
    if lemma in _read_known():
        return
    with KNOWN_FILE.open("a", encoding="utf-8") as f:
        f.write(lemma + "\n")


def on_review_answer(reviewer, card, ease: int) -> None:
    note = card.note()
    try:
        if note.note_type()["name"] != NOTE_TYPE:
            return
    except Exception:
        return

    # Find current streak from tags; rebuild without the easy:N tag.
    streak = 0
    new_tags = []
    for tag in note.tags:
        if tag.startswith(TAG_PREFIX):
            try:
                streak = int(tag[len(TAG_PREFIX):])
            except ValueError:
                pass
        else:
            new_tags.append(tag)

    if ease == EASE_EASY:
        streak += 1
    else:
        streak = 0

    if streak > 0:
        new_tags.append(f"{TAG_PREFIX}{streak}")

    note.tags = new_tags
    note.flush()

    if streak < THRESHOLD:
        return

    # Threshold met: graduate the lemma to the known list and suspend.
    try:
        lemma = _norm(note["Lemma"]) if "Lemma" in note else ""
    except Exception:
        lemma = ""
    if lemma:
        _append_known(lemma)

    card_ids = list(note.card_ids())
    if card_ids and aqt.mw and aqt.mw.col:
        aqt.mw.col.sched.suspend_cards(card_ids)


gui_hooks.reviewer_did_answer_card.append(on_review_answer)
