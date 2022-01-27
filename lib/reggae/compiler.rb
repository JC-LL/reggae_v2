require_relative 'parser'
require_relative 'parser'

module Reggae

  class Compiler
    attr_accessor :options
    def compile filename
      ast=Parser.new.parse(filename)
    end
  end

end
