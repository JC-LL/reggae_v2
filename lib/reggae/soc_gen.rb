module Reggae
  class SOCGen < Generator
    def generate model
      code=Code.new
      code << ieee_header()
      code << library("ip_lib")
      code << library("uart_bus_master_lib")
      code.newline
      code << library("#{model.name}_lib")
      code << use("#{model.name}_lib","#{model.name}_pkg")
      code.newline

      definition={
        :entity => {
          :name => model.name,
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
            signal("master_to_bus_addr"  , "unsigned(31 downto 0)"),
            signal("master_to_bus_data"  , "std_logic_vector(31 downto 0)"),
            signal("bus_to_master_data"  , "std_logic_vector(31 downto 0)"),
            comment(),
            signal("bus_to_slave_en   "  , "std_logic"),
            signal("bus_to_slave_wr   "  , "std_logic"),
            signal("bus_to_slave_addr "  , "unsigned(31 downto 0)"),
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
            instance("uart_bus_master_i","uart_bus_master_lib","uart_bus_master","rtl",genmap=nil,
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
              [
                comment("-"*60),
                comment("IP_#{ip.name} instanciation"),
                comment("-"*60),
                instance(label="IP_#{ip.name}_#{idx}",lib="ip_lib",entity="ip_#{ip.name}","rtl",
                  genmap={
                    "address_start" => "MEMORY_MAP(IP_#{ip.name.upcase}).address_start",
                    "address_end"   => "MEMORY_MAP(IP_#{ip.name.upcase}).address_start"
                  },
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
      entity=VHDL::Entity.new(definition[:entity])
      arch  =VHDL::Architecture.new(definition)
      code << entity.code
      code.newline
      code << arch.code
      code
    end
  end
end
