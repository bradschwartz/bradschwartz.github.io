

local:
	$(shell /usr/bin/bundle exec jekyll serve)

install:
	$(shell /usr/bin/bundle install --path .vendor/bundle)

upgrade:
	$(shell /usr/bin/bundle update github-pages)