module Reggae
  class IPGen < Generator
    def generate ip

      definition={
        :entity => {
          :name => "ip_"+ip.name,
          :generic => {
            :address_start     => ["unsigned(31 downto 0)",hexa_vhdl(ip.addr_range.start,32)],
            :address_end       => ["unsigned(31 downto 0)",hexa_vhdl(ip.addr_range.end  ,32)],
          },
          :ports => {
            "reset_n          " => [:in , "std_logic"],
            "clk              " => [:in , "std_logic"],
            "bus_to_slave_en  " => [:in , "std_logic"],
            "bus_to_slave_wr  " => [:in , "std_logic"],
            "bus_to_slave_addr" => [:in , "std_logic_vector(31 downto 0)"],
            "bus_to_slave_data" => [:in , "std_logic_vector(31 downto 0)"],
            "slave_to_bus_data" => [:out, "std_logic_vector(31 downto 0)"],
          },
        },
        :arch   => {
          :name => 'rtl',
          :declarations => [
            emit_arch_declaration(ip)
          ],
          :body => [
            newline(),
            emit_write_regs(ip),
            newline(),
            emit_read_regs(ip)
          ]
        }
      }
      code_ent=generate_entity_arch(definition)
    end

    #============= hard stuff==============
    def emit_arch_declaration ip
      code=Code.new
      code << comment("registers")
      ip.regs.each do |reg|
        code << "signal reg_#{reg.name.ljust(18)} : std_logic_vector(#{reg.size-1} downto 0);"
      end

      code << comment("register addresses")
      ip.regs.each do |reg|
        code << "constant ADDR_#{reg.name.upcase.ljust(15)} : std_logic_vector(31 downto 0) := #{hexa_vhdl(reg.addr,32)};"
      end

      code << comment("register reset values")
      ip.regs.each do |reg|
        # binary notation :
        if (reg.size % 4 == 0) #e.g : 32
          hexa  = reg.init.to_s(16).rjust(reg.size/4,'0')
          reset = "x\"#{hexa  }\""
        else
          bits=reg.init.to_s(2).rjust(reg.size,'0')[-reg.size..-1]
          reset= "\"#{bits}\""
        end
        code << "constant RESET_#{reg.name.upcase.ljust(14)} : std_logic_vector(#{reg.size-1} downto 0) := #{reset};--#{reg.size}"
      end

      code << comment("bit indexes")
      ip.regs.each do |reg|
        reg.bits.each do |bit|
          code << "constant #{reg.name.upcase}_#{bit.name.upcase}".ljust(29)+" : natural := #{bit.id};"
        end
      end

      if ip.regs.map{|r| r.bitfields}.flatten.any?
        code << comment("bitfield indexes")
        ip.regs.each do |reg|
          reg.bitfields.each do |bitf|
            code << "constant #{reg.name.upcase}_#{bitf.name.upcase}_UPPER".ljust(29)+" : natural := #{bitf.range.end};"
            code << "constant #{reg.name.upcase}_#{bitf.name.upcase}_LOWER".ljust(29)+" : natural := #{bitf.range.start};"
          end
        end
      end

      if ip.regs.map{|r| r.sampling}.flatten.any?
        code << comment("sampled registers")
        ip.regs.each do |reg|
          if sig=reg.sampling
            code << "signal #{sig} : std_logic_vector(#{reg.size} downto 0);"
          end
        end
      end

      if ip.regs.map{|r| r.bits}.flatten.any?{|b| b.sampling}
        code << comment("sampled bits")
        ip.regs.each do |reg|
          reg.bits.each do |bit|
            if sig=bit.sampling
              code << "signal #{sig} : std_logic;"
            end
          end
        end
      end

      if ip.regs.map{|r| r.bitfields}.flatten.any?{|b| b.sampling}
        code << comment("sampled bitfields")
        ip.regs.each do |reg|
          reg.bitfields.each do |bitfield|
            if sig=bitfield.sampling
              code << "signal #{sig} : std_logic_vector(#{bitfield.size-1} downto 0);"
            end
          end
        end
      end
      code
    end


    def emit_write_regs ip
      code=Code.new
      code << "write_regs_p : process(reset_n,clk)"
      code << "begin"
      code << "  if reset_n='0' then"
      code.indent=4
      ip.regs.each do |reg|
        code << "reg_#{reg.name} <= RESET_#{reg.name.upcase};";
      end
      code.indent=0
      code << "  elsif rising_edge(clk) then"
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
      code << "    else "
      code.indent=6
      if ip.regs.map{|r| r.bits}.flatten.any?{|bit| bit.toggling}
        code << "--toggling bits"
        ip.regs.each do |reg|
          reg.bits.each do |bit|
            if bit.toggling
              code << "reg_#{reg.name}(#{reg.name.upcase}_#{bit.name.upcase}) <= '0';"
            end
          end
        end
      end
      if ip.regs.map{|r| r.bits}.flatten.any?{|bit| bit.sampling}
        code << "--sampling bits"
        ip.regs.each do |reg|
          reg.bits.each do |bit|
            if sig=bit.sampling
              code << "reg_#{reg.name}(#{reg.name.upcase}_#{bit.name.upcase}) <= #{sig};"
            end
          end
        end
      end
      if ip.regs.map{|r| r.bitfields}.flatten.any?{|bitf| bitf.sampling}
        code << "--sampling bitfields"
        ip.regs.each do |reg|
          rname=reg.name.upcase
          reg.bitfields.each do |bitfield|
            bname=bitfield.name.upcase
            if sig=bitfield.sampling
              range="#{rname}_#{bname}_UPPER downto #{rname}_#{bname}_LOWER"
              code << "reg_#{reg.name}(#{range}) <= #{sig};"
            end
          end
        end
      end
      code.indent=0
      code << "    end if;"
      code << "  end if;"
      code << "end process;"
      code
    end

    def emit_read_regs ip
      code=Code.new
      code << "read_regs :process(reset_n,clk)"
      code << "begin"
      code << "  if reset_n='0' then"
      code << "    slave_to_bus_data <= x\"00000000\";"
      code << "  elsif rising_edge(clk) then"
      code << "    slave_to_bus_data <= x\"00000000\";"
      code << "    if bus_to_slave_en='1' and bus_to_slave_wr='0' then"
      code << "      case bus_to_slave_addr is"
      code.indent=8
      ip.regs.each do |reg|
        code << "when ADDR_#{reg.name.upcase} =>"
        code.indent=10
        code << "slave_to_bus_data(#{reg.size-1} downto 0) <= reg_#{reg.name};"
        code.indent=8
      end
      code.indent=0
      code << "        when others =>"
      code << "          null;"
      code << "      end case;"
      code << "    end if;"
      code << "  end if;"
      code << "end process;"
      code
    end

    #======================================
    def generate_entity_arch definition
      # vhdl model elaboration
      entity = VHDL::Entity.new(definition[:entity])
      arch   = VHDL::Architecture.new(definition)
      # code production
      code=Code.new
      code << reggae_header
      code << ieee_header
      code << entity.code
      code.newline
      code << arch.code
      code
    end
  end
end
