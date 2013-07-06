require 'active_support/core_ext/time/zones'

# encoding: UTF-8
module MongoMapper
  module Extensions
    module Time
      def to_mongo(value)
        if !value || '' == value
          nil
        else
          time_class = ::Time.zone || ::Time
          time = value.is_a?(::Time) ? value : time_class.parse(value.to_s)
          if time
            # Time#to_f seems to automatically round on 1.9+, so we can construct the fractional time manually
            f_time = time.tv_sec + (time.usec / 1000000.0)

            # Then round it to 3 decimals
            at((f_time * 1000.0).to_i / 1000.0).utc
          end
        end
      end

      def from_mongo(value)
        if value and zone = ::Time.zone
          value.in_time_zone(zone)
        else
          value
        end
      end

    end
  end
end

class Time
  extend MongoMapper::Extensions::Time
end