module Reggae

  class SOCGen < Generator

    attr_accessor :entity,:architecture

    def generate model
      definition={
        :entity => {
          :name => "soc_"+model.name,
          :ports => {
            :reset_n   => [:in , "std_logic"],
            :clk100    => [:in , "std_logic"],
            :rx        => [:in , "std_logic"],
            :tx        => [:out, "std_logic"],
          },
        },
        :arch   => {
          :name => 'rtl',
          :declarations => [
            signal("master_to_bus_en  "  , "std_logic"),
            signal("master_to_bus_wr  "  , "std_logic"),
            signal("master_to_bus_addr"  , "std_logic_vector(31 downto 0)"),
            signal("master_to_bus_data"  , "std_logic_vector(31 downto 0)"),
            signal("bus_to_master_data"  , "std_logic_vector(31 downto 0)"),
            comment(),
            signal("bus_to_slave_en   "  , "std_logic"),
            signal("bus_to_slave_wr   "  , "std_logic"),
            signal("bus_to_slave_addr "  , "std_logic_vector(31 downto 0)"),
            signal("bus_to_slave_data "  , "std_logic_vector(31 downto 0)"),
            comment(),
            model.ips.map do |ip|
              signal("slave_to_bus_data_IP_#{ip.name.upcase}","std_logic_vector(31 downto 0)")
            end
          ].flatten,
          :body => [
            comment("-"*60),
            comment("UART BUS MASTER"),
            comment("-"*60),
            instance("uart_bus_master_i","uart_lib","uart_bus_master","rtl",genmap=nil,
              portmap={
                "reset_n           " => "reset_n",
                "clk100            " => "clk100",
                comment("uart side") => nil, #trick
                "rx                " => "rx",
                "tx                " => "tx",
                comment("bus side")  => nil,
                "master_to_bus_en  " => "master_to_bus_en",
                "master_to_bus_wr  " => "master_to_bus_wr",
                "master_to_bus_addr" => "master_to_bus_addr",
                "master_to_bus_data" => "master_to_bus_data",
                "bus_to_master_data" => "bus_to_master_data",
              }
            ),
            comment("-"*60),
            comment("BUS wiring"),
            comment("-"*60),
            sassign("bus_to_slave_en   " , "master_to_bus_en"),
            sassign("bus_to_slave_wr   " , "master_to_bus_wr"),
            sassign("bus_to_slave_addr " , "master_to_bus_addr"),
            sassign("bus_to_slave_data " , "master_to_bus_data"),
            sassign("bus_to_master_data" , or_(model.ips.map{|ip| "slave_to_bus_data_IP_#{ip.name.upcase}"})),

            model.ips.map.with_index do |ip,idx|
              genmap={
                "ADDRESS_START  " => "MEMORY_MAP(IP_#{ip.name.upcase}).address_start",
                "ADDRESS_END    " => "MEMORY_MAP(IP_#{ip.name.upcase}).address_end",
              }
              if ip.is_bram
                genmap.merge(
                  "BRAM_ADDR_SIZE " => "8",
                  "BRAM_DATA_SIZE " => "8",
                )
              end
              [
                comment("-"*60),
                comment("IP_#{ip.name} instanciation"),
                comment("-"*60),
                instance(label="IP_#{ip.name}_#{idx}",lib="ip_lib",entity="ip_#{ip.is_bram ? "bram" : ip.name}","rtl",
                  genmap,
                  portmap={
                    "reset_n            " => "reset_n",
                    "clk                " => "clk100",
                    comment("bus interface") => nil,
                    "bus_to_slave_en    " => "bus_to_slave_en",
                    "bus_to_slave_wr    " => "bus_to_slave_wr",
                    "bus_to_slave_addr  " => "bus_to_slave_addr",
                    "bus_to_slave_data  " => "bus_to_slave_data",
                    "slave_to_bus_data  " => "slave_to_bus_data_IP_#{ip.name.upcase}",
                  }
                )
              ]
            end
          ].flatten # body
        }
      }

      @entity       = VHDL::Entity.new(definition[:entity])
      @architecture = VHDL::Architecture.new(definition)

      code=Code.new
      code << reggae_header()
      code << ieee_header()
      code << library("ip_lib")
      code << library("uart_lib")
      code << library("soc_lib")
      code << use("soc_lib","soc_#{model.name}_pkg.all")
      code.newline
      code << entity.code
      code.newline
      code << architecture.code
      code
    end

    def generate_soc_pkg model
      code=Code.new
      code << reggae_header()
      code << ieee_header()
      code << "package soc_#{model.name}_pkg is"
      code.newline
      code.indent=2
      code << "type ip_names is ("
      code.indent=4
      model.ips.each do |ip|
        code << "IP_#{ip.name.upcase},"
      end
      code.indent=2
      code << ");"
      code.newline
      code << "type ip_location is record"
      code << "  address_start   : unsigned(31 downto 0);"
      code << "  address_end     : unsigned(31 downto 0);"
      code << "end record;"
      code.newline
      code << "type memory_map_t is array(ip_names) of ip_location;"
      code.newline
      code << "constant MEMORY_MAP : memory_map_t :=("
      code.indent=4
      max=model.ips.map(&:name).map(&:size).max
      model.ips.each do |ip|
        addr_min=hexa_vhdl(ip.addr_range.start,32)
        addr_max=hexa_vhdl(ip.addr_range.end,32)
        code << "IP_#{ip.name.upcase.ljust(max)} => (#{addr_min}, #{addr_max}),"
      end
      code.indent=2
      code << ");"
      code.indent=0
      code.newline
      code << "end package;"
      code
    end
  end
end
