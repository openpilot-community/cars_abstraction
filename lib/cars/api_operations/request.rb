module Cars
  module APIOperations
    module Request
      module ClassMethods
        def request(path:, method: 'get', params: {})
          client = Client.active_client
          
          page_key = "#{path.gsub('/','_')}.html"
          store_path = File.join(Rails.root,'log','scrapes')
          full_path = File.join(store_path,page_key)
          FileUtils.mkdir_p(store_path)

          if !File.exist? full_path
            resp = client.request(
              path: path,
              method: method,
              params: params
            )
            File.write("#{full_path}", resp.body.force_encoding('UTF-8'))
          else
            resp = client.request(
              path: "file:///#{full_path}",
              method: "get"
            )
          end
          
          resp
        end

        def request_other(url:, method: 'get', params: {})
          # print "[REQUEST] #{method.upcase} #{url}\n"

          client = Client.active_client
          resp = client.request_other(
            url: url,
            method: method,
            params: params
          )

          resp
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      # protected

      def request(path:, method: 'get', params: {})
        self.class.request(path: path,
                           method: method,
                           params: params)
      end

      def request_other(url:, method: 'get', params: {})
        self.class.request_other(url: url,
                                 method: method,
                                 params: params)
      end
    end
  end
end
