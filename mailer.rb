Rails.application.config.action_mailer.default_url_options = {
  host: ENV['HOST'],
}
Rails.application.config.action_mailer.delivery_method = :smtp
Rails.application.config.action_mailer.smtp_settings = {
  :address => 'smtp.resend.com',
  :user_name => 'resend',
  :password => ENV['RESEND_API_KEY'],
  :domain => 'happyscribe.com',
  :port => 465,
  :authentication => :plain,
  :tls => true,
}
