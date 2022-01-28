module Reggae

  module VHDL

    module Helpers

      def comment txt=""
        "-- #{txt}"
      end

      def newline
        ""
      end

      def ieee_header
        code=Code.new
        code << "library ieee;"
        code << "use ieee.std_logic_1164.all;"
        code << "use ieee.numeric_std.all"
        code.newline
        code
      end

      def library name
        "library #{name};"
      end

      def use lib,pkg
        "use #{lib}.#{pkg};"
      end

      def signal name,type,init=nil
        init=" := #{init}" if init
        "signal #{name} : #{type}#{init};"
      end

      def constant name,type,value
        "constant #{name} : #{type} := #{value};"
      end

      def hexa_vhdl hexa,size
        mdata=hexa.match(/0x([0-9a-fA-F]+)/)
        value=$1.to_s.rjust(size/4,'0')
        "x\"#{value}\""
      end

      def sassign lhs,rhs
        "#{lhs} <= #{rhs};"
      end

      def or_ elements
        elements.join(" or ")
      end

      def instance label,lib,entity,arch,gen_map_h,port_map_h
        code=Code.new
        code << "#{label} : entity #{lib}.#{entity}(#{arch})"
        code.indent=2
        code << generic_map(gen_map_h) if gen_map_h
        code << port_map(port_map_h)
        code.indent=0
        code
      end

      def generic_map h
        code=Code.new
        code << "generic map("
        code.indent=2
        h.each do |name,value|
          code << "#{name} => #{value},"
        end
        code.indent=0
        code << ")"
        code
      end

      def port_map h
        code=Code.new
        code << "port map("
        code.indent=2
        h.each do |formal,actual|
          # this allows to insert --comments in port map :
          rhs= "=> #{actual}," if actual
          code << "#{formal} #{rhs}"
        end
        code.indent=0
        code << ");"
        code
      end

      def clocked_process label,clocking_h,async_reset_assigns=nil,body
        code=Code.new
        code << "#{label} : process(#{clocking_h.values.join(',')})"
        code << "begin"
        code.indent=2
        code << "if #{clocking_h[:async_reset]}='0' then"
        code.indent=4
        async_reset_assigns.each do |assign|
          code << assign
        end
        code.indent=2
        code << "elsif rising_edge(#{clocking_h[:clk]}) then "
        code << "end if;"
        code.indent=0
        code << "end process;"
        code
      end

      def sanitize code
        txt=code.finalize
        txt.gsub!(/,\s*\)/,')')
        txt.gsub!(/;\s*\)/,')')
      end

    end


  end
end
