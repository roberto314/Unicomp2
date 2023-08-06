library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity board_6502 is
    Port ( 
        A        : in std_logic_vector(15 downto 0);
        RES0     : in std_logic;
        RES1     : in std_logic;
        RES2     : in std_logic;
        MOSI     : in  STD_LOGIC; -- SPI Interface
        SCK      : in  STD_LOGIC; -- SPI Interface
        nDOE     : out STD_LOGIC := '1'; -- Data Buffer Enable
        nAOE     : out STD_LOGIC := '1'; -- Address Buffer Enable
        CLKF     : in std_logic;  -- Main Clock Input
        RnW      : in  STD_LOGIC; -- R/W from CPU
        PHI2CPU  : in  STD_LOGIC; -- PHI 2 from CPU
        PHI1CPU  : in  STD_LOGIC; -- PHI 1 from CPU
        PH0      : out STD_LOGIC; -- PHI 0 to CPU
        nPH0     : out STD_LOGIC; -- PHI 0 to CPU (inverted)
        nML      : in  STD_LOGIC; -- Memory Lock from CPU
        nRST     : in  STD_LOGIC; -- Reset CPU
        nBUSFREE : out  STD_LOGIC; -- Bus Free means High-Z on Bus
        nMWR     : out STD_LOGIC := '1'; -- Mem Write to Bus
        nMRD     : out STD_LOGIC := '1'; -- Mem Read to Bus
        PHI1     : out STD_LOGIC; -- PHI Output to Bus
        PHI2     : out STD_LOGIC  -- PHI Output to Bus
        );
end board_6502;

architecture Behavioral of board_6502 is
    --signal w_n_CS       : std_logic :='1';
    signal clk_divider  : unsigned(3 downto 0);
    signal s_nMRD       : std_logic :='1';
    signal s_nMWR       : std_logic :='1';
    signal s_BUS        : std_logic :='1';
    signal s_PH0     : std_logic :='1';

begin

s_nMRD <= NOT(RnW AND PHI2CPU);       -- thats how it is usually done.
s_nMWR <= NOT((NOT RnW) AND PHI2CPU); -- thats how it is usually done.

-- nAOE <= '0'; -- works (2MHz possible)
s_BUS <= nRST AND (s_PH0 OR PHI2CPU); -- Reset must release bus bc. of STM32!

nAOE <= NOT(s_BUS); -- test -works
nDOE <= NOT(s_BUS); -- test -works
nBUSFREE <= s_BUS;
-------------------- external RD and WR Signals ---------------
nMRD <= s_nMRD;
nMWR <= s_nMWR;

process (CLKF)
    begin
        if rising_edge(CLKF) then
            clk_divider   <= clk_divider + 1;
        end if;
    end process;
    s_PH0 <= clk_divider(2);
    nPH0 <= NOT(s_PH0);
    PH0 <= s_PH0;

process (CLKF, s_PH0) --this delays the PHI0 to the CPU for half period of CLKF (8MHz) -not needed!
    begin
        if falling_edge(CLKF) then
            --if s_PH0 = '1' then
                --nPH0 <= NOT(s_PH0);
                --PH0 <= s_PH0;
            --end if;
        end if;
    end process;
end Behavioral;