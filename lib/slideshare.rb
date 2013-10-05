require 'digest/sha1'

class Slideshare
  def self.upload(file_name)
    credentials = YAML.load_file(File.join(File.dirname(__FILE__), '../credentials.yml'))
    api_key = credentials['slideshare_api_key']
    secret = credentials['slideshare_secret']
    slideshare_password = credentials['slideshare_password']
    slideshare_login = credentials['slideshare_login']
    private_slideshare_upload = credentials['private_slideshare_upload']

    file_path = "./lib/public/#{file_name}"
    now = Time.now.to_i.to_s
    hashed = Digest::SHA1.hexdigest("#{secret}#{now}")

    curl_return = `curl -F slideshow_srcfile=@#{file_path} -F username=#{slideshare_login} -F password=#{slideshare_password} -F slideshow_title=#{file_name.gsub('.pdf','')}-resume https://www.slideshare.net/api/2/upload_slideshow -F api_key=#{api_key} -F ts=#{now} -F hash=#{hashed} -F make_slideshow_private=#{private_slideshare_upload}`
  end
end
