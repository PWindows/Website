# frozen_string_literal: true

require "date"
require "json"
require "nokogiri"
require "set"
require "uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
DESTINATION = File.expand_path(ARGV.fetch(0, "_site"), ROOT)
SITE_CONFIG = YAML.safe_load_file(File.join(ROOT, "_config.yml"))
SITE_URL = SITE_CONFIG.fetch("url", "").to_s.delete_suffix("/")
LANGUAGES = SITE_CONFIG.fetch("languages")
DEFAULT_LANG = SITE_CONFIG.fetch("default_lang")
SITE_META = YAML.safe_load_file(File.join(ROOT, "_data", "site_meta.yml"))

PUBLIC_ROUTES = %w[
  /
  /404.html
  /about
  /articles
  /contact
  /departments/
  /departments/minecraft
  /departments/roblox
  /departments/unity
  /feedback
  /games
  /games/obby-of-dominance
  /games/sacred-cubes
  /games/sacred-remains
  /rules
  /sitemap
  /staff
  /staff/petermazep
  /staff/isaacaxolotl
].freeze

NOINDEX_ROUTES = Set.new(%w[/404.html /games/sacred-cubes]).freeze

ROUTE_IDS = {
  "/" => "home",
  "/404.html" => "not-found",
  "/about" => "about",
  "/articles" => "news",
  "/contact" => "contact",
  "/departments/" => "departments",
  "/departments/minecraft" => "mcd",
  "/departments/roblox" => "rd",
  "/departments/unity" => "ud",
  "/feedback" => "feedback",
  "/games" => "games",
  "/games/obby-of-dominance" => "ood",
  "/games/sacred-cubes" => "sacred-cubes-compat",
  "/games/sacred-remains" => "sr",
  "/rules" => "rules",
  "/sitemap" => "sitemap",
  "/staff" => "staff",
  "/staff/petermazep" => "staff-petermazep",
  "/staff/isaacaxolotl" => "staff-isaacaxolotl"
}.freeze

PRODUCTION_FONT_FILES = Set.new(%w[
  LICENSE_OFL.txt
  Minecraft-Seven_v2.woff
  Minecraft-Tenv2.woff2
  NotoSans-Regular.woff2
  Minecraft-TwentyOne.ttf
]).freeze

PRODUCTION_ALIBABA_FONTS = Set.new(%w[
  AlibabaPuHuiTi-3-115-Black/AlibabaPuHuiTi-3-115-Black.woff2
  AlibabaPuHuiTi-3-55-Regular/AlibabaPuHuiTi-3-55-Regular.woff2
]).freeze

RTL_LANGUAGES = Set.new(%w[ar-sa he-il]).freeze
FALLBACK_ROUTES = Set.new(%w[
  /articles
  /departments/
  /departments/minecraft
  /departments/roblox
  /departments/unity
  /games
  /games/obby-of-dominance
  /games/sacred-cubes
  /games/sacred-remains
  /rules
  /sitemap
  /staff
  /staff/isaacaxolotl
  /staff/petermazep
]).freeze

def generated_page_path(path)
  route = path.to_s.delete_prefix("/")
  relative_file = if route.empty?
                    "index.html"
                  elsif route.end_with?("/")
                    File.join(route, "index.html")
                  elsif File.extname(route).empty?
                    "#{route}.html"
                  else
                    route
                  end

  File.join(DESTINATION, relative_file)
end

def localized_route(route, lang)
  return route if lang == DEFAULT_LANG

  "/#{lang}#{route == "/" ? "/" : route}"
end

def front_matter(path)
  match = File.read(path).match(/\A---\s*\n(.*?)\n---\s*\n/m)
  return {} unless match

  YAML.safe_load(
    match[1],
    permitted_classes: [Date, Time],
    aliases: true
  ) || {}
rescue Psych::SyntaxError => error
  { "__error__" => error.message }
end

