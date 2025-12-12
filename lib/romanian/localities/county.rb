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
          (name.blank? || state[:name]&.upcase&.unicode_normalize(:nfkd)&.gsub(/[^\x00-\x7F]/,'').to_s == name.upcase.unicode_normalize(:nfkd)&.gsub(/[^\x00-\x7F]/,'').to_s) && (prefix.blank? || state[:prefix]&.upcase&.unicode_normalize(:nfkd)&.gsub(/[^\x00-\x7F]/,'').to_s == prefix.upcase.mb_chars.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/n, '').to_s)
        end

        if county_data.present?
          County.new(
            name: county_data[:name],
            prefix: county_data[:prefix],
            localities_raw_data: county_data[:localities]
          )
        end
      end

      def self.closest_match_for(name, max_dist: 3)
        raise 'Missing parameter :name' if name.blank?
        assure_data_loaded!

        raw_input = name.to_s
        input = normalize_county_query(name)
        states = Romanian::LOCALITY_DATA[:states]

        # 0) quick aliases (common exonyms/phrases)
        if (pref = alias_to_prefix(input))
          if (exact = get(prefix: pref))
            return exact
          end
        end

        # 1) exact match by prefix (BV, CJ, etc.)
        if input.match?(/\A[A-Z]{1,2}\z/)
          if (exact = get(prefix: input))
            return exact
          end
        end

        # 2) exact match by name (normalized)
        if (exact_state = states.detect { |state| normalize_county_query(state[:name]) == input })
          return build_from_state(exact_state)
        end

        # 3) fuzzy match with composite scoring (distance + token overlap + startswith bonus)
        best_state = nil
        best_parts = nil
        best_score = Float::INFINITY

        states.each do |state|
          score, parts = composite_score(input, state)
          if score < best_score
            best_score = score
            best_state = state
            best_parts = parts
          end
        end

        unless best_state
          # Fallback: if input mentions a Bucharest sector (1..6), prefer Bucharest
          return prefer_bucharest_if_sector(raw_input)
        end

        # Guardrails: ensure the chosen match is not too far
        raw_dist = best_parts[:min_dist]
        overlap  = best_parts[:overlap]

        # Dynamic acceptance threshold (stricter for short inputs)
        dyn = [max_dist, (input.length / 4.0).ceil].max

        # Accept if distance under dyn or if strong token overlap
        if raw_dist > dyn && overlap < 0.5
          # Final fallback: detect generic sector mentions (1..6) → Bucharest
          return prefer_bucharest_if_sector(raw_input)
        end

        build_from_state(best_state)
      end

      # -------------------------
      # helpers (class-private)
      # -------------------------
      class << self
        private

        def normalize_county_query(str)
          s = str.to_s.strip

          # strip common leading words found in addresses / exports
          s = s.sub(/\A\s*(?:JUDE[TȚ](?:UL)?|JUD\.?|MUNICIPIUL|MUN\.?|SECTORUL)\s*/i, '')

          # uppercase + remove diacritics (same idea as your existing get)
          s = s.upcase
          s = s.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/, '').to_s

          # normalize punctuation/spaces
          s = s.gsub(/[^A-Z0-9]+/, ' ').strip
          s = s.gsub(/\s+/, ' ')

          # drop trailing/leading words that are clearly not county signals
          # e.g. "SECTOR 1" should map to Bucuresti county → keep only BUCURESTI if present
          s
        end

        def build_from_state(state)
          return nil unless state
          County.new(
            name: state[:name],
            prefix: state[:prefix],
            localities_raw_data: state[:localities]
          )
        end

        # Levenshtein distance (iterative DP)
        def levenshtein(a, b)
          a = a.to_s
          b = b.to_s
          return b.length if a.empty?
          return a.length if b.empty?

          prev = (0..b.length).to_a
          curr = Array.new(b.length + 1, 0)

          a.each_char.with_index(1) do |ac, i|
            curr[0] = i
            b.each_char.with_index(1) do |bc, j|
              cost = (ac == bc) ? 0 : 1
              curr[j] = [
                curr[j - 1] + 1,      # insertion
                prev[j] + 1,          # deletion
                prev[j - 1] + cost    # substitution
              ].min
            end
            prev, curr = curr, prev
          end

          prev[b.length]
        end

        # Map some popular aliases/exonyms to county prefixes
        def alias_to_prefix(input_norm)
          case input_norm
          when 'BUCURESTI', 'BUCHAREST', 'BUCURESTI MUNICIPIU', 'MUNICIPIUL BUCURESTI', 'MUN BUCURESTI'
            'B'
          when /\ABUCURESTI SECTOR \d\z/
            'B'
          else
            nil
          end
        end

        # Detects if the raw input refers to a Bucharest sector (1..6), even without explicitly saying Bucuresti.
        # Matches variants like: "Sector 3", "sect. 4", "Sectorul-5".
        def sector_refers_to_bucharest?(raw)
          s = raw.to_s
          # Case-insensitive, allow diacritics removal not needed here; accept optional punctuation/hyphen and optional "ul"
          !!(s =~ /\bSECT(?:OR|\.?)(?:UL)?\s*[- ]*([1-6])\b/i)
        end

        def prefer_bucharest_if_sector(raw)
          sector_refers_to_bucharest?(raw) ? get(prefix: 'B') : nil
        end

        # Compute a composite score for a county candidate
        # Returns [score(Float), parts(Hash)]
        def composite_score(input, state)
          state_name = normalize_county_query(state[:name])
          state_code = normalize_county_query(state[:prefix])

          d_name  = levenshtein(input, state_name)
          d_code  = levenshtein(input, state_code)
          d_combo = levenshtein(input, "#{state_code} #{state_name}")
          min_dist = [d_name, d_code, d_combo].min

          # Token overlap on words
          tokens_in  = input.split(' ')
          tokens_nm  = state_name.split(' ')
          overlap_cnt = (tokens_in & tokens_nm).length
          overlap_ratio = if tokens_in.empty? && tokens_nm.empty?
                            1.0
                          elsif tokens_in.empty? || tokens_nm.empty?
                            0.0
                          else
                            overlap_cnt.to_f / [tokens_in.length, tokens_nm.length].max
                          end

          # Startswith bonuses
          starts_bonus = 0
          starts_bonus += 1 if state_name.start_with?(input) || input.start_with?(state_name)
          starts_bonus += 0.5 if input.include?(state_code)

          # Prefer exact code match strongly
          exact_code_bonus = (d_code == 0) ? 3 : 0

          # Final score: lower is better
          bonus = (overlap_ratio >= 0.5 ? 1.0 : 0.0) + starts_bonus + exact_code_bonus
          score = min_dist - bonus

          [score, { min_dist: min_dist, overlap: overlap_ratio, d_name: d_name, d_code: d_code, d_combo: d_combo }]
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
