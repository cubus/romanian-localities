# frozen_string_literal: true

module Romanian
  module Localities    
    class Base      
      def self.assure_data_loaded!        
        require_relative '../locality_data.rb' unless defined?(Romanian::LOCALITY_DATA)
      end

      def string_equals(a, b)
        a.to_s.upcase == b.to_s.upcase
      end

    end
  end
end