require 'sanitize'
module Cars
  class VehicleStyle < LegacyResource
    OBJECT_NAME = 'vehicle_style'.freeze
    extend Cars::APIOperations::List
    include ActionView::Helpers::TextHelper
    # def self.list_resource_url
    #   '/'
    # end

    def self.resource_url
      ""
    end

    def self.list_params
      { page: 1 }
    end

    def retrieve_action
    end
    # #
    # def self.resource_url
    #   '/vehicle'
    # end

    # def self.resource_url
    #   '/vehicle'
    # end

    def parse(page)
      vehicle_page = page
      # boxes = vehicle_page.search('.box')
      # form = vehicle_page.forms.first
      # # puts vehicle_page.body
      values = {}
      specificiation_sections = vehicle_page.search('#specifications-section .cui-page-section__content > div')
      
      values[:specs] = []
      specificiation_sections.each do |section|
        # puts section.search('.specs-accordion-header')
        spec_header = section.search('.specs-accordion-header').first
        # puts section
        if !spec_header.blank?
          spec_type_title = spec_header.text.squish
          section.search('.specs-accordion-body .data-list tbody tr').each do |spec|
            new_spec = {}
            # puts spec.search('.specs-accordion-description')
            spec_key = spec.search('.specs-accordion-description').first.text.squish
            spec_value = spec.search('.data').first.text.squish.gsub(/\\"/,'')
            new_spec[:name] = spec_key
            new_spec[:type] = spec_type_title
            if spec_value.size == 1
              #ITS standard or optional
              if spec_value == "O"
                new_spec[:inclusion] = "option"
              end

              if spec_value == "S"
                new_spec[:inclusion] = "standard"
              end
            else
              new_spec[:value] = spec_value
            end
            # new_spec[:name] = spec.search('.data').first.text.squish
            puts new_spec
            values[:specs] << new_spec
          end
        end
      end
      values
    end
  end
end