def generated_asset_path(value)
  return unless value.is_a?(String) && value.start_with?("/")

  File.join(DESTINATION, value.delete_prefix("/"))
end

def positive_number?(value)
  Float(value).positive?
rescue ArgumentError, TypeError
  false
end

def verify_generated_page(route, lang, errors)
  file = generated_page_path(route)
  unless File.file?(file)
    errors << "Missing generated route #{route} (#{file.delete_prefix("#{DESTINATION}/")})"
    return
  end

  document = Nokogiri::HTML5(File.read(file))
  html = document.at_css("html")
  errors << "#{route} has an unexpected document language" unless html&.[]("lang") == lang
  expected_direction = RTL_LANGUAGES.include?(lang) ? "rtl" : "ltr"
  errors << "#{route} has an unexpected text direction" unless html&.[]("dir") == expected_direction
  main = document.at_css("main")
  errors << "#{route} has an empty <main>" if main.nil? || main.text.strip.empty?
  errors << "#{route} must contain exactly one <h1>" unless document.css("main h1").length == 1
  errors << "#{route} is missing a document title" if document.at_css("title")&.text.to_s.strip.empty?
  if document.at_css('meta[name="description"]')&.[]("content").to_s.strip.empty?
    errors << "#{route} is missing a meta description"
  end

  expected_canonical = "#{SITE_URL}#{route == "/" ? "/" : route}"
  canonicals = document.css('link[rel="canonical"]')
  errors << "#{route} must contain exactly one canonical link" unless canonicals.length == 1
  canonical = canonicals.first&.[]("href")
  errors << "#{route} has an unexpected canonical URL: #{canonical.inspect}" unless canonical == expected_canonical

  base_route = lang == DEFAULT_LANG ? route : route.delete_prefix("/#{lang}")
  base_route = "/" if base_route.empty?
  expected_alternates = LANGUAGES.to_h do |alternate_lang|
    alternate_route = localized_route(base_route, alternate_lang)
    [alternate_lang, "#{SITE_URL}#{alternate_route == "/" ? "/" : alternate_route}"]
  end
  expected_alternates["x-default"] = "#{SITE_URL}#{base_route == "/" ? "/" : base_route}"
  alternate_nodes = document.css('link[rel="alternate"][hreflang]')
  alternate_values = alternate_nodes.group_by { |node| node["hreflang"] }
  expected_alternates.each do |alternate_lang, expected_url|
    nodes = alternate_values.fetch(alternate_lang, [])
    errors << "#{route} must contain exactly one #{alternate_lang} alternate" unless nodes.length == 1
    if nodes.first && nodes.first["href"] != expected_url
      errors << "#{route} has an unexpected #{alternate_lang} alternate: #{nodes.first['href'].inspect}"
    end
  end
  unexpected_alternates = alternate_values.keys.compact - expected_alternates.keys
  errors << "#{route} has unsupported alternates: #{unexpected_alternates.join(', ')}" unless unexpected_alternates.empty?

  route_id = ROUTE_IDS[base_route]
  localized_meta = SITE_META[lang] || SITE_META[DEFAULT_LANG]
  expected_description = localized_meta.dig("descriptions", route_id) if route_id
  actual_description = document.at_css('meta[name="description"]')&.[]("content")
  if expected_description && actual_description != expected_description
    errors << "#{route} does not use its localized metadata description"
  end

  document.css("img").each do |image|
    unless positive_number?(image["width"]) && positive_number?(image["height"])
      errors << "#{route} image lacks positive intrinsic dimensions: #{image['src'].inspect}"
    end
  end

  if NOINDEX_ROUTES.include?(base_route)
    robots = document.at_css('meta[name="robots"]')&.[]("content").to_s.downcase.delete(" ")
    errors << "#{route} must be noindex,follow" unless robots == "noindex,follow"
  end

  document.css('script[type="application/ld+json"]').each do |node|
    JSON.parse(node.text)
  rescue JSON::ParserError => error
    errors << "#{route} has invalid JSON-LD: #{error.message}"
  end

  if lang != DEFAULT_LANG && !%w[zh-cn ja-jp].include?(lang) && FALLBACK_ROUTES.include?(base_route)
    unless document.at_css("[data-english-fallback]")
      errors << "#{route} is missing its explicit English fallback notice"
    end
  end
