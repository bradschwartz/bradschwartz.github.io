

local:
	@/usr/bin/bundle exec jekyll serve

install:
	@/usr/bin/bundle install --path .vendor/bundle

upgrade:
	@/usr/bin/bundle update github-pages