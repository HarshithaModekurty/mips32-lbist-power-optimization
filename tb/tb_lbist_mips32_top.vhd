library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.lbist_pkg.all;
use work.mips32_scan_pkg.all;

entity tb_lbist_mips32_top is
    generic (
        PATTERN_COUNT      : positive := 4;
        RUN_FAULT_CAMPAIGN : boolean := true;
        TARGET_RATE_CODE   : natural range 0 to 7 := 6
    );
end entity;

architecture sim of tb_lbist_mips32_top is
    constant CLK_PERIOD : time := 10 ns;
    signal clk          : std_logic := '0';
    signal rst_n        : std_logic := '0';
    signal start        : std_logic := '0';
    signal instruction  : word_t := x"24010001";
    signal data_read    : word_t := (others => '0');
    signal seed_data    : std_logic_vector(31 downto 0) := x"1ACEB00C";
    signal target_rate  : std_logic_vector(2 downto 0) :=
        std_logic_vector(to_unsigned(TARGET_RATE_CODE, 3));
    signal custom_limit : unsigned(4 downto 0) := (others => '0');
    signal golden_sig   : std_logic_vector(MISR_W_C-1 downto 0) := (others => '0');
    signal fault_en     : std_logic := '0';
    signal fault_chain  : integer range 0 to NUM_CHAINS_C-1 := 0;
    signal fault_site   : integer := 0;
    signal fault_type   : std_logic := '0';
    signal misr_sig     : std_logic_vector(MISR_W_C-1 downto 0);
    signal test_done    : std_logic;
    signal test_pass    : std_logic;
    signal scan_enable  : std_logic;
    signal capture_en   : std_logic;
    signal zero_detect  : std_logic;
    signal toggle_rate  : unsigned(7 downto 0);
    signal scan_toggle_count : unsigned(31 downto 0);
    signal scan_toggle_rate  : unsigned(7 downto 0);
    signal shift_edges  : natural := 0;
    signal capture_edges: natural := 0;
begin
    clk <= not clk after CLK_PERIOD / 2;

    protocol_monitor : process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                shift_edges <= 0;
                capture_edges <= 0;
            else
                assert not (scan_enable = '1' and capture_en = '1')
                    report "Scan and capture enabled simultaneously" severity failure;
                if scan_enable = '1' then
                    shift_edges <= shift_edges + 1;
                end if;
                if capture_en = '1' then
                    capture_edges <= capture_edges + 1;
                end if;
            end if;
        end if;
    end process;

    dut : entity work.lbist_mips32_top
        generic map (
            PATTERN_COUNT => PATTERN_COUNT
        )
        port map (
            clk                  => clk,
            rst_n                => rst_n,
            start                => start,
            instruction          => instruction,
            data_read            => data_read,
            seed_data            => seed_data,
            target_rate_sel      => target_rate,
            custom_toggle_limit  => custom_limit,
            golden_sig           => golden_sig,
            fault_en             => fault_en,
            fault_chain          => fault_chain,
            fault_site           => fault_site,
            fault_type           => fault_type,
            misr_sig             => misr_sig,
            test_done             => test_done,
            test_pass             => test_pass,
            scan_enable           => scan_enable,
            capture_enable        => capture_en,
            all_zero_detected     => zero_detect,
            measured_toggle_rate  => toggle_rate,
            scan_toggle_count     => scan_toggle_count,
            scan_toggle_rate      => scan_toggle_rate
        );

    process
        variable captured_signature : std_logic_vector(MISR_W_C-1 downto 0);
        variable detected_faults    : natural := 0;
        variable tested_faults      : natural := 0;
    begin
        rst_n <= '0';
        wait for 3 * CLK_PERIOD;
        rst_n <= '1';
        wait for 2 * CLK_PERIOD;

        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        wait until test_done = '1';
        assert shift_edges = 256 * PATTERN_COUNT
            report "Unexpected shift edge count in golden run: " &
                   integer'image(shift_edges) severity failure;
        assert capture_edges = PATTERN_COUNT
            report "Unexpected capture edge count in golden run: " &
                   integer'image(capture_edges) severity failure;
        captured_signature := misr_sig;
        assert captured_signature /= (captured_signature'range => '0')
            report "Integrated MISR signature unexpectedly zero" severity failure;

        rst_n <= '0';
        wait for 3 * CLK_PERIOD;
        golden_sig <= captured_signature;
        rst_n <= '1';
        wait for 2 * CLK_PERIOD;

        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        wait until test_done = '1';
        assert shift_edges = 256 * PATTERN_COUNT
            report "Unexpected shift edge count in checked run: " &
                   integer'image(shift_edges) severity failure;
        assert capture_edges = PATTERN_COUNT
            report "Unexpected capture edge count in checked run: " &
                   integer'image(capture_edges) severity failure;
        assert test_pass = '1'
            report "Fault-free integrated MIPS32 LBIST did not pass" severity failure;
        assert zero_detect = '0'
            report "Integrated PRPG entered all-zero state" severity failure;
        assert scan_toggle_count /= 0
            report "Integrated scan activity monitor recorded no transitions"
            severity failure;
        assert scan_toggle_rate <= 100
            report "Integrated scan activity rate exceeded 100 percent"
            severity failure;
        report "Integrated scan transitions = " &
               integer'image(to_integer(scan_toggle_count)) &
               ", measured scan toggle rate = " &
               integer'image(to_integer(scan_toggle_rate)) & "%"
            severity note;

        if RUN_FAULT_CAMPAIGN then
            for chain in 0 to NUM_CHAINS_C-1 loop
                for site_index in 0 to CHAIN_LEN_C-1 loop
                    for fault_value in 0 to 1 loop
                        fault_site <= site_index;
                        fault_chain <= chain;
                        if fault_value = 0 then
                            fault_type <= '0';
                        else
                            fault_type <= '1';
                        end if;
                        fault_en <= '1';
                        tested_faults := tested_faults + 1;

                        rst_n <= '0';
                        wait for 3 * CLK_PERIOD;
                        rst_n <= '1';
                        wait for 2 * CLK_PERIOD;
                        start <= '1';
                        wait for CLK_PERIOD;
                        start <= '0';
                        wait until test_done = '1';
                        if test_pass = '0' then
                            detected_faults := detected_faults + 1;
                        else
                            report "Aliased representative fault: chain=" &
                                   integer'image(chain) & " site=" &
                                   integer'image(fault_site) & " type=" &
                                   std_logic'image(fault_type) severity warning;
                        end if;
                    end loop;
                end loop;
            end loop;

            assert detected_faults * 100 >= tested_faults * 90
                report "Representative fault campaign detected only " &
                       integer'image(detected_faults) & " of " &
                       integer'image(tested_faults) severity failure;
            report "PASS representative four-chain stuck-at fault campaign: " &
                   integer'image(detected_faults) & "/" &
                   integer'image(tested_faults) & " (" &
                   integer'image((detected_faults * 100) / tested_faults) &
                   "%)" severity note;
        else
            report "SKIP integrated fault campaign (RUN_FAULT_CAMPAIGN=false)"
                severity note;
        end if;

        report "PASS integrated four-chain MIPS32 LBIST smoke test" severity note;
        stop;
        wait;
    end process;
end architecture;
