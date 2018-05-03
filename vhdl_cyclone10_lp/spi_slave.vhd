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
signal sync_mosi : std_logic_vector(1 downto 0);
signal sync_sck : std_logic_vector(1 downto 0);
signal sync_ss : std_logic_vector(1 downto 0);


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
				
				sync_mosi <= sync_mosi(0) & mosi;
				sync_sck <= sync_sck(0) & sck;
				sync_ss <= sync_ss(0) & ss;

				case sync_ss is
					when "11" => 
						i_shiftregister := data_rd;
						cnt := 0;
--						i_flip := '0';
					when "10" =>
						miso <= i_shiftregister(31);
					when "01" =>
						cnt := 0;
						iwren := '1';
						data_wr <= i_shiftregister;
					when "00" =>
						case sync_sck is
							when "01" => 
								i_shiftregister := i_shiftregister(30 downto 0) & sync_mosi(0);
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
