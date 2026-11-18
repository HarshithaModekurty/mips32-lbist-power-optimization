library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity modified_prpg_4lane_adapter is
    port (
        clk                   : in  std_logic;
        rst_n                 : in  std_logic;
        lbist_enable          : in  std_logic;
        seed_load             : in  std_logic;
        seed_data             : in  std_logic_vector(31 downto 0);
        target_rate_sel       : in  std_logic_vector(2 downto 0);
        custom_toggle_limit   : in  unsigned(4 downto 0);
        pattern_valid         : out std_logic;
        all_zero_detected     : out std_logic;
        scan_data_parallel    : out std_logic_vector(3 downto 0);
        raw_pattern_out       : out std_logic_vector(31 downto 0);
        modification_active   : out std_logic;
        instantaneous_toggles : out unsigned(4 downto 0);
        measured_toggle_rate  : out unsigned(7 downto 0)
    );
end entity;

architecture rtl of modified_prpg_4lane_adapter is
    signal modified_pattern : std_logic_vector(31 downto 0);
begin
    prpg : entity work.modified_prpg_top
        generic map (
            WIDTH => 32
        )
        port map (
            clk                   => clk,
            rst_n                 => rst_n,
            lbist_enable          => lbist_enable,
            seed_load             => seed_load,
            seed_data             => seed_data,
            target_rate_sel       => target_rate_sel,
            custom_toggle_limit   => custom_toggle_limit,
            pattern_valid         => pattern_valid,
            all_zero_detected     => all_zero_detected,
            scan_data_parallel    => modified_pattern,
            scan_data_serial      => open,
            raw_pattern_out       => raw_pattern_out,
            prev_pattern_out      => open,
            modification_active   => modification_active,
            baseline_hamming_dist => open,
            instantaneous_toggles => instantaneous_toggles,
            total_word_toggles    => open,
            total_patterns_gen    => open,
            total_serial_toggles  => open,
            total_serial_shifts   => open,
            measured_toggle_rate  => measured_toggle_rate
        );

    scan_data_parallel(0) <= modified_pattern(0);
    scan_data_parallel(1) <= modified_pattern(8);
    scan_data_parallel(2) <= modified_pattern(16);
    scan_data_parallel(3) <= modified_pattern(24);
end architecture;
