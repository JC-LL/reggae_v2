module Reggae
  class HostScript

    def generate model

      puts "=> generating example script (ruby)"
      code=Code.new
      code << "# generated automatically by Reggae "
      code << "BUS_WR=0b11"
      code << "BUS_RD=0b01"
      code.newline
      code << "def to_4bytes int"
      code << "  (0..3).map{|i| (int >> i*8) & 0xff}"
      code << "end"
      code.newline
      code << "def from_4bytes ary"
      code << "  ary.each_with_index{|byte,idx| byte << (8*idx)}.sum"
      code << "end"
      code.newline
      code << "transactions=["
      code << "  [BUS_WR, 0x00000000,0x00000005],#wr LEDS 0b101"
      code << "  [BUS_RD, 0x00000001,0x00000000],#rd SWITCHES"
      code << "  # writing to BRAM1"
      code << "  [BUS_WR, 0x00000002,0x000000AA],"
      code << "  [BUS_WR, 0x00000003,0x000000AA],"
      code << "  [BUS_WR, 0x00000004,0x000000AA],"
      code << "  [BUS_WR, 0x00000005,0x000000AA],"
      code << "  [BUS_WR, 0x00000006,0x000000AA],"
      code << "  [BUS_WR, 0x00000101,0x000000AA],"
      code << "  # WRITING to BRAM2"
      code << "  [BUS_WR, 0x00000102,0x00000001],"
      code << "  [BUS_WR, 0x00000103,0x00000002],"
      code << "  [BUS_WR, 0x00000104,0x00000003],"
      code << "  [BUS_WR, 0x00000105,0x00000004],"
      code << "  [BUS_WR, 0x00000106,0x00000005],"
      code << "  [BUS_WR, 0x00000201,0x00000006],"
      code << "  # READING from BRAM2"
      code << "  [BUS_RD, 0x00000102,0x00000000],"
      code << "  [BUS_RD, 0x00000103,0x00000000],"
      code << "  [BUS_RD, 0x00000104,0x00000000],"
      code << "  [BUS_RD, 0x00000105,0x00000000],"
      code << "  [BUS_RD, 0x00000106,0x00000000],"
      code << "  [BUS_RD, 0x00000201,0x00000000],"
      code << "  # READING from BRAM1"
      code << "  [BUS_RD, 0x00000002,0x00000000],"
      code << "  [BUS_RD, 0x00000003,0x00000000],"
      code << "  [BUS_RD, 0x00000004,0x00000000],"
      code << "  [BUS_RD, 0x00000005,0x00000000],"
      code << "  [BUS_RD, 0x00000006,0x00000000],"
      code << "  [BUS_RD, 0x00000101,0x00000000],"
      code << "]"
      code.newline
      code << "require 'uart'"
      code << "uart = UART.open '/dev/ttyUSB1', 19200, '8N1'"
      code.newline
      code << "transactions.each do |cmd,addr,data|"
      code << "  if cmd==BUS_WR"
      code << "    puts \"write 0x%08x,   0x%08x\" % [addr,data]"
      code << "    uart.write [BUS_WR].pack 'C'"
      code << "    uart.write to_4bytes(addr).pack 'C*'"
      code << "    uart.write to_4bytes(data).pack 'C*'"
      code << "  else"
      code << "    print \"read  0x%08x -> \" % [addr]"
      code << "    uart.write [BUS_RD].pack 'C'"
      code << "    uart.write to_4bytes(addr).pack 'C*'"
      code << "    bytes=[]"
      code << "    while bytes.size !=4"
      code << "      byte=uart.read(1)"
      code << "      bytes << byte.unpack('c') if byte"
      code << "    end"
      code << "    bytes.flatten!"
      code << "    int32=from_4bytes(bytes)"
      code << "    puts \"0x%08x\" % [int32]"
      code << "  end"
      code << "end"
      code

      reggae_dir=__dir__
      host_dir=Dir.pwd+"/GENERATED_#{model.name.to_s.upcase}/host/"
      FileUtils.mkdir_p host_dir
      code.save_as host_dir+"/example.rb",verbose=false
    end
  end
end
