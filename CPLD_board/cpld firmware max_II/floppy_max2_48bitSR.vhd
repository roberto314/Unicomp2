library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
                   
entity floppy_controller is                                        
     Port
     (
          clk50   : in  std_logic; -- 50MHz from CPLD board
          ph0     : in  std_logic; -- PHI0 (8MHz) from mainboard
          ph2     : in  std_logic; -- PHI" (1MHz) from mainboard
          nCSCPLD : in  std_logic; -- /CS from STM32
          uSCK    : in  std_logic; -- SCK from STM32
          uMOSI   : in  std_logic; -- MOSI from STM32
          nRST    : in  std_logic; -- /Reset from mainboard
          RnWin   : in  std_logic; -- R/W from mainboard
          uRnW    : in  std_logic; -- R/W from STM32
          unINT   : out std_logic; -- /Interrupt to STM32
          --unINT   : in std_logic; -- /Interrupt to STM32
          uMISO   : out std_logic; -- MISO to STM32
          Dio     : inout std_logic_vector(7 downto 0); -- Data from mainboard
          A       : in std_logic_vector(15 downto 0);   -- Address from mainboard
          As      : out std_logic_vector(19 downto 0)    -- here only for debug
     );     
end floppy_controller;
                                              
architecture Behavioral of floppy_controller is
	-- Version number: Design_Major_Minor
	constant VERSION_NUM       : std_logic_vector(7 downto 0) := x"71";

	signal spi_data_valid   : std_logic;

	-- spi_data_out has Version Number on the highest 8 bits
	signal spi_data_temp       : std_logic_vector(47 downto 0) := x"710000000000";
	signal spi_data            : std_logic_vector(47 downto 0);
	signal spi_data_out_valid  : std_logic;
	signal ncs_fdc             : std_logic;
	signal ncs_drv             : std_logic;
	signal ncs                 : std_logic;
	signal sr_Data_new         : std_logic := '1';
	signal uc_Data_new         : std_logic := '1';
	signal srDinRDY            : std_logic;
	signal sDRQ                : std_logic;
	signal sINT                : std_logic;
	signal D_temp              : std_logic_vector(7 downto 0);
	signal uc_data_update         : unsigned(3 downto 0);
	signal sr_data_update         : unsigned(3 downto 0);

	--alias VERSION_NUM    is spi_data(47 downto 40); --
	alias D_drv          is spi_data(39 downto 32); -- 8014
	alias D_fdc_cmst     is spi_data(7 downto 0);   -- 8018
	alias D_fdc_trk      is spi_data(15 downto 8);  -- 8019
	alias D_fdc_sec      is spi_data(23 downto 16); -- 801A
	alias D_fdc_dat      is spi_data(31 downto 24); -- 801B

	alias D_temp_ver     is spi_data(47 downto 40); --

begin
	
	spi_slave : entity work.SPI_SLAVE -- 48 bit shift register
	port map (
		CLK      => clk50,
		RST      => not nRST,
		-- SPI MASTER INTERFACE
		SCLK     => uSCK,
		CS_N     => nCSCPLD, -- and not (sr_Data_new or uc_Data_new),
		MOSI     => uMOSI,
		MISO     => uMISO,
		-- USER INTERFACE
		DIN      => spi_data,
		DIN_VLD  => sr_Data_new or uc_Data_new,
		--DIN_RDY  => srDinRDY,
		DOUT     => spi_data_temp,
		DOUT_VLD => spi_data_out_valid
	);

-- Chip Select
	ncs_drv <= '0' when A(15 downto 2) = "10000000000101" else '1';-- 8014 - 8017 cs for drive reg.
	ncs_fdc <= '0' when A(15 downto 2) = "10000000000110" else '1';-- 8018 - 801B cs for floppy controller
    	ncs <= ncs_drv and ncs_fdc; -- combined cs 


-- Bus Isolation
	-- READ
    	Dio <= D_fdc_cmst when RnWin = '1' and ncs_fdc = '0' and A(1 downto 0) = "00" and nRST = '1' else (others => 'Z');
    	Dio <= D_fdc_trk  when RnWin = '1' and ncs_fdc = '0' and A(1 downto 0) = "01" and nRST = '1' else (others => 'Z');
    	Dio <= D_fdc_sec  when RnWin = '1' and ncs_fdc = '0' and A(1 downto 0) = "10" and nRST = '1' else (others => 'Z');
    	Dio <= D_fdc_dat  when RnWin = '1' and ncs_fdc = '0' and A(1 downto 0) = "11" and nRST = '1' else (others => 'Z');
    	Dio <= D_drv      when RnWin = '1' and ncs_drv = '0' and nRST = '1' else (others => 'Z');

    	-- WRITE

	--unINT <= ncs_fdc or RnWin; -- Interrupt only when writing
	unINT <= uc_Data_new; -- Interrupt only when writing from Unicomp

process (clk50)
	begin
		if rising_edge(clk50) then
			if nRST = '0' then
				spi_data <= VERSION_NUM & x"0000000000";
				sr_data_update <= "1111";
			else
				if spi_data_out_valid = '1' then
					if uRnW = '0' then
						spi_data <= VERSION_NUM & spi_data_temp(39 downto 0); -- update only once
					end if;
				end if;
				if sr_data_update > "0000" and nCSCPLD = '1' then
					sr_Data_new <= '1';
					sr_data_update <= sr_data_update - 1;
				end if;
				if sr_data_update = "0000" then
					sr_Data_new <= '0';
				end if;
				--if sr_data_update = "1110" then
				--	sr_Data_new <= '1';         -- update after deselect
				--end if;
				if nCSCPLD = '0' then
					sr_data_update <= "0001";
				end if;
--######################################## UNICOMP Write Rgister and New Data Signal Generation
				if uc_data_update > "0000" and ncs = '1' then
					uc_Data_new <= '1';
					uc_data_update <= uc_data_update - 1;
				end if;
				if uc_data_update = "0000" then
					uc_Data_new <= '0';
				end if;

				if RnWin = '0' and ncs_drv = '0' and ph2 = '1' then -- Write Drive Reg
					D_drv <= Dio;
					uc_data_update <= "0001";
				elsif RnWin = '0' and ncs_fdc = '0' and ph2 = '1' then -- Write FDC Reg
					uc_data_update <= "0001";
					case A(1 downto 0) is
						when "00" =>
						D_fdc_cmst <= Dio;
						when "01" =>
						D_fdc_trk <= Dio;
						when "10" =>
						D_fdc_sec <= Dio;
						when "11" =>
						D_fdc_dat <= Dio;
					end case;
				end if;
			end if;
     	end if;
end process;
As(19) <= sr_Data_new;
As(17) <= uc_Data_new;
--As(15) <= srDinRDY;

end Behavioral;