end

errors = []

errors << "default_lang must be included in languages" unless LANGUAGES.include?(DEFAULT_LANG)
errors << "The first configured language must be default_lang" unless LANGUAGES.first == DEFAULT_LANG
unless SITE_CONFIG.fetch("exclude_from_localization", []).include?("sitemap.xml")
  errors << "sitemap.xml must be excluded from localization"
end
errors << "The default language must not generate a prefixed directory" if Dir.exist?(File.join(DESTINATION, DEFAULT_LANG))
LANGUAGES.reject { |lang| lang == DEFAULT_LANG }.each do |lang|
  if File.exist?(File.join(DESTINATION, lang, "sitemap.xml"))
    errors << "Only the root sitemap.xml should be generated"
  end
end

default_page_file = generated_page_path("/")
if File.file?(default_page_file)
  default_page = Nokogiri::HTML5(File.read(default_page_file))
  language_options = default_page.css("[data-language-select] option").group_by { |option| option["lang"] }
  LANGUAGES.each do |lang|
    options = language_options.fetch(lang, [])
    errors << "Language #{lang} is missing from the language selector" if options.empty?
    errors << "Language #{lang} appears more than once in the language selector" if options.length > 1
    errors << "Language #{lang} is missing a display label" if options.first&.text.to_s.strip.empty?
  end

  unexpected_languages = language_options.keys.compact - LANGUAGES
  unless unexpected_languages.empty?
    errors << "Language selector contains unsupported languages: #{unexpected_languages.join(', ')}"
  end
end

begin
  site_uri = URI.parse(SITE_URL)
  errors << "_config.yml url must be an absolute HTTPS URL" unless site_uri.is_a?(URI::HTTPS) && site_uri.host
rescue URI::InvalidURIError
  errors << "_config.yml url is invalid: #{SITE_URL.inspect}"
end

site_data_path = File.join(ROOT, "_data", "site.yml")
if File.file?(site_data_path)
  site_data = YAML.safe_load_file(site_data_path)
  server_addresses = site_data.dig("server", "address")
  if server_addresses.is_a?(Hash)
    default_server_address = server_addresses[DEFAULT_LANG].to_s
    errors << "Site data is missing server.address.#{DEFAULT_LANG}" if default_server_address.empty?
    server_addresses.each do |lang, value|
      errors << "Site data has an unsupported server language: #{lang}" unless LANGUAGES.include?(lang)
      server_address = value.to_s
      errors << "Site data has an empty server.address.#{lang}" if server_address.empty?
      unless server_address.match?(/\A[a-z0-9.-]+\z/i)
        errors << "Site server.address.#{lang} is invalid: #{server_address.inspect}"
      end
    end
  else
    errors << "Site data is missing server.address"
  end

  %w[support shop discord youtube twitter].each do |name|
    value = site_data.dig("links", name).to_s
    if value.empty?
      errors << "Site data is missing links.#{name}"
      next
    end

    begin
      uri = URI.parse(value)
      errors << "Site link #{name} must use HTTPS: #{value.inspect}" unless uri.is_a?(URI::HTTPS) && uri.host
    rescue URI::InvalidURIError
      errors << "Site link #{name} is invalid: #{value.inspect}"
    end
  end
  unless site_data.dig("links", "support") == site_data.dig("links", "discord")
    errors << "Support must use the working Discord fallback"
  end
else
  errors << "Missing _data/site.yml"
end

