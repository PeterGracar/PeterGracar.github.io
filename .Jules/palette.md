## 2024-05-23 - Interactive Tooltips need Keyboard Support
**Learning:** The `.hover-image` tooltip implementation relies solely on mouse events (`mouseenter`, `click`), making important content (like the office map) inaccessible to keyboard users.
**Action:** When creating custom interactive elements (like tooltips or popovers) that aren't native buttons, always add `tabindex="0"`, `role="button"`, and `keydown` handlers for Enter/Space to ensure keyboard accessibility.
