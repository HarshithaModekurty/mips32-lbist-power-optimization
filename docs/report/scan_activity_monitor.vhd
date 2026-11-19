library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity scan_activity_monitor is
    generic (
        LANES : positive := 4
    );
    port (
        clk             : in  std_logic;
        rst_n           : in  std_logic;
        scan_enable     : in  std_logic;
        scan_data       : in  std_logic_vector(LANES - 1 downto 0);
        toggle_count    : out unsigned(31 downto 0);
        measured_rate   : out unsigned(7 downto 0)
    );
end entity;

architecture rtl of scan_activity_monitor is
    signal previous_data : std_logic_vector(LANES - 1 downto 0) := (others => '0');
    signal previous_valid : std_logic := '0';
    signal toggle_count_i : unsigned(31 downto 0) := (others => '0');
    signal shift_count_i  : unsigned(31 downto 0) := (others => '0');
begin
    toggle_count <= toggle_count_i;

    process(clk, rst_n)
        variable transitions : natural range 0 to LANES;
    begin
        if rst_n = '0' then
            previous_data  <= (others => '0');
            previous_valid <= '0';
            toggle_count_i <= (others => '0');
            shift_count_i  <= (others => '0');
        elsif rising_edge(clk) then
            if scan_enable = '1' then
                transitions := 0;
                for lane in 0 to LANES - 1 loop
                    if previous_valid = '1' and
                       scan_data(lane) /= previous_data(lane) then
                        transitions := transitions + 1;
                    end if;
                end loop;
                toggle_count_i <= toggle_count_i + transitions;
                shift_count_i <= shift_count_i + 1;
                previous_data <= scan_data;
                previous_valid <= '1';
            else
                previous_valid <= '0';
            end if;
        end if;
    end process;

    process(toggle_count_i, shift_count_i)
        variable denominator : natural;
        variable numerator   : natural;
        variable rate        : natural;
    begin
        denominator := to_integer(shift_count_i) * LANES;
        if denominator = 0 then
            rate := 0;
        else
            numerator := to_integer(toggle_count_i) * 100;
            rate := numerator / denominator;
            if rate > 100 then
                rate := 100;
            end if;
        end if;
        measured_rate <= to_unsigned(rate, measured_rate'length);
    end process;
end architecture;
