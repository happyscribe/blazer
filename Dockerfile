# Digest pins the v3.5.2 rebuild on Ruby 4.0.10 (CVE-2026-132825); upstream re-pushes tags in place.
FROM ankane/blazer:v3.5.2@sha256:6468461684b522fd1991f3ec9278d53fa9b5a1c758a1f2dc58ca5ca32047e576

COPY blazer.yml /app/config/blazer.yml
COPY mailer.rb /app/config/initializers/mailer.rb
COPY opsgenie.rb /app/config/initializers/opsgenie.rb
