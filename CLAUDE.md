# CLAUDE.md

Guidance for AI assistants working in this repository. Keep changes minimal and
consistent with the existing conventions below.

**Keep this file up to date.** When a change makes any statement here
inaccurate — new/renamed/removed pages, simulations, collections, CSS tokens,
workflows, or directory-layout shifts — update the relevant section in the
same commit as the change. If you notice drift between CLAUDE.md and the
actual repo while working on something unrelated, fix the drift too.

## Project overview

This is the personal academic website of **Peter Gracar** (Lecturer in
Probability, University of Leeds), served at **https://gracar.org** via GitHub
Pages. It is a small, dependency-light Jekyll site whose primary purpose is to
list publications, collaborators, talks, teaching, and host a few interactive
probability simulations.

- Build system: **Jekyll** (GitHub Pages default — no `Gemfile`, no custom
  plugins, no Node/npm build).
- Hosting: GitHub Pages, custom domain configured via `CNAME` (`gracar.org`).
  Deployment is driven by `.github/workflows/pages.yml`, which runs
  `actions/jekyll-build-pages` on every push to `main` and uploads the
  resulting site as the Pages artifact.
- Content model: Jekyll **collections** of front-matter-only Markdown files.
  Rendering happens inside the page templates, not in individual content files.

## Repository layout

```
_config.yml                 Jekyll config: site metadata + collection declarations
_layouts/default.html       The single shared layout (header, nav, footer, meta)
_includes/publication_item.html  Renders a single <li> for a publication
_publications/*.md          Publication entries (preprint / accepted / published)
_coauthors/*.md             Coauthor directory, referenced by publications via coauthor_id
_talks/*.md                 Talks / conferences / workshops
_modules/*.md               Teaching modules
_mini_cv/*.md               Short CV timeline entries shown on the homepage

index.html                  Home (About)
research.html               Publications, collaborators, talks
teaching.html               Current modules
contact.html                Email/office/address
map.html                    Directions to office 9.10p1
secret.html                 Unlisted auto-index of all pages/static files (noindex)
404.html                    Custom 404

simulations/                All interactive simulation HTML lives here, and is
                            served from /simulations/<name>.html.
  contact-process.html        Embedded simulation: SIS contact process on a
                              mobile geometric random graph. Jekyll-wrapped
                              (layout: default), linked from research.html
                              at simulations/contact-process.html.
  levy-vs-bm.html             Embedded simulation: Lévy flight vs Brownian
                              motion. Jekyll-wrapped, linked from research.html
                              at simulations/levy-vs-bm.html.
  detection-percolation.html  Embedded simulation: hitting time for a moving
                              Poisson particle system (first contact or first
                              coverage by the largest connected component), with
                              Lévy motion smoothed into a continuous glide.
                              Jekyll-wrapped but **superseded** by the
                              discontinuous variant below: it is marked
                              no_index and is no longer linked from
                              research.html (retained, so its URL and standalone
                              copy still work, and it stays listed on
                              secret.html).
  detection-percolation-discontinuous.html  Embedded simulation: a variant of
                              detection-percolation.html where Lévy motion is
                              drawn as a *genuine discontinuous jump process*
                              (particles dwell, then jump instantly, with a
                              fading line marking each leap) while Brownian
                              motion stays continuous. Jekyll-wrapped, and the
                              detection-percolation sim now linked from
                              research.html at
                              simulations/detection-percolation-discontinuous.html.
  contact-process-standalone.html   Self-contained (Tailwind + MathJax via CDN)
  levy-vs-bm-standalone.html        copy of each simulation for offline /
  detection-percolation-standalone.html  external use. No Jekyll front matter,
  detection-percolation-discontinuous-standalone.html  so they are served as
                                    static files at /simulations/<name>.html and
                                    surfaced automatically in secret.html.
                                    (levy-vs-bm-standalone.html is the former
                                    presentation variant; its logic matches the
                                    embedded levy-vs-bm.html. The
                                    detection-percolation-discontinuous pair adds
                                    the discontinuous-Lévy variant described
                                    above.)

playgrounds/                Native Swift Playground (`.swiftpm`) apps that
                            mirror each web simulation. Excluded from the
                            Jekyll build via `_config.yml`'s `exclude:` list
                            so they are not published to gracar.org. Three
                            packages: ContactProcess.swiftpm,
                            LevyVsBrownian.swiftpm, DetectionPercolation.swiftpm.

style.css                   Single global stylesheet (CSS custom properties,
                            light/dark via prefers-color-scheme)
site.js                     Email deobfuscation, nav active state, tooltip/hover
                            previews, Esc-to-close behaviour

uploads/                    Drop-zone for arbitrary files (any type), served as
                            static assets at /uploads/<name>. Kept out of the
                            sitemap (static files are never enumerated there)
                            and disallowed in robots.txt, but surfaced on
                            secret.html via site.static_files. Holds a
                            .gitkeep so the empty folder persists in git
                            (dotfiles are ignored by Jekyll, so .gitkeep is
                            not listed on secret.html). Must NOT be added to
                            _config.yml's exclude: list, or its files would
                            not be published.
img/                        Avatar, map, figure previews (.webp)
papers/                     PDF reprints (SPA129.pdf, waw2020.pdf, waw2023.pdf)
banner.webp                 Social-share image used as og:image and
                            twitter:image in _layouts/default.html.

CONTENT_GUIDE.md            Human-facing content authoring guide (excluded from build)
CNAME                       gracar.org
robots.txt, sitemap.xml     SEO; sitemap is a Liquid template over site.pages
site.webmanifest, favicon*, apple-touch-icon, android-chrome-*  PWA icons
.github/workflows/pages.yml GitHub Actions workflow that builds with Jekyll
                            and deploys to GitHub Pages on push to main.
.gitignore                  Ignores .DS_Store, /.claude, and the build-time
                            /_data/upload_dates.json (see secret.html notes)
```