sitemap_file = File.join(DESTINATION, "sitemap.xml")
article_locations = []
if File.file?(sitemap_file)
  sitemap = Nokogiri::XML(File.read(sitemap_file))
  locations = sitemap.xpath("//*[local-name()='loc']").filter_map do |node|
    URI.parse(node.text).path
  rescue URI::InvalidURIError
    errors << "Sitemap contains an invalid location: #{node.text.inspect}"
    nil
  end
  errors << "Sitemap contains duplicate locations" unless locations.length == locations.uniq.length

  expected_pages = LANGUAGES.each_with_object(Set.new) do |lang, routes|
    (PUBLIC_ROUTES - NOINDEX_ROUTES.to_a).each { |route| routes << localized_route(route, lang) }
  end
  article_prefixes = LANGUAGES.map do |lang|
    lang == DEFAULT_LANG ? "/article/" : "/#{lang}/article/"
  end
  article_locations = locations.select do |path|
    article_prefixes.any? { |prefix| path.start_with?(prefix) }
  end
  unexpected = locations.reject do |path|
    expected_pages.include?(path) || article_prefixes.any? { |prefix| path.start_with?(prefix) }
  end
  missing = expected_pages - locations.to_set
  errors << "Unexpected sitemap locations: #{unexpected.join(', ')}" unless unexpected.empty?
  errors << "Missing sitemap locations: #{missing.to_a.join(', ')}" unless missing.empty?
else
  errors << "Missing generated sitemap.xml"
end

LANGUAGES.each do |lang|
  PUBLIC_ROUTES.each do |route|
    verify_generated_page(localized_route(route, lang), lang, errors)
  end
end
article_locations.each do |route|
  lang = LANGUAGES.find { |candidate| route.start_with?("/#{candidate}/") } || DEFAULT_LANG
  verify_generated_page(route, lang, errors)
end

human_sitemap_file = File.join(DESTINATION, "sitemap.html")
if File.file?(human_sitemap_file)
  human_sitemap = Nokogiri::HTML5(File.read(human_sitemap_file))
  human_links = human_sitemap.css("main a[href]").map { |link| URI(link["href"]).path }.to_set
  default_article_locations = article_locations.select { |path| path.start_with?("/article/") }
  expected_human_links = (PUBLIC_ROUTES.to_set - NOINDEX_ROUTES - ["/sitemap"]) | default_article_locations.to_set
  missing_human_links = expected_human_links - human_links
  unless missing_human_links.empty?
    errors << "Human-readable site map is missing: #{missing_human_links.to_a.join(', ')}"
  end

  footer_links = human_sitemap.css(".footer a[href]").map { |link| URI(link["href"]).path }
  errors << "Footer must link to /sitemap" unless footer_links.include?("/sitemap")
  errors << "Footer still exposes sitemap.xml" if footer_links.include?("/sitemap.xml")
else
  errors << "Missing generated sitemap.html"
end

forbidden_outputs = [
  File.join(DESTINATION, "AGENTS.md"),
  File.join(DESTINATION, "README.md"),
  File.join(DESTINATION, "tools"),
  File.join(DESTINATION, "assets", "extra")
]
forbidden_outputs.each do |path|
  errors << "Excluded source was published: #{path.delete_prefix("#{DESTINATION}/")}" if File.exist?(path)
end

font_output_directory = File.join(DESTINATION, "assets", "mojang", "fonts")
published_fonts = if Dir.exist?(font_output_directory)
                    Dir.children(font_output_directory).to_set
                  else
                    Set.new
                  end
missing_fonts = PRODUCTION_FONT_FILES - published_fonts
unexpected_fonts = published_fonts - PRODUCTION_FONT_FILES
errors << "Missing production font files: #{missing_fonts.to_a.sort.join(', ')}" unless missing_fonts.empty?
errors << "Unused font files were published: #{unexpected_fonts.to_a.sort.join(', ')}" unless unexpected_fonts.empty?

