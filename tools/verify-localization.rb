# frozen_string_literal: true

require "date"
require "jekyll"
require "nokogiri"
require "yaml"

Jekyll::PluginManager.require_from_bundler

# Inspect built pages and render the installed theme in memory; never rebuild or
# modify site sources. Bundler's theme resolution also honors local overrides.
class LocalizationVerifier
  UI_KEYS = %w[
    home_heading copy_server join_section copy_server_coming_soon launch_bedrock
    coming_soon copy_success copy_failure copied flip_card_details pause_animation
    resume_animation share_on date_format datetime_format written_by published
    share_story read_more latest_news show_more last_updated profile_picture social_links
  ].freeze
  BODY_LABELS = {
    "copy-success" => "copy_success", "copy-failure" => "copy_failure",
    "copied-label" => "copied", "flip-card-details" => "flip_card_details",
    "pause-animation" => "pause_animation", "resume-animation" => "resume_animation"
  }.freeze

  def initialize(destination)
    @root = File.expand_path("..", __dir__)
    @destination = File.expand_path(destination, @root)
    @site = Jekyll::Site.new(Jekyll.configuration("source" => @root, "quiet" => true))
    @site.prepare
    @site.reset
    @site.read
    @data = @site.data
    @config = @site.config
    @default = @config.fetch("default_lang")
    @languages = @config.fetch("languages")
    @pages = Dir[File.join(@root, "pages", "**", "*.{html,md,markdown}")]
      .map { |path| metadata(path) }.select { |page| page["layout"] && page["permalink"] }
    @articles = Dir[File.join(@root, "_articles", "**", "*.{html,md,markdown}")].map do |path|
      metadata(path).merge("permalink" => "/article/#{File.basename(path, File.extname(path))}")
    end.group_by { |article| article.fetch("permalink") }
    @documents = {}
    @errors = []
  end

  def run
    @languages.each do |locale|
      verify_locale_data(locale)
      articles = localized_articles(locale)
      (@pages + articles).each { |page| verify_metadata(page, locale) }
      verify_home(locale)
      verify_departments(locale)
      verify_staff(locale)
      verify_games(locale)
      verify_rules(locale)
      verify_page_headers(locale)
      verify_sitemap(locale, articles)
      articles.each { |article| verify_article(article, locale) }
    end
    verify_rendered_fixtures
    if @errors.empty?
      puts "Localization verification passed for #{@languages.length} locales (including rendered metadata and author fixtures)."
    else
      warn @errors.map { |error| "- #{error}" }.join("\n")
      exit 1
    end
  end

  private

  def metadata(path)
    front_matter = File.read(path)[/\A---\s*\n(.*?)\n---\s*\n/m, 1]
    front_matter ? YAML.safe_load(front_matter, permitted_classes: [Date, Time], aliases: true) : {}
  end

  def check(condition, message)
    @errors << message unless condition
  end

  def first_value(*values)
    values.find { |value| !value.nil? && value != false && !(value.respond_to?(:empty?) && value.empty?) }
  end

  def localized_path(route, locale)
    locale == @default ? route : "/#{locale}#{route}"
  end

  def document(route, locale)
    path = localized_path(route, locale)
    @documents[path] ||= begin
      relative = path.delete_prefix("/")
      relative = "index.html" if relative.empty?
      relative += "index.html" if relative.end_with?("/")
      relative += ".html" if File.extname(relative).empty?
      filename = File.join(@destination, relative)
      unless File.file?(filename)
        @errors << "Missing localized page #{path}"
        return nil
      end
      parsed = Nokogiri::HTML5(File.read(filename), max_errors: 100)
      parsed.errors.each { |error| @errors << "#{path} HTML parse error: #{error.message.strip}" }
      parsed
    end
  end

  def text_is(node, expected, context)
    check(node && node.text.strip == expected.to_s, "#{context} has unexpected text")
  end

  def language_is(node, expected, context)
    language_node = node && ([node] + node.ancestors.to_a).find { |ancestor| ancestor["lang"] }
    actual = language_node && language_node["lang"]
    check(actual == expected, "#{context} language is #{actual.inspect}, expected #{expected}")
  end

  def localized_field(record, field, locale)
    active_value = record.dig(locale, field)
    first_value(active_value) ? [active_value, locale] : [record.dig(@default, field), @default]
  end

  def field_is(node, record, field, locale, context)
    value, language = localized_field(record, field, locale)
    text_is(node, value, context)
    language_is(node, language, context)
  end

  def ui(locale)
    @data.fetch("ui").fetch(locale, @data.fetch("ui").fetch(@default))
  end

  def translated_site_value(locale, field, id = nil)
    sources = [@data.dig("site_meta", locale), @data.dig("translations", locale, "site"),
               @data.dig("site_meta", @default), @data.dig("translations", @default, "site")]
    first_value(*sources.map { |source| id ? source&.dig(field, id) : source&.[](field) })
  end

  def localized_articles(locale)
    @articles.values.filter_map do |versions|
      versions.find { |article| article["lang"] == locale } || versions.find { |article| article["lang"] == @default }
    end
  end

  def verify_locale_data(locale)
    check(@data.dig("ui", locale).is_a?(Hash), "Missing UI locale #{locale}")
    UI_KEYS.each { |key| check(!ui(locale)[key].to_s.strip.empty?, "Missing #{locale} UI key #{key}") }
    { "copy_success" => "{address}", "copy_failure" => "{address}",
      "flip_card_details" => "{title}", "share_on" => "{platform}" }.each do |key, token|
      check(ui(locale)[key].to_s.scan(token).length == 1, "#{locale} #{key} must contain one #{token} token")
    end
    %w[contact feedback].each do |page|
      key = page == "contact" ? ["support", "text"] : ["send-text"]
      copy = @data.dig("translations", locale, page, *key).to_s
      check(copy.include?("Discord"), "#{locale} #{page} must accurately identify Discord support")
      doc = document("/#{page}", locale)
      check(doc&.at_css("main")&.text&.include?(copy) && !copy.empty?, "#{locale} #{page} does not render its support copy")
    end
  end

  def verify_metadata(page, locale)
    route = page.fetch("permalink")
    doc = document(route, locale)
    return unless doc

    name = first_value(translated_site_value(locale, "name"), @config["title"])
    tagline = first_value(translated_site_value(locale, "tagline"), @config["description"])
    title = if page["layout"] == "news"
              page["title"]
            else
              first_value(translated_site_value(locale, "page_titles", page["id"]), page["title"], @config["title"])
            end
    expected_title = route == "/" ? "#{name} - #{tagline}" : "#{title} | #{name}"
    text_is(doc.at_css("title"), expected_title, "#{locale} #{route} metadata title")
    description = first_value(page["summary"], translated_site_value(locale, "descriptions", page["id"]), page["description"], @config["description"])
    description = Nokogiri::HTML5.fragment(description.to_s).text
    check(doc.at_css('meta[name="description"]')&.[]("content") == description, "#{locale} #{route} description precedence is incorrect")
    check(doc.at_css("main")&.[]("tabindex") == "-1", "#{locale} #{route} skip-link target is not focusable")
    BODY_LABELS.each do |attribute, key|
      check(doc.at_css("body")&.[]("data-#{attribute}") == ui(locale)[key], "#{locale} #{route} runtime label #{attribute} is incorrect")
    end
  end

  def verify_home(locale)
    doc = document("/", locale)
    return unless doc

    text_is(doc.at_css("h1 .sr-only"), ui(locale)["home_heading"], "#{locale} accessible home heading")
    language_is(doc.at_css("h1 .sr-only"), locale, "#{locale} accessible home heading")
    text_is(doc.at_css("[data-hero-motion-toggle]"), ui(locale)["pause_animation"], "#{locale} motion control")
    { ".bottom-content [data-copy-ip]" => "copy_server", ".bottom-content .btn-green" => "join_section",
      "#join-java-back [data-copy-ip]" => "copy_server_coming_soon", "#join-bedrock-back .btn-green" => "launch_bedrock" }.each do |selector, key|
      node = doc.at_css(selector)
      check(node&.[]("aria-label") == ui(locale)[key], "#{locale} #{key} accessible label is incorrect")
      language_is(node, locale, "#{locale} #{key} control")
    end
  end

  def verify_departments(locale)
    overview = document("/departments/", locale)
    @data.fetch("departments").each_value do |department|
      path = department.fetch("path")
      link = overview&.css(".department-card a")&.find { |node| node["href"] == localized_path(path, locale) }
      card = link&.ancestors&.find { |node| node["class"].to_s.split.include?("department-card") }
      field_is(card&.at_css("h2"), department, "name", locale, "#{locale} #{path} overview heading")
      field_is(card&.at_css("p"), department, "bio", locale, "#{locale} #{path} overview bio")
      language_is(link, locale, "#{locale} #{path} overview action")
      doc = document(path, locale)
      field_is(doc&.at_css("h1"), department, "name", locale, "#{locale} #{path} heading")
      field_is(doc&.at_css(".content-card > p"), department, "bio", locale, "#{locale} #{path} bio")
      language_is(doc&.at_css(".content-page-intro"), locale, "#{locale} #{path} introduction")
    end
  end

  def verify_staff(locale)
    @data.fetch("staff").each_value do |person|
      next unless person["aboutpage"]

      doc = document(person.fetch("path"), locale)
      field_is(doc&.at_css(".content-page-intro"), person, "role", locale, "#{locale} #{person['path']} header role")
      field_is(doc&.at_css(".staff-role"), person, "role", locale, "#{locale} #{person['path']} role")
      field_is(doc&.at_css(".staff-bio"), person, "bio", locale, "#{locale} #{person['path']} bio")
    end
  end

  def verify_games(locale)
    doc = document("/games", locale)
    @data.fetch("games").each do |game|
      link = doc&.css(".view-game-btn")&.find { |node| node["href"] == localized_path(game["path"], locale) }
      card = link&.parent
      field_is(card&.at_css(".game-summary"), game, "summary", locale, "#{locale} #{game['path']} summary")
      language_is(card&.at_css('[class*="game-status--"]'), locale, "#{locale} #{game['path']} status")
      language_is(link, locale, "#{locale} #{game['path']} action")
    end
  end

  def verify_rules(locale)
    doc = document("/rules", locale)
    return unless doc

    text_is(doc.at_css("h1"), @data.dig("translations", locale, "site", "page_titles", "rules"), "#{locale} rules heading")
    language_is(doc.at_css("h1"), locale, "#{locale} rules heading")
    language_is(doc.at_css(".rules-container h2"), @default, "#{locale} fallback rules")
    language_is(doc.at_css(".last-updated-rules"), locale, "#{locale} rules update label")
  end

  def verify_page_headers(locale)
    @pages.select { |page| page["layout"] == "page" }.each do |page|
      doc = document(page["permalink"], locale)
      next unless doc

      active_heading = first_value(@data.dig("site_meta", locale, "page_titles", page["id"]), @data.dig("translations", locale, "site", "page_titles", page["id"]))
      expected_heading = first_value(page["heading"], active_heading, translated_site_value(locale, "page_titles", page["id"]), page["title"])
      language = !page["heading"] && active_heading ? locale : first_value(page["lang"], @default)
      text_is(doc.at_css("h1"), expected_heading, "#{locale} #{page['permalink']} page heading")
      language_is(doc.at_css("h1"), language, "#{locale} #{page['permalink']} page heading")
      language_is(doc.at_css(".content-page-intro"), first_value(page["lang"], @default), "#{locale} #{page['permalink']} page intro") if page["intro"]
    end
  end

  def verify_sitemap(locale, articles)
    doc = document("/sitemap", locale)
    return unless doc

    language_is(doc.at_css("#sitemap-pages-heading"), @default, "#{locale} sitemap fallback labels")
    records = @data.fetch("games") + @data.fetch("departments").values
    records.each do |record|
      link = doc.css("main a").find { |node| node["href"] == localized_path(record["path"], locale) }
      language = record[locale] ? locale : @default
      language_is(link, language, "#{locale} sitemap #{record['path']} entry")
      language_is(link&.parent&.at_css("p"), language, "#{locale} sitemap #{record['path']} description")
    end
    articles.each do |article|
      link = doc.css("main a").find { |node| node["href"] == localized_path(article["permalink"], locale) }
      text_is(link, article["title"], "#{locale} sitemap article title")
      language_is(link, article["lang"], "#{locale} sitemap article title")
      time = link&.parent&.at_css("time")
      language_is(time, locale, "#{locale} sitemap article date")
      text_is(time, article["date"].strftime(ui(locale)["date_format"]), "#{locale} sitemap formatted date")
    end
  end

  def verify_article(article, locale)
    doc = document(article["permalink"], locale)
    return unless doc

    language_is(doc.at_css(".article"), article["lang"], "#{locale} article content")
    text_is(doc.at_css("h1"), article["title"], "#{locale} article title")
    person = @data.fetch("staff").fetch(article["author"])
    name, = localized_field(person, "name", locale)
    check(doc.at_css(".author-pfp")&.[]("alt") == "#{name} #{ui(locale)['profile_picture']}", "#{locale} article author image label is incorrect")
    field_is(doc.at_css(".author-role"), person, "role", locale, "#{locale} article author role") if first_value(person.dig(locale, "role"), person.dig(@default, "role"))
    language_is(doc.at_css(".author-info time"), locale, "#{locale} article date")
    text_is(doc.at_css(".author-info time"), article["date"].strftime(ui(locale)["date_format"]), "#{locale} article formatted date")
    %w[X Reddit Facebook].zip(doc.css(".share-story-links a")).each do |platform, link|
      check(link&.[]("aria-label") == ui(locale)["share_on"].to_s.sub("{platform}", platform), "#{locale} #{platform} share label is incorrect")
      language_is(link, locale, "#{locale} #{platform} share label")
    end
  end

  def render_layout(layout, page, content = "<p>Fixture content</p>")
    path = File.join(@site.theme.root, "_layouts", "#{layout}.html")
    body = File.read(path).sub(/\A---\s*\n.*?\n---\s*\n/m, "")
    payload = { "site" => @site.site_payload["site"], "page" => page, "content" => content }
    @site.liquid_renderer.file(path).parse(body).render!(payload, registers: { site: @site, page: page })
  end

  def verify_rendered_fixtures
    @site.active_lang = @default
    author = 'A "quoted" & friend'
    @data["staff"]["localization-fixture"] = { "pfp" => "/assets/staffpfp/staff.png", @default => { "name" => author, "role" => "Contributor" } }
    article = { "layout" => "news", "title" => 'An article with "quotes"', "summary" => "Article summary",
                "lang" => @default, "url" => "/article/localization-fixture", "date" => Time.utc(2026, 6, 16),
                "author" => "localization-fixture", "type" => "NEWS", "banner" => "/assets/mojang/img/bg-grass.png",
                "related-articles" => ["not-a-published-article"] }
    parsed = Nokogiri::HTML5.fragment(render_layout("news", article), max_errors: 100)
    image = parsed.at_css(".author-pfp")
    check(parsed.errors.empty?, "Quoted-author fixture contains HTML parse errors")
    check(image&.[]("alt") == "#{author} #{ui(@default)['profile_picture']}", "Author image alt must preserve quotes and ampersands as text")
    check(image && image.attribute_nodes.map(&:name).sort == %w[alt class height src width], "Quoted author name must not create extra image attributes")

    locale = @languages.find { |language| language != @default }
    return unless locale

    @site.active_lang = locale
    @data["site_meta"][locale] ||= {}
    layers = [@data["site_meta"][locale], @data["translations"][locale]["site"],
              @data["site_meta"][@default], @data["translations"][@default]["site"]]
    page = { "layout" => "page", "id" => "localization-fixture", "title" => "Page fallback", "description" => "Page description", "url" => "/localization-fixture" }
    layers.each_with_index do |layer, index|
      (layer["page_titles"] ||= {})[page["id"]] = "Title layer #{index}"
      (layer["descriptions"] ||= {})[page["id"]] = "Description layer #{index}"
    end
    5.times do |index|
      parsed = Nokogiri::HTML5(render_layout("default", page), max_errors: 100)
      check(parsed.errors.empty?, "Metadata fixture #{index} contains HTML parse errors")
      expected_title = index < 4 ? "Title layer #{index}" : page["title"]
      check(parsed.at_css("title")&.text&.start_with?("#{expected_title} | "), "Metadata title precedence failed at layer #{index}")
      expected_description = index < 4 ? "Description layer #{index}" : page["description"]
      check(parsed.at_css('meta[name="description"]')&.[]("content") == expected_description, "Metadata description precedence failed at layer #{index}")
      next unless index < 4

      layers[index]["page_titles"].delete(page["id"])
      layers[index]["descriptions"].delete(page["id"])
    end
    layers.first["page_titles"][page["id"]] = "Generic title that must not replace an article"
    layers.first["descriptions"][page["id"]] = "Generic description that must not replace an article"
    parsed = Nokogiri::HTML5(render_layout("default", article.merge("id" => page["id"])), max_errors: 100)
    check(parsed.at_css("title")&.text&.start_with?("#{article['title']} | "), "Article title must override generic metadata")
    check(parsed.at_css('meta[name="description"]')&.[]("content") == article["summary"], "Article summary must override generic metadata")
  end
end

LocalizationVerifier.new(ARGV.fetch(0, "_site")).run
