FROM ankane/blazer

COPY blazer.yml /app/config/blazer.yml
COPY mailer.rb /app/config/initializers/mailer.rb
COPY opsgenie.rb /app/config/initializers/opsgenie.rb