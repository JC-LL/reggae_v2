module Reggae
  class AstNode
    def accept(visitor, arg=nil)
       name = self.class.name.split(/::/).last
       visitor.send("visit#{name}".to_sym, self ,arg) # Metaprograming !
    end

    def str
      ppr=PrettyPrinter.new
      self.accept(ppr)
    end
  end

  class RegMap < AstNode
    attr_accessor :name
    attr_accessor :bus
    attr_accessor :ips
  end

  class Bus < AstNode
    attr_accessor :name
    attr_accessor :addr_size
    attr_accessor :data_size
  end

  class Ip < AstNode
    attr_accessor :name
    attr_accessor :addr_range
    attr_accessor :regs
    attr_accessor :is_bram
  end

  class Reg < AstNode
    attr_accessor :name
    attr_accessor :addr
    attr_accessor :init
    attr_accessor :bits
    attr_accessor :bitfields
  end

  class Bit < AstNode
    attr_accessor :name
    attr_accessor :toggling
  end

  class Bitfield < AstNode
    attr_accessor :range
    attr_accessor :name
  end

  class AddrRange < AstNode
    attr_accessor :start,:end
  end

end
