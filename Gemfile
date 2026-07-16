source "https://rubygems.org"

if Gem.win_platform?
    gem "jekyll", "~> 4.3"
    gem "webrick"
    
    group :jekyll_plugins do
        gem "jekyll-sitemap"
    end
else
    gem "github-pages", group: :jekyll_plugins
end
gem "html-proofer", "~> 5.0"
