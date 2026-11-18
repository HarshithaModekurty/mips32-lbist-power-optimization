-- =============================================================================
-- File        : lbist_pkg.vhd
-- Description : Shared constants, types, and component declarations for the
--               scan-based LBIST system.
--               Updated for 4-channel parallel scan architecture (MIPS32).
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package lbist_pkg is

  --------------------------------------------------------------------------
  -- Configurable System Parameters
  -- Aligned with Member-1 MIPS32 4-channel scan architecture:
  --   4 parallel scan chains × 256 flip-flops per chain = 1,024 total FFs
  --------------------------------------------------------------------------
  constant NUM_CHAINS_C  : integer := 4;     -- Number of parallel scan chains
  constant CHAIN_LEN_C   : integer := 256;   -- Shift cycles per pattern per chain
  constant TOTAL_FFS_C   : integer := NUM_CHAINS_C * CHAIN_LEN_C; -- 1024 FFs
  constant MISR_W_C      : integer := 32;    -- MISR register width (32-bit compactor)
  constant PAT_CNT_C     : integer := 1000;  -- Default test patterns

  --------------------------------------------------------------------------
  -- LBIST FSM State Encoding (3-bit binary)
  --   000 IDLE    – waiting for start
  --   001 INIT    – reset MISR, initialize PRPG, pulse DUT reset
  --   010 SHIFT   – shift CHAIN_LEN cycles (scan_enable=1, 4 bits into MISR)
  --   011 CAPTURE – apply test clock (capture_enable=1, 1 cycle)
  --   100 LOAD    – advance PRPG to next pattern (1 cycle)
  --   101 COMPARE – compare MISR signature vs. golden
  --   110 PASS    – test passed
  --   111 FAIL    – test failed (signature mismatch)
  --------------------------------------------------------------------------
  constant ST_IDLE    : std_logic_vector(2 downto 0) := "000";
  constant ST_INIT    : std_logic_vector(2 downto 0) := "001";
  constant ST_SHIFT   : std_logic_vector(2 downto 0) := "010";
  constant ST_CAPTURE : std_logic_vector(2 downto 0) := "011";
  constant ST_LOAD    : std_logic_vector(2 downto 0) := "100";
  constant ST_COMPARE : std_logic_vector(2 downto 0) := "101";
  constant ST_PASS    : std_logic_vector(2 downto 0) := "110";
  constant ST_FAIL    : std_logic_vector(2 downto 0) := "111";

end package lbist_pkg;
