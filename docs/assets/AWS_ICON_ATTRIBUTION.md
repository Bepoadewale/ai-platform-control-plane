# Diagram asset attribution

`aws-icons/` contains selected, unmodified SVGs from the [AWS Architecture Icons]
(https://aws.amazon.com/architecture/icons/) icon package, downloaded on 2026-10-04:

`Icon-package_07312026.5846e92413caa21490223536cc97f1269e44fa92.zip`

The official AWS page permits customers and partners to use these assets in architecture diagrams.
`../cloud-pilot-architecture.svg` is generated locally by
[`scripts/generate-cloud-architecture.mjs`](../../scripts/generate-cloud-architecture.mjs), which
inlines the selected SVGs so README rendering does not rely on third-party image hosting.
