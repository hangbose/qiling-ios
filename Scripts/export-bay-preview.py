"""Export the Shenzhen Bay demo as an offline HTML file with its art and font."""
import argparse
import base64
import mimetypes
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
    art = "../Resources/Assets.xcassets/BayJourney.imageset/bay.png"
    font = "../Resources/BayLetterpress.ttf"
    license_text = (ROOT / "Resources/BayLetterpress-LICENSE.txt").read_text(encoding="utf-8")
    css = css.replace(font, data_url(font))
    html = html.replace(art, data_url(art))
    html = html.replace('<link rel="stylesheet" href="bay.css">', f"<style>{css}</style>")
    html = html.replace('<script src="bay.js"></script>', f"<script>{js}</script>")
    html = html.replace("</body>", f'<script type="text/plain" id="font-license">{license_text}</script>\n</body>')
    destination.write_text(html, encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    export(parser.parse_args().destination)
