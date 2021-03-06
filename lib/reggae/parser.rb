require 'sxp'
module Reggae

  class Parser

    def parse filename
      puts "=> parsing '#{filename}'"
      sxp=SXP.read IO.read(filename)
      ast=objectify(sxp)
    end

    def objectify sxp
      parse_regmap(sxp)
    end

    def say txt
      #puts txt.to_s.light_green
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
        bus.addr_size=parse_single(sxp.shift).to_i
        bus.data_size=parse_single(sxp.shift).to_i
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
      while sxp.any?
        kind=header(sxp.first)
        case kind
        when :size
          reg.size = parse_single(sxp.shift)
        when :address
          reg.addr = parse_single(sxp.shift)
        when :sampling
          reg.sampling = parse_single(sxp.shift)
        when :init
          value = parse_single(sxp.shift)
          case value
          when /0x([0-9a-fA-F]+)/
            reg.init=$1.to_i(16)
          when /0b([0-1]+)/
            reg.init=$1.to_i(2)
          when /([0-9]+)/
            reg.init=$1.to_i
          else
            raise "Syntax ERROR for reg init value : prefer '0x....' instead of '#{value}'"
          end
        when :bit
          reg.bits << parse_bit(sxp.shift)
        when :bitfield
          reg.bitfields << parse_bitfield(sxp.shift)
        else
          puts "syntax error : expecting 'bit' or 'bitfield' as s-expression header. got #{kind}"
        end
      end
      reg.size||=32
      reg.size=reg.size.to_i
      reg
    end

    def parse_bit sxp
      say "parse_bit #{sxp}"
      bit=Bit.new
      header   = sxp.shift
      bit.id   = sxp.shift
      bit.name = parse_single(sxp.shift)
      if sxp.any?
        case header=header(sxp.first)
        when :toggling
          bit.toggling=true
        when :sampling
          bit.sampling=parse_single(sxp.shift)
        end
      end
      bit
    end

    def parse_bitfield sxp
      say "parse_bitfield #{sxp}"
      bitfield=Bitfield.new
      header           = sxp.shift
      bitfield.range   = parse_bitfield_range(sxp.shift)
      bitfield.name    = parse_single(sxp.shift)
      if sxp.any?
        case header=header(sxp.first)
        when :sampling
          bitfield.sampling=parse_single(sxp.shift)
        end
      end
      bitfield.size=(bitfield.range.end-bitfield.range.start).abs + 1
      bitfield
    end

    def parse_bitfield_range sxp
      mdata   = sxp.match(/(\d+)..(\d+)/)
      min,max = mdata.captures.map(&:to_i).minmax
      range=BitFieldRange.new
      range.start = min
      range.end   = max
      range
    end

    def header sxp
      sxp.first
    end

    def rest sxp
      sxp[1..-1]
    end
  end
end
