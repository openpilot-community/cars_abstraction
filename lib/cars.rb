require 'cars/version'
# API operations
require 'cars/api_operations/list'
require 'cars/api_operations/request'

require 'cars/util'
require 'cars/client'
require 'cars/legacy_object'
require 'cars/legacy_resource'
require 'cars/list_object'

# Named API resources
require 'cars/vehicle'
require 'cars/vehicle_style'

module Cars
  @config = nil

  class << self
    def config
      @config ||= load_config(config_path).freeze
    end

    def config_path
      if defined?(Rails)
        File.join(Rails.root, 'config', 'cars.yml')
      else
        'cars.yml'
      end
    end

    def load_config(yaml_file)
      return {} unless File.exist?(yaml_file)
      cfg = YAML.safe_load(File.open(yaml_file))
      cfg = cfg[Rails.env] if defined? Rails
      cfg
    end
  end
end
