library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_scan_register_bank is
  generic (BITS : positive := 1024; CHAINS : positive := 4);
end;
architecture test of tb_scan_register_bank is
  signal clk : std_logic := '0';
  signal reset, shift, capture : std_logic := '0';
  signal din, q : std_logic_vector(BITS-1 downto 0) := (others=>'0');
  signal si, so : std_logic_vector(CHAINS-1 downto 0) := (others=>'0');
begin
  clk <= not clk after 5 ns;
  dut: entity work.scan_register_bank generic map(BITS,CHAINS)
    port map(clk,reset,shift,capture,din,si,so,q);
  process
    variable model, expected : std_logic_vector(BITS-1 downto 0) := (others=>'0');
    procedure tick is begin wait until rising_edge(clk); wait for 1 ns; end;
  begin
    reset<='1'; shift<='1'; capture<='1'; si<=(others=>'1'); tick;
    assert q=model report "Reset priority" severity failure;
    reset<='0'; shift<='0';
    for i in 0 to BITS-1 loop
      if (i mod 7)=0 or (i mod 11)=2 then expected(i):='1'; end if;
    end loop;
    din<=expected; tick; model:=expected;
    assert q=model report "Parallel capture" severity failure;
    capture<='0'; din<=not expected; tick;
    assert q=model report "Hold" severity failure;
    shift<='1'; capture<='1'; -- shifting wins over capture
    for cycle in 0 to 2*((BITS+CHAINS-1)/CHAINS)+3 loop
      for c in 0 to CHAINS-1 loop
        assert so(c)=model(c+((BITS-1-c)/CHAINS)*CHAINS)
          report "Serial output mapping" severity failure;
        if ((cycle+3*c) mod 5)<2 then si(c)<='1'; else si(c)<='0'; end if;
      end loop;
      wait for 1 ns;
      for i in BITS-1 downto 0 loop
        if i<CHAINS then model(i):=si(i); else model(i):=model(i-CHAINS); end if;
      end loop;
      tick;
      assert q=model report "Shift ordering or chain boundary" severity failure;
    end loop;
    report "PASS scan bits=" & integer'image(BITS) & " chains=" & integer'image(CHAINS);
    stop; wait;
  end process;
end;
