# Content Guide

This site uses Jekyll collections so content can be maintained in human-readable Markdown files.

## Collections

- Publications: `_publications/*.md`
- Coauthors: `_coauthors/*.md`
- Talks: `_talks/*.md`
- Teaching modules: `_modules/*.md`
- Mini CV entries (homepage): `_mini_cv/*.md`

## Publication template

```md
---
title: "Paper title"
title_url: "https://..."
status: "preprint" # preprint | accepted | published
date: "2025-03-24" # required for preprint/published; optional for accepted
coauthors: # optional list of coauthor IDs
  - "peter-moerters"
  - "arne-grauer"
outlet_name: "Journal name" # optional
outlet_url: "https://..." # optional
citation_text: "30: 1-29 (2025)" # optional
preprint_label: "arXiv:2503.18577" # optional
preprint_url: "https://arxiv.org/abs/2503.18577" # optional
note: "Optional note"
simulations: # optional list of interactive simulations illustrating this paper
  - url: "simulations/rainbow-percolation.html"
    label: "an illustrated tour of the model"
---
```

Validation and behavior:

- Required fields: `title`, `title_url`, `status`.
- `date` is required for `preprint` and `published`, optional for `accepted`.
- Invalid items are skipped.
- `coauthors` is optional; when present, each value must be a valid coauthor ID from `_coauthors`.
- Coauthors are rendered alphabetically by `last_name`, then `name`, regardless of the order in the `coauthors` list.
- Accepted papers without `date` appear at the top of the "Published and accepted papers" section.
- LaTeX math in titles is typeset on the research page (for example, `$\\alpha$`).
- When using backslashes in front matter (for example `\alpha`), wrap the title in single quotes to avoid YAML escape handling.
- `simulations` is optional. Each item needs both `url` and `label`; items missing either are skipped. An entry with at least one valid item gets a "Simulation"/"Simulations" pill next to its status badge, and a line under the entry reading "Interactive simulation: <label>" (pluralised, labels separated by `·`, when there are several). Labels read as a continuation of that prefix, so they start lowercase unless they begin with a proper noun. The same simulation may be listed on more than one publication.

## Coauthor template

```md
---
coauthor_id: "peter-moerters"
name: "Peter Mörters"
last_name: "Mörters"
profile_url: "https://www.mi.uni-koeln.de/~moerters/"
---
```

Validation and behavior:

- Required fields: `coauthor_id`, `name`, `last_name`.
- `profile_url` is optional.
- If `profile_url` is omitted or left blank, the coauthor name is shown without a link.
- Publication entries reference coauthors by `coauthor_id`.
- Collaborators on the research page are deduplicated and sorted by `last_name`, then `name`.

## Talk template

```md
---
title: "Talk title"
event_url: "https://..."
date: "2024-09-18"
location: "Berlin, Germany"
---
```

Validation and behavior:

- Required fields: `title`, `event_url`, `date`, `location`.
- Invalid talks are skipped.
- Talks are ordered newest first.

## Module template

```md
---
code: "MATH5320M"
title: "Discrete Time Finance"
role: "Module leader"
active: true
order: 10
---
```

Validation and behavior:

- Required fields: `code`, `title`, `role`, `active`.
- Invalid modules are skipped.
- Only `active: true` modules are shown.
- Modules are ordered by `order` ascending, then `code`.

## Mini CV template

```md
---
period: "2023-present"
order: 10
---
Lecturer in Probability, University of Leeds
```

Validation and behavior:

- Required fields: `period`, `order`.
- Body content is markdown and rendered as the CV line text.
- Entries are shown on the homepage in ascending `order`.
