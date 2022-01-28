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
      import_assets
      generate_ips
      generate_soc
      generate_sim
      generate_syn
    end

    def set_paths
      puts "=> setting paths"
      @reggae_dir=__dir__
      @dest_dir=Dir.pwd+"/GENERATED_#{model.name.to_s.upcase}"
      FileUtils.mkdir_p @dest_dir
      FileUtils.mkdir_p @dest_dir+"/assets"
    end

    def import_assets
      puts "=> importing assets"
      system("cp -r #{@reggae_dir}/../../assets/uart/ #{@dest_dir}/assets")
    end

    def generate_ips
      puts "=> generating IPs"
      FileUtils.mkdir_p @dest_dir+"/hdl"
      model.ips.each{|ip| generate_ip(ip)}
    end

    def generate_ip ip
      puts "=> generating IP '#{ip.name}'"
      code_entity=IPGen.new.generate(ip)
      filename=@dest_dir+"/hdl/IP_#{ip.name}.vhd"
      save_as code_entity,filename
    end

    def generate_soc
      puts "=> generating SoC '#{model.name}'"
      code=SOCGen.new.generate(model)
      filename=@dest_dir+"/hdl/SOC_#{model.name}.vhd"
      save_as code,filename
    end

    def generate_sim
      puts "=> generating simulation files"
      FileUtils.mkdir_p @dest_dir+"/sim"
    end

    def generate_syn
      puts "=> generating synthesis files"
      FileUtils.mkdir_p @dest_dir+"/syn"
    end

    def save_as code,filename
      File.open(filename,'w'){|f| f.puts sanitize(code)}
    end

  end
end
