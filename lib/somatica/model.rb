module Somatica
  class Model
    class << self
      def find_or_create(owner_class, *args, &block)
        options = args.last.is_a?(Hash) ? args.pop : {}
        name = args.first || :default

        if owner_class.respond_to?(:somatic_models) && model = owner_class.somatic_models[name]
          if model.owner_class != owner_class && (options.any? || block_given?)
            model = model.clone
            model.owner_class = owner_class
          end
          model.instance_eval(&block) if block_given?
        else
          model = new(owner_class, name, options, &block)
        end
        model
      end
    end

    attr_reader :owner_class, :name, :js_class, :columns, :includes, :map

    def initialize(owner_class, name, options, &block)
      @name = name
      @js_class = options[:js_class] || owner_class
      @columns = options[:columns] || []
      @includes = options[:includes] || []
      self.owner_class = owner_class
      map options[:map]
      instance_eval(&block) if block_given?
    end

    def includes(*args)
      @includes.concat args
    end

    def map(arg = nil, &block)
      return @map if arg.nil? && !block_given?
      @map = arg || block
      method_name = "#{name}_somatic_map"
      action = @map.is_a?(Proc) ? @map : -> { @map }
      owner_class.send(:define_method, method_name, @map)
      @map
    end

    def owner_class=(klass)
      @owner_class = klass
      owner_class.class_eval do
        @somatic_models ||= Hash.new
        def self.somatic_models
          @somatic_models ||= superclass.somatic_models.dup
        end
      end
      owner_class.somatic_models[name] = self
    end
  end
end