alibaba_directory = File.join(DESTINATION, "assets", "fonts")
published_alibaba_fonts = if Dir.exist?(alibaba_directory)
                            Dir.glob(File.join(alibaba_directory, "**", "*")).select { |path| File.file?(path) }
                              .map { |path| path.delete_prefix("#{alibaba_directory}/") }.to_set
                          else
                            Set.new
                          end
missing_alibaba_fonts = PRODUCTION_ALIBABA_FONTS - published_alibaba_fonts
unexpected_alibaba_fonts = published_alibaba_fonts - PRODUCTION_ALIBABA_FONTS
errors << "Missing production Alibaba fonts: #{missing_alibaba_fonts.to_a.sort.join(', ')}" unless missing_alibaba_fonts.empty?
errors << "Unused Alibaba fonts were published: #{unexpected_alibaba_fonts.to_a.sort.join(', ')}" unless unexpected_alibaba_fonts.empty?

manifest_path = File.join(DESTINATION, "assets", "manifest.json")
if File.file?(manifest_path)
  manifest_text = File.read(manifest_path)
  errors << "Manifest contains unresolved Liquid" if manifest_text.include?("{{") || manifest_text.include?("{%")
  begin
    manifest = JSON.parse(manifest_text)
    errors << "Manifest start_url must resolve to /" unless manifest["start_url"] == "/"
    Array(manifest["icons"]).each do |icon|
      icon_path = generated_asset_path(icon["src"])
      errors << "Manifest icon is missing: #{icon['src']}" unless icon_path && File.file?(icon_path)
    end
  rescue JSON::ParserError => error
    errors << "Manifest is invalid JSON: #{error.message}"
  end
else
  errors << "Missing generated assets/manifest.json"
end

text_extensions = Set.new(%w[.css .html .js .json .md .txt .xml])
Dir.glob(File.join(DESTINATION, "**", "*")).select { |path| File.file?(path) && text_extensions.include?(File.extname(path)) }.each do |path|
  content = File.read(path)

  relative = path.delete_prefix("#{DESTINATION}/")
  errors << "Unresolved Liquid was published in #{relative}" if content.include?("{{") || content.include?("{%")
  errors << "Conflict marker was published in #{relative}" if content.match?(/^(?:<<<<<<<|=======|>>>>>>>)/)
end

games = YAML.safe_load_file(File.join(ROOT, "_data", "games.yml"))
game_slugs = games.map { |game| game["slug"] }
game_paths = games.map { |game| game["path"] }
errors << "Game slugs must be unique" unless game_slugs.length == game_slugs.uniq.length
errors << "Game paths must be unique" unless game_paths.length == game_paths.uniq.length

games.each do |game|
  identifier = game["slug"] || "(unknown)"
  %w[slug path status image engine language].each do |field|
    errors << "Game #{identifier} is missing #{field}" if game[field].to_s.strip.empty?
  end
  %w[title summary].each do |field|
    if game.dig(DEFAULT_LANG, field).to_s.strip.empty?
      errors << "Game #{identifier} is missing fallback #{DEFAULT_LANG}.#{field}"
    end
  end
  errors << "Game #{identifier} points to a missing page" unless File.file?(generated_page_path(game["path"]))

  image = generated_asset_path(game["image"])
  errors << "Game #{identifier} image must be root-relative" unless image
  errors << "Game #{identifier} references a missing image" if image && !File.file?(image)
  errors << "Game #{identifier} image width must be positive" unless positive_number?(game["image_width"])
  errors << "Game #{identifier} image height must be positive" unless positive_number?(game["image_height"])
  errors << "Game #{identifier} effect must be true or false" unless [true, false].include?(game["effect"])

  debris = game["debris"]
  if debris
    if debris.is_a?(Hash)
      debris_image = generated_asset_path(debris["path"])
      errors << "Game #{identifier} debris.path must be root-relative" unless debris_image
      if game["effect"] && debris_image && !File.file?(debris_image)
        errors << "Game #{identifier} references missing debris"
      end
      if game["effect"]
        errors << "Game #{identifier} debris width must be positive" unless positive_number?(debris["width"])
        errors << "Game #{identifier} debris height must be positive" unless positive_number?(debris["height"])
      end
      if debris.key?("scale") && !positive_number?(debris["scale"])
        errors << "Game #{identifier} debris.scale must be positive"
      end
    else
      errors << "Game #{identifier} debris must be a mapping"
    end
  elsif game["effect"]
    errors << "Game #{identifier} must define debris when effect is enabled"
  end
