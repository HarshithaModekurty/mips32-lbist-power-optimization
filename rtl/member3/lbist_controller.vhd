-- =============================================================================
-- File        : lbist_controller.vhd
-- Entity      : lbist_controller
-- Description : Moore-machine FSM sequencing the LBIST test.
--               Updated with 4-channel scan control signals:
--                 - test_mode       : high during BIST execution
--                 - scan_enable     : high during 256-cycle SHIFT phase
--                 - capture_enable  : high during 1-cycle CAPTURE phase
--                 - dut_rst_sync    : active-high synchronous reset pulse for DUT
--
-- Course      : VL405 – Design for Testability Lab
-- Member      : 3 – LBIST Controller & Fault Analysis
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lbist_pkg.all;

entity lbist_controller is
  generic (
    CHAIN_LENGTH  : integer := CHAIN_LEN_C;   -- 256 cycles per chain
    PATTERN_COUNT : integer := PAT_CNT_C;     -- Number of test patterns
    MISR_WIDTH    : integer := MISR_W_C       -- 32 bits
  );
  port (
    clk            : in  std_logic;
    rst_n          : in  std_logic;    -- Active-low system reset
    start          : in  std_logic;    -- Pulse to begin LBIST

    -- Golden and MISR signature inputs for evaluation
    golden_sig     : in  std_logic_vector(MISR_WIDTH-1 downto 0);
    misr_sig       : in  std_logic_vector(MISR_WIDTH-1 downto 0);

    -- ── Member 1 MIPS32 Scan-Control Interface ────────────────────────────
    test_mode      : out std_logic;    -- '1' = LBIST test mode active
    scan_enable    : out std_logic;    -- '1' = shift mode
    capture_enable : out std_logic;    -- '1' = capture functional response
    dut_rst_sync   : out std_logic;    -- Active-high synchronous reset for MIPS
    scan_en        : out std_logic;    -- Backward-compatible alias for scan_enable

    -- ── Internal / Member-2 Control Signals ────────────────────────────────
    misr_rst_n     : out std_logic;    -- Active-low MISR synchronous reset
    misr_capture   : out std_logic;    -- Enable MISR compression during SHIFT
    prpg_advance   : out std_logic;    -- Advance PRPG pattern generator

    -- ── Status and Monitoring ──────────────────────────────────────────────
    test_done      : out std_logic;
    test_pass      : out std_logic;
    state_out      : out std_logic_vector(2 downto 0);
    pattern_num    : out std_logic_vector(15 downto 0)
  );
end entity lbist_controller;

architecture rtl of lbist_controller is

  signal state     : std_logic_vector(2 downto 0) := ST_IDLE;
  signal shift_cnt : integer range 0 to CHAIN_LENGTH + 1 := 0;
  signal pat_cnt   : integer range 0 to PATTERN_COUNT    := 0;
  signal sig_match : std_logic;

begin

  sig_match   <= '1' when (misr_sig = golden_sig) else '0';
  state_out   <= state;
  pattern_num <= std_logic_vector(to_unsigned(pat_cnt, 16));

  -- Backward-compatibility wire
  scan_en     <= '1' when (state = ST_SHIFT) else '0';

  -- =========================================================================
  -- State register and counters
  -- =========================================================================
  p_seq : process(clk, rst_n)
  begin
    if rst_n = '0' then
      state     <= ST_IDLE;
      shift_cnt <= 0;
      pat_cnt   <= 0;

    elsif rising_edge(clk) then

      case state is

        when ST_IDLE =>
          shift_cnt <= 0;
          pat_cnt   <= 0;
          if start = '1' then
            state <= ST_INIT;
          end if;

        when ST_INIT =>
          shift_cnt <= 0;
          pat_cnt   <= 0;
          state     <= ST_SHIFT;

        when ST_SHIFT =>
          if shift_cnt = CHAIN_LENGTH - 1 then
            shift_cnt <= 0;
            state     <= ST_CAPTURE;
          else
            shift_cnt <= shift_cnt + 1;
          end if;

        when ST_CAPTURE =>
          if pat_cnt = PATTERN_COUNT - 1 then
            pat_cnt <= 0;
            state   <= ST_COMPARE;
          else
            pat_cnt <= pat_cnt + 1;
            state   <= ST_LOAD;
          end if;

        when ST_LOAD =>
          state <= ST_SHIFT;

        when ST_COMPARE =>
          if sig_match = '1' then
            state <= ST_PASS;
          else
            state <= ST_FAIL;
          end if;

        when ST_PASS | ST_FAIL =>
          null;   -- Hold result until reset

        when others =>
          state <= ST_IDLE;

      end case;
    end if;
  end process p_seq;

  -- =========================================================================
  -- Combinational output decode
  -- =========================================================================
  p_out : process(state)
  begin
    test_mode      <= '0';
    scan_enable    <= '0';
    capture_enable <= '0';
    dut_rst_sync   <= '0';
    misr_rst_n     <= '1';
    misr_capture   <= '0';
    prpg_advance   <= '0';
    test_done      <= '0';
    test_pass      <= '0';

    case state is
      when ST_INIT =>
        test_mode      <= '1';
        dut_rst_sync   <= '1';   -- Synchronous reset pulse to MIPS core
        misr_rst_n     <= '0';   -- Initialize MISR to all-ones seed
        prpg_advance   <= '1';   -- Initialize first PRPG pattern

      when ST_SHIFT =>
        test_mode      <= '1';
        scan_enable    <= '1';   -- MIPS32 scan multiplexers select scan_in
        misr_capture   <= '1';   -- MISR compresses 4 scan_out bits

      when ST_CAPTURE =>
        test_mode      <= '1';
        capture_enable <= '1';   -- MIPS32 executes 1 clock cycle of normal logic

      when ST_LOAD =>
        test_mode      <= '1';
        prpg_advance   <= '1';   -- Advance to next PRPG pattern

      when ST_COMPARE =>
        test_mode      <= '1';

      when ST_PASS =>
        test_done      <= '1';
        test_pass      <= '1';

      when ST_FAIL =>
        test_done      <= '1';
        test_pass      <= '0';

      when others =>
        null;
    end case;
  end process p_out;

end architecture rtl;
