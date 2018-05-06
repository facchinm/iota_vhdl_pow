-- IOTA Pearl Diver VHDL Port
--
-- Written 2018 by Thomas Pototschnig <microengineer18@gmail.com>
--
-- This source code is currently licensed under
-- Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)
-- 
-- http://www.microengineer.eu
-- 
-- If you like my project please consider a donation to
--
-- LLEYMHRKXWSPMGCMZFPKKTHSEMYJTNAZXSAYZGQUEXLXEEWPXUNWBFDWESOJVLHQHXOPQEYXGIRBYTLRWHMJAOSHUY
--
-- As soon as donations reach 1000MIOTA, everything will become
-- GPL and open for any use - commercial included.

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity spi_slave is
	port
	(
		clk : in std_logic;
		reset : in std_logic;
		
		mosi : in std_logic;
		miso : out std_logic;
		sck : in std_logic;
		ss : in std_logic;
		
		
		data_rd : in std_logic_vector(31 downto 0);
		data_wr : out std_logic_vector(31 downto 0);
		data_wren : out std_logic
		
	);
end spi_slave;


architecture behv of spi_slave is
signal sync_mosi : std_logic_vector(3 downto 0);
signal sync_sck : std_logic_vector(3 downto 0);
signal sync_ss : std_logic_vector(3 downto 0);


begin

	process(clk)
	variable cnt : integer range 0 to 32 := 0;
	variable iwren : std_logic;
	variable i_miso : std_logic;
	variable i_shiftregister : std_logic_vector(31 downto 0);

	begin
		if rising_edge(clk) then
			if reset='1' then
				cnt := 0;
				data_wren <= '0';
				iwren := '0';
			else
				iwren := '0';
				
				sync_mosi <= sync_mosi(2 downto 0) & mosi;
				sync_sck <= sync_sck(2 downto 0) & sck;
				sync_ss <= sync_ss(2 downto 0) & ss;

				case sync_ss(2 downto 1) is
					when "11" => 
						i_shiftregister := data_rd;
						cnt := 0;
--						i_flip := '0';
					when "10" =>
						miso <= i_shiftregister(31);
					when "01" =>
						if cnt = 32 then
							iwren := '1';
						end if;
						cnt := 0;
						data_wr <= i_shiftregister;
					when "00" =>
						case sync_sck(2 downto 1) is
							when "01" => 
								i_shiftregister := i_shiftregister(30 downto 0) & sync_mosi(2);
								cnt := cnt + 1;
							when "10" =>
								miso <= i_shiftregister(31);
							when others =>
						end case;
					when others =>
				end case;
				data_wren <= iwren;
			end if;
		end if;
	end process;
	

end behv;
