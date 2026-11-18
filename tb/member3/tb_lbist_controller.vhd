-- =============================================================================
-- File        : tb_lbist_controller.vhd
-- Entity      : tb_lbist_controller
-- Description : Unit testbench for 4-channel LBIST Controller FSM.
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lbist_pkg.all;

entity tb_lbist_controller is
end entity tb_lbist_controller;

architecture sim of tb_lbist_controller is

  constant CLK_PERIOD   : time    := 10 ns;
  constant CHAIN_LEN_TB : integer := 4;    -- Small chain for fast FSM check
  constant PAT_CNT_TB   : integer := 3;
  constant MISR_W       : integer := 32;

  signal clk            : std_logic := '0';
  signal rst_n          : std_logic := '0';
  signal start          : std_logic := '0';
  signal golden_sig     : std_logic_vector(MISR_W-1 downto 0) := (others => '0');
  signal misr_sig       : std_logic_vector(MISR_W-1 downto 0) := (others => '0');

  signal test_mode      : std_logic;
  signal scan_enable    : std_logic;
  signal capture_enable : std_logic;
  signal dut_rst_sync   : std_logic;
  signal scan_en        : std_logic;
  signal misr_rst_n     : std_logic;
  signal misr_capture   : std_logic;
  signal prpg_advance   : std_logic;
  signal test_done      : std_logic;
  signal test_pass      : std_logic;
  signal state_out      : std_logic_vector(2 downto 0);
  signal pattern_num    : std_logic_vector(15 downto 0);
  signal sim_done       : boolean := false;

begin

  clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

  dut : entity work.lbist_controller
    generic map (
      CHAIN_LENGTH  => CHAIN_LEN_TB,
      PATTERN_COUNT => PAT_CNT_TB,
      MISR_WIDTH    => MISR_W
    )
    port map (
      clk            => clk,
      rst_n          => rst_n,
      start          => start,
      golden_sig     => golden_sig,
      misr_sig       => misr_sig,
      test_mode      => test_mode,
      scan_enable    => scan_enable,
      capture_enable => capture_enable,
      dut_rst_sync   => dut_rst_sync,
      scan_en        => scan_en,
      misr_rst_n     => misr_rst_n,
      misr_capture   => misr_capture,
      prpg_advance   => prpg_advance,
      test_done      => test_done,
      test_pass      => test_pass,
      state_out      => state_out,
      pattern_num    => pattern_num
    );

  p_stim : process
    procedure do_reset is
    begin
      rst_n <= '0';
      start <= '0';
      wait for 4 * CLK_PERIOD;
      rst_n <= '1';
      wait for 2 * CLK_PERIOD;
    end procedure;
  begin
    -- TC1: PASS scenario
    report "TC1: PASS scenario" severity note;
    do_reset;
    golden_sig <= x"12345678";
    misr_sig   <= x"12345678";

    start <= '1';
    wait for CLK_PERIOD;
    start <= '0';

    wait until test_done = '1';
    wait for CLK_PERIOD;

    assert test_pass = '1'
      report "TC1 FAIL: Expected test_pass='1'" severity error;
    report "TC1 PASS: Correctly evaluated PASS" severity note;

    -- TC2: FAIL scenario
    report "TC2: FAIL scenario" severity note;
    do_reset;
    golden_sig <= x"FFFFFFFF";
    misr_sig   <= x"00000000";

    start <= '1';
    wait for CLK_PERIOD;
    start <= '0';

    wait until test_done = '1';
    wait for CLK_PERIOD;

    assert test_pass = '0'
      report "TC2 FAIL: Expected test_pass='0'" severity error;
    report "TC2 PASS: Correctly evaluated FAIL" severity note;

    -- TC3: Timing & scan control validation
    report "TC3: Control signal check" severity note;
    do_reset;
    start <= '1';
    wait for CLK_PERIOD;
    start <= '0';

    wait until state_out = ST_SHIFT;
    assert (scan_enable = '1' and test_mode = '1' and capture_enable = '0')
      report "TC3 FAIL: Control signals wrong in SHIFT" severity error;

    wait until state_out = ST_CAPTURE;
    assert (scan_enable = '0' and test_mode = '1' and capture_enable = '1')
      report "TC3 FAIL: Control signals wrong in CAPTURE" severity error;

    report "TC3 PASS: test_mode, scan_enable, capture_enable sequencing correct" severity note;
    wait until test_done = '1';

    report "===== tb_lbist_controller: all tests complete =====" severity note;
    sim_done <= true;
    wait;
  end process p_stim;

end architecture sim;
