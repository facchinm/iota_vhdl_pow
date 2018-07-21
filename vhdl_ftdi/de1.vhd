-- IOTA Pearl Diver VHDL Port
--
-- 2018 by Thomas Pototschnig <microengineer18@gmail.com,
-- http://microengineer.eu
-- discord: pmaxuw#8292
--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
-- 
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
-- LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
-- OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
-- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWAR

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity de1 is
	generic(
		counter_size  :  INTEGER := 17 --counter size (17 bits gives 10.9ms with 12MHz clock)
		);
	port (
		clk12M : in std_logic;
		--reset : in std_logic;
		button : in std_logic;
		led_running : out std_logic;
		led_found : out std_logic;
		led_overflow : out std_logic;
		
		UULEDS : out std_logic_vector(4 downto 0); -- Unused LEDs

		bdbus0_sck : in std_logic;
		bdbus1_mosi : in std_logic;
		bdbus2_miso : out std_logic;
		bdbus3_ss : in std_logic;
		bdbus4 : inout std_logic;
		bdbus5 : inout std_logic
	);
end;

architecture beh of de1 is

signal flipflops : std_logic_vector(1 downto 0); --input flip flops
signal counter_set : std_logic; --sync reset to zero
signal state : std_logic := '1';
signal ledstate : std_logic := '0';
signal lastButtonState : std_logic := '0';
signal counter_out : std_logic_vector(counter_size downto 0) := (others => '0'); --counter output

signal led_running_state : STD_LOGIC;
signal led_overflow_state : STD_LOGIC;
signal led_found_state : STD_LOGIC;

signal nreset : std_logic;

signal pll_clk : std_logic;
signal pll_reset : std_logic := '0';
signal pll_locked : std_logic;

signal spi_data_tx : std_logic_vector(31 downto 0);
signal spi_data_rx  : std_logic_vector(31 downto 0);
signal spi_data_rx_en : std_logic;
signal spi_data_strobe : std_logic;

signal pll_slow : std_logic;

component spi_slave
	port
	(
		clk : in std_logic;
		reset : in std_logic;
		
		mosi : in std_logic;
		miso : out std_logic;
		sck : in std_logic;
		ss : in std_logic;
		data_strobe : in std_logic;
		
		
		data_rd : in std_logic_vector(31 downto 0);
		data_wr : out std_logic_vector(31 downto 0);
		data_wren : out std_logic
	);
end component;

component pll
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC ;
		c1 : out std_logic;
		locked		: OUT STD_LOGIC 
	);
end component;

component curl
	port
	(
		clk : in std_logic;
		clk_slow : in std_logic;
		reset : in std_logic;
		
		spi_data_rx : in std_logic_vector(31 downto 0);
		spi_data_tx : out std_logic_vector(31 downto 0);
		spi_data_rxen : in std_logic;
		spi_data_strobe : out std_logic;

		overflow : out std_logic;
		running : out std_logic;
		found : out std_logic
	);
end component;

begin
	nreset <= '0';--not reset
	bdbus4 <= 'Z';
	bdbus5 <= 'Z';
	
	counter_set <= flipflops(0) xor flipflops(1); --determine when to start/reset counter
	

	pll0 : pll port map (
		areset => pll_reset,
		inclk0 => clk12M,
		c0 => pll_clk,
		c1	=> pll_slow,
		locked => pll_locked
	);
	
	
	spi0 : spi_slave port map (
		clk => pll_slow,
		reset => nreset,
		
		mosi => bdbus1_mosi,
		miso => bdbus2_miso,
		sck => bdbus0_sck,
		ss => bdbus3_ss,
		data_strobe => spi_data_strobe,
		
		data_rd => spi_data_tx,
		data_wr => spi_data_rx,
		data_wren => spi_data_rx_en
	);
	
	curl0 : curl port map (
		clk => pll_clk,
		reset => nreset,
		clk_slow => pll_slow,
		
		spi_data_rx => spi_data_rx,
		spi_data_tx => spi_data_tx,
		spi_data_rxen => spi_data_rx_en,
		spi_data_strobe => spi_data_strobe,
		
		overflow => led_overflow_state,
		running => led_running_state,
		found => led_found_state
	);
	
	--Debounce button
	PROCESS(clk12M)
	BEGIN
		IF(clk12M'EVENT and clk12M = '1') THEN
			flipflops(0) <= NOT button;
			flipflops(1) <= flipflops(0);
			IF(counter_set = '1') THEN                  --reset counter because input is changing
				counter_out <= (OTHERS => '0');
			ELSIF(counter_out(counter_size) = '0') THEN --stable input time is not yet met
				counter_out <= counter_out + 1;
			ELSE                                        --stable input time is met
				state <= flipflops(1);
			END IF;    
		END IF;
		
	END PROCESS;
	
	--Control LEDs
	PROCESS(clk12M)
	BEGIN
		IF(rising_edge(clk12M)) THEN
			IF(state = '1' and lastButtonState = '0') THEN     --active-high
				ledstate <= not ledstate;								--button pressed -> toggle led
			END IF;
			lastButtonState <= state;
			IF(ledstate = '1') THEN
				led_found <= led_found_state;
				led_running <= led_running_state;
				led_overflow <= led_overflow_state;
			ELSE
				led_found <= '0';
				led_running <= '0';
				led_overflow <= '0';
			END IF;
		END IF;
	END PROCESS;
	

end architecture;
