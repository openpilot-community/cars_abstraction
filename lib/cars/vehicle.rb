require 'sanitize'
module Cars
  class Vehicle < LegacyResource
    OBJECT_NAME = 'vehicle'.freeze
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
      # 'ajax_refresh_buckets'
    end

    def parse(page)
      vehicle_page = page
      # boxes = vehicle_page.search('.box')
      # form = vehicle_page.forms.first
      # # puts vehicle_page.body
      values = {}
      trim_sections = vehicle_page.search('.cui-accordion-section')
      values[:name] = ""
      values[:image] = "#{Cars.config['base_url'].gsub('/research','')}#{vehicle_page.search('.trim_listing__image img').first.attributes['src']}"
      values[:trims] = []
      trim_sections.each do |section|
        if section.search('.cui-accordion-section__title').first
          trim_title = section.search('.cui-accordion-section__title').first.text.gsub('Trim: ','')
          
          new_trim = {
            :name => trim_title
          }
          style_keys = []
          section.search('#labels-row > .cell').reverse.drop(1).reverse.each do |key|
            style_keys << key.text.parameterize('_').gsub('style','name')
          end
          new_trim[:styles] = []
          section.search('.trim-details > .trim-card').each do |trim_style_card|
            trim_cells = trim_style_card.search('.cell')
            link = trim_cells.last.search('a').first.attributes['href']
            new_style = {}
            style_keys.each_with_index do |item, index|
              new_style[:"#{item}"] = trim_cells[index].text.squish
            end
            new_style[:link] = "#{Cars.config['base_url'].gsub('/research','')}#{link}"
            new_trim[:styles] << new_style
          end
          values[:trims] << new_trim
        end
      end
      values
    end

    def fix_markdown(html)
      ReverseMarkdown.convert(html, tag_border: '').gsub('&nbsp;', ' ')
    end

    def fix_html(html)
      html_cleaned = Sanitize.fragment(html, Sanitize::Config.merge(Sanitize::Config::BASIC,
                                                                    elements: Sanitize::Config::BASIC[:elements] - %w[p br],
                                                                    attributes: { 'a' => %w[href title],
                                                                                  'span' => ['class'] },
                                                                    whitespace_elements: {
                                                                      'br' => { before: '', after: '\n' },
                                                                      'div' => { before: '', after: '' },
                                                                      'p'   => { before: '', after: '' }
                                                                    }))
      # html_cleaned = html_stripped.gsub(/\ +/, ' ')
      # html_cleaned = html_cleaned.gsub(/\n\ +/, '')
      # html_stripped = html_stripped.gsub(/\n/, '<br />')
      html_cleaned = simple_format(html_cleaned, {}, wrapper_tag: 'p', sanitize: false)

      # html_clean = html_stripped.gsub(/<p><br><\/p>/, '<br />')
      #
      # html_clean = html_clean.gsub('<br /><br />', '<br />')
      #
      # html_clean = html_clean.gsub('<br>', '<br />')
      # html_clean = html_clean.gsub(/\<br \/\>\n\<br \/>\n/, '<br />')
      # html_clean = html_clean.gsub(/\<\/p\>\n\<br \/\>/, '</p>')
      # html_clean = html_clean.gsub(/\<br \/\>\<\/p\>/, '</p>')
      # pp html_cleaned
      html_cleaned
    end
  end
end
