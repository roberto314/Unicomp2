LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
--this is comment
library ieee; 
use ieee.std_logic_1164.all; 
entity spi_slave is 
    port(
        sclk : in std_logic;
        mosi : in std_logic;
        ss_n : in std_logic; 
        data    : in std_logic_vector(47 downto 0); 
        miso  : out std_logic); 
end spi_slave; 
architecture archi of spi_slave is 
  signal dat_reg: std_logic_vector(47 downto 0); 

  begin  
    process (sclk, ss_n, data) 
      begin 
        if (ss_n='1') then 
          dat_reg <= data; 
        elsif (sclk'event and sclk='1') then 
          dat_reg <= dat_reg(46 downto 0) & mosi; 
        end if; 
    end process; 

    miso <= dat_reg(47); 
end archi; 