# Repository Instructions

## Project overview

This repository contains the public PWindows website. It is a static Jekyll
site deployed from the `main` branch. Preserve the current visual identity,
public URLs, accessibility behavior, and data-driven templates unless a task
explicitly requires a change.

## Repository structure

- `pages/index.html` is the homepage and retains the `/` permalink.
- `pages/` contains public pages. Every page must declare an explicit
  `permalink` so reorganizing source files does not change its URL.
- `_articles/` contains news posts in the `articles` collection.
- `_layouts/` contains page shells; `_includes/` contains reusable markup.
- `_data/games.yml`, `_data/departments.yml`, `_data/staff.yml`, and
  `_data/site.yml` are the canonical sources for game, department, staff, and
  shared site-link information.
- `assets/css/style.css` is the main production stylesheet.
- `assets/css/news.css` contains article-specific styles.
- `assets/js/extra.js` contains site-wide behavior.
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
node --check assets/js/extra.js
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
- `/departments/`
- `/departments/minecraft`
- `/departments/roblox`
- `/departments/unity`
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

Do not publish `AGENTS.md`, `README.md`, `tools/`, `vendor/`, or `assets/extra/`.
Do not delete fonts or other retained files from `assets/extra/`; they are kept
for future use even though the directory is excluded from the generated site.

## Pages, templates, and metadata

- Reuse layouts and includes instead of duplicating shared markup.
- Use the `page` layout for conventional content pages.
- Use the `department` layout for department detail pages and set the
  front-matter `department` value to a valid `_data/departments.yml` key.
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
- `image`
- `engine`
- `language`

Game paths must point to real public pages. Keep game lists and game footer
links data-driven instead of duplicating them in templates. Optional debris
effects use `effect: true` with a tracked root-relative `debris.path`; a
positive `debris.scale` is optional. Disabled effects may retain placeholder
debris metadata, but the referenced asset must exist before enabling the effect.

Department records in `_data/departments.yml` require:

- `name`
- `path`
- `staff_department`
- `bio`

Department paths must point to real public pages. `staff_department` must
match the `department` value used by the corresponding staff records. Keep the
department overview, detail pages, team listings, and footer links data-driven.
Department detail pages must reuse the `department` layout, and every
department in the data file must have a detail page.

Keys in `_data/staff.yml` are stable author identifiers used by articles. Do
not rename them without updating every article reference. Staff shown on the
staff page or department pages use `aboutpage: true` and require `name`, `pfp`,
`role`, and `bio`; `socials` is optional. Do not expose placeholder or private
staff records with `aboutpage: false`. When a department has no public staff
profiles, preserve the explicit empty-team state. Local image paths must be
root-relative and point to tracked files.

Articles should use valid staff keys for `author`, retain stable filenames and
URLs, and provide the front matter required by their layout. Reuse
`_includes/article-card.html` for article listings and preserve the empty-news
state.

Shared server and external-link values belong in `_data/site.yml`. Templates
and JavaScript-facing data attributes must render those values instead of
duplicating literal URLs or the server address.

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

## Agent info
You are a coding assistant. Always respond with only the final code and a brief, necessary explanation. Never include your internal reasoning, chain-of-thought, or planning steps. Be direct.
