require 'sxp'
module Reggae

  class Parser

    def parse filename
      puts "=> parsing '#{filename}'".green
      sxp=SXP.read IO.read(filename)
      pp ast=objectify(sxp)
    end

    def objectify sxp
      parse_regmap(sxp)
    end

    def say txt
      puts txt.to_s.light_green
    end

    # (header value) => return value
    def parse_single sxp
      sxp.last
    end

    def parse_regmap sxp
      say "parse regmap"
      map=RegMap.new
      map.ips=[]
      if header(sxp)==:regmap
        sxp.shift
        map.name= sxp.shift
        map.bus = parse_bus(sxp.shift)
        while sxp.any?
          map.ips << parse_ip(sxp.shift)
        end
      else
        puts "syntax error : expecting 'soc' as s-expression header"
      end
      map
    end

    def parse_bus sxp
      say "parse bus"
      bus=Bus.new
      if (header=header(sxp))==:bus
        header   = sxp.shift
        bus.name = sxp.shift
        bus.addr_size=parse_single(sxp.shift)
        bus.data_size=parse_single(sxp.shift)
      else
        puts "syntax error : expecting 'bus' as s-expression header. got #{header}"
      end
      bus
    end

    def parse_ip sxp
      say "parse ip"
      ip=Ip.new
      ip.regs=[]
      if (header=header(sxp))==:ip
        header  = sxp.shift
        ip.name = sxp.shift
        ip.addr_range=parse_range sxp.shift
        while sxp.any?
          case next_header=header(sxp.first)
          when :reg
            ip.regs << parse_reg(sxp.shift)
          when :is_bram
            ip.is_bram = parse_single(sxp.shift)
          else
            puts "syntax error : unknown header '#{next_header}'"
          end
        end
      else
        puts "syntax error : expecting 'ip' as s-expression header. got #{header}"
      end
      ip
    end

    def parse_range sxp
      say "parse_range"
      rge=AddrRange.new
      if (header=header(sxp))==:range
        sxp.shift
        rge.start = sxp.shift
        rge.end   = sxp.shift
      else
        puts "syntax error : expecting 'range' as s-expression header. got #{header}"
      end
      rge
    end

    def parse_reg sxp
      say "parse_reg #{sxp}"
      reg= Reg.new
      reg.bits=[]
      reg.bitfields=[]
      header   = sxp.shift
      reg.name = sxp.shift
      reg.addr = parse_single(sxp.shift)
      reg.init = parse_single(sxp.shift)
      while sxp.any?
        case header=header(sxp.first)
        when :bit
          reg.bits << parse_bit(sxp.shift)
        when :bitfield
          reg.bitfields << parse_bitfield(sxp.shift)
        else
          puts "syntax error : expecting 'bit' or 'bitfield' as s-expression header. got #{header}"
        end
      end
      reg
    end

    def parse_bit sxp
      say "parse_bit #{sxp}"
      bit=Bit.new
      header   = sxp.shift
      bit.id   = sxp.shift
      bit.name = parse_single(sxp.shift)
      bit
    end

    def parse_bitfield sxp
      say "parse_bitfield #{sxp}"
      bitfield=Bitfield.new
      header           = sxp.shift
      bitfield.range   = sxp.shift
      bitfield.name    = parse_single(sxp.shift)
      bitfield
    end

    def parse_bit sxp
      say "parse_bit #{sxp}"
      p header   = sxp.shift
      p bit_id   = sxp.shift
      p bit_name = parse_single(sxp.shift)
    end


    def header sxp
      sxp.first
    end

    def rest sxp
      sxp[1..-1]
    end
  end
end
