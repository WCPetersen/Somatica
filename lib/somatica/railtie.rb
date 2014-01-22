require "somatica/model"

module Somatica
  class Railtie < Rails::Railtie
    initializer "somatica.extend_active_record" do
      ActiveSupport.on_load(:active_record) do
        def somatic_model(*args, &block)
          Somatica::Model.find_or_create(self, *args, &block)
        end
      end
    end
    config.after_initialize do
      require "somatica/load_order"
    end
  end
end
