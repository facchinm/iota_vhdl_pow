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

	signal SCKr : std_logic_vector(2 downto 0);
	signal SSELr : std_logic_vector(2 downto 0);
	signal MOSIr : std_logic_vector(1 downto 0);
	signal MOSI_data : std_logic;
	
	signal SCK_risingedge : std_logic;
	signal SCK_fallingedge : std_logic;
	signal SSEL_startmessage : std_logic;
	signal SSEL_endmessage : std_logic;
	signal SSEL_active : std_logic;

	signal bitcnt : integer range 0 to 254 := 0;
	signal received : std_logic;
	signal data_received : std_logic_vector(31 downto 0);
	signal data_sent : std_logic_vector(31 downto 0);
begin

	process (clk)
	begin
		if rising_edge(clk) then
			if reset='1' then
				SCKr <= (others => '0');
				SSELr <= (others => '0');
				MOSIr <= (others => '0');
			else
				SCKr <= SCKr(1 downto 0) & sck;
				SSELr <= SSELr(1 downto 0) & ss;
				MOSIr <= MOSIr(0) & MOSI;
			end if;
		end if;
	end process;	

	process (clk)
	begin
		if rising_edge(clk) then
			if reset='1' then
				bitcnt <= 0;
				data_received <= (others => '0');
			else
				if not SSEL_active='1' then	
					bitcnt <= 0;
				elsif SCK_risingedge='1' then
					bitcnt <= bitcnt + 1;
					data_received <= data_received(30 downto 0) & MOSI_data;
				end if;
			end if;
		end if;
	end process;	

	process (clk)
	begin
		if rising_edge(clk) then
			if reset='1' then
				received <= '0';
			else
				if SSEL_active = '1' and SCK_risingedge = '1' and bitcnt = 31 then
					received <= '1';
				else
					received <= '0';
				end if;
--				received <= SSEL_active and SCK_risingedge and bitcnt = 31;
			end if;
		end if;
	end process;	
	
	process (clk)
	begin
		if rising_edge(clk) then
			if reset='1' then
				data_wren <= '0';
				data_wr <= (others => '0');
			else
				if received='1' then
					data_wren <= '1';
					data_wr <= data_received;
				else
					data_wren <= '0';
				end if;
			end if;
		end if;
	end process;	

	process (clk)
	begin
		if rising_edge(clk) then
			if reset='1' then
				data_sent <= (others => '0');
			else
				if SSEL_active='1' then
					if SSEL_startmessage='1' then
						data_sent <= data_rd;
					elsif SCK_fallingedge='1' then
						if bitcnt = 0 then
							data_sent <= (others => '0');
						else
							data_sent <= data_sent(30 downto 0) & '0';
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;	
	
	miso <= data_sent(31);
	
	SCK_risingedge <= not SCKr(2) and SCKr(1);
	SCK_fallingedge <= SCKr(2) and not SCKr(1);

	SSEL_startmessage <= SSELr(2) and not SSELr(1);
	SSEL_endmessage <= not SSELr(2) and SSELr(1);
	SSEL_active <= not SSELr(1);

	MOSI_data <= MOSIr(1);


--	process(clk)
--	variable cnt : integer range 0 to 32 := 0;
--
--	begin
--		if rising_edge(clk) then
--			if reset='1' then
--				cnt := 0;
--				data_wren <= '0';
--			else
--				data_wren <= '0';
--
--				if ss_1='1' and ss_0='1' then
--					shiftregister <= data_rd;
--				end if;
--				
--				-- falling edge ... begin
--				if ss_1='1' and ss_0='0' then
--					miso <= shiftregister(31);
--				end if;
--				
--				-- end of transmission
--				if ss_1='0' and ss_0='1' then
--					cnt := 0;
--					data_wren <= '1';
--					data_wr <= shiftregister;
--				end if;
--				
--				if ss_1='0' and ss_0='0' then
--					if sck_1='0' and sck_0='1' then
--						shiftregister <= shiftregister(30 downto 0) & mosi; --sync_mosi(0);
--						cnt := cnt + 1;
--					end if;
--					
--					if sck_1='1' and sck_0='0' then
--						miso <= shiftregister(31);
--					end if;
--				end if;
--			end if;
--		end if;
--	end process;
--	
--	process(clk)
--	begin
--		if rising_edge(clk) then
--			if reset='1' then
--				ss_0 <= '0';
--				ss_1 <= '0';
--				sck_0 <= '0';
--				sck_1 <= '0';
--			else
--				ss_0 <= ss;
--				sck_0 <= sck;
--				ss_1 <= ss_0;
--				sck_1 <= sck_0;
--			end if;
--		end if;
--	end process;

	
	
	
	
	
	
end behv;
