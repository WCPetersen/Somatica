require 'tsort'
#Dir["#{Rails.root}/app/models/**/*.rb"].each do |path|
#  require path
#end

module Somatica
  module LoadOrdering
    class LoadChain
      include TSort

      attr_reader :models
      attr_reader :load_order

      def initialize(somatic_models)
        @connections = Hash.new { |h,k| h[k] = Set.new }
        somatic_models.each do |somatic_model|
          links = []
          owner_class = somatic_model.owner_class
          somatic_model.includes.each do |name|
            reflection = owner_class.reflect_on_association(name.to_sym)
            links << reflection.klass unless reflection.nil?
          end

          @connections[somatic_model.js_class].merge links
        end
        @models = (@connections.keys + @connections.values.map(&:to_a)).flatten.uniq
        @load_order = strongly_connected_components.reverse
      end

      def tsort_each_node(&block)
        @models.each(&block)
      end

      def tsort_each_child(model, &block)
        @connections[model].each(&block) if @connections.has_key?(model)
      end
    end

    models = ActiveRecord::Base.descendants.select { |m| m.respond_to?(:somatic_models) }
    somatic_models = models.collect_concat { |m| m.somatic_models.values }
    chain = LoadChain.new(somatic_models)
    Somatica::LOAD_ORDER = chain.load_order
    Somatica::LINKED_MODELS = chain.models
  end
end
