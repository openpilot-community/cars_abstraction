module Cars
  class LegacyResource < LegacyObject
    include Cars::APIOperations::Request

    # A flag that can be set a behavior that will cause this resource to be
    # encoded and sent up along with an update of its parent resource. This is
    # usually not desirable because resources are updated individually on their
    # own endpoints, but there are certain cases, replacing a customer's source
    # for example, where this is allowed.
    attr_accessor :save_with_parent

    def self.class_name
      name.split('::')[-1]
    end

    def self.list_resource_url
      if self == LegacyResource
        raise NotImplementedError, 'LegacyResource is an abstract class.  You should perform actions on its subclasses (Story, Topic, etc.)'
      end
      "/#{CGI.escape(class_name.downcase)}"
    end

    def self.resource_url
      if self == LegacyResource
        raise NotImplementedError, 'LegacyResource is an abstract class.  You should perform actions on its subclasses (Story, Topic, etc.)'
      end
      "/#{CGI.escape(class_name.downcase)}"
    end

    def retrieve_method
      'get'
    end

    def save_action; end

    def retrieve_action; end

    def list_action; end

    def retrieve_params
      # { action: retrieve_action, id: id }
    end

    def parse(page); end

    def refresh
      page = request(path: "#{resource_url}/#{id}", method: retrieve_method, params: retrieve_params)
      
      parsed = parse(page)
      initialize_from(parsed, {})
    end

    def list_resource_url
      "#{@base_url}#{self.class.list_resource_url}"
    end

    def resource_url
      "#{@base_url}#{self.class.resource_url}"
    end

    def self.retrieve(id, opts = {})
      opts = Util.normalize_opts(opts)
      instance = new(id, opts)
      instance.refresh
      instance
    end
  end
end
