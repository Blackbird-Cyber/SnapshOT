# Vendored JavaScript origin

Written by `scripts/import-vendor-js.sh`; do not edit by hand. The committed
files in this directory are the source of truth for the package build, which
never touches the network. To refresh them, change the values at the top of the
script and run it again.

| | vis-network | iframe-worker |
|---|---|---|
| Version | `10.1.2` | `1.0.4` |
| Tarball | `https://registry.npmjs.org/vis-network/-/vis-network-10.1.2.tgz` | `https://registry.npmjs.org/iframe-worker/-/iframe-worker-1.0.4.tgz` |
| npm integrity | `sha512-1Kj7GD7XNjygliqRWXv/VPT1X/2eKz2e09PvwDtETHwuvKJ0emid7/PmWoFqCMypun8rLbjgmalSfPkiVZ8ZMg==` | `sha512-roeaaI+Lg1LJNfgpCjoRe/+WzEjy9+Z08LoEvu85MCPbBjwm+qXz8Ag5U05lHa6V1CysZyGzE0SOkAtSUA5q7Q==` |
| Extracted from | `package/standalone/umd/vis-network.min.cjs` | `package/shim/index.js` |
| Shipped as | `vis-network.min.js` | `iframe-worker-shim.js` |
| sha256 of shipped file | `e7653a735c9014c5a1c22e9dac5733c2d94e97fab0a4f8dabe0ed9170ac5e512` | `e8e412dbcfea9b7e31b5ffa288d7b6035915e714c542f4176a0cdbe262fc9609` |
| Licence | (Apache-2.0 OR MIT); texts in `LICENSE-vis-network` | MIT; text in `LICENSE-iframe-worker` |

## Why each file is here

- **vis-network** draws the interactive graphs (`assets/js/snapshot-graphs.js`
  mounts it on every `<div class="snapshot-graph">`). The standalone UMD build
  bundles its own dependencies, so it is the only file needed. It is renamed from
  `.cjs` to `.js` because Firefox on `file://` decides the MIME type from the
  extension.
- **iframe-worker** is the shim Material's `offline` plugin loads so that search
  works on `file://`, where Web Workers are not allowed. The plugin references
  `https://unpkg.com/iframe-worker/shim`; the build hook rewrites that to this
  local copy on every page.