There is no `Gemfile`, `package.json`, or test suite — the only automation is
the `pages.yml` workflow above, which uses GitHub Pages' default Jekyll
toolchain.

### No Jekyll theme

`_config.yml` contains an explicit `theme: null` line. This is a deliberate
guard: the site ships its own `_layouts/default.html` and `style.css`, and
does **not** use any Jekyll theme. In the past the repo's
`Settings → Pages → Theme` UI was left in a state where a theme was still
being activated at build time even though `_config.yml` did not declare
one, which caused the theme's `assets/css/style.scss` entry point to be
compiled and published as a phantom page at `/assets/css/style.css` (visible
in `secret.html`'s `site.pages` listing). The explicit `theme: null` forces
Jekyll to deactivate any theme that the Pages UI might still be configured
with. **Do not remove the line** without first confirming in the repo
settings that no theme is selected and that `/secret` no longer contains an
`/assets/css/style.css` entry.

## Collections and front-matter conventions

Collections are declared in `_config.yml` with `output: false` — they are data
sources only, never individual pages. Templates iterate `site.<collection>` and
render inline.

All collection files are **front-matter-only Markdown** (empty bodies, except
`_mini_cv` whose body is the CV line). `CONTENT_GUIDE.md` is the authoritative
schema for each template and is excluded from the build via `_config.yml`.

Key rules mirrored by the templates (see `_includes/publication_item.html` and
`research.html`):

- **Publications** (`_publications/*.md`)
  - Required: `title`, `title_url`, `status` (`preprint` | `accepted` | `published`).
  - `date` is required for `preprint` / `published`, optional for `accepted`.
  - Items missing required fields are silently skipped by the Liquid template.
  - `coauthors` is a list of `coauthor_id` strings; unknown IDs are ignored.
  - Coauthors are always rendered alphabetically by `last_name` then `name`,
    regardless of list order in the file.
  - Preprints list is sorted by `date` descending; accepted-without-date
    entries are shown first in the published/accepted section, followed by
    dated accepted+published items by `date` descending.
  - LaTeX math is allowed in titles (the research page loads MathJax via
    `mathjax: true`). When a title contains a backslash escape like `\alpha`,
    wrap it in **single quotes** so YAML does not process the backslash.
  - Filenames conventionally start with the publication date
    (`YYYY-MM-DD-slug.md`) but Jekyll does not require this — sorting uses the
    front-matter `date`, not the filename.

- **Coauthors** (`_coauthors/*.md`)
  - Required: `coauthor_id`, `name`, `last_name`. `profile_url` optional.
  - Add a new coauthor file **before** referencing the ID from a publication.

- **Talks** (`_talks/*.md`)
  - Required: `title`, `event_url`, `date`, `location`. Sorted newest first.

- **Modules** (`_modules/*.md`)
  - Required: `code`, `title`, `role`, `active`. Only `active: true` is shown.
  - Ordered by `order` ascending, then `code`.

- **Mini CV** (`_mini_cv/*.md`)
  - Required front matter: `period`, `order`. The Markdown **body** is the
    line text (rendered with `markdownify` and wrapper `<p>` stripped).

When adding content, follow the exact schemas in `CONTENT_GUIDE.md` and prefer
editing existing files as templates — do not invent new front-matter keys
unless you also update the consuming template.

## Page template conventions

Every user-facing page starts with a Jekyll front-matter block that `default.html`
reads. Keep these fields populated on new pages:

```yaml
---
layout: default
data_page: <slug>          # used for nav active state via site.js
title: "..."               # <title> + og:title + twitter:title
description: "..."         # <meta name=description>
og_description: "..."      # og:description
twitter_description: "..." # optional; falls back to og_description
canonical: "https://gracar.org/<path>"
mathjax: true              # optional; only set when math is actually used
no_index: true             # optional; adds <meta name=robots content=noindex>
no_analytics: true         # optional; disables the gtag snippet for this page
---
```

The layout injects:

- Skip link, site header, primary nav (About/Research/Teaching/Contact).
- MathJax v3 (inline `$...$`, display `$$...$$`) only when `mathjax: true`.
- Google Analytics (`G-PY7PCVWS5X`) unless `no_analytics: true`.
- `style.css?v=<n>` and `site.js?v=<n>` — **bump the `?v=` query string when
  editing `style.css` or `site.js`** so returning visitors pick up the change.

All asset and nav `href`/`src` attributes in `default.html` are
root-absolute (`/style.css`, `/site.js`, `/research.html`, …). Do **not**
reintroduce bare relative paths — pages under `simulations/` are served at
`/simulations/<name>.html`, and relative hrefs in the layout would then
resolve to `/simulations/style.css`, etc., and 404.

`site.js` behaviour to be aware of:

- Builds the email link from base64 blobs hardcoded in `site.js`, injecting
  the assembled `mailto:` link into `contact.html`'s empty `#e9` slot. The
  `<noscript>` fallback in that slot shows a lightly-munged address
  (`P.Gracar [at] leeds [dot] ac [dot] uk`) so non-JS users can still reach it.
- Highlights the active nav item by matching `data-page-link` against
  `body[data-page]`.
- Injects the current year into any `[data-year]` node (used in the footer).
- Pride Month easter egg: during June (`getMonth() === 5`) it adds a `pride`
  class to `<body>` and reveals the footer `[data-pride-toggle]` button. CSS
  keyed off `body.pride` draws thin rainbow strips (the `--pride-gradient`
  token) under the nav and atop the footer and swaps in-content link underlines
  to the rainbow gradient (via the `--underline-image` token, which defaults to
  the solid accent underline). A click toggles the class and persists the choice
  in
  `localStorage['pride-colours']` (`"on"`/`"off"`, default on, `try/catch`
  guarded). The toggle is hidden and the class absent outside June.
- Wires up `.hover-image` buttons with `.hover-img` children for the figure
  previews on the home and research pages (hover on desktop, click on touch,
  Esc to dismiss, click-outside to dismiss).

## Simulations directory

All interactive simulation HTML files live under `simulations/` and are served
at `/simulations/<name>.html`. There are two flavours:

- **Jekyll-wrapped** — `simulations/contact-process.html`,
  `simulations/levy-vs-bm.html`, `simulations/detection-percolation.html`, and
  `simulations/detection-percolation-discontinuous.html`
  use `layout: default` and are addressed by the relative paths
  `simulations/<name>.html`. `research.html` links contact-process, levy-vs-bm,
  and detection-percolation-**discontinuous**; the plain
  `detection-percolation.html` is now `no_index` and **not** linked (superseded
  by the discontinuous variant), though it is still a Jekyll page served at its
  URL. Their public URLs are `gracar.org/simulations/<name>.html`; the
  `canonical:` field in each page's front matter must match. Do **not** add a
  `permalink:` field to bring them back to the site root — the layout's nav and
  asset hrefs assume pages are addressed by their source path.
- **Standalone** — `simulations/contact-process-standalone.html`,
  `simulations/levy-vs-bm-standalone.html`,
  `simulations/detection-percolation-standalone.html`, and
  `simulations/detection-percolation-discontinuous-standalone.html` are
  **independent HTML
  documents** with no Jekyll front matter (Tailwind + MathJax via CDN, own
  light/dark toggle persisted in `localStorage['theme-pref']`). They are
  intended for offline / presentation use and, because they have no front
  matter, Jekyll copies them through as static files at
  `/simulations/<name>.html`. They are not linked from the navigation or
  sitemap but are surfaced automatically in `secret.html` via
  `site.static_files`. The Lévy standalone file was previously named
  `levy-vs-bm-presentation.html`; its logic matches the embedded
  `levy-vs-bm.html`.

- **Discontinuous-Lévy variant** — the
  `detection-percolation-discontinuous.html` / `-standalone.html` pair is a copy
  of the detection-percolation pair whose **only** behavioural difference is the
  Lévy motion model: instead of spreading each heavy-tailed jump over
  `⌈|J|/speed⌉` ticks so it reads as a smooth *glide* (what the original
  `movePart` does), a particle **dwells** for a randomised waiting time
  (`sampleDwell`, mean `Config.jumpDwellMean` ticks) and then **jumps
  instantly** — a true discontinuity. Readability comes from the dwell plus
  fading "jump markers" (`State.jumpMarks`, `recordJumpMark`, `ageJumpMarks`,
  drawn in `draw`): a short line from departure→landing that fades over
  `Config.jumpMarkerLife` frames, bolder for the distinguished target. The
  target's trail also pen-lifts at each jump (via a per-point `jumped` flag) so
  it shows a discrete set of visited points rather than a fake glide. Brownian
  mode is copied verbatim and stays genuinely continuous. Because the target
  now skips intermediate points, hit detection only tests landing positions —
  the correct behaviour for a jump process.

Each web simulation (except the discontinuous-Lévy variant) also has a
companion native Swift Playground app under
`playgrounds/<Name>.swiftpm/`. These are excluded from the Jekyll build (see
`exclude:` in `_config.yml`) and are not part of the published site, but
share the model/parameters with their HTML counterparts. When fixing a bug
in a simulation, check whether the same logic is duplicated in the
standalone HTML copy (and, where relevant, in the Swift package) and update
them together. The `detection-percolation-discontinuous` pair has **no** Swift
counterpart; its two HTML files must be kept in sync with each other.

## SEO, sitemap, and the "secret" index

- `sitemap.xml` is a Liquid template that enumerates `site.pages`, skipping any
  page marked `no_index` and the sitemap itself. New pages are included
  automatically.
- `secret.html` is an unlisted full index of pages, static HTML files, PDFs,
  and `uploads/` files. It is marked `no_index`, `no_analytics`,
  `sitemap: false`, and excludes itself from its own list. It exists so
  standalone simulations, reprints, and uploaded files remain discoverable to
  the author without adding them to the public sitemap. The "Uploads" section
  lists every static file whose path contains `/uploads/` (any extension); the
  HTML and PDF sections exclude `/uploads/` paths so an uploaded HTML/PDF is
  not listed twice. Each upload also shows the date it was added, looked up
  from `site.data.upload_dates` (keyed by the file's repo-relative path, e.g.
  `uploads/<name>`). That data file, `_data/upload_dates.json`, is **generated
  at build time** by `pages.yml`: a step runs `git log -1 --format=%cs` for
  every tracked `uploads/` file and records the date of the last commit that
  touched it. Filesystem mtimes are deliberately **not** used — `actions/checkout`
  stamps every file with the checkout time, and an mtime restored on the runner
  (e.g. via `git-restore-mtime`) did not reliably survive the Dockerised
  `jekyll-build-pages` step, leaving every upload dated to the build time. The
  full-history checkout (`fetch-depth: 0`) is required so `git log` can see the
  original commits. `_data/upload_dates.json` is git-ignored and never
  committed, so generating it does not churn history; absent it (e.g. a plain
  local build), uploads simply render with no date.
  It also renders a small "Build info" panel using `site.time` (the build
  timestamp, always available) and `site.github.build_revision` /
  `site.github.repository_nwo` from the `jekyll-github-metadata` plugin (which
  GitHub Pages ships enabled by default — not a new dependency). The commit
  block is guarded by `{% if site.github.build_revision %}` so local builds
  without GitHub metadata degrade to showing only the build time.
- `404.html` is also `no_index` + `no_analytics`.

## Local development

No toolchain is checked in. If you need a live preview:

```sh
# one-off
bundle exec jekyll serve
# or, without a Gemfile, using github-pages defaults
jekyll serve
```

In most editing sessions you will **not** run Jekyll locally — the site is
small enough that changes to Markdown/HTML can be verified by reading the
templates and pushing. GitHub Pages rebuilds on push to `main`.

## Coding conventions

- **No new dependencies.** Do not add Gemfiles, npm packages, build tools,
  CSS/JS bundlers, or Jekyll plugins without explicit instruction. Keep the
  site buildable by stock GitHub Pages.
- **No new files unless necessary.** Prefer adding a publication/coauthor/etc.
  by creating a file in the relevant collection; prefer editing an existing
  page template over adding a new one.
- **HTML/Liquid**: match the indentation and defensive `{% if %}` style in
  `_includes/publication_item.html` — the templates silently skip entries with
  missing required fields rather than erroring.
- **CSS**: all styles live in `style.css`. It uses CSS custom properties
  (`--color-*` and `--text-*` — the previous `--space-*` spacing tokens were
  removed as unused, plus `--pride-gradient` and `--underline-image` for the
  June easter egg) and a `prefers-color-scheme: dark` block. Prefer extending
  the existing variables over adding hard-coded values.
- **JS**: keep `site.js` small and framework-free. It is a single IIFE that
  short-circuits gracefully when the elements it looks for are absent.
- **Cache busting**: bump `?v=<n>` on `style.css` / `site.js` in
  `_layouts/default.html` when their contents change.
- **Images**: use `.webp` in `img/` with explicit `width`, `height`, and
  `loading` attributes, mirroring existing usage.
- **Accessibility**: preserve the skip link, `aria-*` attributes on nav and
  hover-image buttons, and the `<noscript>` fallback on the contact email.

## Git workflow

- Development branches follow the pattern used by this session (e.g.
  `claude/<description>`). Push to the designated branch; do not push directly
  to `main` unless explicitly instructed.
- Commit messages in history are short, imperative, and topic-focused
  (e.g. *"Expose embedded simulations in sitemap"*, *"Fix Lévy sausage shading
  and add slider tick marks"*). Match that style.
- Do **not** open pull requests unless the user asks for one.
