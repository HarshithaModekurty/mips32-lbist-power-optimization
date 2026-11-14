library ieee;
use ieee.std_logic_1164.all;

-- Balanced interleaving: chain c contains c, c+CHAINS, c+2*CHAINS, ... .
-- No padding flops; shorter chains continue shifting on every shift edge.
entity scan_register_bank is
  generic (BITS : positive := 1024; CHAINS : positive := 4);
  port (clk, reset, scan_enable, capture_enable : in std_logic;
        functional_next : in std_logic_vector(BITS-1 downto 0);
        scan_in : in std_logic_vector(CHAINS-1 downto 0);
        scan_out : out std_logic_vector(CHAINS-1 downto 0);
        state : out std_logic_vector(BITS-1 downto 0));
end entity;

architecture rtl of scan_register_bank is
  signal q : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin
  assert CHAINS <= BITS report "CHAINS must not exceed BITS" severity failure;
  state <= q;
  outputs: for c in 0 to CHAINS-1 generate
    scan_out(c) <= q(c + ((BITS-1-c)/CHAINS)*CHAINS);
  end generate;
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then q <= (others => '0');
      elsif scan_enable = '1' then
        for i in 0 to BITS-1 loop
          if i < CHAINS then q(i) <= scan_in(i);
          else q(i) <= q(i-CHAINS); end if;
        end loop;
      elsif capture_enable = '1' then q <= functional_next;
      end if;
    end if;
  end process;
end architecture;
