library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
                   
entity dream6800_video is                                        
     Port
     (
          clk50   : in  std_logic;
          ph0     : in  std_logic;
          --DMAEN: in  std_logic;
          --BA:    in  std_logic;
          As      : out std_logic_vector(19 downto 0) := (others=>'Z');
          D_in    : in std_logic_vector(7 downto 0);
          HSYNC   : out std_logic;
          VSYNC   : out std_logic;
          SBLU    : out std_logic
          --nHALT: out std_logic;
     );     
end dream6800_video;
                                              
architecture Behavioral of dream6800_video is
	signal hDiv       : unsigned(7 downto 0);
	signal vDiv       : unsigned(10 downto 0);
	signal vtim       : unsigned(10 downto 0);
	signal loaddlytim : unsigned(6 downto 0);
	signal patterncnt : unsigned(2 downto 0);

	signal nHsync     : std_logic; -- 15.6kHz
	signal VertEn     : std_logic; -- 25Hz
	signal vCntEn       : std_logic := '0';
	signal vSyncOut   : std_logic;
	signal SRLoad     : std_logic;
	signal VidOut     : std_logic;
	signal SRout      : std_logic := '1';
	signal Stemp      : std_logic_vector(2 downto 0);
	signal pattern    : std_logic_vector(7 downto 0);
	signal A_int      : std_logic_vector(15 downto 0);
	
	alias H1  is hDiv(1); -- 1MHz
	alias H2  is hDiv(2); -- 500kHz
	alias H4  is hDiv(3); -- 250kHz
	alias H8  is hDiv(4); -- 125kHz
	alias H16 is hDiv(5); -- 62.5k
	alias H32 is hDiv(6); -- 31.25k
	alias H64 is hDiv(7); -- 15.6k  (64us)
	
	alias V0  is vDiv(1); -- this is hSync / 4 (only in Hi-Res)
	alias V1  is vDiv(2); -- this is hSync / 8 (1.95kHz := 513ns)
	alias V2  is vDiv(3); -- 977Hz := 1.03ms
	alias V4  is vDiv(4); -- 488Hz := 2.05ms
	alias V8  is vDiv(5); -- 244Hz := 4.1ms
	alias V16 is vDiv(6); -- 122Hz := 8.2ms
	alias V32 is vDiv(7); -- 61Hz  := 16.4ms
	alias V64 is vDiv(8); -- 30Hz  := 32.8ms (only 19.97ms needed)

begin                                                       

--Components
	SR: entity work.CD4014
		port map (
			--D   => pattern,
			D   => D_in,
			clk => not hDiv(0), --Low-Res
			--clk => not ph0, --Hi-Res
			Q   => SRout,
			SHLD => not SRLoad
			--ds  => '0'
		);

process (ph0)
	begin
		if falling_edge(ph0) then -- one tic is 1/4MHz = 250ns
    			hDiv <= hDiv + 1;

               --  Low-Res Load
			if H4 = '0' then -- delay of approx 650 ns
				loaddlytim <= loaddlytim + 1;
				if loaddlytim >= 2 then -- 650ns
					SRLoad <= '0';
				else
					SRLoad <= '1';
				end if;
			else
				loaddlytim <= (others => '0');
			end if;

               --  Hi-Res Load
--			if H2 = '0' then
--				loaddlytim <= loaddlytim + 1;
--				if loaddlytim >= 1 then 
--					SRLoad <= '0';
--				else
--					SRLoad <= '1';
--				end if;
--			else
--				loaddlytim <= (others => '0');
--			end if;

--			if nHsync = '0' then
--				if vCntEn = '0' then
--					vCntEn <= '1'; -- allow only once per falling edge
--					if vDiv >= 527 then -- 525 Lines in total
--		    				vDiv <= to_unsigned(0,11);
--		    				patterncnt <= to_unsigned(1,3);
--		    				--vDiv <= (others => '0');
--		    			else
--		    				vDiv <= vDiv + 1;
--		    				patterncnt <= patterncnt + 1;
--		    				if vDiv = 335 then -- Position of picture
--		    					vSyncOut <= '0';
--		    				end if;
--		    				if vDiv = 345 then -- Length of sync pulse (~300us)
--		    					vSyncOut <= '1';
--		    				end if;
--		    			end if;
--	    				
--		    			if patterncnt(2) = '1' then -- make a pattern for testing Lo-Res
--		    			--if patterncnt(1) = '1' then -- make a pattern for testing Hi-Res
--		    				pattern <= x"55";
--		    			else
--		    				pattern <= x"AA";
--		    			end if;
--
--				end if;
--	    		else
--	    			vCntEn <= '0';
--	     	end if;

     	end if;
