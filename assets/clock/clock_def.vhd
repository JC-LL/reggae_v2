library ieee;
use ieee.std_logic_1164.all;

package clock_def is

  constant HALF_PERIOD : time      :=  5 ns;
  signal clk100        : std_logic := '0';

end package;
