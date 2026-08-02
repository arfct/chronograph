#!/usr/bin/env python3
"""Regenerates apple/Extensions/cmudict-ipa.txt from the CMU Pronouncing Dictionary.

Converts ARPAbet to IPA styled like https://github.com/arfct/enigma defaults:
stress as combining accents (acute primary, grave secondary) and long vowels
doubled. Output is sorted "word\tipa" lines for binary search (apple/Extensions/Cmudict.swift).

Usage:
  curl -sLO https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict
  python3 scripts/generate-cmudict-ipa.py cmudict.dict > apple/Extensions/cmudict-ipa.txt
"""
import re
import sys

VOWELS = {
    "AA": "ɑɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔɔ", "AW": "aʊ", "AY": "aɪ",
    "EH": "ɛ", "ER": "ɝ", "EY": "eɪ", "IH": "ɪ", "IY": "ii", "OW": "oʊ",
    "OY": "ɔɪ", "UH": "ʊ", "UW": "uu",
}
SCHWA = {"AH": "ə", "ER": "ɚ"}  # unstressed variants
CONSONANTS = {
    "B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "F": "f", "G": "g", "HH": "h",
    "JH": "dʒ", "K": "k", "L": "l", "M": "m", "N": "n", "NG": "ŋ", "P": "p",
    "R": "ɹ", "S": "s", "SH": "ʃ", "T": "t", "TH": "θ", "V": "v", "W": "w",
    "Y": "j", "Z": "z", "ZH": "ʒ",
}
ACUTE, GRAVE = "́", "̀"

entries = []
for line in open(sys.argv[1]):
    line = line.split("#")[0].strip()
    if not line:
        continue
    parts = line.split()
    word = parts[0]
    if word.endswith(")"):  # alternate pronunciation
        continue
    if not re.fullmatch(r"[a-z'\-\.]+", word):
        continue
    ipa = ""
    for phoneme in parts[1:]:
        stress = phoneme[-1] if phoneme[-1].isdigit() else None
        base = phoneme.rstrip("012")
        if base in VOWELS:
            symbol = SCHWA.get(base) if stress == "0" and base in SCHWA else VOWELS[base]
            accent = ACUTE if stress == "1" else GRAVE if stress == "2" else ""
            ipa += symbol[0] + accent + symbol[1:]
        else:
            ipa += CONSONANTS.get(base, base.lower())
    entries.append(f"{word}\t{ipa}")

print("\n".join(sorted(entries)))
