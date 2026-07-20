# PWindows Website

The public website for PWindows, built with Jekyll and deployed from the `main` branch.

## Local development

```sh
bundle install
bundle exec jekyll serve
```

Open `http://localhost:4000`. Before submitting a change, run the same checks used by CI:

```sh
bundle exec jekyll build
bundle exec htmlproofer ./_site --disable-external --ignore-urls '/minecraft:/'
bundle exec ruby tools/verify-site.rb ./_site
```

## Project structure

- `index.html` is the homepage.
- `pages/` contains regular public pages. Each page must define an explicit `permalink` so moving its source does not change its public URL.
- `pages/sitemap.html` automatically lists titled public pages, game data, and published news articles. The footer links to this readable page; `sitemap.xml` remains available for search engines.
- `_articles/` contains news posts rendered by the `articles` collection.
- `_layouts/` and `_includes/` contain shared page structure and components.
- `_data/staff.yml`, `_data/games.yml`, `_data/departments.yml`, and `_data/site.yml` contain reusable staff, game, department, server, and shared-link information.
- `assets/` contains production styles, scripts, images, icons, and the retained font library.
- `tools/` contains local utilities and is excluded from the generated site.

## Content data

Game records require `slug`, `title`, `path`, `status`, `summary`, `image`, `engine`, and `language`. Optional debris effects may retain placeholder metadata while disabled, require a tracked image before being enabled, and may set a positive scale. Staff record keys are stable author IDs used by news articles; each visible profile uses `name`, `pfp`, `role`, `bio`, optional `socials`, and `aboutpage: true`.

All font files and specimen pages under `assets/mojang/fonts/` are retained for future use. Only the three fonts referenced by production CSS and the font license are published; unused formats and specimen files are excluded from deployment.

## Activity
![Alt](https://repobeats.axiom.co/api/embed/3d627adb527aaf7280944a459c84a220a43c76a4.svg "Repobeats analytics image")
