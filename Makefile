THEME := $(shell grep 'theme:' _config.yml | cut -d' ' -f2)

.PHONY: serve
serve:
	bundle exec jekyll serve --drafts --host 0.0.0.0

.PHONY: layouts
layouts:
	bundle info --path $(THEME)
