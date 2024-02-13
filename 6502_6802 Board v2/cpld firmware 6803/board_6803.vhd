library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity board_6803 is
    Port ( 
        A        : in std_logic_vector(15 downto 1);
        nHALT_in : in std_logic;  -- HALT Input
        nHALT    : out std_logic;  -- HALT to CPU
        BA       : in std_logic;  -- Bus Accsess (needed for /HALT)
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
        E_Out    : out STD_LOGIC  -- PHI Output to Bus
        );
end board_6803;

architecture Behavioral of board_6803 is
    --signal w_n_CS       : std_logic :='1';
    signal clk_divider  : unsigned(3 downto 0);
    signal s_nMRD       : std_logic :='1';
    signal s_nMWR       : std_logic :='1';
    signal s_BUS        : std_logic :='1';
    signal s_PH0        : std_logic :='1';
    signal s_BCLKWS     : std_logic :='1';
    signal s_CPUCLK     : std_logic :='1';
    signal s_EVMA       : std_logic :='1';
    signal s_ELEVEL     : std_logic :='1';

begin
E_Out <= E_CPU;
s_nMRD <= NOT(RnW AND E_CPU);          -- test
s_nMWR <= NOT((NOT RnW) AND E_CPU); --works better!
s_BUS <= nRST AND E_CPU; --works fine

nBUSFREE <= s_BUS;
nAOE <= NOT(s_BUS); 
nDOE <= NOT(s_BUS); 

-------------------- external RD and WR Signals ---------------
nMRD <= s_nMRD;
nMWR <= s_nMWR;

process (CLKF, E_CPU)
    begin
        if rising_edge(CLKF) then
            if E_CPU = '1' and s_ELEVEL = '0' then -- first high of E
                s_ELEVEL <= '1';
                clk_divider <= "0001"; -- sync cycle to 1
                --clk_divider <= (others => '0'); -- reset cycle
                --clk_divider <= "0011"; -- set cycle to 3
            elsif E_CPU = '0' and s_ELEVEL = '1' then
                s_ELEVEL <= '0';
                clk_divider <= clk_divider + 1;
            else
                clk_divider <= clk_divider + 1;
--                if clk_divider > 7 then
--                    clk_divider <= (others => '0');
--                else
--                    clk_divider <= clk_divider + 1;
--                end if;
            end if;
--            if s_nMWR = '0' then
--                nMWR <= '0';
--            else
--                nMWR <= '1';
--            end if;
        end if;
end process;
--s_PH0 <= clk_divider(2);

s_CPUCLK <= clk_divider(0); -- MC6802 has 4MHz oscillator for 1MHz operation
nPH0 <= NOT(s_CPUCLK);
PH0 <= s_CPUCLK;

process (E_CPU)
    begin
        if rising_edge(E_CPU) then
            if nHALT_in = '1' then
                nHALT <= '1';
            else
                nHALT <= '0';
            end if;
        end if;
end process;

process (CLKF, clk_divider)
    begin
        if falling_edge(CLKF) then
            if clk_divider = 7 then
            --if clk_divider = 6 then --
                s_BCLKWS <= '1';
            end if;
            if clk_divider = 4 then 
            --if clk_divider = 5 then  -- try a little later, no change
            --if clk_divider = 3 then -- try a little sooner, no change
                s_BCLKWS <= '0';
            end if;
        end if;
end process;

end Behavioral;
