# Build the site into public/
build:
    zola build

# Serve locally with drafts and live reload
serve:
    zola serve --drafts

# Validate links and content
check:
    zola check