module Reggae
  class IPGen < Generator
    def generate ip

      definition={
        :entity => {
          :name => ip.name,
          :generic => {
            :address_start     => ["unsigned(31 downto 0)","x\"00000000\""],
            :address_end       => ["unsigned(31 downto 0)",nil], #just testing if nil works
          },
          :ports => {
            "reset_n          " => [:in , "std_logic"],
            "clk              " => [:in , "std_logic"],
            "bus_to_slave_en  " => [:in , "std_logic"],
            "bus_to_slave_wr  " => [:in , "std_logic"],
            "bus_to_slave_addr" => [:in , "unsigned(31 downto 0)"],
            "bus_to_slave_data" => [:in , "std_logic_vector(31 downto 0)"],
            "slave_to_bus_data" => [:out, "std_logic_vector(31 downto 0)"],
          },
        },
        :arch   => {
          :name => 'rtl',
          :declarations => [
            comment("registers"),
            ip.regs.map{|reg| signal("reg_#{reg.name}".ljust(20),"std_logic_vector(#{(reg.size||32).to_i-1} downto 0)")},
            comment("register addresses"),
            ip.regs.map{|reg| constant("ADDR_#{reg.name.upcase}".ljust(20),"std_logic_vector(#{(reg.size||32).to_i-1} downto 0)",hexa_vhdl(reg.addr,32))},
            comment("register reset value"),
            ip.regs.map{|reg| constant("RESET_#{reg.name.upcase}".ljust(20),"std_logic_vector(#{(reg.size||32).to_i-1} downto 0)",hexa_vhdl(reg.init,(reg.size).to_i))},
            comment("bit indexes"),
            ip.regs.map do |reg|
              reg.bits.map do |bit|
                constant("#{reg.name.upcase}_#{bit.name.upcase}".ljust(20), "natural", bit.id)
              end
            end.flatten,
            newline()
          ],
          :body => [
            emit_write_regs(ip)
          ]
        }
      }
      code_ent=generate_entity_arch(definition)
    end

    def emit_write_regs ip
      code=Code.new
      code << "write_regs :process(reset_n,clk)"
      code << "begin"
      code << "  if reset_n='0' then"
      code.indent=4
      ip.regs.each do |reg|
        code << "reg_#{reg.name} <= RESET_#{reg.name.upcase}";
      end
      code.indent=0
      code << "  elsif rising_edge(clk) then"
      code << "    slave_to_bus_data <= x\"00000000\";"
      code << "    if bus_to_slave_en='1' and bus_to_slave_wr='1' then"
      code << "      case bus_to_slave_addr is"
      code.indent=8
      ip.regs.each do |reg|
        code << "when ADDR_#{reg.name.upcase} => "
        code.indent=10
        code << "reg_#{reg.name} <= bus_to_slave_data(#{reg.size-1} downto 0);"
        code.indent=8
      end
      code.indent=0
      code << "        when others =>"
      code << "          null;"
      code << "      end case;"
      code << "    else --sampling and toggling"
      code << "      --toggling"
      code.indent=6
      ip.regs.each do |reg|
        reg.bits.each do |bit|
          if bit.toggling
            code << "reg_control(#{reg.name.upcase}_#{bit.name.upcase}) <= '0';"
          end
        end
      end
      code.indent=0
      code << "      --sampling"
      
      code << "      reg_status(STATUS_STOPPED) <= robot_stopped;"
      code << "      reg_status(STATUS_FAILURE) <= robot_failure;"
      code << "      reg_status(STATUS_LOCH_UPPER downto STATUS_LOCH_LOWER) <= robot_loch;"
      code << "    end if;"
      code << "  end if;"
      code << "end process;"
      code
    end

    def generate_pkg definition
      code=Code.new
      code
    end

    def generate_entity_arch definition
      # vhdl model elaboration
      entity = VHDL::Entity.new(definition[:entity])
      arch   = VHDL::Architecture.new(definition)
      # code production
      code=Code.new
      code << ieee_header
      code << entity.code
      code.newline
      code << arch.code
      code
    end
  end
end