end process;

process (ph0)
	begin
		if rising_edge(ph0) then --maybe slightly better than on falling edge?
			if nHsync = '0' then
				if vCntEn = '0' then
					vCntEn <= '1'; -- allow only once per falling edge
					if vDiv >= 311 then -- 312 Lines in total
		    				vDiv <= to_unsigned(0,11);
		    				patterncnt <= to_unsigned(1,3);
		    				--vDiv <= (others => '0');
		    			else
		    				vDiv <= vDiv + 1;
		    				patterncnt <= patterncnt + 1;
		    				if vDiv = 222 then -- Position of picture
		    					vSyncOut <= '0';
		    				end if;
		    				if vDiv = 230 then -- Length of sync pulse (~300us)
		    					vSyncOut <= '1';
		    				end if;
		    			end if;
	    				
		    			--if patterncnt(2) = '1' then -- make a pattern for testing Lo-Res
		    			if patterncnt(1) = '1' then -- make a pattern for testing Hi-Res
		    				pattern <= x"55";
		    			else
		    				pattern <= x"AA";
		    			end if;

				end if;
	    		else
	    			vCntEn <= '0';
	     	end if;

     	end if;
end process;

nHsync <= NOT(H8 AND H16 AND H64 AND NOT H32);
VertEn <= (NOT V32 AND NOT V64); -- we don't need software turn off of video
--VertEn <= (NOT V32 AND NOT V64 AND DMAEN);
--nHALT <= NOT VertEn;
VidOut <= not H64 AND VertEn and SRout;

--            Low-Res Address Mapping
A_int(0)  <= H8;  -- Mapping Counter Out to Address
A_int(1)  <= H16; -- Mapping Counter Out to Address
A_int(2)  <= H32; -- Mapping Counter Out to Address
A_int(3)  <= V1;  -- Mapping Counter Out to Address
A_int(4)  <= V2;  -- Mapping Counter Out to Address
A_int(5)  <= V4;  -- Mapping Counter Out to Address
A_int(6)  <= V8;  -- Mapping Counter Out to Address
A_int(7)  <= V16; -- Mapping Counter Out to Address
A_int(8)  <= '1'; -- Mapping Counter Out to Address (Low-Res Video RAM starts at 0x100)
A_int(9)  <= '0'; -- Mapping Counter Out to Address
A_int(10) <= '0'; -- Mapping Counter Out to Address
A_int(11) <= '0'; -- Mapping Counter Out to Address
A_int(12) <= '0'; -- Mapping Counter Out to Address
A_int(13) <= '0'; -- Mapping Counter Out to Address
A_int(14) <= '0'; -- Mapping Counter Out to Address
A_int(15) <= '0'; -- Mapping Counter Out to Address

--            Hi-Res Address Mapping
--A_int(0)  <= H4;  -- Mapping Counter Out to Address
--A_int(1)  <= H8;  -- Mapping Counter Out to Address
--A_int(2)  <= H16; -- Mapping Counter Out to Address
--A_int(3)  <= H32; -- Mapping Counter Out to Address
--A_int(4)  <= V0;  -- Mapping Counter Out to Address
--A_int(5)  <= V1;  -- Mapping Counter Out to Address
--A_int(6)  <= V2;  -- Mapping Counter Out to Address
--A_int(7)  <= V4;  -- Mapping Counter Out to Address
--A_int(8)  <= V8;  -- Mapping Counter Out to Address (Hi-Res Video RAM starts at 0x0000)
--A_int(9)  <= V16; -- Mapping Counter Out to Address
--A_int(10) <= '0'; -- Mapping Counter Out to Address
--A_int(11) <= '0'; -- Mapping Counter Out to Address
--A_int(12) <= '0'; -- Mapping Counter Out to Address
--A_int(13) <= '0'; -- Mapping Counter Out to Address
--A_int(14) <= '0'; -- Mapping Counter Out to Address
--A_int(15) <= '0'; -- Mapping Counter Out to Address

-- Address Output
--As <= A_int when BA = '1' else (others => 'Z');

--pin_1 <= NOT SRLoad;   --/MRD --does not work
--pin_1 <= NOT (SRLoad AND VertEn);   --/MRD --works ok
As(19) <= NOT VertEn;   --/MRD --works maybe a little better

As(18) <= NOT vSyncOut; --RTC
--pin_3 <= H4;
HSYNC <= NOT nHsync;
SBLU <= VidOut;       -- SBLU is EGA Pin 7 and MDA Video
VSYNC <= NOT vSyncOut;
--pin_7 <= V1;
--pin_8 <= H64;
--pin_53 <= SRLoad;
end Behavioral;