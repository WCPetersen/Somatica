module Somatica
  class Parcel
    def initialize
      @unloaded_models = Set.new
      @stubs = []
    end

    def stub(arg, *more)
      flat = [arg].flatten
      @unloaded_models.merge flat
      @stubs.push *flat
      more.each { |r| stub(r) }
    end

    def add(arg, *more)
      @unloaded_models.merge [arg].flatten
      more.each { |r| add(r) }
      true
    end

    # @todo [create array-style index for model loading (part 1)] [shortens generated javascript] [(time)] []
    def compressed_tables
      @compressed_tables ||= tables.map do |klass, models|
        [klass, models.collect { |model| model.somatic_map.values }]
      end
    end

    def tables
      @unloaded_models.subtract @stubs
      prepare
      @model_tables.reject { |_, models| models.empty? }
    end

    def prepare
      @model_tables = Hash.new { |h,k| h[k] = Set.new }
      @model_tables.merge! @somatic_models.classify { |m| (defined? m.js_class) ? m.js_class : m.class }

      LOAD_ORDER.each do |classes|
        if classes.length == 1
          klass = classes.first
          models = @model_tables[klass]
          load_single_table(klass, models) unless models.empty?
        else
          added_sets = Hash.new { |h,k| h[k] = Set.new }
          loop do
            classes.each do |c|
              added = added_sets[c]
              models = @model_tables[c] - added
              load_single_table(c, models) unless models.empty?
              added.merge models
            end
            break if classes.all? { |c| @model_tables[c].length == added_sets[c].length }
          end
        end
      end
    end

    private

    def load_single_table(klass, models)
      return unless defined? klass.somatic_includes
      preloader = SomaticPreloader.new(models.reject { |r| r.is_a? ModelWrapper }, klass.somatic_includes)
      preloader.run
      klass.somatic_includes.each do |assoc|
        assoc = assoc.to_sym
        related_class = klass.reflect_on_association(assoc).klass
        related_class = related_class.js_class if defined? related_class.js_class
        related_models = preloader.records.collect_concat { |m| m.association(assoc).target }.uniq - @stubs
        @model_tables[related_class].merge related_models
      end
    end
  end

  class SomaticPreloader < ActiveRecord::Associations::Preloader
    def preload_one(association)
      grouped_records(association).each do |reflection, klasses|
        klasses.each do |klass, records|
          not_loaded = records.reject { |r| r.association(association).loaded? }
          preloader_for(reflection).new(klass, not_loaded, reflection, options).run unless not_loaded.empty?
        end
      end
    end
  end
end
