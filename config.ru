$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(__FILE__)))
require 'bundler'
Bundler.require

require 'app'
run App
