library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lbist_pkg.all;
use work.mips32_scan_pkg.all;

entity lbist_mips32_top is
    generic (
        PATTERN_COUNT : positive := 2
    );
    port (
        clk                 : in  std_logic;
        rst_n               : in  std_logic;
        start               : in  std_logic;
        instruction         : in  word_t;
        data_read           : in  word_t;
        seed_data           : in  std_logic_vector(31 downto 0);
        target_rate_sel     : in  std_logic_vector(2 downto 0);
        custom_toggle_limit : in  unsigned(4 downto 0);
        golden_sig          : in  std_logic_vector(MISR_W_C-1 downto 0);
        fault_en            : in  std_logic;
        fault_chain         : in  integer range 0 to NUM_CHAINS_C-1;
        fault_site          : in  integer;
        fault_type          : in  std_logic;
        misr_sig            : out std_logic_vector(MISR_W_C-1 downto 0);
        test_done           : out std_logic;
        test_pass           : out std_logic;
        scan_enable         : out std_logic;
        capture_enable      : out std_logic;
        all_zero_detected   : out std_logic;
        measured_toggle_rate: out unsigned(7 downto 0);
        scan_toggle_count   : out unsigned(31 downto 0);
        scan_toggle_rate    : out unsigned(7 downto 0)
    );
end entity;

architecture rtl of lbist_mips32_top is
    signal prpg_scan_in   : std_logic_vector(NUM_CHAINS_C-1 downto 0);
    signal dut_scan_in_i  : std_logic_vector(NUM_CHAINS_C-1 downto 0);
    signal dut_scan_out_i : std_logic_vector(NUM_CHAINS_C-1 downto 0);
    signal prpg_enable    : std_logic;
    signal prpg_seed_load : std_logic;
    signal test_mode_i    : std_logic;
    signal dut_rst_sync   : std_logic;
    signal scan_en_alias  : std_logic;
    signal capture_i      : std_logic;
    signal core_reset     : std_logic;
    signal instruction_address : word_t;
    signal data_address       : word_t;
    signal data_write         : word_t;
    signal data_write_enable  : std_logic;
    signal illegal_instruction: std_logic;
    signal misaligned_access  : std_logic;
    signal debug_state        : state_t;
    signal pattern_state      : std_logic_vector(2 downto 0);
    signal scan_toggle_rate_i : unsigned(7 downto 0);
begin
    prpg_enable    <= scan_enable;
    prpg_seed_load <= '1' when pattern_state = ST_INIT else '0';
    core_reset     <= dut_rst_sync or not rst_n;
    capture_enable <= capture_i;

    scan_activity : entity work.scan_activity_monitor
        generic map (
            LANES => NUM_CHAINS_C
        )
        port map (
            clk           => clk,
            rst_n         => rst_n,
            scan_enable   => scan_enable,
            scan_data     => dut_scan_in_i,
            toggle_count  => scan_toggle_count,
            measured_rate => scan_toggle_rate_i
        );

    scan_toggle_rate <= scan_toggle_rate_i;

    controller : entity work.lbist_top
        generic map (
            NUM_CHAINS    => NUM_CHAINS_C,
            CHAIN_LENGTH  => CHAIN_LEN_C,
            PATTERN_COUNT => PATTERN_COUNT,
            MISR_WIDTH    => MISR_W_C
        )
        port map (
            clk            => clk,
            rst_n          => rst_n,
            start          => start,
            prpg_scan_in   => prpg_scan_in,
            prpg_advance   => open,
            dut_scan_in    => dut_scan_in_i,
            dut_scan_out   => dut_scan_out_i,
            test_mode      => test_mode_i,
            scan_enable    => scan_enable,
            capture_enable => capture_i,
            dut_rst_sync   => dut_rst_sync,
            scan_en        => scan_en_alias,
            fault_en       => fault_en,
            fault_chain    => fault_chain,
            fault_site     => fault_site,
            fault_type     => fault_type,
            golden_sig     => golden_sig,
            misr_sig       => misr_sig,
            test_done      => test_done,
            test_pass      => test_pass,
            state_out      => pattern_state,
            pattern_num    => open
        );

    prpg : entity work.modified_prpg_4lane_adapter
        port map (
            clk                   => clk,
            rst_n                 => rst_n,
            lbist_enable          => prpg_enable,
            seed_load             => prpg_seed_load,
            seed_data             => seed_data,
            target_rate_sel       => target_rate_sel,
            custom_toggle_limit   => custom_toggle_limit,
            pattern_valid         => open,
            all_zero_detected     => all_zero_detected,
            scan_data_parallel    => prpg_scan_in,
            raw_pattern_out       => open,
            modification_active   => open,
            instantaneous_toggles => open,
            measured_toggle_rate  => measured_toggle_rate
        );

    core : entity work.mips32_core
        generic map (
            SCAN_CHAINS => NUM_CHAINS_C
        )
        port map (
            clk                  => clk,
            reset                => core_reset,
            run_enable           => '0',
            test_mode            => test_mode_i,
            scan_enable          => scan_enable,
            capture_enable       => capture_i,
            scan_in              => dut_scan_in_i,
            scan_out             => dut_scan_out_i,
            instruction          => instruction,
            instruction_address  => instruction_address,
            data_read            => data_read,
            data_address         => data_address,
            data_write           => data_write,
            data_write_enable    => data_write_enable,
            illegal_instruction  => illegal_instruction,
            misaligned_access    => misaligned_access,
            debug_state          => debug_state
        );
end architecture;
