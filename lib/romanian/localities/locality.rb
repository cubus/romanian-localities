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
          (locality.name&.upcase&.unicode_normalize(:nfkd)&.gsub(/[^\x00-\x7F]/,'').to_s == name.upcase&.unicode_normalize(:nfkd)&.gsub(/[^\x00-\x7F]/,'').to_s) && (parent_locality.blank? || locality.parent_locality&.upcase&.unicode_normalize(:nfkd)&.gsub(/[^\x00-\x7F]/,'').to_s == parent_locality&.upcase&.unicode_normalize(:nfkd)&.gsub(/[^\x00-\x7F]/,'').to_s)
        end

        locality
      end

      def self.closest_match_for(name, county: nil, max_dist: 3)

        raise 'name missing' if name.blank?
        raise 'county missing' if county.blank?

        assure_data_loaded!

        # Resolve county by its name/prefix or fuzzy
        county_obj = resolve_county(county)
        return nil unless county_obj

        candidates = county_obj.localities

        input_norm = normalize_locality_query(name)

        # 1) try exact by raw name (case-insensitive)
        if (exact = candidates.find { |loc| loc.name&.upcase == name.to_s.upcase })
          return exact
        end

        # 2) try exact by diacritics-stripped name or provided normalized_name
        if (exact2 = candidates.find do |loc|
              ln  = normalize_locality_query(loc.name)
              lnn = normalize_locality_query(loc.normalized_name)
              ln == input_norm || lnn == input_norm
            end)
          return exact2
        end

        # 3) prioritize locality names that start with the search term (normalized)
        prefix_matches = candidates.select do |loc|
          ln  = normalize_locality_query(loc.name)
          lnn = normalize_locality_query(loc.normalized_name)
          ln.start_with?(input_norm) || lnn.start_with?(input_norm)
        end

        unless prefix_matches.empty?
          # pick the one with the shortest remainder after the prefix match
          best_prefix = prefix_matches.min_by do |loc|
            ln  = normalize_locality_query(loc.name)
            lnn = normalize_locality_query(loc.normalized_name)
            remainders = []
            remainders << (ln.length - input_norm.length) if ln.start_with?(input_norm)
            remainders << (lnn.length - input_norm.length) if lnn.start_with?(input_norm)
            remainders.min || 0
          end
          return best_prefix
        end

        # 4) fuzzy within county — Levenshtein over normalized strings
        pairs = candidates.map do |loc|
          ln  = normalize_locality_query(loc.name)
          lnn = normalize_locality_query(loc.normalized_name)
          d1 = Romanian::Localities::County.send(:levenshtein, input_norm, ln)
          d2 = Romanian::Localities::County.send(:levenshtein, input_norm, lnn)
          d  = [d1, d2].compact.min
          d ? [d, loc] : nil
        end.compact

        best_dist, best_loc = pairs.min_by { |pair| pair.first } || [nil, nil]

        return nil if best_loc.nil?

        # dynamic guardrail: do not accept very distant matches for short inputs
        dyn = [max_dist.to_i, (input_norm.length / 4.0).ceil].max
        best_dist <= dyn ? best_loc : nil
      end

      class << self
        private

        # Normalization similar to County.normalize_county_query, but tailored for localities
        def normalize_locality_query(str)
          s = str.to_s.strip.upcase
          s = s.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/, '')
          s = s.gsub(/[^A-Z0-9]+/, ' ').strip
          s.gsub(/\s+/, ' ')
        end

        def resolve_county(county)
          County.get(name: county) || County.get(prefix: county) || County.closest_match_for(county)
        end
      end
    end
  end
end
# Romanian::Localities::Locality.get(name: "Braşov")