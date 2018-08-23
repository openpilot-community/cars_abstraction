module Cars
  module APIOperations
    module List
      attr_accessor :list_params
      def self.list_params
        { page: 1 }
      end

      def serialize_from_dropdown_items(rows)
        data = []
        rows.each do |row|
          data << {
            id: row.value,
            name: row.text
          }
        end
        data
      end

      def serialize_from_users(rows)
        data = []
        rows.each do |row|
          data << Cars::User.parse_user(row.value, row.text, false)
        end
        data
      end

      def serialize_from_stories(rows)
        data = []
        rows.each do |row|
          next unless row.search('.story-id').children.first
          id_tag_element = row.search('.dropdown-menu li a').first
          next unless id_tag_element

          id_tag_element_json = JSON.parse(id_tag_element.attr('data-story-info'))

          next unless id_tag_element_json.key?('id')
          legacy_id = id_tag_element_json['id']

          title = row.search('.story-heading').text

          status_name = row.search('.btn.btn-success.base-indent-right').first ? 'Active' : 'Inactive'
          queue_name = row.search('.dropdown-toggle').first.text.strip!
          img_element = row.search('img')

          if img_element.first
            image = "#{@base_url}#{img_element.first.attr('src').gsub('/s/', '/l/')}"
          end

          db_id = row.search('.story-id a').first.text.delete('#')
          story_slug = row.search('.story-id span').first.text
          data << {
            id: legacy_id,
            object: 'story',
            db_id: db_id,
            title: title,
            slug: story_slug,
            status: status_name,
            queue: queue_name,
            image: image ? image : ''
          }
        end
        data
      end

      def serialize_from_lineitems(rows)
        data = rows.map do |row|
          new_row = {}

          line_item_link = row.search('.line-item-link').first
          if line_item_link
            new_row[:name] = line_item_link.text
            new_row[:link] = line_item_link.attr('href')
          end

          # check for btn-primary (edit usually)
          edit_button = row.search('.btn-primary').first

          if edit_button
            if edit_button.attr('data-item-open-popup')
              new_row[:id] = edit_button.attr('data-item-open-popup')
            end
            if edit_button.attr('data-trendwatcher-open-popup')
              new_row[:id] = edit_button.attr('data-trendwatcher-open-popup')
            end
            if edit_button.attr('data-guide-open-popup')
              new_row[:id] = edit_button.attr('data-guide-open-popup')
            end
          end

          status_label = row.search('span.label').first

          new_row[:status] = status_label.text.downcase if status_label
          new_row[:object] = class_name.downcase
          new_row unless new_row[:id] == 'delete selected' || !new_row[:id] || new_row[:id].blank?
        end
        # pp data
        data
      end

      def serialize_from_table(columns, rows)
        column_map = {}
        column_index = {}
        columns.each_with_index do |column, i|
          next if column.text.blank?
          column_name = column.text.camelize.gsub('#', 'sequence').delete(' ').underscore
          column_index[i] = column_name
          column_map[:"#{column_name}"] = nil
        end

        data = rows.map do |row|
          new_row = column_map.dup
          edit_button = row.search('.btn-primary').first
          if row.attr('data-record-id')
            new_row[:id] = row.attr('data-record-id')
          elsif edit_button
            if edit_button.attr('data-item-open-popup')
              new_row[:id] = edit_button.attr('data-item-open-popup')
            end
            if edit_button.attr('data-source-open-popup')
              new_row[:id] = edit_button.attr('data-source-open-popup')
            end
          end

          row.children.each_with_index do |column, i|
            column_text = column.text
            if column_index[i] == 'status'
              column_text = column.search('.btn').first.text.strip!
            end

            new_row[:"#{column_index[i]}"] = column_text
          end
          new_row[:object] = class_name.downcase
          new_row if new_row[:sequence] != 'delete selected'
        end
        # pp data
        data
      end

      def list(opts = {})
        params = if list_params
                   list_params.merge(opts)
                 else
                   opts
                 end

        page = request(path: list_resource_url, method: 'post', params: params)
        if %w[Category Partner].include?(class_name)
          form = page.forms.first

          data = serialize_from_dropdown_items(form.field_with(name: dropdown_name).options)
        elsif class_name == 'User'
          # GET USERS SELECT
          form = page.forms.first

          data = serialize_from_users(form.field_with(name: 'filter_owner').options)
        else
          recordsForm = page.search('#recordsForm').first

          data = if recordsForm
                   # recordsForm flow
                   serialize_from_table(recordsForm.search('thead th'), recordsForm.search('tbody tr'))
                 else
                   if page.search('.box-content .line-item').first
                     serialize_from_lineitems(page.search('.box-content .line-item'))
                   else
                     serialize_from_stories(page.search('.stories-list .story'))
                   end
                 end
        end

        records = data.map do |record|
          new(record[:id]).send(:initialize_from, record, {}) if record
        end

        obj = {
          object: 'list',
          data: records.compact
        }
        ListObject.construct_from(obj)
      end

      # The original version of #list was given the somewhat unfortunate name of
      # #all, and this alias allows us to maintain backward compatibility (the
      # choice was somewhat misleading in the way that it only returned a single
      # page rather than all objects).
      alias all list
    end
  end
end
