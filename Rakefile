$:.unshift File.dirname(__FILE__)
$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'bundler'
Bundler.require
require 'app'

desc 'All DB related tasks'
namespace :db do
  desc 'Erases and re-create the DB tables'
  task :reset do
    DataMapper.auto_migrate!
  end

  desc 'Updates the DB tables'
  task :update do
    DataMapper.auto_upgrade!
  end
end