# Reggae : FPGA register map VHDL generation

## What is it ?
Reggae is a simple tool that generates a System-on-Chip architecture from a a description of its memory map.

The tool is especially targeted to quick prototyping of early demonstrators on FPGA.

## Memory map specification : s-expression based
The memory map, specified by the user, is described in a s-expression based file.

A full example is provided in tests directory. A simple IP interface can be as simple as :

```
  ...
  (ip "switches"
    (range 0x1 0x1)
    (reg "switches"
      (address 0x1)
      (sampling "sig_switches")
      (init 0xcafebabe)
    )
  )
  ...
```
Here we have simply asked Reggae to generate an IP named "switches", with a single register, also named "switches", that reset to default value 0xcafebabe. This register samples a signal named "sig_switches", that will be user-defined, probably connected to actual switches !

More detailed low-level specification can be used : bits and bitfields, toggling etc

```
(ip "robot"
  (range 0x202 0x203)
  (reg "control"
    (address 0x202)
    (size 5)
    (init 0xdeadbeef)
    (bit 0
      (name "go")
      (toggling true)
    )
    (bit 1
      (name "stop")
    )
    (bit 2
      (name "light_on")
    )
    (bit 3
      (name "turn_right")
    )
    (bit 4
      (name "turn_left")
    )
  )
  (reg "status"
    (address 0x203)
    (init 0x0)
    (bit 0
      (name "stopped")
      (sampling "robot_stopped")
    )
    (bit 1
      (name "failure")
      (sampling "robot_failure")
    )
    (bitfield 2..31
      (name "loch")
      (sampling "robot_loch")
    )
  )

)
```

Reggae will then create the following architecture, as well as testbench and synthesis files (for Vivado, today for Nexysa7).

## SoC architecture

The SoC template is given as example below.
