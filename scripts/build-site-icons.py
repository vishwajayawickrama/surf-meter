#!/usr/bin/env python3
"""Convert pinned upstream brand paths to cached, offline SwiftUI geometry.

Requires fonttools (authoring only). Runtime uses only the generated JSON.
"""
import argparse
import json
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path

SIMPLE_VERSION = "16.36.0"
AWESOME_VERSION = "7.3.1"
# domain identity is presentation only; accounting/classification is unchanged.
SITES = [
    ("youtube", "YouTube", ["youtube.com", "youtu.be"], False),
    ("facebook", "Facebook", ["facebook.com", "fb.com"], False),
    ("instagram", "Instagram", ["instagram.com"], False),
    ("x", "X / Twitter", ["x.com", "twitter.com"], True),
    ("reddit", "Reddit", ["reddit.com", "redd.it"], False),
    ("tiktok", "TikTok", ["tiktok.com"], True),
    ("linkedin", "LinkedIn", ["linkedin.com"], False),
    ("github", "GitHub", ["github.com"], True),
    ("google", "Google", ["google.com", "google.co.uk", "google.lk", "google.co.in"], False),
    ("openai", "ChatGPT", ["chatgpt.com"], True),
    ("openai", "OpenAI", ["openai.com"], True),
    ("googlegemini", "Gemini", ["gemini.google.com"], False),
    ("claude", "Claude", ["claude.ai", "anthropic.com"], False),
    ("perplexity", "Perplexity", ["perplexity.ai"], False),
    ("stackoverflow", "Stack Overflow", ["stackoverflow.com"], False),
    ("wikipedia", "Wikipedia", ["wikipedia.org"], True),
    ("discord", "Discord", ["discord.com", "discord.gg"], False),
    ("twitch", "Twitch", ["twitch.tv"], False),
    ("spotify", "Spotify", ["spotify.com"], False),
    ("netflix", "Netflix", ["netflix.com"], False),
    ("pinterest", "Pinterest", ["pinterest.com"], False),
    ("whatsapp", "WhatsApp", ["whatsapp.com"], False),
    ("telegram", "Telegram", ["telegram.org", "t.me"], False),
    ("notion", "Notion", ["notion.so", "notion.site"], True),
    ("figma", "Figma", ["figma.com"], False),
    ("medium", "Medium", ["medium.com"], True),
    ("substack", "Substack", ["substack.com"], False),
    ("bluesky", "Bluesky", ["bsky.app"], False),
    ("duckduckgo", "DuckDuckGo", ["duckduckgo.com"], False),
    ("huggingface", "Hugging Face", ["huggingface.co"], False),
    ("gmail", "Gmail", ["gmail.com", "mail.google.com"], False),
    ("googledrive", "Google Drive", ["drive.google.com"], False),
    ("zoom", "Zoom", ["zoom.us"], False),
    ("slack", "Slack", ["slack.com"], False),
    ("amazon", "Amazon", ["amazon.com", "amazon.co.uk", "amazon.in"], False),
    ("apple", "Apple", ["apple.com", "icloud.com"], True),
    ("microsoft", "Microsoft", ["microsoft.com", "live.com", "office.com", "outlook.com"], False),
    ("yahoo", "Yahoo", ["yahoo.com"], False),
    ("ebay", "eBay", ["ebay.com", "ebay.co.uk"], False),
    ("aliexpress", "AliExpress", ["aliexpress.com"], False),
    ("coursera", "Coursera", ["coursera.org"], False),
    ("udemy", "Udemy", ["udemy.com"], False),
    ("dropbox", "Dropbox", ["dropbox.com"], False),
    ("trello", "Trello", ["trello.com"], False),
    ("devdotto", "DEV Community", ["dev.to"], True),
    ("gitlab", "GitLab", ["gitlab.com"], False),
    ("bitbucket", "Bitbucket", ["bitbucket.org"], False),
    ("leetcode", "LeetCode", ["leetcode.com"], False),
]
FALLBACKS = {
    "linkedin": ("faLinkedinIn", "0A66C2"), "openai": ("faOpenai", "000000"),
    "slack": ("faSlack", "611F69"), "amazon": ("faAmazon", "C77D00"),
    "microsoft": ("faMicrosoft", "5E5E5E"), "yahoo": ("faYahoo", "6001D2"),
}

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--simple-icons", required=True, type=Path)
    parser.add_argument("--font-awesome", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=Path("sources/surf-meter-app/resources/site-icons"))
    args = parser.parse_args()
    assert json.loads((args.simple_icons / "package.json").read_text())["version"] == SIMPLE_VERSION
    assert json.loads((args.font_awesome / "package.json").read_text())["version"] == AWESOME_VERSION
    metadata = {r["slug"]: r for r in json.loads((args.simple_icons / "data/simple-icons.json").read_text())}
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    for slug, title, domains, monochrome in SITES:
        source = args.simple_icons / "icons" / f"{slug}.svg"
        if source.exists():
            svg = source.read_text().strip()
            color = metadata[slug]["hex"]
            attribution = f"https://github.com/simple-icons/simple-icons/blob/{SIMPLE_VERSION}/icons/{slug}.svg"
        else:
            # Extract literal geometry from the upstream data file, without executing JS.
            import re
            name, color = FALLBACKS[slug]
            code = (args.font_awesome / f"{name}.js").read_text()
            width = int(re.search(r"var width = (\d+);", code)[1])
            height = int(re.search(r"var height = (\d+);", code)[1])
            path = re.search(r"var svgPathData = '([^']+)';", code)[1]
            svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}"><path d="{path}"/></svg>'
            attribution = f"https://www.npmjs.com/package/@fortawesome/free-brands-svg-icons/v/{AWESOME_VERSION}"
        (args.output / f"{slug}.svg").write_text(svg + "\n")
        root = ET.fromstring(svg)
        x, y, width, height = map(float, root.attrib["viewBox"].split())
        scale = 24 / max(width, height)
        transform = (scale, 0, 0, scale, (24-width*scale)/2-x*scale, (24-height*scale)/2-y*scale)
        commands = []
        for element in root.iter():
            if element.tag.split("}")[-1] != "path":
                continue
            pen = RecordingPen()
            parse_path(element.attrib["d"], TransformPen(pen, transform))
            for op, points in pen.value:
                opcode = {"moveTo": 0, "lineTo": 1, "curveTo": 2, "qCurveTo": 3, "closePath": 4, "endPath": 4}[op]
                assert len(points) == {0: 1, 1: 1, 2: 3, 3: 2, 4: 0}[opcode]
                commands.append([opcode] + [round(v, 6) for point in points for v in point])
        records.append(dict(slug=slug, title=title, domains=domains, hex=color, monochrome=monochrome, source=attribution, commands=commands))
    (args.output / "brands.json").write_text(json.dumps(records, separators=(",", ":"), ensure_ascii=False) + "\n")
    shutil.copyfile(args.simple_icons / "LICENSE.md", args.output / "simple-icons-license.txt")
    shutil.copyfile(args.simple_icons / "DISCLAIMER.md", args.output / "simple-icons-disclaimer.txt")
    shutil.copyfile(args.font_awesome / "LICENSE.txt", args.output / "font-awesome-license.txt")
    print(f"Generated {len(records)} brand identities for {sum(len(r['domains']) for r in records)} domain aliases; offline vectors only.")

if __name__ == "__main__":
    main()
