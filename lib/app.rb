require 'ostruct'
require 'erb'
require 'slideshare'

# Load all model files
Dir[File.join(File.dirname(__FILE__), 'model/*.rb')].each { |f| require f }
DataMapper.finalize

class App < Sinatra::Base
  credentials = YAML.load_file(File.join(File.dirname(__FILE__), '../credentials.yml'))
  config = YAML.load_file(File.join(File.dirname(__FILE__), '../config.yml'))
  helpers Sinatra::JSON
  set :erb, :format => :html5
  enable :sessions

  configure do
    DataMapper.setup(:default, "mysql://#{credentials['mysql_login']}:#{credentials['mysql_password']}@127.0.0.1/#{credentials['mysql_db']}")
    set :public_folder, File.dirname(__FILE__) + '/public'
  end

  before do
    @user = Users.get(session[:user_id])
  end

  before do
    pass if (request.path_info == '/oauth' || request.path_info == '/oauth2/callback')
    redirect to('/oauth') unless @user
  end

  get '/' do
    doc = Nokogiri::XML(access_token.get("https://api.linkedin.com/v1/people/~:(first-name,last-name,headline,educations,skills,picture-url,positions:(start-date:(year,month),end-date,title,company:(name,id)))").body)

    user = Hash.new()
    industries = Hash.new()
    companies = Array.new()
    user['positions'] = Array.new()
    # Getting positions infos
    doc.xpath('//position')[0..4].each do |p|

      # If no company name we ignore the position
      unless p.at_xpath('company').at_xpath('name').nil?
        position = { 'company_name' => p.at_xpath('company').at_xpath('name').text,
                     'start-year' => p.at_xpath('start-date').at_xpath('year').text }
        title = p.at_xpath('title')
        position['title'] = title ? title.text : ''
        start_month = p.at_xpath('start-date').at_xpath('month')
        position['start-month'] = start_month ? start_month.text : '1'

        if p.at_xpath('end-date')
          position['end-year'] = p.at_xpath('end-date').at_xpath('year').text
          end_month = p.at_xpath('end-date').at_xpath('month')
          position['end-month'] = end_month ? end_month.text : '12'
        else
          time = Time.now
          position['end-year'] = time.year
          position['end-month'] = time.month
        end

        unless p.at_xpath('company').at_xpath('id').nil?
          company = Nokogiri::XML(access_token.get("https://api.linkedin.com/v1/companies/#{p.at_xpath('company').at_xpath('id').text()}:(industries,square-logo-url,logo-url)").body)
          companies << company.xpath('//square-logo-url').text() unless company.xpath('//square-logo-url').text.empty?

          company.xpath('//industry').each do |c|
            unless c.at_xpath('name').nil?
              industries[c.at_xpath('name').text()] = 0 if industries[c.at_xpath('name').text()].nil?
              diff = position['end-year'].to_i - position['start-year'].to_i
              diff = 1 if diff == 0 
              industries[c.at_xpath('name').text()] += diff
            end
          end
        end

      user['positions'] << position
      end
    end
    user['industries'] = industries
    user['company-logos'] = companies

    user['educations'] = Array.new()
    # Getting education infos
    doc.xpath('//education')[0..4].each do |p|
      
      # If school name is empty we ignore the entry
      unless p.at_xpath('school-name').nil?
        education = { 'school-name' => p.at_xpath('school-name').text,
          'start-date' => p.at_xpath('start-date').at_xpath('year').text }
        degree = p.at_xpath('degree')
        education['degree'] = degree ? degree.text : ''
        
        if p.at_xpath('end-date')
          education['end-date'] = p.at_xpath('end-date').at_xpath('year').text
        else
          education['end-date'] = '2013'
        end
        user['educations'] << education
      end
    end

    # Getting user basic informations
    doc.xpath('//person').each do |c|
      user['first_name'] = c.at_xpath('first-name').text().gsub(' ','-') unless c.at_xpath('first-name').nil?
      user['last_name'] = c.at_xpath('last-name').text() unless c.at_xpath('last-name').nil?
      user['headline'] = c.at_xpath('headline').text() unless c.at_xpath('headline').nil?
      user['picture-url'] = c.at_xpath('picture-url').text() unless c.at_xpath('picture-url').nil?
    end

    # Getting user skills
    user['skills'] = Array.new()
    doc.xpath('//skill')[0..10].each do |s|
      user['skills'] << s.at_xpath('name').text unless s.at_xpath('name').nil?
    end

    # Generating HTML
    context = Hash.new{|h, k| h[k] = []}
    context[:user] = user
    erb_instance = ERB.new(File.read('lib/views/index.erb'))
    html = erb_instance.result(OpenStruct.new(context).instance_eval { binding })

    # Converting HTML to PDF and uploading to SlideShare
    File.open("lib/public/#{user['first_name']}-#{user['last_name']}.html", 'w') {|f| f.write(html) }
    `phantomjs ./lib/pdf_gen.js ./lib/public/#{user['first_name']}-#{user['last_name']}.html ./lib/public/#{user['first_name']}-#{user['last_name']}.pdf`

    if config['slideshare_upload'] == 1
      Slideshare.upload("#{user['first_name']}-#{user['last_name']}.pdf")
    end
    
    # Dirty debuging
    #p industries
    #p user
    #p companies
    erb :index, :locals => {:user => user}
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
    access_token = OAuth2::AccessToken.new(oauth_client, token.token, {
        :mode => :query,
        :param_name => "oauth2_access_token",
    })

    # Get the info about the logged in user
    response = access_token.get('https://api.linkedin.com/v1/people/~:(id,first-name,last-name)')
    doc = Nokogiri::XML(response.body)
    linkedin_id = doc.xpath('//person/id').text
    @user = Users.first(:linkedin_id => linkedin_id)
    if @user.nil?
      # Create user
      @user = Users.create(:linkedin_id => linkedin_id,
        :first_name => doc.xpath('//person/first-name').text,
        :last_name => doc.xpath('//person/last-name').text,
        :access_token => token.token)
    else
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
