library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity board_6502 is
    Port ( 
        A        : in std_logic_vector(15 downto 8);
        CON0     : in std_logic;
        CON1     : in std_logic;
        CON2     : in std_logic;
        MOSI     : in  STD_LOGIC; -- SPI Interface
        SCK      : in  STD_LOGIC; -- SPI Interface
        CS       : in  STD_LOGIC; -- SPI Interface
        DDIR     : out STD_LOGIC := '1'; -- Data Buffer Direction
        nDOE     : out STD_LOGIC := '1'; -- Data Buffer Enable
        nAOE     : out STD_LOGIC := '1'; -- Address Buffer Enable
        DOT_CLK  : in std_logic;  -- Main Clock Input
        CLK_in   : in  STD_LOGIC; -- Main Clock Input
        nHLT     : in  STD_LOGIC; -- Atari Halt
        RnW      : in  STD_LOGIC; -- R/W from CPU
        PHI2CPU  : in  STD_LOGIC; -- PHI 2 from CPU
        PHI1CPU  : in  STD_LOGIC; -- PHI 1 from CPU
        PHI0CPU  : out STD_LOGIC; -- PHI 0 to CPU
        nML      : in  STD_LOGIC; --
        RnWout   : out STD_LOGIC := '1'; -- R/W Out to Bus
        nMWR     : out STD_LOGIC := '1'; -- Mem Write to Bus
        nMRD     : out STD_LOGIC := '1'; -- Mem Read to Bus
        PHI1     : out STD_LOGIC; -- PHI Output to Bus
        PHI2     : out STD_LOGIC; -- PHI Output to Bus
        nRAMCE   : out STD_LOGIC;
        nRAMWE   : out STD_LOGIC
        );
end board_6502;

architecture Behavioral of board_6502 is
    --signal w_n_CS       : std_logic :='1';
    signal clk_divider  : unsigned(3 downto 0);
    signal w_cpuClk     : std_logic;
    signal w_n_RAMCS    : std_logic :='1';
    signal w_n_ROMCS    : std_logic :='1';
    signal s_nMRD       : std_logic :='1';
    signal s_nMWR       : std_logic :='1';

begin

s_nMRD <= NOT(RnW AND PHI2CPU);
s_nMWR <= NOT((NOT RnW) AND PHI2CPU);
--s_nMRD <= NOT(RnW       AND ( clk_divider(1)));
--s_nMWR <= NOT((NOT RnW) AND ( clk_divider(1)));

PHI1 <= PHI1CPU;
PHI2 <= PHI2CPU;
--PHI2 <= NOT(PHI1CPU); -- doesn't work
RnWout <= RnW;
--nAOE <= '0'; --NOT(PHI2CPU);
--nAOE <= PHI1CPU;
--nAOE <= NOT(clk_divider(2)); --test -works
-- nAOE <= '0'; -- works (2MHz possible)
nAOE <= NOT(clk_divider(2) OR PHI2CPU); -- test -works
-- For nDOE:
-- NOT(PHI2CPU); does not work
-- NOT(PHI1CPU); does not work
-- PHI1CPU; does not work
-- PHI2CPU; does not work
-- clk_divider(1); does not work

-- NOT(clk_divider(1)); does work!

--nDOE <= NOT(clk_divider(2)); 
nDOE <= NOT(clk_divider(2) OR PHI2CPU); -- test
DDIR <= RnW;
----------------------------- RAM on board --------------------
--w_n_RAMCS <= '0' when (A >= x"00") and (A <= x"7F") else '1';
--w_n_ROMCS <= '0' when (A >= x"C0") and (A <= x"FF") else '1';
nRAMCE <= (w_n_RAMCS AND w_n_ROMCS) OR (s_nMRD AND s_nMWR);
nRAMWE <= w_n_RAMCS OR s_nMWR;
-------------------- external RD and WR Signals ---------------
nMRD <= s_nMRD;
nMWR <= s_nMWR;

process (DOT_CLK)
    begin
        if rising_edge(DOT_CLK) then
            clk_divider   <= clk_divider + 1;
        end if;
    end process;
    PHI0CPU <= clk_divider(2);
end Behavioral;