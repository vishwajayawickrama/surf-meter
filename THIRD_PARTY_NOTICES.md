# Third-party notices

## Public Suffix List

`Sources/SurfMeterCore/Resources/public_suffix_list.dat` is the Mozilla/community Public Suffix List, retrieved on 2026-11-06 from [publicsuffix.org](https://publicsuffix.org/list/public_suffix_list.dat). Its version and upstream commit are embedded in the file header. It is distributed under the [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/). The original source, notices, and rules remain intact. SurfMeter bundles the ICANN and private sections and makes no runtime network requests to update the list.

## Documentation assets

The architecture diagram fonts and icons retain their respective license files in `docs/diagrams`. TypeScript is a development dependency; its license is supplied by its npm package. Platform symbols in the native interface are Apple SF Symbols used through system APIs, rather than bundled third-party brand artwork.

## Chrome setup screenshots

The three Chrome screenshots in `docs/media/setup/sources/chrome-*.png` are from Google's [Hello World extension tutorial](https://developer.chrome.com/docs/extensions/get-started/tutorial/hello-world), Chrome for Developers. The page identifies its content as [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), except where otherwise noted. The documentation figures add numbered vector callouts and layout around the original screenshots; the sources are retained unchanged. They depict Google's Hello Extensions example, not an installed SurfMeter extension. See `docs/media/setup/README.md` for individual asset URLs and modifications.
