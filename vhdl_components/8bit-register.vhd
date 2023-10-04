-- *************************************************
--                           = == 
--                         * | | /*
--     **     -------     *  | |/  *
--    *  *====|     |====|   | |    |
--     **     -------     *  | |\  *
--                         * | | \*
--            ELEKTRONIK     = ==
--            ENTWICKLER
--            AACHEN
-- 
-- Adresse:
-- F.Juergen Gensicke, Dipl.-Ing. (FH)
-- Kirberichshofer Weg 31, D-52066 Aachen
--
-- Tel.:  +49 / 241 / 47580488
-- Mobil: +49 / 173 / 2931531
-- E-Mail: info@ee-ac.de
-- *************************************************
-- Entwickelt fuer:
--
-- Firmennamen
--
-- Adresse:
-- Firma
-- Ansprechpartner
-- Strasse, D-PLZ Ort
--
-- Tel.:  +49 / Vorwahl / Anschluss
-- Mobil: +49 / Vorwahl / Anschluss
-- E-Mail: E-Mail-Adresse
-- *************************************************
-- Datei: top_8bit-register.vhd
-- Autor: F.Juergen Gensicke
-- Datum: 23.01.2011
-- *************************************************
-- Beschreibung :
--
-- Diese VHDL-Datei erzeugt ein 8-Bit Register.
--
-- Revisionen:
-- =============================
-- Aenderung am DATUM Version X:
-- Autor: F.Juergen Gensicke
-- Was?:
-- Text mit Aenderungsbeschreibung
-- Design Goal: Timing
-- Strategie: Performance with IO Packaging
-- *************************************************
-- Libraries:
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- *************************************************

entity Reg_8bit is
Port (
	CLK		: in std_logic;
	RST		: in std_logic;
	D		: in std_logic_vector(7 downto 0);
	Q		: out std_logic_vector(7 downto 0)
     );
end Reg_8bit;

architecture arc_Reg_8bit_intern of Reg_8bit is

-- Defintionen fuer Signale

begin

-- ###########################################
-- Process Statements
-- ###########################################
process (CLK, RST)
begin
	if (RST='1') then
		Q <= (others => '0');
	elsif (CLK'event and CLK='1') then -- CLK rising edge
		Q <= D;
	end if;
end process;
 
end arc_Reg_8bit_intern;
