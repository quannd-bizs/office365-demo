# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

ENV["CLIENT_ID"] = "your_client_id"
ENV["CLIENT_SECRET"] = "your_secret_key"