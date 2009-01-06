require 'extlib/inflection'
require 'shoulda'
require 'shoulda/data_mapper/assertions'
require 'shoulda/data_mapper/macros'

module Test # :nodoc: all
  module Unit
    class TestCase
      include Shoulda::DataMapper::Assertions
      extend Shoulda::DataMapper::Macros
    end
  end
end

class String
  def camelize
    Extlib::Inflection.camelize(self)
  end

  def classify
    Extlib::Inflection.classify(self)
  end

  def constantize
    Extlib::Inflection.constantize(self)
  end
end
