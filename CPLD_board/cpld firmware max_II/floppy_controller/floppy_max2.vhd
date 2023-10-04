library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
                   
entity floppy_controller is                                        
     Port
     (
          clk50   : in  std_logic;
          ph0     : in  std_logic;
          nCSCPLD : in  std_logic;
          uSCK    : in  std_logic;
          uMOSI   : in  std_logic;
          nRST    : in  std_logic;
          RnWin   : in  std_logic;
          unINT   : out std_logic;
          uMISO   : out std_logic;
          Dio     : inout std_logic_vector(7 downto 0);
          A       : in std_logic_vector(15 downto 0);
          As      : in std_logic_vector(19 downto 0) -- here only for debug
     );     
end floppy_controller;
                                              
architecture Behavioral of floppy_controller is
	-- Version number: Design_Major_Minor
	--signal VERSION_NUM       : std_logic_vector(7 downto 0) := x"71";

	signal spi_data_valid   : std_logic;

	-- spi_data_out has Version Number on the highest 8 bits
	signal spi_data_temp       : std_logic_vector(47 downto 0);
	signal spi_data            : std_logic_vector(47 downto 0);
	signal spi_data_out_valid  : std_logic;
	signal spi_data_update     : std_logic;
	signal ncs_fdc             : std_logic;
	signal ncs_drv             : std_logic;
	signal ncs                 : std_logic;
	signal sDRQ                : std_logic;
	signal sINT                : std_logic;
	signal D_temp              : std_logic_vector(7 downto 0);

	alias VERSION_NUM    is spi_data(47 downto 40); --
	alias D_drv_out      is spi_data(39 downto 32); --
	alias D_fdc_dat_out  is spi_data(31 downto 24); --
	alias D_fdc_sec_out  is spi_data(23 downto 16); --
	alias D_fdc_trk_out  is spi_data(15 downto 8); --
	alias D_fdc_stat_out is spi_data(7 downto 0); --

	alias D_temp_in      is spi_data(47 downto 40); --
	alias D_drv_in       is spi_data(39 downto 32); --
	alias D_fdc_dat_in   is spi_data(31 downto 24); --
	alias D_fdc_sec_in   is spi_data(23 downto 16); --
	alias D_fdc_trk_in   is spi_data(15 downto 8); --
	alias D_fdc_comm_in  is spi_data(7 downto 0); --

begin
	
	spi_slave : entity work.SPI_SLAVE -- 48 bit shift register
	port map (
		CLK      => clk50,
		RST      => '0', --not nRST,
		-- SPI MASTER INTERFACE
		SCLK     => uSCK,
		CS_N     => nCSCPLD,
		MOSI     => uMOSI,
		MISO     => uMISO,
		-- USER INTERFACE
		DIN      => spi_data,
		DIN_VLD  => '1', --spi_data_valid,
		--DIN_RDY  => '0',
		DOUT     => spi_data_temp,
		DOUT_VLD => spi_data_out_valid
	);

-- Chip Select
	ncs_fdc <= '0' when A(15 downto 2) = "11100000000101" else '1';-- E014 - E017 cs for floppy controller
	ncs_drv <= '0' when A(15 downto 2) = "11100000000110" else '1';-- E018 - E01B cs for drive reg.
    	ncs <= ncs_drv and ncs_fdc; -- combined cs 


-- Bus Isolation
	-- READ
    	Dio <= D_fdc_stat_out when RnWin = '0' and ncs_fdc = '0' and A(1 downto 0) = "00" and nRST = '1' else (others => 'Z');
    	Dio <= D_fdc_trk_out  when RnWin = '0' and ncs_fdc = '0' and A(1 downto 0) = "01" and nRST = '1' else (others => 'Z');
    	Dio <= D_fdc_sec_out  when RnWin = '0' and ncs_fdc = '0' and A(1 downto 0) = "10" and nRST = '1' else (others => 'Z');
    	Dio <= D_fdc_dat_out  when RnWin = '0' and ncs_fdc = '0' and A(1 downto 0) = "11" and nRST = '1' else (others => 'Z');
    	Dio <= D_drv_out      when RnWin = '0' and ncs_drv = '0' and nRST = '1' else (others => 'Z');

    	-- WRITE

	unINT <= ncs_fdc;

process (ph0)
	begin
		--if rising_edge(clk50) then
		if nRST = '0' then
			spi_data <= x"710000000000"; -- upper 8 bit = Version Number
			spi_data_update <= '0';
		elsif rising_edge(ph0) then
			if spi_data_out_valid = '1' then
				if spi_data_update = '0' then
					spi_data <= spi_data_temp; -- update only once
					spi_data_update <= '1';
				end if;
			else
				spi_data_update <= '0';
			end if;
			if RnWin = '0' and ncs_drv = '0' then -- Write Drive Reg
				D_drv_in <= Dio;
			elsif RnWin = '0' and ncs_fdc = '0' then -- Write FDC Reg
				case A(1 downto 0) is
					when "00" =>
					D_fdc_comm_in <= Dio;
					when "01" =>
					D_fdc_trk_in  <= Dio;
					when "10" =>
					D_fdc_sec_in  <= Dio;
					when "11" =>
					D_fdc_dat_in  <= Dio;
				end case;
			end if;
			--D_drv_in <= 
		end if;
     	--end if;
end process;


end Behavioral;