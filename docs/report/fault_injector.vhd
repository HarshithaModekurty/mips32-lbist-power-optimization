-- =============================================================================
-- File        : fault_injector.vhd
-- Entity      : fault_injector
-- Description : 4-channel stuck-at fault injector for LBIST fault simulation.
--
--   Sits between the MIPS32 4-bit scan_out bus and the 4-input MISR.
--   fault_site is the physical cell position from the scan-in end
--   (0 .. CHAIN_LENGTH-1). Once the fault reaches the scan-out end, the
--   selected chain is held at fault_type ('0' = SA0, '1' = SA1).
--
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use work.lbist_pkg.all;

entity fault_injector is
  generic (
    CHAIN_LENGTH : integer := CHAIN_LEN_C;   -- 256 shift cycles
    NUM_CHAINS   : integer := NUM_CHAINS_C    -- 4 parallel scan chains
  );
  port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    scan_enable  : in  std_logic;    -- From lbist_controller

    -- 4-channel data path
    scan_out_i   : in  std_logic_vector(NUM_CHAINS-1 downto 0);
    scan_out_o   : out std_logic_vector(NUM_CHAINS-1 downto 0);

    -- Fault configuration
    fault_en     : in  std_logic;
    fault_chain  : in  integer range 0 to NUM_CHAINS-1; -- Which chain (0 to 3)
    fault_site   : in  integer;                          -- Cell position (0 to 255)
    fault_type   : in  std_logic;                        -- '0'=SA0, '1'=SA1
    shift_pos    : out integer
  );
end entity fault_injector;

architecture rtl of fault_injector is

  signal shift_cnt_reg : integer range 0 to CHAIN_LENGTH - 1 := 0;
  signal fault_reached : std_logic := '0';

begin

  shift_pos <= shift_cnt_reg;

  -- -------------------------------------------------------------------------
  -- Shift cycle counter
  -- -------------------------------------------------------------------------
  p_cnt : process(clk, rst_n)
  begin
    if rst_n = '0' then
      shift_cnt_reg <= 0;
      fault_reached <= '0';
    elsif rising_edge(clk) then
      if scan_enable = '1' then
        if fault_en = '1' and
           shift_cnt_reg >= CHAIN_LENGTH - 1 - fault_site then
          fault_reached <= '1';
        end if;

        if shift_cnt_reg = CHAIN_LENGTH - 1 then
          shift_cnt_reg <= 0;
        else
          shift_cnt_reg <= shift_cnt_reg + 1;
        end if;
      else
        shift_cnt_reg <= 0;
      end if;
    end if;
  end process p_cnt;

  -- -------------------------------------------------------------------------
  -- The output fault becomes observable after the selected cell's propagation
  -- latency and remains active through capture, modeling a stuck scan cell.
  -- -------------------------------------------------------------------------
  gen_channels : for i in 0 to NUM_CHAINS-1 generate
    scan_out_o(i) <= fault_type when
                     fault_en = '1' and fault_reached = '1' and
                     fault_chain = i
                     else scan_out_i(i);
  end generate gen_channels;

end architecture rtl;
