module Cars
  class LegacyObject
    include Enumerable

    @@permanent_attributes = Set.new([:id])

    # The default :id method is deprecated and isn't useful to us
    undef :id if method_defined?(:id)

    def initialize(id = nil, opts = {})
      id, @retrieve_params = Util.normalize_id(id)
      @opts = opts
      @original_values = {}
      @values = {}
      # This really belongs in APIResource, but not putting it there allows us
      # to have a unified inspect method
      @unsaved_values = Set.new
      @transient_values = Set.new
      @values[:id] = id if id
    end

    def self.construct_from(values, _opts = {})
      values = Cars::Util.symbolize_names(values)
      # work around protected #initialize_from for now
      new(values[:id]).send(:initialize_from, values, {})
    end

    def ==(other)
      other.is_a?(LegacyObject) && @values == other.instance_variable_get(:@values)
    end

    def to_s(*_args)
      JSON.pretty_generate(to_hash)
    end

    def inspect
      id_string = respond_to?(:id) && !id.nil? ? " id=#{id}" : ''
      "#<#{self.class}:0x#{object_id.to_s(16)}#{id_string}> JSON: " + JSON.pretty_generate(@values)
    end

    def [](k)
      # pp 'In []'
      @values[k.to_sym]
    end

    def []=(k, v)
      send(:"#{k}=", v)
    end

    def keys
      @values.keys
    end

    def values
      @values.values
    end

    def to_json(*_a)
      JSON.generate(@values)
    end

    def as_json(*a)
      @values.as_json(*a)
    end

    def to_hash
      maybe_to_hash = lambda do |value|
        value.respond_to?(:to_hash) ? value.to_hash : value
      end

      @values.each_with_object({}) do |(key, value), acc|
        acc[key] = case value
                   when Array
                     value.map(&maybe_to_hash)
                   else
                     maybe_to_hash.call(value)
                   end
      end
    end

    def each(&blk)
      @values.each(&blk)
    end

    def serialize_params(options = {})
      update_hash = {}

      @values.each do |k, v|
        # There are a few reasons that we may want to add in a parameter for
        # update:
        #
        #   1. The `force` option has been set.
        #   2. We know that it was modified.
        #   3. Its value is a LegacyObject. A LegacyObject may contain modified
        #      values within in that its parent LegacyObject doesn't know about.
        #
        unsaved = @unsaved_values.include?(k)
        if options[:force] || unsaved || v.is_a?(LegacyObject)
          update_hash[k.to_sym] =
            serialize_params_value(@values[k], @original_values[k], unsaved, options[:force], key: k)
        end
      end

      # a `nil` that makes it out of `#serialize_params_value` signals an empty
      # value that we shouldn't appear in the serialized form of the object
      update_hash.reject! { |_, v| v.nil? }

      update_hash
    end

    class << self
      # This class method has been deprecated in favor of the instance method
      # of the same name.
      def serialize_params(obj, options = {})
        obj.serialize_params(options)
      end
      extend Gem::Deprecate
      deprecate :serialize_params, '#serialize_params', 2016, 9
    end

    # A protected field is one that doesn't get an accessor assigned to it
    # (i.e. `obj.public = ...`) and one which is not allowed to be updated via
    # the class level `Model.update(id, { ... })`.
    def self.protected_fields
      []
    end

    protected

    def metaclass
      class << self; self; end
    end

    def remove_accessors(keys)
      # not available in the #instance_eval below
      protected_fields = self.class.protected_fields

      metaclass.instance_eval do
        keys.each do |k|
          next if protected_fields.include?(k)
          next if @@permanent_attributes.include?(k)

          # Remove methods for the accessor's reader and writer.
          [k, :"#{k}=", :"#{k}?"].each do |method_name|
            remove_method(method_name) if method_defined?(method_name)
          end
        end
      end
    end

    def add_accessors(keys, values)
      # not available in the #instance_eval below
      protected_fields = self.class.protected_fields

      metaclass.instance_eval do
        keys.each do |k|
          next if protected_fields.include?(k)
          next if @@permanent_attributes.include?(k)

          define_method(k) { @values[k] }
          define_method(:"#{k}=") do |v|
            if v == ''
              raise ArgumentError, "You cannot set #{k} to an empty string. " \
                'We interpret empty strings as nil in requests. ' \
                "You may set (object).#{k} = nil to delete the property."
            end
            @values[k] = Util.convert_to_legacy_object(v, @opts)
            dirty_value!(@values[k])
            @unsaved_values.add(k)
          end

          if [FalseClass, TrueClass].include?(values[k].class)
            define_method(:"#{k}?") { @values[k] }
          end
        end
      end
    end

    def method_missing(name, *args)
      # TODO: only allow setting in updateable classes.
      if name.to_s.end_with?('=')
        attr = name.to_s[0...-1].to_sym

        # Pull out the assigned value. This is only used in the case of a
        # boolean value to add a question mark accessor (i.e. `foo?`) for
        # convenience.
        val = args.first

        # the second argument is only required when adding boolean accessors
        add_accessors([attr], attr => val)

        begin
          mth = method(name)
        rescue NameError
          raise NoMethodError, "Cannot set #{attr} on this object. HINT: you can't set: #{@@permanent_attributes.to_a.join(', ')}"
        end
        return mth.call(args[0])
      elsif @values.key?(name)
        return @values[name]
      end

      begin
        super
      rescue NoMethodError => e
        # If we notice the accessed name if our set of transient values we can
        # give the user a slightly more helpful error message. If not, just
        # raise right away.
        raise unless @transient_values.include?(name)

        raise NoMethodError, e.message + ".  HINT: The '#{name}' attribute was set in the past, however.  It was then wiped when refreshing the object with the result returned by Cars's Dashboard, probably as a result of a save().  The attributes currently available on this object are: #{@values.keys.join(', ')}"
      end
    end

    def respond_to_missing?(symbol, include_private = false)
      @values && @values.key?(symbol) || super
    end

    # Re-initializes the object based on a hash of values (usually one that's
    # come back from an Dashboard call). Adds or removes value accessors as necessary
    # and updates the state of internal data.
    #
    # Protected on purpose! Please do not expose.
    #
    # ==== Options
    #
    # * +:values:+ Hash used to update accessors and values.
    # * +:opts:+ Options for LegacyObject like an Dashboard key.
    # * +:partial:+ Indicates that the re-initialization should not attempt to
    #   remove accessors.
    def initialize_from(values, opts, partial = false)
      @opts = Util.normalize_opts(opts)
      # @opts = {}
      # the `#send` is here so that we can keep this method private
      @original_values = self.class.send(:deep_copy, values)
      # pp @original_values
      removed = partial ? Set.new : Set.new(@values.keys - values.keys)
      added = Set.new(values.keys - @values.keys)

      remove_accessors(removed)
      add_accessors(added, values)

      removed.each do |k|
        @values.delete(k)
        @transient_values.add(k)
        @unsaved_values.delete(k)
      end

      update_attributes(values, opts, dirty: false)
      values.each_key do |k|
        @transient_values.delete(k)
        @unsaved_values.delete(k)
      end

      self
    end

    def update_attributes(values, opts = {}, method_options = {})
      # Default to true. TODO: Convert to optional arguments after we're off
      # 1.9 which will make this quite a bit more clear.
      dirty = method_options.fetch(:dirty, true)
      values.each do |k, v|
        add_accessors([k], values) unless metaclass.method_defined?(k.to_sym)
        @values[k] = Util.convert_to_legacy_object(v, opts)
        dirty_value!(@values[k]) if dirty
        @unsaved_values.add(k)
      end
    end

    def serialize_params_value(value, original, unsaved, force, key: nil)
      if value.nil?
        ''

      # The logic here is that essentially any object embedded in another
      # object that had a `type` is actually an Dashboard resource of a different
      # type that's been included in the response. These other resources must
      # be updated from their proper endpoints, and therefore they are not
      # included when serializing even if they've been modified.
      #
      # There are _some_ known exceptions though.
      #
      # For example, if the value is unsaved (meaning the user has set it), and
      # it looks like the Dashboard resource is persisted with an ID, then we include
      # the object so that parameters are serialized with a reference to its
      # ID.
      #
      # Another example is that on save Dashboard calls it's sometimes desirable to
      # update a customer's default source by setting a new card (or other)
      # object with `#source=` and then saving the customer. The
      # `#save_with_parent` flag to override the default behavior allows us to
      # handle these exceptions.
      #
      # We throw an error if a property was set explicitly but we can't do
      # anything with it because the integration is probably not working as the
      # user intended it to.
      elsif value.is_a?(LegacyResource) && !value.save_with_parent
        if !unsaved
          nil
        elsif value.respond_to?(:id) && !value.id.nil?
          value
        else
          raise ArgumentError, "Cannot save property `#{key}` containing " \
            "an Dashboard resource. It doesn't appear to be persisted and is " \
            'not marked as `save_with_parent`.'
        end

      elsif value.is_a?(Array)
        update = value.map { |v| serialize_params_value(v, nil, true, force) }

        # This prevents an array that's unchanged from being resent.
        update if update != serialize_params_value(original, nil, true, force)

      # Handle a Hash for now, but in the long run we should be able to
      # eliminate all places where hashes are stored as values internally by
      # making sure any time one is set, we convert it to a LegacyObject. This
      # will simplify our model by making data within an object more
      # consistent.
      #
      # For now, you can still run into a hash if someone appends one to an
      # existing array being held by a LegacyObject. This could happen for
      # example by appending a new hash onto `additional_owners` for an
      # account.
      elsif value.is_a?(Hash)
        Util.convert_to_stripe_object(value, @opts).serialize_params

      elsif value.is_a?(LegacyObject)
        update = value.serialize_params(force: force)

        # If the entire object was replaced, then we need blank each field of
        # the old object that held a value. The new serialized values will
        # override any of these empty values.
        update = empty_values(original).merge(update) if original && unsaved

        update

      else
        value
      end
    end

    private

    # Produces a deep copy of the given object including support for arrays,
    # hashes, and LegacyObjects.
    def self.deep_copy(obj)
      case obj
      when Array
        obj.map { |e| deep_copy(e) }
      when Hash
        obj.each_with_object({}) do |(k, v), copy|
          copy[k] = deep_copy(v)
          copy
        end
      when LegacyObject
        LegacyObject.construct_from(
          deep_copy(obj.instance_variable_get(:@values)),
          # obj.instance_variable_get(:@opts).select do |k, _v|
          #   Util::OPTS_COPYABLE.include?(k)
          # end
        )
      else
        obj
      end
    end
    private_class_method :deep_copy

    def dirty_value!(value)
      case value
      when Array
        value.map { |v| dirty_value!(v) }
      when LegacyObject
        value.dirty!
      end
    end

    # Returns a hash of empty values for all the values that are in the given
    # LegacyObject.
    def empty_values(obj)
      values = case obj
               when Hash         then obj
               when LegacyObject then obj.instance_variable_get(:@values)
               else
                 raise ArgumentError, "#empty_values got unexpected object type: #{obj.class.name}"
               end

      values.each_with_object({}) do |(k, _), update|
        update[k] = ''
      end
    end
  end
end
