library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mips32_scan_pkg.all;

-- Single-cycle educational MIPS32 subset. Combinational instruction/data reads.
-- No delay slots, exceptions, interrupts, caches, HI/LO, or unaligned accesses.
entity mips32_core is
  generic (SCAN_CHAINS : positive := 4);
  port (clk, reset, run_enable, test_mode, scan_enable, capture_enable : in std_logic;
        scan_in : in std_logic_vector(SCAN_CHAINS-1 downto 0);
        scan_out : out std_logic_vector(SCAN_CHAINS-1 downto 0);
        instruction : in word_t;
        instruction_address : out word_t;
        data_read : in word_t;
        data_address, data_write : out word_t;
        data_write_enable : out std_logic;
        illegal_instruction, misaligned_access : out std_logic;
        debug_state : out state_t);
end entity;

architecture rtl of mips32_core is
  signal q, d : state_t := (others => '0');
  signal shift, capture : std_logic;
begin
  shift <= test_mode and scan_enable;
  capture <= ((not test_mode) and run_enable) or
             (test_mode and capture_enable and not scan_enable);
  bank: entity work.scan_register_bank
    generic map (BITS => STATE_BITS, CHAINS => SCAN_CHAINS)
    port map (clk, reset, shift, capture, d, scan_in, scan_out, q);
  instruction_address <= q(31 downto 0);
  debug_state <= q;

  process(all)
    variable regs : register_file_t;
    variable next_state : state_t;
    variable pc4, next_pc, a, b, result, imm, address : unsigned(31 downto 0);
    variable op, fn, rs, rt, rd, shamt, dest : natural;
    variable write_reg, store, bad, alignment : boolean;
  begin
    regs(0) := (others => '0');
    for r in 1 to 31 loop regs(r) := q(32*r+31 downto 32*r); end loop;
    next_state := q;
    pc4 := unsigned(q(31 downto 0)) + 4; next_pc := pc4;
    op := to_integer(unsigned(instruction(31 downto 26)));
    rs := to_integer(unsigned(instruction(25 downto 21)));
    rt := to_integer(unsigned(instruction(20 downto 16)));
    rd := to_integer(unsigned(instruction(15 downto 11)));
    shamt := to_integer(unsigned(instruction(10 downto 6)));
    fn := to_integer(unsigned(instruction(5 downto 0)));
    a := unsigned(regs(rs)); b := unsigned(regs(rt));
    imm := unsigned(resize(signed(instruction(15 downto 0)),32));
    address := a + imm; result := (others => '0'); dest := rt;
    write_reg := false; store := false; bad := false; alignment := false;
    case op is
      when 0 =>
        dest := rd; write_reg := true;
        case fn is
          when 0 => result := shift_left(b,shamt);
          when 2 => result := shift_right(b,shamt);
          when 3 => result := unsigned(shift_right(signed(b),shamt));
          when 8 => next_pc := a; write_reg := false;
          when 33 => result := a+b; -- ADDU
          when 35 => result := a-b; -- SUBU
          when 36 => result := a and b;
          when 37 => result := a or b;
          when 38 => result := a xor b;
          when 39 => result := not (a or b);
          when 42 => if signed(a)<signed(b) then result(0):='1'; end if;
          when 43 => if a<b then result(0):='1'; end if;
          when others => bad := true; write_reg := false;
        end case;
      when 9 => result := a+imm; write_reg := true; -- ADDIU
      when 10 =>
        if signed(a)<signed(imm) then result(0):='1'; end if; write_reg := true;
      when 11 => if a<imm then result(0):='1'; end if; write_reg := true;
      when 12 => result := a and resize(unsigned(instruction(15 downto 0)),32); write_reg := true;
      when 13 => result := a or resize(unsigned(instruction(15 downto 0)),32); write_reg := true;
      when 14 => result := a xor resize(unsigned(instruction(15 downto 0)),32); write_reg := true;
      when 15 => result := unsigned(instruction(15 downto 0)) & x"0000"; write_reg := true;
      when 35 =>
        alignment := address(1 downto 0)/="00";
        result := unsigned(data_read); write_reg := not alignment;
      when 43 => alignment := address(1 downto 0)/="00"; store := not alignment;
      when 4 | 5 =>
        if (op=4 and a=b) or (op=5 and a/=b) then next_pc := pc4+shift_left(imm,2); end if;
      when 2 | 3 =>
        next_pc(31 downto 28) := pc4(31 downto 28);
        next_pc(27 downto 2) := unsigned(instruction(25 downto 0));
        next_pc(1 downto 0) := "00";
        if op=3 then dest:=31; result:=pc4; write_reg:=true; end if;
      when others => bad := true;
    end case;
    if next_pc(1 downto 0)/="00" then
      alignment := true; next_pc := pc4;
    end if;
    if write_reg and dest/=0 then next_state(32*dest+31 downto 32*dest):=std_logic_vector(result); end if;
    next_state(31 downto 0):=std_logic_vector(next_pc); d <= next_state;
    data_address <= std_logic_vector(address); data_write <= std_logic_vector(b);
    data_write_enable <= '0';
    if store and test_mode='0' and reset='0' and run_enable='1' then data_write_enable<='1'; end if;
    illegal_instruction <= '0'; if bad then illegal_instruction<='1'; end if;
    misaligned_access <= '0'; if alignment then misaligned_access<='1'; end if;
  end process;
end architecture;
