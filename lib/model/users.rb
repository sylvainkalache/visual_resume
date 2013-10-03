class Users
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :linkedin_id, String, :unique_index => true
  property :first_name, String
  property :last_name, String
  property :access_token, String, :length => 255
  property :notification_email, Boolean
  property :notification_linkedin, Boolean
end
