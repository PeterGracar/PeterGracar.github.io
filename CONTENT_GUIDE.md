# Content Guide

This site uses Jekyll collections so content is maintained in human-readable Markdown files.

## Collections

- Publications: `_publications/*.md`
- Talks: `_talks/*.md`
- Teaching modules: `_modules/*.md`

## Publication template

```md
---
title: "Paper title"
title_url: "https://..."
status: "preprint" # preprint | accepted | published
date: "2025-03-24" # required for preprint/published; optional for accepted
coauthors: # optional
  - id: "peter-moerters"
    name: "Peter Mörters"
    last_name: "Mörters"
    url: "https://..."
outlet_name: "Journal name" # optional
outlet_url: "https://..." # optional
citation_text: "30: 1-29 (2025)" # optional
preprint_label: "arXiv:2503.18577" # optional
preprint_url: "https://arxiv.org/abs/2503.18577" # optional
note: "Optional note"
---
```

Validation and behavior:

- Required fields: `title`, `title_url`, `status`.
- `date` is required for `preprint` and `published`, optional for `accepted`.
- Invalid items are skipped.
- If `coauthors` is present, each coauthor must include `id`, `name`, and `last_name`.
- Coauthors are optional (single-author items can omit `coauthors`).
- Accepted papers without `date` appear at the top of the "Published and accepted papers" section.

## Talk template

```md
---
title: "Talk title"
url: "https://..."
date: "2024-09-18"
location: "Berlin, Germany"
---
```

Validation and behavior:

- Required fields: `title`, `url`, `date`, `location`.
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

## Collaborators

- Collaborators are derived from publication coauthors.
- Entries are deduplicated by `id`.
- Display order is alphabetical by `last_name`, then `name`.
- If `url` is present, the collaborator name is rendered as a link.
