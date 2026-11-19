-- =============================================================================
-- File        : lbist_top.vhd
-- Entity      : lbist_top
-- Description : Top-level integration of Member-3's 4-channel LBIST subsystem.
--               Directly interfaces with Member 1's MIPS32 scan architecture:
--                 - 4 parallel scan inputs: dut_scan_in(3 downto 0)
--                 - 4 parallel scan outputs: dut_scan_out(3 downto 0)
--                 - Control lines: test_mode, scan_enable, capture_enable, dut_rst_sync
--
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lbist_pkg.all;

entity lbist_top is
  generic (
    NUM_CHAINS    : integer := NUM_CHAINS_C;   -- 4
    CHAIN_LENGTH  : integer := CHAIN_LEN_C;    -- 256
    PATTERN_COUNT : integer := PAT_CNT_C;
    MISR_WIDTH    : integer := MISR_W_C
  );
  port (
    clk            : in  std_logic;
    rst_n          : in  std_logic;    -- Active-low system reset
    start          : in  std_logic;    -- Pulse to begin LBIST

    -- ── Member-2 (PRPG) Interface ─────────────────────────────────────────
    prpg_scan_in   : in  std_logic_vector(NUM_CHAINS-1 downto 0); -- 4 pattern bits
    prpg_advance   : out std_logic;

    -- ── Member-1 (MIPS32 Scan Core) Interface ─────────────────────────────
    dut_scan_in    : out std_logic_vector(NUM_CHAINS-1 downto 0);
    dut_scan_out   : in  std_logic_vector(NUM_CHAINS-1 downto 0);
    test_mode      : out std_logic;
    scan_enable    : out std_logic;
    capture_enable : out std_logic;
    dut_rst_sync   : out std_logic;
    scan_en        : out std_logic;    -- Backward-compatible alias

    -- ── Fault Injection Interface (Verification use only) ─────────────────
    fault_en       : in  std_logic;
    fault_chain    : in  integer range 0 to NUM_CHAINS-1;
    fault_site     : in  integer;
    fault_type     : in  std_logic;

    -- ── Signature & Status Interface ──────────────────────────────────────
    golden_sig     : in  std_logic_vector(MISR_WIDTH-1 downto 0);
    misr_sig       : out std_logic_vector(MISR_WIDTH-1 downto 0);
    test_done      : out std_logic;
    test_pass      : out std_logic;
    state_out      : out std_logic_vector(2 downto 0);
    pattern_num    : out std_logic_vector(15 downto 0)
  );
end entity lbist_top;

architecture rtl of lbist_top is

  signal scan_enable_i  : std_logic;
  signal misr_rst_n_i   : std_logic;
  signal misr_capture_i : std_logic;
  signal prpg_adv_i     : std_logic;

  signal corrupted_bus  : std_logic_vector(NUM_CHAINS-1 downto 0);
  signal misr_sig_i     : std_logic_vector(MISR_WIDTH-1 downto 0);

begin

  -- Direct signal passthroughs
  dut_scan_in  <= prpg_scan_in;
  scan_enable  <= scan_enable_i;
  scan_en      <= scan_enable_i;
  prpg_advance <= prpg_adv_i;
  misr_sig     <= misr_sig_i;

  -- =========================================================================
  -- Sub-component: LBIST Controller
  -- =========================================================================
  u_ctrl : entity work.lbist_controller
    generic map (
      CHAIN_LENGTH  => CHAIN_LENGTH,
      PATTERN_COUNT => PATTERN_COUNT,
      MISR_WIDTH    => MISR_WIDTH
    )
    port map (
      clk            => clk,
      rst_n          => rst_n,
      start          => start,
      golden_sig     => golden_sig,
      misr_sig       => misr_sig_i,
      test_mode      => test_mode,
      scan_enable    => scan_enable_i,
      capture_enable => capture_enable,
      dut_rst_sync   => dut_rst_sync,
      scan_en        => open,
      misr_rst_n     => misr_rst_n_i,
      misr_capture   => misr_capture_i,
      prpg_advance   => prpg_adv_i,
      test_done      => test_done,
      test_pass      => test_pass,
      state_out      => state_out,
      pattern_num    => pattern_num
    );

  -- =========================================================================
  -- Sub-component: 4-Channel Fault Injector
  -- =========================================================================
  u_fi : entity work.fault_injector
    generic map (
      CHAIN_LENGTH => CHAIN_LENGTH,
      NUM_CHAINS   => NUM_CHAINS
    )
    port map (
      clk         => clk,
      rst_n       => rst_n,
      scan_enable => scan_enable_i,
      scan_out_i  => dut_scan_out,
      scan_out_o  => corrupted_bus,
      fault_en    => fault_en,
      fault_chain => fault_chain,
      fault_site  => fault_site,
      fault_type  => fault_type,
      shift_pos   => open
    );

  -- =========================================================================
  -- Sub-component: 4-Input MISR
  -- =========================================================================
  u_misr : entity work.misr
    generic map (
      WIDTH      => MISR_WIDTH,
      NUM_INPUTS => NUM_CHAINS
    )
    port map (
      clk         => clk,
      rst_n       => misr_rst_n_i,
      enable      => misr_capture_i,
      parallel_in => corrupted_bus,
      signature   => misr_sig_i
    );

end architecture rtl;
