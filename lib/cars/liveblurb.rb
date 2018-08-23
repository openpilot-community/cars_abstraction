module Cars
  class Liveblurb < LegacyResource
    extend Cars::APIOperations::List

    OBJECT_NAME = 'liveblurb'.freeze

    def save_action
      'save_liveblurb'
    end

    def retrieve_action; end

    def resource_url
      "/headlines/#{id}"
    end

    def self.list_resource_url
      '/headlines'
    end

    def retrieve_method
      'get'
    end

    def parse(page)
      values = {}
      form = page.forms.first
      pp form
      values[:id] = id
      values[:object] = OBJECT_NAME
      values[:name] = form.title
      values[:description] = form.description
      values[:expiration] = form.expiration
      values[:image_url] = page.search('.box-content img').first.attr('src')
      values[:status] = form.status.to_i == 1 ? 'active' : 'inactive'

      values
    end
  end
end
