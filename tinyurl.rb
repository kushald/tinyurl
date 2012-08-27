%w(rubygems sinatra haml dm-core dm-timestamps dm-types uri restclient xmlsimple dm-transactions).each {|library| require library}
disable :show_exceptions

get '/' do
	haml :index
end

post '/' do
	uri = URI::parse(params[:original])
	raise "Invalid Url" unless uri.kind_of? URI::HTTP or uri.kind_of? URI::HTTPS
	custom = params[:custom].empty? ? nil : params[:custom]
	@link = Link.shorten(params[:original],custom)
	haml :index
end

get '/:short_url' do
	link = Link.first(:identifier => params[:short_url])
	link.visits << Visit.create(ip => get_remote_ip(env))
	link.save
	redirect link.url.original, 301
end

error do haml :index end

def get_remote_ip(env)
	env['REMOTE_ADDR']
end

enable :inline_templates

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'mysql://root:qwaszx@localhost/tinyurl')
class Url
	include DataMapper::Resource
	property :id, Serial
	property :original, String, :length => 255
	belongs_to :link, :required => false
end

class Link
	include DataMapper::Resource
	property :identifier, String, :key => true
	property :created_at, DateTime
	has 1, :url
	has n, :visits
  
	def self.shorten(original,custom=nil)
		url = Url.first(:original => original)
		return url.link if url
		link = nil
		if custom
			raise 'Someone has already taken url' if Link.first(:identifier => custom)
			transaction do |txn|
				link = Link.new(:identifier => custom)
				link.url = Url.create(:original => original)
				link.save
			end
		else
			transaction do |txn|
			p "-e"*80

				link = create_link(original)
				p link

			end
		end
		return link
	end
  
	private
  
	def self.create_link(original)
		url = Url.create(:original => original)
		if Link.first(:identifier => url.id.to_s(36)).nil?
			link = Link.new(:identifier => url.id.to_s(36))
			link.url = url
			link.save
			return link
		else
			create_link(original)
		end
	end
end
class Visit
	include DataMapper::Resource
	property :id, Serial
	property :created_at, DateTime
	property :ip, IPAddress
	property :country, String
	belongs_to :link
  
	after :create, :set_country
  
	def set_country
		xml = RestClient.get "http://api.hostip.info/get_xml.php?ip=#{ip}"
		self.country = XmlSimple.xml_in(xml.to_s, {'ForceArray' => false})['featureMember']['Hostip']['countryAbbrev']
		self.save
	end	
end
DataMapper.finalize
__END__

@@ layout
!!! 1.1
%html
  %head
    %title Tiny Url
    %link{:rel => 'stylesheet', :href => 'http://www.blueprintcss.org/blueprint/screen.css', :type => 'text/css'}  
  %body
    .container
      %p
      = yield

@@ index
%h1.title Tiny Url
- unless @link.nil?
  .success
    %code= @link.url.original
    has been shortened to 
    %a{:href => "/#{@link.identifier}"}
      = "http://tinyclone.saush.com/#{@link.identifier}"
    %br
    Go to 
    %a{:href => "/info/#{@link.identifier}"}
      = "http://tinyclone.saush.com/info/#{@link.identifier}"
    to get more information about this link.
- if env['sinatra.error']
  .error= env['sinatra.error'] 
%form{:method => 'post', :action => '/'}
  Shorten this:
  %input{:type => 'text', :name => 'original', :size => '70'} 
  %input{:type => 'submit', :value => 'now!'}
  %br
  to custom
  %input{:type => 'text', :name => 'custom', :size => '20'} 
  (optional)
%p  
%small copyright &copy;
%a{:href => '#'}
  Kushal Dongre
%p
  %a{:href => 'http://github.com/kushald/store'}
    Full source code