--
-- ls165.vhd
--
-- Description:  This is a VHDL synthesizable description of the 74LS165
--               8-Bit Parallel-to-Serial Shift Register.
--               
-- 
-- Author:  Wilson Li
-- Date:    March 27, 1997
-- 
--

library ieee;
use ieee.std_logic_1164.all;


entity ls165 is
  port(
    p:      in std_logic_vector(7 downto 0);
    pl:     in std_logic;
    ds:     in std_logic;
    cp1:    in std_logic;
    cp2:    in std_logic;
    q7:     out std_logic;
    q7_bar: out std_logic
  );
end ls165;


architecture ls165_body of ls165 is

  signal q_buf:      std_logic_vector(7 downto 0);
  signal gated_clk:  std_logic;

begin

  q7 <= q_buf(7);
  q7_bar <= not q_buf(7);
  gated_clk <= cp1 or cp2;
  
  process(gated_clk)

  begin

    if gated_clk'event and gated_clk = '1' then

      if pl = '0' then

        q_buf <= p;

      else

        -- shift by 1 bit
        --
        q_buf(0) <= ds;
        q_buf(1) <= q_buf(0);
        q_buf(2) <= q_buf(1);
        q_buf(3) <= q_buf(2);
        q_buf(4) <= q_buf(3);
        q_buf(5) <= q_buf(4);
        q_buf(6) <= q_buf(5);
        q_buf(7) <= q_buf(6);

      end if;

    end if;

  end process;

end ls165_body;

