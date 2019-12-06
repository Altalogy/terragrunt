# Builds Terragrunt Website hosted on Github Pages and built with Jekyll.
cd terragrunt_website && JEKYLL_ENV=production bundle exec jekyll build && rm -rf ../docs && mkdir ../docs && cp -r _site/* ../docs/
