#!/usr/bin/env python3
"""Écrit des réglages dans config.toml en gardant les commentaires et la mise en forme.

Usage : config_set.py <config.toml> '<json>'
  json = {"section.sous.cle": valeur, ...}  — valeur null = supprimer la clé.
Les tables manquantes sont créées. Écriture atomique (fichier temporaire + rename),
donc Quick-Bar ne relit jamais un fichier à moitié écrit.
"""
import json
import os
import sys
import tempfile
import tomllib

import tomlkit


def set_key(doc, dotted, value):
    parts = dotted.split(".")
    node = doc
    for p in parts[:-1]:
        if p not in node or not isinstance(node[p], (dict, tomlkit.items.Table)):
            node[p] = tomlkit.table()
        node = node[p]
    last = parts[-1]
    if value is None:
        if last in node:
            del node[last]
    else:
        node[last] = value


def main():
    path, updates = sys.argv[1], json.loads(sys.argv[2])
    try:
        with open(path, encoding="utf-8") as f:
            doc = tomlkit.parse(f.read())
    except FileNotFoundError:
        doc = tomlkit.document()
    for k, v in updates.items():
        set_key(doc, k, v)
    d = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".config.", suffix=".toml")
    out = tomlkit.dumps(doc)
    try:
        tomllib.loads(out)            # jamais un config.toml illisible : Quick-Bar perdrait tous ses réglages
    except tomllib.TOMLDecodeError as e:
        os.close(fd)
        os.unlink(tmp)
        sys.exit("config.toml non écrit, le résultat serait invalide : %s" % e)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(out)
    os.replace(tmp, path)


if __name__ == "__main__":
    main()
