module Reggae

  class Compiler
    attr_accessor :options
    def compile filename
      model  = Parser.new.parse(filename)
      code   = VHDLGen.new.generate(model)
      script = HostScript.new.generate(model)
    end
  end

end
