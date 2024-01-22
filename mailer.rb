Rails.application.config.action_mailer.default_url_options = {
  host: ENV['HOST'],
}
Rails.application.config.action_mailer.delivery_method = :smtp
Rails.application.config.action_mailer.smtp_settings = {
  :user_name => 'apikey',
  :password => ENV['SENDGRID_API_KEY'],
  :domain => 'www.happyscribe.co',
  :address => 'smtp.sendgrid.net',
  :port => 587,
  :authentication => :plain,
  :enable_starttls_auto => true,
}
Rails.application.config.action_mailer.default_options = {
  from: "mailer@product-alerts.happyscribe.com"
}