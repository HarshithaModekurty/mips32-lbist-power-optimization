-- =============================================================================
-- File        : dut_scan_chain.vhd
-- Entity      : dut_scan_chain
-- Description : Placeholder model of 4 parallel MIPS32 scan chains.
--               Each chain is N flip-flops long (total = 4 × N FFs).
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use work.lbist_pkg.all;

entity dut_scan_chain is
  generic (
    NUM_CHAINS : integer := NUM_CHAINS_C;  -- 4
    N          : integer := CHAIN_LEN_C    -- 256
  );
  port (
    clk            : in  std_logic;
    rst_n          : in  std_logic;
    test_mode      : in  std_logic;
    scan_enable    : in  std_logic;
    capture_enable : in  std_logic;
    scan_in        : in  std_logic_vector(NUM_CHAINS-1 downto 0);
    scan_out       : out std_logic_vector(NUM_CHAINS-1 downto 0)
  );
end entity dut_scan_chain;

architecture rtl of dut_scan_chain is

  type chain_array_t is array (0 to NUM_CHAINS-1) of std_logic_vector(N-1 downto 0);
  signal ff       : chain_array_t := (others => (others => '0'));
  signal comb_out : chain_array_t;

begin

  -- Scan outputs are LSBs of each chain
  gen_outs : for c in 0 to NUM_CHAINS-1 generate
    scan_out(c) <= ff(c)(0);
  end generate;

  -- Inter-stage combinational logic for observability
  gen_comb : for c in 0 to NUM_CHAINS-1 generate
    gen_bits : for i in 0 to N-1 generate
      comb_out(c)(i) <= ff(c)(i) xor ff((c+1) mod NUM_CHAINS)((i+1) mod N);
    end generate;
  end generate;

  -- 4 parallel scan registers
  gen_chains : for c in 0 to NUM_CHAINS-1 generate
    p_chain : process(clk, rst_n)
    begin
      if rst_n = '0' then
        ff(c) <= (others => '0');
      elsif rising_edge(clk) then
        if scan_enable = '1' then
          -- Shift mode
          ff(c)(N-1)          <= scan_in(c);
          ff(c)(N-2 downto 0) <= ff(c)(N-1 downto 1);
        elsif capture_enable = '1' then
          -- Capture functional combinational response
          ff(c) <= comb_out(c);
        end if;
      end if;
    end process p_chain;
  end generate;

end architecture rtl;
