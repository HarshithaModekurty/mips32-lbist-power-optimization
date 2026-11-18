-- =============================================================================
-- File        : tb_lbist_sweep.vhd
-- Entity      : tb_lbist_sweep
-- Description : Fault-coverage sweep testbench.
--               PAT_CNT_TB is a top-level generic so GHDL can override it
--               at run-time:  ghdl -r ... tb_lbist_sweep -gPAT_CNT_TB=100
--
--   Prints one machine-parseable summary line:
--     SWEEP_RESULT PAT_CNT=N DETECTED=D TOTAL=T COVERAGE=C
--
-- Course      : VL405 DFT Lab | Member 3
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_lbist_sweep is
  generic (
    PAT_CNT_TB   : integer := 50;   -- overridden by sweep script
    CHAIN_LEN_TB : integer := 16    -- keep fixed; matches placeholder DUT
  );
end entity tb_lbist_sweep;

architecture sim of tb_lbist_sweep is

  constant CLK_PERIOD : time    := 10 ns;
  constant MISR_W     : integer := 32;

  signal clk          : std_logic := '0';
  signal rst_n        : std_logic := '0';
  signal start        : std_logic := '0';
  signal prpg_scan_in : std_logic;
  signal prpg_advance : std_logic;
  signal scan_en      : std_logic;
  signal dut_scan_in  : std_logic;
  signal dut_scan_out : std_logic;
  signal fault_en     : std_logic := '0';
  signal fault_site   : integer   := 0;
  signal fault_type   : std_logic := '0';
  signal golden_sig   : std_logic_vector(MISR_W-1 downto 0) := (others => '0');
  signal misr_sig     : std_logic_vector(MISR_W-1 downto 0);
  signal test_done    : std_logic;
  signal test_pass    : std_logic;
  signal state_out    : std_logic_vector(2 downto 0);
  signal pattern_num  : std_logic_vector(15 downto 0);

begin

  clk <= not clk after CLK_PERIOD / 2;

  u_prpg : entity work.prpg_placeholder
    generic map (WIDTH => MISR_W)
    port map (clk => clk, rst_n => rst_n,
              advance => prpg_advance, serial_out => prpg_scan_in);

  u_dut : entity work.dut_scan_chain
    generic map (N => CHAIN_LEN_TB)
    port map (clk => clk, rst_n => rst_n, scan_en => scan_en,
              scan_in => dut_scan_in, scan_out => dut_scan_out);

  u_lbist : entity work.lbist_top
    generic map (CHAIN_LENGTH  => CHAIN_LEN_TB,
                 PATTERN_COUNT => PAT_CNT_TB,
                 MISR_WIDTH    => MISR_W)
    port map (
      clk => clk, rst_n => rst_n, start => start,
      prpg_scan_in => prpg_scan_in, prpg_advance => prpg_advance,
      scan_en => scan_en, dut_scan_in => dut_scan_in,
      dut_scan_out => dut_scan_out,
      fault_en => fault_en, fault_site => fault_site,
      fault_type => fault_type, golden_sig => golden_sig,
      misr_sig => misr_sig, test_done => test_done,
      test_pass => test_pass, state_out => state_out,
      pattern_num => pattern_num);

  -- =========================================================================
  -- Main process: golden run + fault loop
  -- =========================================================================
  p_main : process
    variable golden_cap  : std_logic_vector(MISR_W-1 downto 0);
    variable detected    : integer := 0;
    variable total       : integer;

    procedure do_reset is
    begin
      rst_n <= '0'; start <= '0';
      wait for 6 * CLK_PERIOD;
      rst_n <= '1';
      wait for 2 * CLK_PERIOD;
    end procedure;

    procedure run_lbist is
    begin
      start <= '1';
      wait for CLK_PERIOD;
      start <= '0';
      wait until test_done = '1';
      wait for CLK_PERIOD;
    end procedure;

  begin
    total    := 2 * CHAIN_LEN_TB;
    detected := 0;

    -- Phase 1: golden signature
    fault_en <= '0'; golden_sig <= (others => '0');
    do_reset;
    run_lbist;
    golden_cap := misr_sig;

    -- Phase 2: fault loop
    for site in 0 to CHAIN_LEN_TB-1 loop
      for ftype in 0 to 1 loop
        fault_en   <= '1';
        fault_site <= site;
        fault_type <= '0' when ftype = 0 else '1';
        golden_sig <= golden_cap;
        wait for CLK_PERIOD;
        do_reset;
        fault_en   <= '1';
        fault_site <= site;
        fault_type <= '0' when ftype = 0 else '1';
        golden_sig <= golden_cap;
        wait for CLK_PERIOD;
        run_lbist;
        if test_pass = '0' then
          detected := detected + 1;
        end if;
      end loop;
    end loop;

    -- Machine-parseable summary (Python script greps for this line)
    report "SWEEP_RESULT PAT_CNT=" & integer'image(PAT_CNT_TB) &
           " DETECTED="  & integer'image(detected) &
           " TOTAL="     & integer'image(total) &
           " COVERAGE="  & integer'image((detected * 100) / total)
      severity note;

    wait;
  end process p_main;

end architecture sim;

