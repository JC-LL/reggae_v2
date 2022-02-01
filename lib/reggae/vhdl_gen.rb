require 'fileutils'
require_relative 'code'
require_relative 'vhdl_helpers'

module Reggae

  class VHDLGen
    include VHDL::Helpers
    attr_accessor :model

    def generate model
      puts "=> generating model '#{model.name}'"
      @model=model
      set_paths
      reference_ip_lib
      generate_ips
      generate_soc
      generate_sim
      generate_syn
      pp @lib_files
    end

    def set_paths
      puts "=> setting paths"
      @reggae_dir=__dir__
      @dest_dir=Dir.pwd+"/GENERATED_#{model.name.to_s.upcase}"
      FileUtils.mkdir_p hdl_dir   =@dest_dir
      @lib_files={
        :clock_lib => [], # for some uart tb reason, clock is defined is this separate package.
        :uart_lib  => [],
        :ip_lib    => [],
        :soc_lib   => [],
      }
    end

    def reference_ip_lib
      puts "=> referencing IP LIB"
      #order matters. simple cp -r is not enough
      @lib_files[:clock_lib] << "#{@reggae_dir}/../../assets/clock/clock_def.vhd"
      uart=[
        "#{@reggae_dir}/../../assets/uart/uart_fifo.vhd",
        "#{@reggae_dir}/../../assets/uart/uart_cst.vhd",
        "#{@reggae_dir}/../../assets/uart/uart_cst_SIM.vhd",
        "#{@reggae_dir}/../../assets/uart/uart_tick_gen.vhd",
        "#{@reggae_dir}/../../assets/uart/uart_sender.vhd",
        "#{@reggae_dir}/../../assets/uart/uart_receiver.vhd",
        "#{@reggae_dir}/../../assets/uart/uart.vhd",
        "#{@reggae_dir}/../../assets/uart/uart_bus_master_fsm.vhd",
        "#{@reggae_dir}/../../assets/uart/uart_bus_master.vhd",
        "#{@reggae_dir}/../../assets/uart/uart_api.vhd",
      ].each do |source|
        @lib_files[:uart_lib] << source
      end
    end

    def generate_ips
      puts "=> generating IPs"
      FileUtils.mkdir_p @dest_dir+"/rtl"
      model.ips.each{|ip| generate_ip(ip)}
    end

    def generate_ip ip
      puts "=> generating IP '#{ip.name}'"
      if ip.is_bram
        @lib_files[:ip_lib] << "#{@reggae_dir}/../../assets/bram/bram.vhd"
        @lib_files[:ip_lib] << "#{@reggae_dir}/../../assets/bram/ip_bram.vhd"
        @lib_files[:ip_lib].uniq!
      else
        filename=@dest_dir+"/rtl/IP_#{ip.name}.vhd"
        @lib_files[:ip_lib] << filename
        code_entity=IPGen.new.generate(ip)
        save_as code_entity,filename
      end
    end

    def generate_soc
      puts "=> generating SoC '#{model.name}'"
      soc_gen=SOCGen.new
      #-- soc pkg (memory map)
      code=soc_gen.generate_soc_pkg(model)
      filename=@dest_dir+"/rtl/SOC_#{model.name}_pkg.vhd"
      save_as code,filename
      @lib_files[:soc_lib] << filename
      #-- soc top level
      code=soc_gen.generate(model)
      @top=soc_gen.entity #used by TbGen
      filename=@dest_dir+"/rtl/SOC_#{model.name}.vhd"
      save_as code,filename
      @lib_files[:soc_lib] << filename
    end

    def generate_sim
      puts "=> generating simulation files"
      FileUtils.mkdir_p sim_dir=@dest_dir+"/tb"
      code = TbGen.new.generate(@top)
      filename=sim_dir+"/SOC_#{model.name}_tb.vhd"
      save_as code,filename
      @lib_files[:soc_lib] << filename

      #-- compile_ghdl.x
      File.open(sim_dir+"/ghdl.x",'w') do |f|
        f.puts "echo \"=> cleaning\""
        f.puts "rm -rf *.cf #{model.name}_tb #{model.name}_tb.ghw"
        f.puts
        @lib_files[:clock_lib].each do |vhdl|
          name=File.basename(vhdl)
          f.puts "echo \"=> analyzing [clock_lib] '#{name}'\""
          f.puts "ghdl -a --std=08 --work=clock_lib #{vhdl}"
          f.puts
        end
        @lib_files[:uart_lib].each do |vhdl|
          # include only CST for simulation here. Exclude uart_cst.vhd
          unless vhdl.end_with?("uart_cst.vhd")
            name=File.basename(vhdl)
            f.puts "echo \"=> analyzing [uart_lib] '#{name}'\""
            f.puts "ghdl -a --std=08 --work=uart_lib #{vhdl}"
            f.puts
          end
        end
        @lib_files[:ip_lib].each do |vhdl|
          name=File.basename(vhdl)
          f.puts "echo \"=> analyzing [ip_lib] '#{name}'\""
          f.puts "ghdl -a --std=08 --work=ip_lib #{vhdl}"
          f.puts
        end
        @lib_files[:soc_lib].each do |vhdl|
          name=File.basename(vhdl)
          f.puts "echo \"=> analyzing [soc_lib] '#{name}'\""
          f.puts "ghdl -a --std=08 --work=soc_lib #{vhdl}"
          f.puts
        end
        f.puts "echo \"=> elaborating soc_#{model.name}_tb\""
        f.puts "ghdl -e --std=08 --work=soc_lib  SOC_#{model.name}_tb"

        f.puts "echo \"=> running #{model.name}_tb\""
        f.puts "ghdl -r soc_#{model.name}_tb --wave=soc_#{model.name}_tb.ghw"

        f.puts "echo \"=> viewing #{model.name}_tb\""
        f.puts "gtkwave soc_#{model.name}_tb.ghw soc_#{model.name}_tb.sav"
      end
    end

    def generate_syn
      puts "=> generating synthesis files"

      code=Code.new
      code << "set partname \"xc7a100tcsg324-1\""
      code << "set xdc_constraints \"./nexysa7.xdc\""
      code << "set outputDir ./SYNTH_OUTPUTS"
      code << "file mkdir $outputDir"
      @lib_files[:clock_lib].each do |vhdl|
        name=File.basename(vhdl)
        code << "read_vhdl -library clock_lib #{vhdl}"
      end
      @lib_files[:uart_lib].each do |vhdl|
        # Exclude uart_cst_SIM.vhd
        exclude=["uart_cst_SIM.vhd","uart_api.vhd"]
        unless exclude.include? vhdl.split('/').last
          name=File.basename(vhdl)
          code << "read_vhdl -library uart_lib #{vhdl}"
        end
      end
      @lib_files[:ip_lib].each do |vhdl|
        name=File.basename(vhdl)
        code << "read_vhdl -library ip_lib #{vhdl}"
      end
      @lib_files[:soc_lib].each do |vhdl|
        name=File.basename(vhdl)
        unless name.end_with? ("_tb.vhd")
          code <<  "read_vhdl -library soc_lib #{vhdl}"
        end
      end
      code << "read_xdc $xdc_constraints"
      code << "synth_design -top soc_#{model.name} -part $partname"
      code << "write_checkpoint -force $outputDir/post_synth.dcp"
      code << "report_timing_summary -file $outputDir/post_synth_timing_summary.rpt"
      code << "report_utilization -file $outputDir/post_synth_util.rpt"
      code << ""
      code << "opt_design"
      code << "place_design"
      code << ""
      code << "write_checkpoint -force $outputDir/post_place.dcp"
      code << "report_utilization -file $outputDir/post_place_util.rpt"
      code << "report_timing_summary -file $outputDir/post_place_timing_summary.rpt"
      code << "route_design"
      code << "write_checkpoint -force $outputDir/post_route.dcp"
      code << "report_route_status -file $outputDir/post_route_status.rpt"
      code << "report_timing_summary -file $outputDir/post_route_timing_summary.rpt"
      code << "report_power -file $outputDir/post_route_power.rpt"
      code << "report_drc -file $outputDir/post_imp_drc.rpt"
      code << "write_bitstream -force $outputDir/top.bit"
      code << "exit"

      FileUtils.mkdir_p syn_dir=@dest_dir+"/syn"
      code.save_as syn_dir+"/script.tcl",verbose=false

      FileUtils.cp "#{@reggae_dir}/../../assets/vivado/nexysa7.xdc", syn_dir
    end

    def save_as code,filename
      File.open(filename,'w'){|f|
        k=sanitize(code)
        f.puts sanitize(code)
      }
    end


  end
end
