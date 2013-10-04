require 'digest/sha1'

class Slideshare
  def self.upload(file_name)
    credentials = YAML.load_file(File.join(File.dirname(__FILE__), '../credentials.yml'))
    api_key = credentials['slideshare_api_key']
    secret = credentials['slideshare_secret']
    temporary_testing_password = credentials['temporary_testing_password']

    file_path = "/home/ubuntu/visual_resume/lib/public/#{file_name}"
    now = Time.now.to_i.to_s
    hashed = Digest::SHA1.hexdigest("#{secret}#{now}")

    curl_return = `curl -F slideshow_srcfile=@#{file_path} -F username='sylvainkalache' -F password=#{temporary_testing_password} -F slideshow_title='Hackday test' https://www.slideshare.net/api/2/upload_slideshow -F api_key=#{api_key} -F ts=#{now} -F hash=#{hashed} -F make_slideshow_private=Y`
  end
end
