# frozen_string_literal: true

require "date"
require "nokogiri"
require "set"
require "uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
DESTINATION = File.expand_path(ARGV.fetch(0, "_site"), ROOT)
SITE_CONFIG = YAML.safe_load_file(File.join(ROOT, "_config.yml"))
SITE_URL = SITE_CONFIG.fetch("url", "").to_s.delete_suffix("/")

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
  /rules
  /sitemap
  /staff
].freeze

PRODUCTION_FONT_FILES = Set.new(%w[
  LICENSE_OFL.txt
  Minecraft-Seven_v2.woff
  Minecraft-Tenv2.woff2
  NotoSans-Regular.woff2
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

def local_asset_path(value)
  return unless value.is_a?(String) && value.start_with?("/")

  File.join(ROOT, value.delete_prefix("/"))
end

def positive_number?(value)
  Float(value).positive?
rescue ArgumentError, TypeError
  false
end

def verify_generated_page(route, errors)
  file = generated_page_path(route)
  unless File.file?(file)
    errors << "Missing generated route #{route} (#{file.delete_prefix("#{DESTINATION}/")})"
    return
  end

  document = Nokogiri::HTML5(File.read(file))
  main = document.at_css("main")
  errors << "#{route} has an empty <main>" if main.nil? || main.text.strip.empty?
  errors << "#{route} must contain exactly one <h1>" unless document.css("main h1").length == 1
  errors << "#{route} is missing a document title" if document.at_css("title")&.text.to_s.strip.empty?
  if document.at_css('meta[name="description"]')&.[]("content").to_s.strip.empty?
    errors << "#{route} is missing a meta description"
  end

  expected_canonical = "#{SITE_URL}#{route == "/" ? "/" : route}"
  canonical = document.at_css('link[rel="canonical"]')&.[]("href")
  errors << "#{route} has an unexpected canonical URL: #{canonical.inspect}" unless canonical == expected_canonical
end

errors = []

begin
  site_uri = URI.parse(SITE_URL)
  errors << "_config.yml url must be an absolute HTTPS URL" unless site_uri.is_a?(URI::HTTPS) && site_uri.host
rescue URI::InvalidURIError
  errors << "_config.yml url is invalid: #{SITE_URL.inspect}"
end

site_data_path = File.join(ROOT, "_data", "site.yml")
if File.file?(site_data_path)
  site_data = YAML.safe_load_file(site_data_path)
  server_address = site_data.dig("server", "address").to_s
  errors << "Site data is missing server.address" if server_address.empty?
  errors << "Site server.address is invalid: #{server_address.inspect}" unless server_address.match?(/\A[a-z0-9.-]+\z/i)

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
else
  errors << "Missing _data/site.yml"
end

sitemap_file = File.join(DESTINATION, "sitemap.xml")
article_locations = []
if File.file?(sitemap_file)
  sitemap = Nokogiri::XML(File.read(sitemap_file))
  locations = sitemap.xpath("//*[local-name()='loc']").map { |node| URI(node.text).path }
  errors << "Sitemap contains duplicate locations" unless locations.length == locations.uniq.length

  expected_pages = PUBLIC_ROUTES.to_set - ["/404.html"]
  article_locations = locations.select { |path| path.start_with?("/article/") }
  unexpected = locations.reject { |path| expected_pages.include?(path) || path.start_with?("/article/") }
  missing = expected_pages - locations.to_set
  errors << "Unexpected sitemap locations: #{unexpected.join(', ')}" unless unexpected.empty?
  errors << "Missing sitemap locations: #{missing.to_a.join(', ')}" unless missing.empty?
else
  errors << "Missing generated sitemap.xml"
end

(PUBLIC_ROUTES + article_locations).uniq.each do |route|
  verify_generated_page(route, errors)
end

human_sitemap_file = File.join(DESTINATION, "sitemap.html")
if File.file?(human_sitemap_file)
  human_sitemap = Nokogiri::HTML5(File.read(human_sitemap_file))
  human_links = human_sitemap.css("main a[href]").map { |link| URI(link["href"]).path }.to_set
  expected_human_links = (PUBLIC_ROUTES.to_set - ["/404.html", "/sitemap"]) | article_locations.to_set
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
  File.join(DESTINATION, "tools")
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
#errors << "Missing production font files: #{missing_fonts.to_a.sort.join(', ')}" unless missing_fonts.empty?
#errors << "Unused font files were published: #{unexpected_fonts.to_a.sort.join(', ')}" unless unexpected_fonts.empty?

font_sources = Dir[File.join(ROOT, "assets", "mojang", "fonts", "*.{eot,otf,svg,ttf,woff,woff2}")]
#errors << "The retained font library is missing" if font_sources.empty?

games = YAML.safe_load_file(File.join(ROOT, "_data", "games.yml"))
game_slugs = games.map { |game| game["slug"] }
game_paths = games.map { |game| game["path"] }
errors << "Game slugs must be unique" unless game_slugs.length == game_slugs.uniq.length
errors << "Game paths must be unique" unless game_paths.length == game_paths.uniq.length

games.each do |game|
  identifier = game["slug"] || "(unknown)"
  %w[slug title path status summary image engine language].each do |field|
    errors << "Game #{identifier} is missing #{field}" if game[field].to_s.strip.empty?
  end
  errors << "Game #{identifier} points to a missing page" unless File.file?(generated_page_path(game["path"]))

  image = local_asset_path(game["image"])
  errors << "Game #{identifier} image must be root-relative" unless image
  errors << "Game #{identifier} references a missing image" if image && !File.file?(image)
  errors << "Game #{identifier} effect must be true or false" unless [true, false].include?(game["effect"])

  debris = game["debris"]
  if debris
    if debris.is_a?(Hash)
      debris_image = local_asset_path(debris["path"])
      errors << "Game #{identifier} debris.path must be root-relative" unless debris_image
      if game["effect"] && debris_image && !File.file?(debris_image)
        errors << "Game #{identifier} references missing debris"
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
  %w[name path staff_department bio].each do |field|
    errors << "Department #{key} is missing #{field}" if department[field].to_s.strip.empty?
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

  %w[name pfp role bio].each do |field|
    errors << "Staff member #{key} is missing #{field}" if person[field].to_s.strip.empty?
  end
  image = local_asset_path(person["pfp"])
  errors << "Staff member #{key} pfp must be root-relative" unless image
  errors << "Staff member #{key} references a missing image" if image && !File.file?(image)
end

article_sources = Dir[File.join(ROOT, "_articles", "*.{md,markdown,html}")]
expected_article_locations = article_sources.map do |path|
  "/article/#{File.basename(path, File.extname(path))}"
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
  errors << "Article #{identifier} must use the news layout" unless metadata["layout"] == "news"
  errors << "Article #{identifier} references an unknown author" unless staff.key?(metadata["author"])

  banner = local_asset_path(metadata["banner"])
  errors << "Article #{identifier} banner must be root-relative" unless banner
  errors << "Article #{identifier} references a missing banner" if banner && !File.file?(banner)
end

if errors.empty?
  puts "Site verification passed."
else
  warn errors.map { |error| "- #{error}" }.join("\n")
  exit 1
end
