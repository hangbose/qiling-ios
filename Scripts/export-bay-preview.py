"""Export the Shenzhen Bay demo as an offline HTML file with its art and font."""
import argparse
import base64
import mimetypes
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "Preview"


def data_url(resource):
    path = PREVIEW / resource
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def export(destination):
    html = (PREVIEW / "BayJourney.html").read_text(encoding="utf-8")
    css = (PREVIEW / "bay.css").read_text(encoding="utf-8")
    js = (PREVIEW / "bay.js").read_text(encoding="utf-8")
    images = set(re.findall(r'src="(\.\./Resources/Assets\.xcassets/[^"]+)"', html))
    trail = (PREVIEW / "bay-trail.js").read_text(encoding="utf-8")
    html = html.replace('<script src="bay-trail.js"></script>', f"<script>{trail}</script>")
    bench = (PREVIEW / "bay-bench.js").read_text(encoding="utf-8")
    html = html.replace('<script src="bay-bench.js"></script>', f"<script>{bench}</script>")
    audio = "../Resources/BayChime.wav"
    html = html.replace(audio, data_url(audio))
    pages = (PREVIEW / "bay-pages.js").read_text(encoding="utf-8")
    html = html.replace('<script src="bay-pages.js"></script>', f"<script>{pages}</script>")
    font = "../Resources/QilingJournal.ttf"
    license_text = (ROOT / "Resources/QilingJournal-LICENSE.txt").read_text(encoding="utf-8")
    css = css.replace(font, data_url(font))
    for art in images:
        html = html.replace(art, data_url(art))
    html = html.replace('<link rel="stylesheet" href="bay.css">', f"<style>{css}</style>")
    html = html.replace('<script src="bay.js"></script>', f"<script>{js}</script>")
    html = html.replace("</body>", f'<script type="text/plain" id="font-license">{license_text}</script>\n</body>')
    destination.write_text(html, encoding="utf-8")


def export_site(destination):
    """Publish just the game and its referenced media, keeping large images cacheable."""
    destination.mkdir(parents=True, exist_ok=True)
    html = (PREVIEW / "BayJourney.html").read_text(encoding="utf-8")
    css = (PREVIEW / "bay.css").read_text(encoding="utf-8")
    assets = set(re.findall(r'(?:src=|url\()"\.\./Resources/([^"]+)"', html + css))
    assets.add("QilingJournal-LICENSE.txt")
    for asset in assets:
        target = destination / "assets" / asset
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / "Resources" / asset, target)
    for script in re.findall(r'<script src="([\w-]+\.js)"></script>', html):
        shutil.copyfile(PREVIEW / script, destination / script)
    html = html.replace("../Resources/", "assets/")
    html = re.sub(r'<img alt="" id="wide', '<img loading="lazy" alt="" id="wide', html)
    (destination / "index.html").write_text(html, encoding="utf-8")
    (destination / "bay.css").write_text(css.replace("../Resources/", "assets/"), encoding="utf-8")
    (destination / ".nojekyll").touch()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--site", action="store_true")
    args = parser.parse_args()
    (export_site if args.site else export)(args.destination)
