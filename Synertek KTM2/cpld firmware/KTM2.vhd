library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity KTM2 is
    Port ( 
        A      : in  std_logic_vector(15 downto 1);
        CON0   : in  std_logic;
        CON1   : in  std_logic;
        CON2   : in  std_logic;
        nRRDIS : in  std_logic; -- RAM ROM Disable form Peripheral
        MOSI   : in  STD_LOGIC; -- SPI Interface
        SCK    : in  STD_LOGIC; -- SPI Interface
        nSPICS : in  STD_LOGIC; -- SPI Interface
        nWE    : out STD_LOGIC; -- output to SRAM
        nUWE   : in  STD_LOGIC;  -- WE from microcontroller
        nEDEN  : out STD_LOGIC; -- Output for Address Buffer enable (245)
        nLOAD  : out STD_LOGIC; -- Output enable of '590 (opposite to nEDEN!)
        nOVR   : in  STD_LOGIC; -- Override input from uC
        CLK_in : in  STD_LOGIC; -- high speed clock in
        PHI2   : in  STD_LOGIC; -- CPU clock in
        nDE    : out STD_LOGIC; -- Output for Data Bufer enable (245)
        nMRD   : in  STD_LOGIC; -- CPU Read 
        nMWR   : in  STD_LOGIC; -- CPU Write 
        nOE595 : out STD_LOGIC; -- Output on for '595
        nEWE   : out STD_LOGIC -- Direction ofr '245 Data Bufer
        );
end KTM2;

architecture Behavioral of KTM2 is
    signal w_n_RAMCS  : std_logic :='1';
    signal w_n_ROMCS  : std_logic :='1';
    signal w_n_CS     : std_logic :='1';
    signal n_REXT     : std_logic :='1';
    signal n_WEXT     : std_logic :='1';
    signal n_ADDEXT   : std_logic :='1';
    signal ADDDIR     : std_logic;
    SIGNAL spi_data32 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    alias rom_lower is spi_data32(31 downto 24);
    alias rom_upper is spi_data32(23 downto 16);
    alias ram_lower is spi_data32(15 downto 8);
    alias ram_upper is spi_data32(7 downto 0);
begin
-- SPI Slave Receiver works. Tested with frequency divider below
    slave_data : entity work.spi_slave_r
    port map (
        SCLK     => SCK,
        SS       => nSPICS,
        MOSI     => MOSI,
        --MISO     => GP07,
        -- USER INTERFACE
        --Din      => spi0_data_out8,
        Dout     => spi_data32
    );

--w_n_RAMCS <= '0' when (A > x"0000") and (A < x"7FFF") else '1';

--w_n_ROMCS <= '0' when (A(15 downto 8) >= x"FC") AND CON0 = '0' else '1';
--w_n_RAMCS <= '0' when (A(15 downto 8) <= x"7F") AND CON0 = '0' else '1';
w_n_ROMCS <= '0' when (A(15 downto 8) >= rom_lower) AND nRRDIS = '1' else '1';
w_n_RAMCS <= '0' when (A(15 downto 8) <= ram_upper) AND nRRDIS = '1' else '1';
--w_n_ROMCS <= '0' when (A(15 downto 8) <= rom_upper) AND CON0 = '1' else '1';
--w_n_RAMCS <= '0' when (A(15 downto 8) >= ram_lower) AND CON0 = '1' else '1';
--w_n_ROMCS <= '0' when (A(15 downto 8) >= spi_data_in16(15 downto 8)) and (A(15 downto 8) <= spi_data_in16(7 downto 0)) else '1';
w_n_CS <= w_n_RAMCS AND w_n_ROMCS;

n_REXT <= nMRD OR w_n_CS; -- nMRD <= NOT(RnW AND PHI2CPU);
n_WEXT <= nMWR OR w_n_CS; -- nMWR <= NOT((NOT RnW) AND PHI2CPU);
n_ADDEXT <= n_REXT AND n_WEXT; -- an external Request is there

--ADDDIR <= NOT n_ADDEXT AND nOVR; --test
--ADDDIR <= '1' AND nOVR; --works
ADDDIR <= NOT n_ADDEXT AND nOVR; --test 
nLOAD <= ADDDIR;
nEDEN <= NOT ADDDIR;

nWE <= (nMWR OR w_n_RAMCS) AND nUWE;
nEWE <= nMWR;
nOE595 <= nUWE;
nDE <= n_ADDEXT OR (NOT nUWE) OR (NOT nOVR);
end Behavioral;