end

departments = YAML.safe_load_file(File.join(ROOT, "_data", "departments.yml"))
department_paths = departments.values.map { |department| department["path"] }
staff_departments = departments.values.map { |department| department["staff_department"] }
errors << "Department paths must be unique" unless department_paths.length == department_paths.uniq.length
errors << "Department staff_department values must be unique" unless staff_departments.length == staff_departments.uniq.length

department_sources = Dir[File.join(ROOT, "pages", "departments", "*.{md,markdown,html}")].to_h do |path|
  metadata = front_matter(path)
  [metadata["department"], [path, metadata]]
end

departments.each do |key, department|
  %w[path staff_department].each do |field|
    errors << "Department #{key} is missing #{field}" if department[field].to_s.strip.empty?
  end
  %w[name bio].each do |field|
    if department.dig(DEFAULT_LANG, field).to_s.strip.empty?
      errors << "Department #{key} is missing fallback #{DEFAULT_LANG}.#{field}"
    end
  end
  errors << "Department #{key} points to a missing page" unless File.file?(generated_page_path(department["path"]))

  source_path, metadata = department_sources[key]
  if source_path.nil?
    errors << "Department #{key} is missing a department source page"
  else
    errors << "Department #{key} page must use the department layout" unless metadata["layout"] == "department"
    errors << "Department #{key} page permalink must match its data path" unless metadata["permalink"] == department["path"]
  end
end

unknown_department_pages = department_sources.keys.compact - departments.keys
unless unknown_department_pages.empty?
  errors << "Department pages reference unknown keys: #{unknown_department_pages.join(', ')}"
end

staff = YAML.safe_load_file(File.join(ROOT, "_data", "staff.yml"))
staff.each do |key, person|
  next unless person["aboutpage"]

  %w[pfp path].each do |field|
    errors << "Staff member #{key} is missing #{field}" if person[field].to_s.strip.empty?
  end
  %w[name role bio].each do |field|
    if person.dig(DEFAULT_LANG, field).to_s.strip.empty?
      errors << "Staff member #{key} is missing fallback #{DEFAULT_LANG}.#{field}"
    end
  end
  image = generated_asset_path(person["pfp"])
  errors << "Staff member #{key} pfp must be root-relative" unless image
  errors << "Staff member #{key} references a missing image" if image && !File.file?(image)
end

article_sources = Dir[File.join(ROOT, "_articles", "**", "*.{md,markdown,html}")]
article_slugs = article_sources.map do |path|
  File.basename(path, File.extname(path))
end.uniq
expected_article_locations = LANGUAGES.each_with_object(Set.new) do |lang, locations|
  article_slugs.each do |slug|
    locations << localized_route("/article/#{slug}", lang)
  end
end.to_set
actual_article_locations = article_locations.to_set
errors << "Sitemap article URLs do not match _articles" unless actual_article_locations == expected_article_locations

