require 'active_record'
require 'dotenv'

Dotenv.load

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL']) 