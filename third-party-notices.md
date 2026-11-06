# Third-party notices

## Public Suffix List

`sources/surf-meter-core/resources/public_suffix_list.dat` is the Mozilla/community Public Suffix List, retrieved on 2026-11-06 from [publicsuffix.org](https://publicsuffix.org/list/public_suffix_list.dat). Its version and upstream commit are embedded in the file header. It is distributed under the [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/). The original source, notices, and rules remain intact. SurfMeter bundles the ICANN and private sections and makes no runtime network requests to update the list.

## Documentation assets

The architecture diagram fonts and icons retain their respective license files in `docs/diagrams`. TypeScript is a development dependency; its license is supplied by its npm package. General interface symbols use Apple SF Symbols through system APIs. Website marks in the current native app use bundled Simple Icons 16.36.0 (CC0) and Font Awesome Free Brands 7.3.1 (CC BY 4.0, Fonticons, Inc.) artwork, converted to cached native vector paths. Source SVGs, source URLs, retained licenses, conversion details and regeneration instructions are in [the website-icon resources](sources/surf-meter-app/resources/site-icons/README.md). The associated marks remain the property of their respective owners. Historical prototype screenshots retain their original illustrative marks.

## Chrome setup screenshots

The three Chrome screenshots in `docs/media/setup/sources/chrome-*.png` are from Google's [Hello World extension tutorial](https://developer.chrome.com/docs/extensions/get-started/tutorial/hello-world), Chrome for Developers. The page identifies its content as [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), except where otherwise noted. The documentation figures add numbered vector callouts and layout around the original screenshots; the sources are retained unchanged. They depict Google's Hello Extensions example, not an installed SurfMeter extension. See `docs/media/setup/README.md` for individual asset URLs and modifications.

## Performance report tooling

The resource figures are generated from the project's numeric measurements using optional [Matplotlib](https://pypi.org/project/matplotlib/), pinned in `scripts/requirements-resource-report.txt`. This is report-generation tooling, not a dependency bundled into the native app. The measurement harness itself uses the Python standard library and macOS system counters.
