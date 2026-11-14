library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mips32_scan_pkg.all;
use std.env.all;

entity tb_mips32_core is end;
architecture test of tb_mips32_core is
  signal clk : std_logic := '0';
  signal reset, run, test_mode, shift, capture : std_logic := '0';
  signal si, so : std_logic_vector(3 downto 0) := (others=>'0');
  signal insn, pc, data_read, address, wd : word_t := (others=>'0');
  signal we, illegal, misaligned : std_logic;
  signal q : state_t;
begin
  clk <= not clk after 5 ns;
  dut: entity work.mips32_core port map(clk,reset,run,test_mode,shift,capture,
    si,so,insn,pc,data_read,address,wd,we,illegal,misaligned,q);
  process
    variable saved, loaded : state_t;
    procedure tick is begin wait until rising_edge(clk); wait for 1 ns; end;
    procedure execute(code : word_t) is
    begin insn<=code; wait for 1 ns; tick; end;
    procedure regcheck(r : natural; value : word_t) is
    begin assert q(32*r+31 downto 32*r)=value
      report "Register mismatch r" & integer'image(r) severity failure; end;
  begin
    reset<='1'; tick; reset<='0'; run<='1';
    execute(x"24010005"); regcheck(1,x"00000005"); -- addiu
    execute(x"2402FFFE"); regcheck(2,x"FFFFFFFE");
    execute(x"00221821"); regcheck(3,x"00000003"); -- addu
    execute(x"00222023"); regcheck(4,x"00000007"); -- subu
    execute(x"00222824"); regcheck(5,x"00000004");
    execute(x"00223025"); regcheck(6,x"FFFFFFFF");
    execute(x"00223826"); regcheck(7,x"FFFFFFFB");
    execute(x"00224027"); regcheck(8,x"00000000");
    execute(x"0041482A"); regcheck(9,x"00000001"); -- signed slt
    execute(x"0041502B"); regcheck(10,x"00000000");
    execute(x"00015880"); regcheck(11,x"00000014");
    execute(x"00026042"); regcheck(12,x"7FFFFFFF");
    execute(x"00026843"); regcheck(13,x"FFFFFFFF");
    execute(x"304E00FF"); regcheck(14,x"000000FE");
    execute(x"340F8000"); regcheck(15,x"00008000");
    execute(x"39F000FF"); regcheck(16,x"000080FF");
    execute(x"3C111234"); regcheck(17,x"12340000");
    execute(x"28520000"); regcheck(18,x"00000001");
    execute(x"2C53FFFF"); regcheck(19,x"00000001");
    execute(x"240000FF"); -- r0 must remain hardwired
    execute(x"24140000"); regcheck(20,x"00000000");
    insn<=x"AC010004"; wait for 1 ns;
    assert we='1' and address=x"00000004" and wd=x"00000005" report "SW bus" severity failure;
    tick;
    data_read<=x"DEADBEEF"; execute(x"8C150004"); regcheck(21,x"DEADBEEF");
    insn<=x"AC010001"; wait for 1 ns;
    assert we='0' and misaligned='1' report "Unaligned store suppression" severity failure;
    tick;
    execute(x"8C150001"); regcheck(21,x"DEADBEEF");
    assert misaligned='1' report "Unaligned load" severity failure;
    saved:=q; execute(x"10210002");
    assert unsigned(pc)=unsigned(saved(31 downto 0))+12 report "BEQ" severity failure;
    saved:=q; execute(x"14220001");
    assert unsigned(pc)=unsigned(saved(31 downto 0))+8 report "BNE" severity failure;
    saved:=q; execute(x"10220002");
    assert unsigned(pc)=unsigned(saved(31 downto 0))+4 report "Untaken branch" severity failure;
    execute(x"08000040"); assert pc=x"00000100" report "J" severity failure;
    execute(x"0C000080"); assert pc=x"00000200" report "JAL" severity failure;
    regcheck(31,x"00000104");
    execute(x"03E00008"); assert pc=x"00000104" report "JR" severity failure;
    execute(x"FC000000"); assert illegal='1' report "Illegal opcode" severity failure;
    execute(x"0000003F"); assert illegal='1' report "Illegal function" severity failure;
    saved:=q; execute(x"1021FFFF");
    assert pc=saved(31 downto 0) report "Negative branch offset" severity failure;
    execute(x"00200008"); -- JR r1=5 is unaligned
    assert misaligned='1' report "Unaligned JR diagnostic" severity failure;
    assert unsigned(pc)=unsigned(saved(31 downto 0))+4 report "Unaligned JR fallthrough" severity failure;
    shift<='1'; capture<='1'; si<=(others=>'1');
    execute(x"2416002B"); regcheck(22,x"0000002B"); -- functional mode ignores test controls
    shift<='0'; capture<='0';
    run<='0'; saved:=q; execute(x"24010009");
    assert q=saved report "Run hold" severity failure;
    test_mode<='1'; run<='1'; insn<=x"AC010004"; wait for 1 ns;
    assert we='0' report "Test-mode memory isolation" severity failure;
    tick; assert q=saved report "Test hold" severity failure;
    -- Arbitrary full scan load: feed highest index first on each chain.
    loaded:=(others=>'0'); loaded(63 downto 32):=x"00000029";
    loaded(31 downto 0):=x"00000080";
    shift<='1'; capture<='1';
    for step in 255 downto 0 loop
      for c in 0 to 3 loop si(c)<=loaded(step*4+c); end loop;
      tick;
    end loop;
    assert q=loaded report "Core full scan load" severity failure;
    shift<='0'; insn<=x"24220001"; tick;
    regcheck(2,x"0000002A"); assert pc=x"00000084" report "Functional test capture" severity failure;
    capture<='0'; saved:=q; tick; assert q=saved report "Capture hold" severity failure;
    shift<='1';
    for step in 255 downto 0 loop
      for c in 0 to 3 loop
        assert so(c)=saved(step*4+c) report "Core response unload" severity failure;
      end loop;
      tick;
    end loop;
    reset<='1'; tick; assert q=(q'range=>'0') report "Reset during scan" severity failure;
    report "PASS core instruction execution, scan load/capture/unload, isolation";
    stop; wait;
  end process;
end;
