source "https://rubygems.org"

ruby_version = Gem::Version.new(RUBY_VERSION)
local_jekyll = Gem.win_platform? || RbConfig::CONFIG["host_os"].include?("darwin")

if local_jekyll
  # github-pages has native dependencies that lag behind macOS Ruby releases.
  if ruby_version >= Gem::Version.new("2.7")
    gem "jekyll", "~> 4.4"
  else
    gem "jekyll", "~> 4.3.0"
  end
  gem "webrick"

  group :jekyll_plugins do
    gem "jekyll-sitemap"
  end
else
  gem "github-pages", group: :jekyll_plugins
end

# html-proofer 5 requires Ruby 3.1, while 4.4 still supports Ruby 2.6-3.0.
# No released html-proofer supports Ruby 4 yet, so keep site builds usable there.
if ruby_version >= Gem::Version.new("3.1") && ruby_version < Gem::Version.new("4.0")
  gem "html-proofer", "~> 5.0"
elsif ruby_version >= Gem::Version.new("2.6") && ruby_version < Gem::Version.new("4.0")
  gem "html-proofer", "~> 4.4"
end
