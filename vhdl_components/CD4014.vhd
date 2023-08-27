--library IEEE;
--use IEEE.std_logic_1164.all;
--
--entity CD4014 is
--	port (
--		D: in STD_LOGIC_VECTOR (7 downto 0); -- Data Input
--		--Q: out STD_LOGIC_VECTOR (2 downto 0); -- Data Output
--		Q: out STD_LOGIC; -- Data Output
--		SHLD: in STD_LOGIC;
--		clk: in STD_LOGIC;
--		ds:     in std_logic
--	);
--end CD4014;
--
--architecture ARCH of CD4014 is
--  signal q_buf: std_logic_vector(7 downto 0);
--
--begin
--  Q <= q_buf(7);
--  --Q(2) <= q_buf(7);
--  --Q(1) <= q_buf(6);
--  --Q(0) <= q_buf(5);
--  
--  process(clk)
--  begin
--    if rising_edge(clk) then
--      if SHLD = '1' then
--        q_buf <= D;
--      else
--        -- shift by 1 bit
--        q_buf(0) <= ds;
--        q_buf(1) <= q_buf(0);
--        q_buf(2) <= q_buf(1);
--        q_buf(3) <= q_buf(2);
--        q_buf(4) <= q_buf(3);
--        q_buf(5) <= q_buf(4);
--        q_buf(6) <= q_buf(5);
--        q_buf(7) <= q_buf(6);
--      end if;
--    end if;
--  end process;
--end ARCH;


library ieee;
use ieee.std_logic_1164.all;
entity  CD4014 is
	port (
		--D0, D1, D2, D3, D4, D5, D6, D7, 
		D: in STD_LOGIC_VECTOR (7 downto 0); -- Data Input
		SHLD, clk:in std_logic; 
		Q, QNot: inout std_logic
	);
end entity  CD4014;

architecture LogicOperation of  CD4014 is
	signal S1, S2, S3, S4, S5, S6, S7, Q0, Q1, Q2, Q3, Q4, Q5, Q6, Q7: std_logic;

	function ShiftLoad (A,B,C: in std_logic) return std_logic is
	begin
		return ((A and B) or (not B and C));
	end function ShiftLoad;

	component dff1 is
		port (
			D, Clock, Pre, Clr: in std_logic;
			Q: inout std_logic
		);
	end component dff1;
	
	begin
	SL1: S1 <= ShiftLoad(Q0, SHLD, D(1));
	SL2: S2 <= ShiftLoad(Q1, SHLD, D(2));
	SL3: S3 <= ShiftLoad(Q2, SHLD, D(3));
	SL4: S4 <= ShiftLoad(Q3, SHLD, D(4));
	SL5: S5 <= ShiftLoad(Q4, SHLD, D(5));
	SL6: S6 <= ShiftLoad(Q5, SHLD, D(6));
	SL7: S7 <= ShiftLoad(Q6, SHLD, D(7));
	FF0: dff1 port map(D => D(0) and not SHLD, Clock => clk, Q => Q0, Pre => '1', Clr => '1');
	FF1: dff1 port map(D => S1,                Clock => clk, Q => Q1, Pre => '1', Clr => '1');
	FF2: dff1 port map(D => S2,                Clock => clk, Q => Q2, Pre => '1', Clr => '1');
	FF3: dff1 port map(D => S3,                Clock => clk, Q => Q3, Pre => '1', Clr => '1');
	FF4: dff1 port map(D => S4,                Clock => clk, Q => Q4, Pre => '1', Clr => '1');
	FF5: dff1 port map(D => S5,                Clock => clk, Q => Q5, Pre => '1', Clr => '1');
	FF6: dff1 port map(D => S6,                Clock => clk, Q => Q6, Pre => '1', Clr => '1');
	FF7: dff1 port map(D => S7,                Clock => clk, Q => Q , Pre => '1', Clr => '1');
	QNot <= not Q;
end architecture LogicOperation;