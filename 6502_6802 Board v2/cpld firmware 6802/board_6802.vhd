library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity board_6802 is
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
        CLK_F    : in std_logic;  -- Fast Clock Input
        CLK_S    : in  STD_LOGIC; -- Slow Clock Input
        nHLT     : in  STD_LOGIC; -- Atari Halt
        RnW      : in  STD_LOGIC; -- R/W from CPU
        E_CPU    : in  STD_LOGIC; -- E from CPU
        MR       : out  STD_LOGIC; -- MR to CPU
        PHI0CPU  : out STD_LOGIC; -- PHI 0 to CPU
        VMA      : in  STD_LOGIC; --
        RnWout   : out STD_LOGIC := '1'; -- R/W Out to Bus
        nMWR     : out STD_LOGIC := '1'; -- Mem Write to Bus
        nMRD     : out STD_LOGIC := '1'; -- Mem Read to Bus
        PHI1     : out STD_LOGIC; -- PHI Output to Bus
        PHI2     : out STD_LOGIC; -- PHI Output to Bus
        nRAMCE   : out STD_LOGIC;
        nRAMWE   : out STD_LOGIC
        );
end board_6802;

architecture Behavioral of board_6802 is
    --signal w_n_CS       : std_logic :='1';
    signal clk_divider  : unsigned(3 downto 0);
    signal w_cpuClk     : std_logic;
    signal w_n_RAMCS    : std_logic :='1';
    signal w_n_ROMCS    : std_logic :='1';
    signal s_nMRD       : std_logic :='1';
    signal s_nMWR       : std_logic :='1';

begin

s_nMRD <= NOT(RnW AND VMA);
s_nMWR <= NOT((NOT RnW) AND VMA);
--s_nMRD <= NOT(RnW       AND ( clk_divider(1)));
--s_nMWR <= NOT((NOT RnW) AND ( clk_divider(1)));

PHI1 <= '0';
PHI2 <= E_CPU;
RnWout <= RnW;
nAOE <= '0';
nDOE <= '0';
DDIR <= RnW;

-------------------- external RD and WR Signals ---------------
nMRD <= s_nMRD;
nMWR <= s_nMWR;

process (CLK_F)
    begin
        if rising_edge(CLK_F) then
            clk_divider   <= clk_divider + 1;
        end if;
    end process;
    PHI0CPU <= clk_divider(0); -- MC6802 has 4MHz oscillator for 1MHz operation
end Behavioral;