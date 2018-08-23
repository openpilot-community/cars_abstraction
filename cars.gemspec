
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cars/version'

Gem::Specification.new do |spec|
  spec.name          = 'cars'
  spec.version       = Cars::VERSION
  spec.authors       = ['Openpilot Community']
  spec.email         = ['support@opc.ai']

  spec.summary       = 'A Ruby-based abstraction library to access data via web scraping of Cars'
  spec.description   = 'A Ruby-based abstraction library to access data via web scraping of Cars'
  spec.homepage      = ''

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = ''
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  spec.add_development_dependency 'bundler', '~> 1.16.a'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spec.add_dependency 'reverse_markdown'
  spec.add_dependency 'sanitize'
  spec.add_dependency 'upmark'
  spec.add_dependency 'mechanize'
  spec.add_dependency 'watir'
  spec.add_dependency 'rails', '~> 4.2.10'

  spec.add_development_dependency 'sqlite3'
end
