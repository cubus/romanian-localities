# frozen_string_literal: true

module Romanian
  module Localities
    class County < Base      
      attr_accessor :name
      attr_accessor :prefix      
      attr_accessor :localities_raw_data
      attr_accessor :localities_array

      def initialize(name: nil, prefix: nil, localities_raw_data: nil, localities_array: nil)
        @name = name
        @prefix = prefix
        @localities_raw_data = localities_raw_data
        @localities_array = localities_array
      end

      def localities 
        @localities_array ||= localities_raw_data.collect do |raw|
          Locality.new(
            name: raw[:name], 
            normalized_name: raw[:normalized_name],
            parent_locality: raw[:parent_locality], 
            county: self
          )          
        end
      end  

      def self.get(name: nil, prefix: nil)        
        if name.blank? && prefix.blank?
          raise 'Missing parameters!. At least of the named params :name or :prefix required'
        end
        assure_data_loaded!  

        county_data = Romanian::LOCALITY_DATA[:states].detect do |state|           
          (name.blank? || state[:name]&.upcase == name&.upcase) && (prefix.blank? || state[:prefix]&.upcase == prefix&.upcase)
        end
        
        county_data ||= Romanian::LOCALITY_DATA[:states].detect do |state|              
          (name.blank? || state[:name]&.upcase&.mb_chars&.normalize(:kd)&.gsub(/[^x00-\x7F]/n, '').to_s == name.upcase.mb_chars.normalize(:kd).gsub(/[^x00-\x7F]/n, '').to_s) && (prefix.blank? || state[:prefix]&.upcase&.mb_chars&.normalize(:kd)&.gsub(/[^x00-\x7F]/n, '').to_s == prefix.upcase.mb_chars.normalize(:kd).gsub(/[^x00-\x7F]/n, '').to_s)
        end

        if county_data.present?        
          County.new(
            name: county_data[:name],
            prefix: county_data[:prefix],
            localities_raw_data: county_data[:localities]
          )
        end
      end  
      
      def self.all 
        assure_data_loaded!  
        Romanian::LOCALITY_DATA[:states].collect do |county_data|           
          County.new(
            name: county_data[:name],
            prefix: county_data[:prefix],
            localities_raw_data: county_data[:localities]
          )
        end
      end

    end
  end
end
