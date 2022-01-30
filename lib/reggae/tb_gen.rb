module Reggae

  class TbGen < Generator

    def generate top
      code=Code.new
      code << reggae_header()
      code << ieee_header()
      code << "library clock_lib;"
      code << "use clock_lib.clock_def.all;"
      code.newline
      code << "library uart_lib;"
      code << "use uart_lib.uart_cst.all;"
      code << "use uart_lib.uart_api.all;"
      code.newline
      code << "library soc_lib;"
      code << "use soc_lib.#{top.name}_pkg.all;"
      code.newline
      code << "entity #{top.name}_tb is"
      code << "end entity;"
      code.newline
      code << "architecture bhv of #{top.name}_tb is"
      code.indent=2
      code << "signal reset_n : std_logic := '0';"
      code << "signal running : boolean := true;"
      code.newline
      code << "-- WARNING : clock is definied in clock_lib"
      code.newline
      code << "signal leds     : std_logic_vector(15 downto 0);"
      code << "signal switches : std_logic_vector( 7 downto 0);"
      code.newline
      code << "signal debug     : std_logic_vector(15 downto 0);"
      code << "signal data_back : std_logic_vector(31 downto 0);"
      code.newline
      code << "constant transactions : bus_transactions_t :=("
      code.indent=4
      code << "--           ADDR        DATA"
      code << '(BUS_WR, x"00000000",x"00000005"),'
      code << '(BUS_RD, x"00000001",x"--------"),'
      code.indent=2
      code << ");"
      code.indent=0

      code << "begin"
      code.indent=2
      code << clocking_and_reset()
      code << dut_instance(top)
      code << serial_sending()
      code << old_rx()
      code << serial_receiving()
      code.indent=0
      code << "end bhv;"
      code
    end

    def clocking_and_reset
      code=Code.new
      code << comment("-"*40)
      code << comment("clock and reset")
      code << comment("-"*40)
      code << "reset_n <= '0','1' after 123 ns;"
      code.newline
      code << "clk100 <= not(clk100) after HALF_PERIOD when running else clk100;"
      code
    end

    def dut_instance top
      name=top.name
      code=Code.new
      code << comment("-"*40)
      code << comment("Design Under Test")
      code << comment("-"*40)
      code << "dut : entity soc_lib.#{name}(rtl)"
      code.indent=2
      code << "port map ("
      code.indent=4
      max=top.ports.keys.map(&:size).max
      top.ports.each do |formal,dir_type|
        case formal
        when :rx
          sig="tx"
        when :tx
          sig="rx"
        else
          sig=formal.to_s
        end
        code << "#{formal.to_s.ljust(max)} => #{sig},"
      end
      code.indent=2
      code << ");"
      code.indent=0
      code
    end

    def serial_sending
      code=Code.new
      code << comment("-"*40)
      code << comment("Sequential Stimuli : Send")
      code << comment("-"*40)
      code << "serial_sending : process"
      code << "  type array_bytes is array(3 downto 0) of std_logic_vector(7 downto 0);"
      code << "  variable bytes : array_bytes;"
      code << "  variable transaction : bus_cmd;"
      code << "begin"
      code << "  report \"running testbench for soc(rtl)\";"
      code << "  report \"waiting for asynchronous reset\";"
      code << "  wait until reset_n='1';"
      code << "  wait_cycles(100);"
      code << "  report \"executing bus master instructions sequence\";"
      code << "  for i in transactions'range loop"
      code << "    transaction := transactions(i);"
      code << "    send_byte(tx,transaction.ctrl);--bus control"
      code << "    send_word(transaction.addr,tx);--bus address"
      code << "    if transaction.ctrl(1 downto 0)=\"01\" then"
      code << "      report \"RD \" & to_hstring(transaction.addr);"
      code << "    else"
      code << "      send_word(transaction.data,tx);--bus data"
      code << "      report \"WR \" & to_hstring(transaction.addr) & \" \" & to_hstring(transaction.data);"
      code << "    end if;"
      code << "    wait_cycles(10);"
      code << "  end loop;"
      code << "  wait_cycles(4000);"
      code << "  report \"end of simulation\";"
      code << "  running <= false;"
      code << "  wait;"
      code << "end process;"
      code
    end

    def old_rx
      code=Code.new
      code << comment("-"*40)
      code << comment("Old Rx needed to detect falling edge of Rx")
      code << comment("-"*40)
      code << "old_rx : process"
      code << "begin"
      code << "  wait until rising_edge(clk100);"
      code << "  rx_1t <= rx;"
      code << "end process;"
      code
    end

    def serial_receiving
      code=Code.new
      code << comment("-"*40)
      code << comment("Sequential Stimuli : Receive")
      code << comment("-"*40)
      code << "serial_receiving:process"
      code << "begin"
      code << "  receive_word(data_back);"
      code << "  report \"received \" & to_hstring(data_back);"
      code << "end process;"
      code
    end
  end
end
