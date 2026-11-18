-- =============================================================================
-- File        : tb_lbist_top.vhd
-- Entity      : tb_lbist_top
-- Description : Full-system testbench for 4-channel LBIST subsystem with
--               automated stuck-at fault coverage analysis.
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lbist_pkg.all;

entity tb_lbist_top is
end entity tb_lbist_top;

architecture sim of tb_lbist_top is

  constant CLK_PERIOD   : time    := 10 ns;
  constant NUM_CH_TB    : integer := 4;
  constant CHAIN_LEN_TB : integer := 16;   -- 16 cycles per chain (64 total FFs for fast sim)
  constant PAT_CNT_TB   : integer := 30;   -- 30 patterns
  constant MISR_W       : integer := 32;

  signal clk            : std_logic := '0';
  signal rst_n          : std_logic := '0';
  signal start          : std_logic := '0';

  signal prpg_scan_in   : std_logic_vector(NUM_CH_TB-1 downto 0);
  signal prpg_advance   : std_logic;

  signal dut_scan_in    : std_logic_vector(NUM_CH_TB-1 downto 0);
  signal dut_scan_out   : std_logic_vector(NUM_CH_TB-1 downto 0);
  signal test_mode      : std_logic;
  signal scan_enable    : std_logic;
  signal capture_enable : std_logic;
  signal dut_rst_sync   : std_logic;
  signal scan_en        : std_logic;

  signal fault_en       : std_logic := '0';
  signal fault_chain    : integer range 0 to NUM_CH_TB-1 := 0;
  signal fault_site     : integer   := 0;
  signal fault_type     : std_logic := '0';

  signal golden_sig     : std_logic_vector(MISR_W-1 downto 0) := (others => '0');
  signal misr_sig       : std_logic_vector(MISR_W-1 downto 0);
  signal test_done      : std_logic;
  signal test_pass      : std_logic;
  signal state_out      : std_logic_vector(2 downto 0);
  signal pattern_num    : std_logic_vector(15 downto 0);
  signal sim_done       : boolean := false;

