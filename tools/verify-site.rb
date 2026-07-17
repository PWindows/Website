# frozen_string_literal: true

require "nokogiri"
require "set"
require "uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
DESTINATION = File.expand_path(ARGV.fetch(0, "_site"), ROOT)
SITE_URL = "https://www.pwindows.qzz.io"

PUBLIC_ROUTES = {
  "/" => "index.html",
  "/404.html" => "404.html",
  "/about" => "about.html",
  "/articles" => "articles.html",
  "/contact" => "contact.html",
  "/feedback" => "feedback.html",
  "/games" => "games.html",
  "/games/obby-of-dominance" => "games/obby-of-dominance.html",
  "/games/sacred-cubes" => "games/sacred-cubes.html",
  "/rules" => "rules.html",
  "/sitemap" => "sitemap.html",
  "/staff" => "staff.html"
}.freeze

errors = []

PUBLIC_ROUTES.each do |route, relative_file|
  file = File.join(DESTINATION, relative_file)
  unless File.file?(file)
    errors << "Missing generated route #{route} (#{relative_file})"
    next
  end

  document = Nokogiri::HTML5(File.read(file))
  main = document.at_css("main")
  errors << "#{route} has an empty <main>" if main.nil? || main.text.strip.empty?
  errors << "#{route} must contain exactly one <h1>" unless document.css("main h1").length == 1
  errors << "#{route} is missing a document title" if document.at_css("title")&.text.to_s.strip.empty?
  errors << "#{route} is missing a meta description" if document.at_css('meta[name="description"]')&.[]("content").to_s.strip.empty?

  expected_canonical = "#{SITE_URL}#{route == "/" ? "/" : route}"
  canonical = document.at_css('link[rel="canonical"]')&.[]("href")
  errors << "#{route} has an unexpected canonical URL: #{canonical.inspect}" unless canonical == expected_canonical
end

sitemap_file = File.join(DESTINATION, "sitemap.xml")
article_locations = []
if File.file?(sitemap_file)
  sitemap = Nokogiri::XML(File.read(sitemap_file))
  locations = sitemap.xpath("//*[local-name()='loc']").map { |node| URI(node.text).path }
  errors << "Sitemap contains duplicate locations" unless locations.length == locations.uniq.length

  expected_pages = PUBLIC_ROUTES.keys.to_set - ["/404.html"]
  article_locations = locations.select { |path| path.start_with?("/article/") }
  source_article_count = Dir[File.join(ROOT, "_articles", "*.{md,markdown,html}")].length
  errors << "Sitemap article count does not match _articles" unless article_locations.length == source_article_count

  unexpected = locations.reject { |path| expected_pages.include?(path) || path.start_with?("/article/") }
  missing = expected_pages - locations.to_set
  errors << "Unexpected sitemap locations: #{unexpected.join(', ')}" unless unexpected.empty?
  errors << "Missing sitemap locations: #{missing.to_a.join(', ')}" unless missing.empty?
else
  errors << "Missing generated sitemap.xml"
end

human_sitemap_file = File.join(DESTINATION, "sitemap.html")
if File.file?(human_sitemap_file)
  human_sitemap = Nokogiri::HTML5(File.read(human_sitemap_file))
  human_links = human_sitemap.css("main a[href]").map { |link| URI(link["href"]).path }.to_set
  expected_human_links = (PUBLIC_ROUTES.keys.to_set - ["/404.html", "/sitemap"]) | article_locations.to_set
  missing_human_links = expected_human_links - human_links
  errors << "Human-readable site map is missing: #{missing_human_links.to_a.join(', ')}" unless missing_human_links.empty?

  footer_links = human_sitemap.css(".footer a[href]").map { |link| URI(link["href"]).path }
  errors << "Footer must link to /sitemap" unless footer_links.include?("/sitemap")
  errors << "Footer still exposes sitemap.xml" if footer_links.include?("/sitemap.xml")
else
  errors << "Missing generated sitemap.html"
end

forbidden_outputs = [
  File.join(DESTINATION, "README.md"),
  File.join(DESTINATION, "tools")
]
forbidden_outputs.each do |path|
  errors << "Excluded source was published: #{path.delete_prefix("#{DESTINATION}/")}" if File.exist?(path)
end

font_specimens = Dir[File.join(DESTINATION, "assets", "mojang", "fonts", "*.html")]
errors << "Font specimen HTML was published" unless font_specimens.empty?

font_sources = Dir[File.join(ROOT, "assets", "mojang", "fonts", "*.{eot,otf,svg,ttf,woff,woff2}")]
errors << "The retained font library is missing" if font_sources.empty?

games = YAML.safe_load_file(File.join(ROOT, "_data", "games.yml"))
games.each do |game|
  %w[slug title path status summary].each do |field|
    errors << "Game #{game['slug'] || '(unknown)'} is missing #{field}" if game[field].to_s.strip.empty?
  end
  output = File.join(DESTINATION, "#{game['path'].delete_prefix('/')}.html")
  errors << "Game #{game['slug']} points to a missing page" unless File.file?(output)
end

staff = YAML.safe_load_file(File.join(ROOT, "_data", "staff.yml"))
staff.each do |key, person|
  next unless person["aboutpage"]

  %w[name pfp role bio].each do |field|
    errors << "Staff member #{key} is missing #{field}" if person[field].to_s.strip.empty?
  end
  image = File.join(ROOT, person["pfp"].to_s.delete_prefix("/"))
  errors << "Staff member #{key} references a missing image" unless File.file?(image)
end

if errors.empty?
  puts "Site verification passed."
else
  warn errors.map { |error| "- #{error}" }.join("\n")
  exit 1
end
