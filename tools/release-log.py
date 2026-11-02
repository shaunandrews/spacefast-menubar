#!/usr/bin/env python3
"""Builds site/releases/index.html, the public release log, from each
release's notes (site/releases/<name>-<version>.html), newest first. Dates come
from the appcast; notes for a release without one carry <h2 data-date="…">."""
import email.utils, html, pathlib, re

site = pathlib.Path(__file__).resolve().parent.parent / "site"
releases = site / "releases"

def version_key(version):
    return tuple(int(part) for part in version.split("."))

dates = {}
appcast = (site / "appcast.xml").read_text() if (site / "appcast.xml").exists() else ""
for item in re.findall(r"<item>(.*?)</item>", appcast, re.S):
    version = re.search(r"<sparkle:version>([^<]+)", item)
    published = re.search(r"<pubDate>([^<]+)", item)
    if version and published:
        dates[version.group(1)] = email.utils.parsedate_to_datetime(published.group(1)).date()

entries = []
for notes in releases.glob("*-*.html"):
    match = re.search(r"-(\d+\.\d+\.\d+)\.html$", notes.name)
    if not match:
        continue
    version, body = match.group(1), notes.read_text().strip()
    stated = re.search(r'data-date="([^"]+)"', body)
    date = dates.get(version) or (stated and stated.group(1))
    body = re.sub(r"<h2[^>]*>.*?</h2>", "", body, count=1, flags=re.S).strip()
    entries.append((version, date, body))
entries.sort(key=lambda entry: version_key(entry[0]), reverse=True)

def when(date):
    if not date:
        return ""
    if isinstance(date, str):
        import datetime
        date = datetime.date.fromisoformat(date)
    return f'<time datetime="{date.isoformat()}">{date.strftime("%B %-d, %Y")}</time>'

sections = "\n".join(
    f'  <section id="v{html.escape(version)}">\n    <h2>{html.escape(version)} {when(date)}</h2>\n    {body}\n  </section>'
    for version, date, body in entries
)

(releases / "index.html").write_text(f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Stash release notes</title>
<meta name="description" content="What's new in each version of Stash.">
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<style>
  :root {{ --ground: #fafafa; --ink: #111; --muted: #6e6e73; --rule: #e5e5e7; color-scheme: light; }}
  @media (prefers-color-scheme: dark) {{
    :root {{ --ground: #101011; --ink: #f5f5f7; --muted: #98989d; --rule: #2a2a2d; color-scheme: dark; }}
  }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; background: var(--ground); color: var(--ink);
    font: 17px/1.6 -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif; -webkit-font-smoothing: antialiased; }}
  a {{ color: inherit; }}
  .wrap {{ max-width: 680px; margin: 0 auto; padding: 0 24px 80px; }}
  header {{ display: flex; justify-content: space-between; padding: 22px 0; font-size: 15px; }}
  header a {{ text-decoration: none; }}
  header a:last-child {{ color: var(--muted); }}
  h1 {{ font: 700 clamp(34px, 6vw, 48px)/1.1 -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
    letter-spacing: -0.025em; margin: 48px 0 8px; }}
  .sub {{ color: var(--muted); margin: 0 0 40px; }}
  section {{ border-top: 1px solid var(--rule); padding: 28px 0 8px; }}
  h2 {{ font-size: 20px; margin: 0 0 12px; display: flex; gap: 12px; align-items: baseline; }}
  h2 time {{ font-size: 15px; font-weight: 400; color: var(--muted); }}
  ul {{ margin: 0; padding-left: 20px; }}
  li {{ margin-bottom: 10px; }}
  li strong {{ font-weight: 600; }}
</style>
</head>
<body>
<div class="wrap">
  <header><a href="../"><strong>Stash</strong></a><a href="../download">Download</a></header>
  <h1>Release notes</h1>
  <p class="sub">What's new in each version. Stash updates itself; ⚙︎ › Check for Updates… if you can't wait.</p>
{sections}
</div>
</body>
</html>
""")
print(f"site/releases/index.html: {len(entries)} releases")
