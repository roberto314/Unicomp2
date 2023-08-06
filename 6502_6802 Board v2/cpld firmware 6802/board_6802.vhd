library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity board_6802 is
    Port ( 
        A        : in std_logic_vector(15 downto 0);
        RES0     : out std_logic;
        RES1     : out std_logic;
        BA       : in std_logic;
        MOSI     : in  STD_LOGIC; -- SPI Interface
        SCK      : in  STD_LOGIC; -- SPI Interface
        nDOE     : out STD_LOGIC := '1'; -- Data Buffer Enable
        nAOE     : out STD_LOGIC := '1'; -- Address Buffer Enable
        CLKF     : in std_logic;  -- Main Clock Input
        RnW      : in  STD_LOGIC; -- R/W from CPU
        E_CPU    : in  STD_LOGIC; -- E from CPU
        nMR      : in  STD_LOGIC; -- Memory Read from CPU
        PH0      : out STD_LOGIC; -- PHI 0 to CPU
        nPH0     : out STD_LOGIC; -- PHI 0 to CPU (inverted)
        VMA      : in  STD_LOGIC; -- Valid Memory Address from CPU
        nRST     : in  STD_LOGIC; -- Reset CPU
        nBUSFREE : out  STD_LOGIC; -- Bus Free means High-Z on Bus
        nMWR     : out STD_LOGIC := '1'; -- Mem Write to Bus
        nMRD     : out STD_LOGIC := '1'; -- Mem Read to Bus
        PHI1     : out STD_LOGIC; -- PHI Output to Bus
        PHI2     : out STD_LOGIC  -- PHI Output to Bus
        );
end board_6802;

architecture Behavioral of board_6802 is
    --signal w_n_CS       : std_logic :='1';
    signal clk_divider  : unsigned(3 downto 0);
    signal s_nMRD       : std_logic :='1';
    signal s_nMWR       : std_logic :='1';
    signal s_BUS        : std_logic :='1';
    signal s_PH0     : std_logic :='1';
    signal s_BCLKWS     : std_logic :='1';
    signal s_CPUCLK     : std_logic :='1';
    signal s_EVMA       : std_logic :='1';
    signal s_BUSTEMP    : std_logic :='1';
    signal s_RST        : std_logic :='1';

begin
s_EVMA <= E_CPU AND VMA;
PHI2 <= s_EVMA;

s_nMRD <= NOT(RnW AND s_EVMA);
s_nMWR <= NOT((NOT RnW) AND s_EVMA);

--s_BUS <= nRST AND (NOT(s_PH0 OR s_BCLKWS) OR E_CPU); -- Reset must release bus bc. of STM32!
--s_BUS <= nRST AND NOT s_BUSTEMP; --Test
s_BUS <= s_RST AND s_BCLKWS; --Test
--s_BUS <= nRST AND NOT(BA); --low if reset == 0 OR BA == 1

nAOE <= NOT(s_BUS); 
nDOE <= NOT(s_BUS); 

nBUSFREE <= s_BUS;
RES0 <= s_PH0;
RES1 <= s_BCLKWS;
s_BUSTEMP <= (NOT s_EVMA) OR s_BCLKWS;
-------------------- external RD and WR Signals ---------------
nMRD <= s_nMRD;
nMWR <= s_nMWR;

process (CLKF)
    begin
        if rising_edge(CLKF) then
            if (clk_divider < 7) then 
                clk_divider <= clk_divider + 1;
            else
                clk_divider <= (others => '0');
            end if;
        end if;
    end process;
    s_RST <= nRST;
    s_PH0 <= clk_divider(2);
    s_CPUCLK <= clk_divider(0); -- MC6802 has 4MHz oscillator for 1MHz operation
    nPH0 <= NOT(s_CPUCLK);
    PH0 <= s_CPUCLK;

--process (CLKF, s_PH0) --this delays the PHI0 to the CPU for half period of CLKF (8MHz) -not needed!
--    begin
--        if falling_edge(CLKF) then
--            --if s_PH0 = '1' then
--                --nPH0 <= NOT(s_PH0);
--                --PH0 <= s_PH0;
--            --end if;
--        end if;
--    end process;

process (CLKF, clk_divider) --this delays the PHI0 to the CPU for half period of CLKF (8MHz) -not needed!
    begin
        if rising_edge(CLKF) then
            if clk_divider = 5 then
                s_BCLKWS <= '0';
            end if;
            if clk_divider = 0 then 
                s_BCLKWS <= '1';
            end if;
        end if;
    end process;
end Behavioral;
