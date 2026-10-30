#!/usr/bin/env python3
# Schreibt die Abschnitte "Stabil" und "Snapshot" der Seite docs/spielen/download.md.
#
# Aufruf (in der GitHub Action vor "mkdocs build"):
#   python tools/make_download_page.py docs/spielen/download.md dl
#
# Erwartet je Bereich einen Ordner dl/snapshot bzw. dl/stabil mit den Dateien des Releases
# (Regatta-windows.zip, Regatta-linux.zip, Regatta-macos.zip, SHA256SUMS.txt, VERSION.txt, TAG.txt).
# Ersetzt in der Seite alles zwischen <!-- DOWNLOADS:START --> und <!-- DOWNLOADS:END -->.
import os
import sys

PLATFORMS = [("Windows", "Regatta-windows.zip"), ("Linux", "Regatta-linux.zip"), ("macOS", "Regatta-macos.zip")]
SECTIONS = [("Stabil", "stabil", "neuestes festes Release (Tag `v*`)"), ("Snapshot", "snapshot", "neuester Stand von `main`")]
START, END = "<!-- DOWNLOADS:START -->", "<!-- DOWNLOADS:END -->"


def read_kv(path):
    out = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            if "=" in line:
                k, v = line.strip().split("=", 1)
                out[k] = v
    return out


def sums(path):
    out = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            parts = line.split()
            if len(parts) == 2:
                out[parts[1].lstrip("*")] = parts[0]
    return out


def section(title, folder, what, base, repo):
    d = os.path.join(base, folder)
    files = [f for _, f in PLATFORMS if os.path.exists(os.path.join(d, f))]
    head = "### %s\n\n" % title
    if not files:
        return head + "Noch kein Download vorhanden (%s).\n" % what
    ver = read_kv(os.path.join(d, "VERSION.txt"))
    tag = open(os.path.join(d, "TAG.txt"), encoding="utf-8").read().strip() if os.path.exists(os.path.join(d, "TAG.txt")) else ""
    hs = sums(os.path.join(d, "SHA256SUMS.txt"))
    lines = [head]
    info = []
    if tag:
        info.append("Version: **%s**" % tag)
    if ver.get("kurz"):
        info.append("Commit `%s`" % ver["kurz"])
    if ver.get("datum"):
        info.append("gebaut am %s" % ver["datum"].replace("T", " ").replace("Z", " UTC"))
    if ver.get("godot"):
        info.append("Godot %s" % ver["godot"])
    lines.append(" · ".join(info) + "\n\n" if info else "\n")
    lines.append("| System | Download | Größe | SHA-256 |\n|---|---|---|---|\n")
    for name, fname in PLATFORMS:
        p = os.path.join(d, fname)
        if not os.path.exists(p):
            continue
        mb = os.path.getsize(p) / 1048576.0
        h = hs.get(fname, "")
        lines.append('| %s | <a class="download" href="../../downloads/%s/%s">%s</a> | %.0f MB | `%s` |\n' % (name, folder, fname, fname, mb, h[:16] + "…" if h else ""))
    if tag:
        lines.append('\nAlle Dateien und Prüfsummen: <a href="https://github.com/%s/releases/tag/%s">Release %s auf GitHub</a>.\n' % (repo, tag, tag))
    return "".join(lines)


def main():
    page, base = sys.argv[1], sys.argv[2]
    repo = os.environ.get("GITHUB_REPOSITORY", "RincewindWizzard/regatta-game")
    block = "\n".join(section(t, f, w, base, repo) for t, f, w in SECTIONS)
    text = open(page, encoding="utf-8").read()
    a, b = text.index(START), text.index(END)
    text = text[: a + len(START)] + "\n" + block + "\n" + text[b:]
    open(page, "w", encoding="utf-8").write(text)
    print("Download-Seite geschrieben:", page)


if __name__ == "__main__":
    main()