begin

  clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

  -- ── 4-Channel PRPG Placeholder ──────────────────────────────────────────
  u_prpg : entity work.prpg_placeholder
    generic map (
      WIDTH      => MISR_W,
      NUM_CHAINS => NUM_CH_TB
    )
    port map (
      clk        => clk,
      rst_n      => rst_n,
      advance    => prpg_advance,
      serial_out => prpg_scan_in
    );

  -- ── 4-Channel Scan Chain Model ──────────────────────────────────────────
  u_dut : entity work.dut_scan_chain
    generic map (
      NUM_CHAINS => NUM_CH_TB,
      N          => CHAIN_LEN_TB
    )
    port map (
      clk            => clk,
      rst_n          => rst_n,
      test_mode      => test_mode,
      scan_enable    => scan_enable,
      capture_enable => capture_enable,
      scan_in        => dut_scan_in,
      scan_out       => dut_scan_out
    );

  -- ── 4-Channel LBIST Top ─────────────────────────────────────────────────
  u_lbist : entity work.lbist_top
    generic map (
      NUM_CHAINS    => NUM_CH_TB,
      CHAIN_LENGTH  => CHAIN_LEN_TB,
      PATTERN_COUNT => PAT_CNT_TB,
      MISR_WIDTH    => MISR_W
    )
    port map (
      clk            => clk,
      rst_n          => rst_n,
      start          => start,
      prpg_scan_in   => prpg_scan_in,
      prpg_advance   => prpg_advance,
      dut_scan_in    => dut_scan_in,
      dut_scan_out   => dut_scan_out,
      test_mode      => test_mode,
      scan_enable    => scan_enable,
      capture_enable => capture_enable,
      dut_rst_sync   => dut_rst_sync,
      scan_en        => scan_en,
      fault_en       => fault_en,
      fault_chain    => fault_chain,
      fault_site     => fault_site,
      fault_type     => fault_type,
      golden_sig     => golden_sig,
      misr_sig       => misr_sig,
      test_done      => test_done,
      test_pass      => test_pass,
      state_out      => state_out,
      pattern_num    => pattern_num
    );

  -- =========================================================================
  -- Main test & fault simulation process
  -- =========================================================================
  p_main : process
    procedure do_reset is
    begin
      rst_n <= '0';
      start <= '0';
      wait for 4 * CLK_PERIOD;
      rst_n <= '1';
      wait for 2 * CLK_PERIOD;
    end procedure;

    procedure run_lbist_and_wait is
    begin
      start <= '1';
      wait for CLK_PERIOD;
      start <= '0';
      wait until test_done = '1';
      wait for CLK_PERIOD;
    end procedure;

    variable golden_capture : std_logic_vector(MISR_W-1 downto 0);
    variable detected_cnt   : integer := 0;
    variable total_faults   : integer;

  begin
    -- 4 chains * CHAIN_LEN_TB positions * 2 (SA0 + SA1)
    total_faults := 2 * NUM_CH_TB * CHAIN_LEN_TB;

    report "" severity note;
    report "============================================================" severity note;
    report "  4-Channel LBIST Fault Coverage Simulation" severity note;
    report "  Parallel scan chains : " & integer'image(NUM_CH_TB) severity note;
    report "  Chain length         : " & integer'image(CHAIN_LEN_TB) & " FFs/chain" severity note;
    report "  Total FFs under test : " & integer'image(NUM_CH_TB * CHAIN_LEN_TB) severity note;
    report "  Total SA faults      : " & integer'image(total_faults) severity note;
    report "============================================================" severity note;

    -- Phase 1: Golden signature
    fault_en   <= '0';
    golden_sig <= (others => '0');
    do_reset;
    run_lbist_and_wait;

    golden_capture := misr_sig;
    report "Golden 4-channel MISR signature = 0x" & to_hstring(golden_capture) severity note;

    -- Phase 2: Fault simulation across all 4 channels
    report "" severity note;
    report "--- Phase 2: Simulating stuck-at faults across 4 chains ---" severity note;

    detected_cnt := 0;

    for ch in 0 to NUM_CH_TB-1 loop
      for site in 0 to CHAIN_LEN_TB-1 loop
        for ftype in 0 to 1 loop

          fault_en    <= '1';
          fault_chain <= ch;
          fault_site  <= site;
          if ftype = 0 then
            fault_type <= '0';  -- SA0
          else
            fault_type <= '1';  -- SA1
          end if;

          golden_sig <= golden_capture;
          wait for CLK_PERIOD;
          do_reset;

          fault_en    <= '1';
          fault_chain <= ch;
          fault_site  <= site;
          if ftype = 0 then
            fault_type <= '0';
          else
            fault_type <= '1';
          end if;
          golden_sig <= golden_capture;
          wait for CLK_PERIOD;

          run_lbist_and_wait;

          if test_pass = '0' then
            detected_cnt := detected_cnt + 1;
          end if;

        end loop; -- ftype
      end loop;   -- site
    end loop;     -- ch

    -- Phase 3: Summary
    report "" severity note;
    report "============================================================" severity note;
    report "           4-CHANNEL FAULT COVERAGE REPORT" severity note;
    report "============================================================" severity note;
    report "  Total stuck-at faults : " & integer'image(total_faults) severity note;
    report "  Detected faults       : " & integer'image(detected_cnt) severity note;
    report "  Undetected (aliased)  : " & integer'image(total_faults - detected_cnt) severity note;
    report "  Fault coverage        : " & integer'image((detected_cnt * 100) / total_faults) & "%" severity note;
    report "============================================================" severity note;

    assert (detected_cnt * 100 / total_faults) >= 90
      report "WARNING: Fault coverage below 90%" severity warning;

    report "===== tb_lbist_top: 4-channel simulation complete =====" severity note;
    sim_done <= true;
    wait;
  end process p_main;

end architecture sim;
