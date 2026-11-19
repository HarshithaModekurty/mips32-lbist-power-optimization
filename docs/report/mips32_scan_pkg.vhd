library ieee;
use ieee.std_logic_1164.all;

package mips32_scan_pkg is
  constant WORD_BITS : positive := 32;
  constant STATE_BITS : positive := 1024; -- PC + registers r1..r31; r0 is hardwired
  subtype word_t is std_logic_vector(31 downto 0);
  subtype state_t is std_logic_vector(STATE_BITS-1 downto 0);
  type register_file_t is array (0 to 31) of word_t;
  function chain_length(chain : natural; chains : positive) return natural;
end package;

package body mips32_scan_pkg is
  function chain_length(chain : natural; chains : positive) return natural is
  begin
    if chain >= chains or chain >= STATE_BITS then return 0; end if;
    return (STATE_BITS-1-chain)/chains + 1;
  end function;
end package body;
