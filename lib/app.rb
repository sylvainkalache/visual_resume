require 'logger'
require 'ostruct'
require 'erb'


# Load all model files
Dir[File.join(File.dirname(__FILE__), 'model/*.rb')].each { |f| require f }
DataMapper.finalize

class App < Sinatra::Base
  credentials = YAML.load_file(File.join(File.dirname(__FILE__), '../credentials.yml'))
  helpers Sinatra::JSON
  set :erb, :format => :html5
  enable :sessions

  configure do
    DataMapper.setup(:default, "mysql://#{credentials['mysql_login']}:#{credentials['mysql_password']}@127.0.0.1/#{credentials['mysql_db']}")
    set :public_folder, File.dirname(__FILE__) + '/public'
  end

  before do
    puts "Retrieving user for user_id #{session[:user_id]}"
    @user = Users.get(session[:user_id])
  end

  before do
    pass if (request.path_info == '/oauth' || request.path_info == '/oauth2/callback')
    redirect to('/oauth') unless @user
  end

  get '/' do
    doc = Nokogiri::XML(access_token.get("https://api.linkedin.com/v1/people/~:(first-name,last-name,headline,positions,educations,skills)").body)

    @user = Hash.new()

    @user['positions'] = Array.new()
    # Getting positions infos
    doc.xpath('//position').each do |p|
      position = { 'company_name' => p.at_xpath('company').at_xpath('name').text,
                 'start-date' => p.at_xpath('start-date').at_xpath('year').text}
      if p.at_xpath('end-date')
        position['end-date'] = p.at_xpath('end-date').at_xpath('year').text
      else
        position['end-date'] = '2013'
      end
      @user['positions'] << position
    end

    @user['educations'] = Array.new()
    # Getting education infos
    doc.xpath('//education').each do |p|
      education = { 'school-name' => p.at_xpath('school-name').text,
                  'start-date' => p.at_xpath('start-date').at_xpath('year').text }
      if p.at_xpath('end-date')
        education['end-date'] = p.at_xpath('end-date').at_xpath('year').text
      else
        education['end-date'] = '2013'
      end
      @user['educations'] << education
    end

    # Getting user basic informations
     doc.xpath('//person').each do |c|      
        @user['first_name'] = c.at_xpath('first-name').text() unless c.at_xpath('first-name').nil?
        @user['last_name'] = c.at_xpath('last-name').text() unless c.at_xpath('last-name').nil?
        @user['headline'] = c.at_xpath('headline').text() unless c.at_xpath('headline').nil?
        @user['picture-url'] = c.at_xpath('picture-url').text() unless c.at_xpath('picture-url').nil?     
      end

    #context = {}
    context = Hash.new{|h, k| h[k] = []}
    context[:user] = @user

    # Getting user skills
    @user['skills'] = Array.new()
    doc.xpath('//skill').each do |s|
      puts s.at_xpath('name')
      @user['skills'] << s.at_xpath('name').text unless s.at_xpath('name').nil?
    end
    
    context = Hash.new{|h, k| h[k] = []}



    p @user
    puts context.inspect
    html = erb.result(OpenStruct.new(context).instance_eval { binding })
    #html = ERB.new(context).result(binding)
    f = File.open('./test.html', 'w')
    f.do { |file| file.write(html) }
    f.close

    erb :index
  end

  get '/oauth' do
    redirect oauth_client.auth_code.authorize_url({
        :scope => 'r_fullprofile',
        :redirect_uri => redirect_uri,
        :state => 'test'
    })
  end

  get '/oauth2/callback' do
    token = oauth_client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri)
    puts "TOKEN: #{token.token}"
    access_token = OAuth2::AccessToken.new(oauth_client, token.token, {
        :mode => :query,
        :param_name => "oauth2_access_token",
    })

    # Get the info about the logged in user
    response = access_token.get('https://api.linkedin.com/v1/people/~:(id,first-name,last-name)')
    doc = Nokogiri::XML(response.body)
    linkedin_id = doc.xpath('//person/id').text
    @user = Users.first(:linkedin_id => linkedin_id)
    puts "User #{@user}"
    if @user.nil?
      puts "Creating user..."
      # Create user
      @user = Users.create(:linkedin_id => linkedin_id,
        :first_name => doc.xpath('//person/first-name').text,
        :last_name => doc.xpath('//person/last-name').text,
        :access_token => token.token)
      puts "User created: #{@user.id}"
    else
      puts "Updating access token for user #{@user.id}"
      @user.update(:access_token => token.token)
    end
    session[:user_id] = @user.id

    redirect to('/')
  end

  get '/logout' do
    session.delete(:user_id)
    redirect to('/')
  end

  helpers do
    def access_token
      return nil unless @user
      OAuth2::AccessToken.new(oauth_client, @user.access_token, {
          :mode => :query,
          :param_name => "oauth2_access_token",
      })
    end

    def oauth_client
      credentials = YAML.load_file(File.join(File.dirname(__FILE__), '../credentials.yml'))
      unless @oauth_client
        @oauth_client = OAuth2::Client.new(credentials['api_key'], credentials['secret_key'], {
            :site => 'https://www.linkedin.com',
            :authorize_url => 'uas/oauth2/authorization?response_type=code',
            :token_url => 'uas/oauth2/accessToken'
        })
      end
      @oauth_client
    end

    def redirect_uri
      uri = URI.parse(request.url)
      uri.path = '/oauth2/callback'
      uri.query = nil
      uri.to_s
    end
  end
end
