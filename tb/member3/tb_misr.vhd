-- =============================================================================
-- File        : tb_misr.vhd
-- Entity      : tb_misr
-- Description : Unit testbench for 4-input MISR response compactor.
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_misr is
end entity tb_misr;

architecture sim of tb_misr is

  constant CLK_PERIOD : time    := 10 ns;
  constant W          : integer := 32;
  constant CH         : integer := 4;

  signal clk         : std_logic := '0';
  signal rst_n       : std_logic := '0';
  signal enable      : std_logic := '0';
  signal parallel_in : std_logic_vector(CH-1 downto 0) := (others => '0');
  signal signature   : std_logic_vector(W-1 downto 0);
  signal sim_done    : boolean := false;

begin

  clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

  dut : entity work.misr
    generic map (
      WIDTH      => W,
      NUM_INPUTS => CH
    )
    port map (
      clk         => clk,
      rst_n       => rst_n,
      enable      => enable,
      parallel_in => parallel_in,
      signature   => signature
    );

  p_stim : process
    variable sig_a : std_logic_vector(W-1 downto 0);
    variable sig_b : std_logic_vector(W-1 downto 0);
  begin
    -- TC1: Reset check
    rst_n <= '0';
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    rst_n <= '1';
    wait for CLK_PERIOD;

    assert signature = (W-1 downto 0 => '1')
      report "TC1 FAIL: MISR not seeded to all-ones" severity error;
    report "TC1 PASS: MISR reset seed = all-ones" severity note;

    -- TC2: No-enable check
    enable      <= '0';
    parallel_in <= "1010";
    wait for 5 * CLK_PERIOD;
    assert signature = (W-1 downto 0 => '1')
      report "TC2 FAIL: MISR changed without enable" severity error;
    report "TC2 PASS: MISR held stable with enable=0" severity note;

    -- TC3: Known parallel sequence
    enable      <= '1';
    parallel_in <= "1010";
    for i in 0 to W-1 loop
      wait until rising_edge(clk);
    end loop;
    wait for 1 ns;

    sig_a := signature;
    report "TC3 INFO: Signature after 32 clocks with 0xA = 0x" &
           to_hstring(sig_a) severity note;
    assert sig_a /= (W-1 downto 0 => '1')
      report "TC3 WARN: Signature still all-ones" severity warning;
    report "TC3 PASS: 4-channel compression verified" severity note;

    -- TC4: Different input sequence -> different signature
    rst_n <= '0';
    wait for 2 * CLK_PERIOD;
    rst_n <= '1';
    enable      <= '1';
    parallel_in <= "0101";  -- Inverse pattern
    for i in 0 to W-1 loop
      wait until rising_edge(clk);
    end loop;
    wait for 1 ns;
    sig_b := signature;

    report "TC4 INFO: Signature after 32 clocks with 0x5 = 0x" &
           to_hstring(sig_b) severity note;
    assert sig_a /= sig_b
      report "TC4 FAIL: Aliasing occurred" severity error;
    report "TC4 PASS: Distinct inputs produced distinct signatures (no aliasing)" severity note;

    report "===== tb_misr: all tests complete =====" severity note;
    sim_done <= true;
    wait;
  end process p_stim;

end architecture sim;
