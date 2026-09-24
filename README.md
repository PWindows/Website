# PWindows Website

The source for the public [PWindows website](https://www.pwindows.qzz.io), built with Jekyll and hosted with GitHub Pages.

## Documentation

Detailed setup, editing, testing, and deployment instructions are available in the [project wiki](https://github.com/PWindows/Website/wiki).

- [Getting started](https://github.com/PWindows/Website/wiki/Getting-Started)
- [Editing pages](https://github.com/PWindows/Website/wiki/Creating-and-Editing-Pages)
- [Managing site data](https://github.com/PWindows/Website/wiki/Managing-Site-Data)
- [Running checks](https://github.com/PWindows/Website/wiki/Running-Checks)

## Quick preview

### Linux/Mac
```sh
git clone https://github.com/PWindows/Website.git
cd Website
bundle install
bundle exec jekyll serve --livereload
```

### Windows
```sh
bundle install
bundle exec jekyll serve --livereload --config _config.yml,_config.windows.yml
```

Open <http://localhost:4000>. See [Local Setup](https://github.com/PWindows/Website/wiki/Local-Setup) for requirements and troubleshooting.

## Shared theme and verification

Layouts, navigation, common styles, and interface translations come from the pinned `pwindows-theme` Git dependency. Website content and localized game, department, and staff records stay in this repository. Substantive content may fall back to English with an explicit language annotation.

Run the Jekyll build, HTMLProofer, `tools/verify-site.rb`, `tools/verify-localization.rb`, and `tools/tests/flip-cards-test.js` before review. Browser setup and execution are documented in `AGENTS.md`. Theme changes must be tested against both consumers, then pinned in Website's lockfile and Shop's Gemfile and lockfile.

Pull requests validate only. Successful `main` and `redesign` builds can publish to GitHub Pages. Support and feedback use the community Discord; server and checkout launch features remain disabled.

## Contributing

Read [CONTRIBUTING.md](.github/CONTRIBUTING.md) before submitting a change. The wiki also provides a step-by-step [pull request guide](https://github.com/PWindows/Website/wiki/Making-a-Pull-Request).

## Activity

![Repository activity](https://repobeats.axiom.co/api/embed/3d627adb527aaf7280944a459c84a220a43c76a4.svg "Repobeats analytics image")
