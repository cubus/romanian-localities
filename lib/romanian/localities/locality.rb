# frozen_string_literal: true

module Romanian
  module Localities
    class Locality < Base 
      attr_accessor :name    
      attr_accessor :normalized_name
      attr_accessor :parent_locality
      attr_accessor :county

      def initialize(name: nil, normalized_name: nil, parent_locality: nil, county: nil)
        @name = name
        @normalized_name = normalized_name
        @parent_locality = parent_locality
        @county = county
      end

      def self.get(name: nil, parent_locality: nil, county: nil)
        if name.blank?
          raise 'Missing parameters!. At least of the named params :name is required'
        end
        assure_data_loaded!

        eligible_counties = [(county || County.all)].flatten
        eligible_localities = eligible_counties.collect(&:localities).flatten


        locality = eligible_localities.detect do |locality|
          (locality.name&.upcase == name.upcase) && (parent_locality.blank? || locality.parent_locality&.upcase == parent_locality&.upcase)
        end
          
        locality ||= eligible_localities.detect do |locality|
          (locality.name&.upcase&.mb_chars&.normalize(:kd)&.gsub(/[^x00-\x7F]/n, '').to_s == name.upcase&.mb_chars&.normalize(:kd)&.gsub(/[^x00-\x7F]/n, '').to_s) && (parent_locality.blank? || locality.parent_locality&.upcase&.mb_chars&.normalize(:kd)&.gsub(/[^x00-\x7F]/n, '').to_s == parent_locality&.upcase&.mb_chars&.normalize(:kd)&.gsub(/[^x00-\x7F]/n, '').to_s)
        end

        locality
      end       
    end
  end
end
# Romanian::Localities::Locality.get(name: "Braşov")