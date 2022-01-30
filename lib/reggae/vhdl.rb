require_relative 'vhdl_helpers'

module Reggae
  module VHDL
    class Entity
      include VHDL::Helpers
      def initialize h
        @e=h
      end

      def name
        @e[:name]
      end

      def ports
        @e[:ports]
      end

      def code
        code=Code.new
        code << "entity #{@e[:name]} is"
        code.indent=2
        if @e[:generic]
          code << "generic ("
          code.indent=4
          @e[:generic].each do |name,type_init|
            type,init=type_init
            init=" := #{init}" if init
            code << "#{name} : #{type}#{init};"
          end
          code.indent=2
          code << ");"
        end
        code << "port("
        code.indent=4
        @e[:ports].each do |name,dir_type|
          dir,type=*dir_type
          code << "#{name} : #{dir} #{type};"
        end
        code.indent=2
        code << ");"
        code.indent=0
        code << "end entity;"
        code
      end
    end

    class Architecture
      include VHDL::Helpers
      def initialize h
        @e=h[:entity]
        @a=h[:arch]
      end

      def code
        code=Code.new
        code << "architecture #{@a[:name]} of #{@e[:name]} is"
        code.indent=2
        @a[:declarations].each{|decl| code << decl}
        code.indent=0
        code << "begin"
        code.indent=2
        @a[:body].each{|stmt| code << stmt}
        code.indent=0
        code << "end #{@a[:name]};"
        code
      end
    end
  end
end