article_sources.each do |path|
  metadata = front_matter(path)
  identifier = File.basename(path)
  if metadata["__error__"]
    errors << "Article #{identifier} has invalid front matter: #{metadata['__error__']}"
    next
  end

  %w[layout title date author banner summary type].each do |field|
    errors << "Article #{identifier} is missing #{field}" if metadata[field].to_s.strip.empty?
  end
  errors << "Article #{identifier} has an unsupported language" unless LANGUAGES.include?(metadata["lang"])
  source_lang = File.basename(File.dirname(path))
  errors << "Article #{identifier} language does not match its directory" unless metadata["lang"] == source_lang
  errors << "Article #{identifier} must use the news layout" unless metadata["layout"] == "news"
  errors << "Article #{identifier} references an unknown author" unless staff.key?(metadata["author"])
  if identifier == "website-redesign-2026-06-16.md" && metadata["date"].to_s != "2026-06-16"
    errors << "Article #{identifier} date must match its stable filename"
  end

  banner = generated_asset_path(metadata["banner"])
  errors << "Article #{identifier} banner must be root-relative" unless banner
  errors << "Article #{identifier} references a missing banner" if banner && !File.file?(banner)
end

root_markers = Dir[File.join(ROOT, "*.txt")]
errors << "Unexpected root development markers: #{root_markers.map { |path| File.basename(path) }.join(', ')}" unless root_markers.empty?

source_pngs = %w[sacred-remains.png sacred-remains-debris.png]
source_pngs.each do |filename|
  path = File.join(ROOT, "assets", "extra", "img", filename)
  errors << "Missing retained Sacred Remains source asset: #{filename}" unless File.file?(path)
end
%w[sacred-remains.webp sacred-remains-debris.webp obby-of-dominance.png].each do |filename|
  path = File.join(DESTINATION, "assets", "img", filename)
  errors << "Missing Website-owned production game asset: #{filename}" unless File.file?(path)
end

gemfile = File.read(File.join(ROOT, "Gemfile"))
unless gemfile.match?(/gem "pwindows-theme".*branch: "main"/)
  errors << "Gemfile must use the shared theme's main branch"
end
errors << "Theme dependency URL must not contain credentials" if gemfile.match?(%r{https://[^/\s]+@github\.com})

workflow_files = Dir[File.join(ROOT, ".github", "workflows", "*.yml")]
workflow_files.each do |path|
  workflow = File.read(path)
  errors << "#{File.basename(path)} must use Ruby 3.4.10" unless workflow.include?("3.4.10")
  errors << "#{File.basename(path)} must not update dependencies" if workflow.include?("bundle update")
end

deployment_workflow = File.read(File.join(ROOT, ".github", "workflows", "gh-jekyll-workflow.yml"))
unless deployment_workflow.match?(/branches:\s*\[[^\]]*main[^\]]*redesign[^\]]*\]/)
  errors << "Deployment workflow must publish main and redesign"
end
required_deployment_checks = [
  "bundle exec jekyll build --trace",
  "bundle exec htmlproofer ./_site",
  "bundle exec ruby tools/verify-site.rb ./_site",
  "node --check assets/js/extra.js"
]
missing_deployment_checks = required_deployment_checks.reject { |check| deployment_workflow.include?(check) }
unless missing_deployment_checks.empty?
  errors << "Deployment workflow is missing checks: #{missing_deployment_checks.join(', ')}"
end
unless deployment_workflow.include?("needs: build") && deployment_workflow.include?("if: ${{ needs.build.result == 'success' }}")
  errors << "Deployment must require a successful build job"
end

checks_workflow = File.read(File.join(ROOT, ".github", "workflows", "site-checks.yml"))
unless checks_workflow.match?(/branches:\s*\[[^\]]*main[^\]]*redesign[^\]]*\]/)
  errors << "Site checks must run on main and redesign"
end

if File.file?(default_page_file)
  default_page = Nokogiri::HTML5(File.read(default_page_file))
  shop_link = default_page.at_css(%{a[href="https://shop.pwindows.qzz.io"]})
  errors << "Website footer is missing the canonical Shop cross-link" unless shop_link
end

if errors.empty?
  puts "Site verification passed."
else
  warn errors.map { |error| "- #{error}" }.join("\n")
  exit 1
end
