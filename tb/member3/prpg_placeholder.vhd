-- =============================================================================
-- File        : prpg_placeholder.vhd
-- Entity      : prpg_placeholder
-- Description : 4-channel PRPG placeholder for Member 2 integration.
--               Outputs 4 pseudorandom bits per clock from a 32-bit Galois LFSR.
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use work.lbist_pkg.all;

entity prpg_placeholder is
  generic (
    WIDTH      : integer := 32;
    NUM_CHAINS : integer := NUM_CHAINS_C   -- 4
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    advance    : in  std_logic;    -- Stub for toggle-rate control interface
    serial_out : out std_logic_vector(NUM_CHAINS-1 downto 0) -- 4 bits per clk
  );
end entity prpg_placeholder;

architecture rtl of prpg_placeholder is

  constant SEED : std_logic_vector(WIDTH-1 downto 0) := x"DEADBEEF";
  signal lfsr_reg : std_logic_vector(WIDTH-1 downto 0) := SEED;

begin

  -- Decorrelated bits tapped from spaced register positions
  serial_out(0) <= lfsr_reg(0);
  serial_out(1) <= lfsr_reg(8);
  serial_out(2) <= lfsr_reg(16);
  serial_out(3) <= lfsr_reg(24);

  p_lfsr : process(clk, rst_n)
    variable fb   : std_logic;
    variable nreg : std_logic_vector(WIDTH-1 downto 0);
  begin
    if rst_n = '0' then
      lfsr_reg <= SEED;
    elsif rising_edge(clk) then
      fb := lfsr_reg(WIDTH-1);

      nreg(WIDTH-1 downto 1) := lfsr_reg(WIDTH-2 downto 0);
      nreg(0)                 := '0';

      nreg(21) := nreg(21) xor fb;
      nreg(1)  := nreg(1)  xor fb;
      nreg(0)  := nreg(0)  xor fb;

      lfsr_reg <= nreg;
    end if;
  end process p_lfsr;

end architecture rtl;
