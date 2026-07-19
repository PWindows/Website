# Repository Instructions

## Project overview

This repository contains the public PWindows website. It is a static Jekyll
site deployed from the `main` branch. Preserve the current visual identity,
public URLs, accessibility behavior, and data-driven templates unless a task
explicitly requires a change.

## Repository structure

- `index.html` is the homepage.
- `pages/` contains public pages. Every page must declare an explicit
  `permalink` so reorganizing source files does not change its URL.
- `_articles/` contains news posts in the `articles` collection.
- `_layouts/` contains page shells; `_includes/` contains reusable markup.
- `_data/games.yml` and `_data/staff.yml` are the canonical sources for game
  and staff information.
- `assets/css/style.css` is the main production stylesheet.
- `assets/css/news.css` contains article-specific styles.
- `assets/js/main.js` contains site-wide behavior.
- `tools/verify-site.rb` enforces public routes, metadata, sitemap contents,
  source-data integrity, and publishing exclusions.
- `_site/` and `.jekyll-cache/` are generated. Never edit them directly.
- `tools/` is for local utilities and must not be published.

## Local development and verification

Install dependencies once:

```sh
bundle install
```

Run the development server:

```sh
bundle exec jekyll serve
```

Before completing a change, run the same checks as CI:

```sh
bundle exec jekyll build
bundle exec htmlproofer ./_site --disable-external --ignore-urls '/minecraft:/'
bundle exec ruby tools/verify-site.rb ./_site
```

For JavaScript changes, also run:

```sh
node --check assets/js/main.js
```

Run `git diff --check` after editing. Fix failures caused by the current change;
do not rewrite unrelated code merely to silence pre-existing issues.

## Public routes and publishing

The following routes are stable and must remain available:

- `/`
- `/404.html`
- `/about`
- `/articles`
- `/contact`
- `/feedback`
- `/games`
- `/games/obby-of-dominance`
- `/games/sacred-cubes`
- `/rules`
- `/sitemap`
- `/staff`
- Existing `/article/:name` URLs

When adding or intentionally removing a public route, update
`tools/verify-site.rb` and the human-readable site map as needed. Keep
`/sitemap` as the footer’s readable site-map destination; `sitemap.xml` is for
search engines.

Do not publish `AGENTS.md`, `README.md`, `tools/`, `vendor/`, or font specimen
HTML pages. Do not delete fonts or other retained files from
`assets/mojang/fonts/`; they are intentionally kept for future use even when
they are excluded from the generated site.

## Pages, templates, and metadata

- Reuse layouts and includes instead of duplicating shared markup.
- Use the `page` layout for conventional content pages.
- Every public page must generate a non-empty `<main>`, exactly one `<h1>`, a
  document title, a canonical URL, and a useful unique description.
- The 404 page must retain `permalink: /404.html` and `sitemap: false`.
- Generate internal URLs and asset URLs with Jekyll’s `relative_url` filter.
  Use `absolute_url` only where an absolute canonical or social URL is needed.
- Escape user- or content-provided values when placing them in HTML
  attributes.
- Keep one shared build revision for CSS and JavaScript cache-busting.
- Do not add a new production stylesheet when an existing stylesheet is the
  appropriate home for the change.

## Data conventions

Game records in `_data/games.yml` require:

- `slug`
- `title`
- `path`
- `status`
- `summary`

Game paths must point to real public pages. Keep game lists and footer links
data-driven instead of duplicating them in templates.

Keys in `_data/staff.yml` are stable author identifiers used by articles. Do
not rename them without updating every article reference. Staff shown on the
staff page use `aboutpage: true` and require `name`, `pfp`, `role`, and `bio`;
`socials` is optional. Local image paths must be root-relative and point to
tracked files.

Articles should use valid staff keys for `author`, retain stable filenames and
URLs, and provide the front matter required by their layout. Reuse
`_includes/article-card.html` for article listings and preserve the empty-news
state.

## CSS and responsive behavior

- Follow the existing organization of base, navigation, components, pages,
  and responsive rules.
- Prefer flat selectors and broadly supported CSS. Avoid nested CSS syntax.
- Preserve visible keyboard focus styles and reduced-motion behavior.
- Test layout logic at narrow mobile widths as well as 375px, 768px, and
  desktop widths. Flex and grid children should be able to shrink; use
  `min-width: 0` where content could otherwise overflow.
- At widths up to 540px, footer columns must remain stacked and must not overlap
  or clip into adjacent sections.
- Avoid horizontal scrolling. Do not rely on `overflow-x: hidden` to conceal a
  component sizing bug.

## Interaction and accessibility requirements

- All interactive behavior must work with keyboard, mouse, and touch input.
- Mobile navigation must trap focus while open, close on Escape and selection,
  return focus appropriately, and lock background scrolling. It must close and
  restore scrolling when crossing the desktop breakpoint.
- Flip cards use hover and focus behavior with a precise pointer. In that mode,
  both the front instruction control and Back button are hidden and removed
  from keyboard navigation.
- On touch or coarse-pointer input, preserve button-driven card flipping with
  visible, enabled front and Back controls.
- Hybrid devices must retain touch behavior after touch input while allowing
  mouse hover behavior.
- Keep `inert`, `aria-hidden`, focusability, and expansion state synchronized so
  only the visible card face is exposed to assistive technology.
- Do not add interaction roles that misrepresent a component’s behavior.
- Disabled buttons must not have `href` attributes.

## Change discipline

- Keep changes scoped to the request and preserve unrelated work in a dirty
  worktree.
- Prefer `git mv` when relocating tracked files so history is retained.
- Do not commit generated `_site/` output.
- Do not invent gameplay details for games marked “In development.”
- Update documentation and verification checks when introducing a new project
  convention or invariant.
