library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
                   
entity dream6800_video is                                        
     Port
     (
          clk50: in  std_logic;
          clk4:  in  std_logic;
          DMAEN: in  std_logic;
          nHALT: out std_logic;
          led:   out std_logic;
          pin_1: out std_logic;
          pin_2: out std_logic;
          pin_3: out std_logic;
          pin_4: out std_logic;
          pin_5: out std_logic;
          pin_6: out std_logic;
          pin_7: out std_logic
     );     
end dream6800_video;
                                              
architecture Behavioral of dream6800_video is
	signal hDiv  : unsigned(7 downto 0);
	signal vDiv  : unsigned(10 downto 0);
	signal timer  : unsigned(15 downto 0); -- 4MHz
	signal vtim   : unsigned(10 downto 0);
	signal hsynctim   : unsigned(6 downto 0);
	signal loaddlytim   : unsigned(6 downto 0);
	--signal vtimen : std_logic <= '0';

	signal nHsync   : std_logic; -- 15.6kHz
	signal VertEn   : std_logic; -- 25Hz
	signal vRst     : std_logic;
	signal vSync    : std_logic;
	signal vSyncOut : std_logic;
	signal vSyncOutEn : std_logic := '0';
	signal H64Dly  : std_logic;
	signal H64DlyEn  : std_logic := '0';
	signal Load  : std_logic;
	signal SRLoad  : std_logic;
	
	alias H1  is hDiv(1); -- 1MHz
	alias H2  is hDiv(2); -- 500kHz
	alias H4  is hDiv(3); -- 250kHz
	alias H8  is hDiv(4); -- 125kHz
	alias H16 is hDiv(5); -- 62.5k
	alias H32 is hDiv(6); -- 31.25k
	alias H64 is hDiv(7); -- 15.6k
	
	alias V1  is vDiv(3); -- 
	alias V2  is vDiv(4);
	alias V4  is vDiv(5);
	alias V8  is vDiv(6);
	alias V16 is vDiv(7);
	alias V32 is vDiv(8);
	alias V64 is vDiv(9);
begin                                                                  

process (clk4)
	begin
		if falling_edge(clk4) then -- one tic is 1/4MHz = 250ns
			if vSync = '1' then
				if vSyncOutEn = '0' then
					--vtim <= to_unsigned(15000,20); --300us
					vtim <= (others => '0');
					vSyncOutEn <= '1';
					vSyncOut <= '1';
				else
	    				vtim <= vtim + 1;
	    				if vtim >= 1200 then
						vSyncOut <= '0';
					end if;
				end if;
			else
				vSyncOutEn <= '0';
			end if;
     	end if;
end process;

process (clk4)
	begin
		if rising_edge(clk4) then
			if H64 = '0' then -- delay of approx 650 ns (630ns measured)
				hsynctim <= hsynctim + 1;
				if hsynctim >= 2 then -- 650ns
					H64Dly <= '1';
				end if;
			else
				H64Dly <= '0';
				hsynctim <= (others => '0');
			end if;

			if H4 = '0' then -- delay of approx 650 ns
				loaddlytim <= loaddlytim + 1;
				if loaddlytim >= 3 then -- 650ns
					Load <= '0';
				end if;
			else
				Load <= '1';
				loaddlytim <= (others => '0');
			end if;
		end if;
end process;

process (clk4)
	begin
		if falling_edge(clk4) then
    			hDiv <= hDiv + 1;
     	end if;
end process;

process (nHsync)
	begin
		if falling_edge(nHsync) then
			if vRst = '0' then
    				vDiv <= vDiv + 1;
    			else
    				vDiv <= (others => '0');
    			end if;
     	end if;
end process;

nHsync <= NOT(H8 AND H16 AND H64 AND NOT H32);
vRst <= V2 AND V4 AND V8 AND V64;
VertEn <= NOT V32 AND NOT V64 AND DMAEN;
nHALT <= NOT VertEn;
vSync <= V8 AND V16 AND V32;
SRLoad <= NOT H4 AND Load;

pin_1 <= H64;
pin_2 <= SRLoad;
pin_3 <= H4;
pin_4 <= nHsync;
pin_5 <= vSync;
pin_6 <= vSyncOut;
pin_7 <= H64Dly;
end Behavioral;