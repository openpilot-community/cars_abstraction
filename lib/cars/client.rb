module Cars
  class HtmlParser
    def self.parse(thing, url = nil, encoding = nil, options = Nokogiri::XML::ParseOptions::DEFAULT_HTML, &block)
      # insert your conversion code here. For example:
      # thing = NKF.nkf("-wm0X", thing).sub(/Shift_JIS/,"utf-8") # you need to rewrite content charset if it exists.
      Nokogiri::HTML::Document.parse(thing, url, encoding, options, &block)
    end
  end
  class Client
    # THESE ARE HERE FOR UTNIL THEY ARE BROKEN OUT INTO THEIR OWN.
    attr_accessor :conn

    def initialize(conn = nil)
      @base_url = Cars.config['base_url']
      # @username = Cars.config['username']
      # @password = Cars.config['password']

      self.conn = conn || self.class.default_conn
      # @system_profiler = SystemProfiler.new
      authenticate
    end

    def self.base_url
      Cars.config['base_url']
    end

    def self.active_client
      Thread.current[:cars_client] || default_client
    end

    def self.default_client
      @default_client ||= Client.new(default_conn)
    end

    # A default mechanize connection to be used when one isn't configured. This
    # object should never be mutated, and instead instantiating your own
    # connection and wrapping it in a Client object should be preferred.
    def self.default_conn
      # We're going to keep connections around so that we can take advantage
      # of connection re-use, so make sure that we have a separate connection
      # object per thread.
      # Thread.current[:cars_client_default_conn] ||= begin
        conn = Mechanize.new
        conn.log = Logger.new "mech.log"
        conn.user_agent_alias = 'Mac Safari'
        # conn.html_parser = Cars::HtmlParser
        conn
      # end
    end

    def authenticate
      pp 'Connecting...'
      # request(path: '/honda-civic-2016/')
    end

    def request_other(url: '', method: 'get', params: {})
      # old_cars_client = Thread.current[:cars_client]
      Thread.current[:cars_client] = self
      method_name = method.downcase
      if conn.respond_to?(method_name) && %w[get post].include?(method_name)
        page = conn.public_send(method_name, url.to_s, params)
        return page
      end
    end

    def request(path: '/', method: 'get', params: {})
      # old_cars_client = Thread.current[:cars_client]
      # Thread.current[:cars_client] = self
      method_name = method.downcase
      # puts conn
      if !path.include? "file://"
        full_url = "#{@base_url}#{path}"
      else
        full_url = path
      end
      puts "[#{method_name}] #{full_url}"
      page = conn.public_send(method_name, full_url, params)
      # page.encoding = 'utf-8'
      return page
      if conn.respond_to?(method_name) && %w[get post].include?(method_name)
        # if %w[post].include?(method_name)
        #   params['Content-Type'] = '[{"key":"Content-Type","value":"application/x-www-form-urlencoded","description":""}]'
        # end

        page = conn.public_send(method_name, "#{@base_url}#{path}", params)
        # page.encoding = 'utf-8'
        return page
      end
    end
  end
end
