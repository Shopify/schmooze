module Schmooze
  Error = Class.new(StandardError)
  DependencyError = Class.new(Error)
  module JavaScript
    Error = Class.new(::Schmooze::Error)
    UnknownError = Class.new(Error)
    def self.const_missing(name)
      const_set(name, Class.new(Error))
    end
  end
end
