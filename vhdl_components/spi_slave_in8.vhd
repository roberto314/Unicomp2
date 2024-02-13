LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
--this is comment
library ieee; 
use ieee.std_logic_1164.all; 
entity spi_slave_in8 is 
    port(
        sclk : in std_logic;
        mosi : in std_logic;
        ss_n : in std_logic; 
        data : out std_logic_vector(7 downto 0); 
        miso : out std_logic
        ); 
end spi_slave_in8; 
architecture archi of spi_slave_in8 is 
  signal dat_reg: std_logic_vector(7 downto 0); 

  begin  
    process (sclk) 
      begin 
        if (sclk'event and sclk = '1') then
          if (ss_n = '0') then 
            dat_reg <= dat_reg(6 downto 0) & mosi; 
          end if; 
        end if; 
    end process; 

    process (ss_n) 
      begin 
        if (ss_n'event and ss_n = '1') then 
          data <= dat_reg;
        end if;

    end process; 

    --miso <= dat_reg(7); 
end archi; 