# Bundled website icons

SurfMeter bundles 48 presentation identities for 67 domain aliases. Artwork is rendered as cached native vector paths in both the menu panel and desktop window. The app does not request favicons, contact an icon service or send recorded domains anywhere. Unknown domains use a local initial and deterministic tile color.

The source SVGs, generated `brands.json`, licenses and disclaimer are kept together. Friendly names and icons are presentation metadata: they do not modify platform classification, aliases in the accounting engine or existing totals. In particular, a Google service already grouped under `google.com` remains in that group.

## Attribution

Most artwork comes from [Simple Icons 16.36.0](https://github.com/simple-icons/simple-icons/tree/16.36.0), distributed under CC0 1.0. See [the retained license](simple-icons-license.txt) and [upstream disclaimer](simple-icons-disclaimer.txt). Each generated record retains its source URL.

LinkedIn, OpenAI/ChatGPT, Slack, Amazon, Microsoft and Yahoo artwork comes from [Font Awesome Free Brands 7.3.1](https://www.npmjs.com/package/@fortawesome/free-brands-svg-icons/v/7.3.1), by Fonticons, Inc. (copyright 2026), licensed under CC BY 4.0 for icons. See [the retained license](font-awesome-license.txt) and [Font Awesome's licensing page](https://fontawesome.com/license/free). Paths are normalized to a 24-point coordinate space, colored for the app's appearances and placed inside rounded tiles. No font or JavaScript runtime is bundled.

The brands and marks belong to their respective owners and identify website activity; they do not imply endorsement of SurfMeter.

## Regeneration

Authoring requires Node/npm for fetching the pinned packages and Python with the pinned `scripts/requirements-site-icons.txt`. These are not app runtime dependencies. From the repository root, use a temporary directory for the extracted packages, then run:

```sh
python3 scripts/build-site-icons.py --simple-icons /path/to/simple-icons/package --font-awesome /path/to/font-awesome/package
./scripts/build-native.sh
.build/SurfMeter.app/Contents/MacOS/SurfMeter --verify-site-icons
.build/SurfMeter.app/Contents/MacOS/SurfMeter --render-site-icons /private/tmp/surfmeter-icon-previews
```

Fetch the two packages with `npm pack simple-icons@16.36.0` and `npm pack @fortawesome/free-brands-svg-icons@7.3.1`, then extract each into a separate temporary directory. The converter verifies package versions and converts SVG paths with FontTools. It never executes upstream JavaScript. Regeneration is a developer action; there is no automatic updater or network lookup in the app.
