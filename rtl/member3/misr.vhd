-- =============================================================================
-- File        : misr.vhd
-- Entity      : misr
-- Description : 32-bit Multiple-Input Signature Register (MISR) response compactor.
--               Updated for 4 parallel scan chains.
--
--               During each SHIFT clock, 4 response bits from the 4 parallel
--               MIPS32 scan chains are compressed simultaneously into this MISR.
--               After all test patterns complete, the resulting 32-bit signature
--               is compared against the golden signature.
--
-- Algorithm   : Galois LFSR with polynomial x^32 + x^22 + x^2 + x + 1
--               and 4 parallel input XOR taps at bits (3 downto 0).
-- Seed        : All-ones (non-zero to avoid lockup).
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity misr is
  generic (
    WIDTH      : integer := 32;   -- Signature register width
    NUM_INPUTS : integer := 4     -- Number of parallel scan chains
  );
  port (
    clk         : in  std_logic;
    rst_n       : in  std_logic;    -- Active-low synchronous reset from controller
    enable      : in  std_logic;    -- Active during SHIFT phase
    parallel_in : in  std_logic_vector(NUM_INPUTS-1 downto 0); -- 4-bit scan response
    signature   : out std_logic_vector(WIDTH-1 downto 0)
  );
end entity misr;

architecture rtl of misr is

  signal misr_reg : std_logic_vector(WIDTH-1 downto 0);

begin

  signature <= misr_reg;

  -- -------------------------------------------------------------------------
  -- 4-Input Galois MISR process
  -- Each clock (when enable='1'):
  --   1. Latch MSB as feedback bit (fb).
  --   2. Shift register left by 1; insert '0' at bit 0.
  --   3. XOR feedback bit into polynomial taps 21, 1, 0.
  --   4. XOR each parallel input bit into corresponding register bit (0 to 3).
  -- -------------------------------------------------------------------------
  p_misr : process(clk)
    variable fb   : std_logic;
    variable nreg : std_logic_vector(WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        misr_reg <= (others => '1');   -- Non-zero seed
      elsif enable = '1' then
        fb := misr_reg(WIDTH-1);

        -- Step 1: Shift left by 1
        nreg(WIDTH-1 downto 1) := misr_reg(WIDTH-2 downto 0);
        nreg(0)                 := '0';

        -- Step 2: XOR Galois polynomial taps (x^32 + x^22 + x^2 + x + 1)
        nreg(21) := nreg(21) xor fb;   -- x^22
        nreg(1)  := nreg(1)  xor fb;   -- x^2
        nreg(0)  := nreg(0)  xor fb;   -- x^1

        -- Step 3: XOR the 4 parallel scan response bits into the register
        for i in 0 to NUM_INPUTS-1 loop
          nreg(i) := nreg(i) xor parallel_in(i);
        end loop;

        misr_reg <= nreg;
      end if;
    end if;
  end process p_misr;

end architecture rtl;
