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
use work.index_table.all;

entity curl is
	generic
	(
		HASH_LENGTH : integer := 243;
		STATE_LENGTH : integer := 729; -- 3 * HASH_LENGTH;
		NONCE_LENGTH : integer := 81; -- HASH_LENGTH / 3;
		NUMBER_OF_ROUNDS : integer := 81;
		PARALLEL : integer := 3;
		INTERN_NONCE_LENGTH : integer	:= 32;
		BITS_MIN_WEIGHT_MAGINUTE_MAX : integer := 26
	);

	port
	(
		clk : in std_logic;
		reset : in std_logic;
		
		spi_data_rx : in std_logic_vector(31 downto 0);
		spi_data_tx : out std_logic_vector(31 downto 0);
		spi_data_rxen : in std_logic;
		overflow : out std_logic;
		running : out std_logic;
		found : out std_logic
	);
	
end curl;

architecture behv of curl is

subtype state_vector_type is std_logic_vector(PARALLEL-1 downto 0);
type curl_state_array is array(integer range <>) of state_vector_type;

signal curl_state_low : curl_state_array(STATE_LENGTH-1 downto 0);
signal curl_state_high : curl_state_array(STATE_LENGTH-1 downto 0);

signal curl_mid_state_low : curl_state_array(STATE_LENGTH-1 downto 0);
signal curl_mid_state_high : curl_state_array(STATE_LENGTH-1 downto 0);

signal flag_running : std_logic := '0';
signal flag_overflow : std_logic := '0';
signal flag_found : std_logic := '0';
signal flag_start : std_logic := '0';

begin
	overflow <= flag_overflow;
	running <= flag_running;
	found <= flag_found;

	process (clk)
		variable	state : integer range 0 to 31 := 0;
		variable round : integer range 0 to 127 := 0;
		variable binary_nonce : unsigned(INTERN_NONCE_LENGTH-1 downto 0);	
		variable ternary_nonce_lo : unsigned(INTERN_NONCE_LENGTH-1 downto 0);	 
		variable ternary_nonce_hi : unsigned(INTERN_NONCE_LENGTH-1 downto 0);	 
		variable mask : state_vector_type;
		
		-- because it looks prettier
		variable spi_cmd : std_logic_vector(5 downto 0);
		variable spi_addr : std_logic_vector(9 downto 0);
		variable spi_data_lo : std_logic_vector(PARALLEL-1 downto 0);
		variable spi_data_hi : std_logic_vector(PARALLEL-1 downto 0);
		
		variable min_weight_magnitude : std_logic_vector(BITS_MIN_WEIGHT_MAGINUTE_MAX-1 downto 0);
		
		-- temporary registers get optimized away
		variable alpha : curl_state_array(STATE_LENGTH-1 downto 0);
		variable beta : curl_state_array(STATE_LENGTH-1 downto 0);
		variable gamma : curl_state_array(STATE_LENGTH-1 downto 0);
		variable delta : curl_state_array(STATE_LENGTH-1 downto 0);
		variable epsilon : curl_state_array(STATE_LENGTH-1 downto 0);
		
	begin
		
		if rising_edge(clk) then
			if reset='1' then
				state := 0;
				binary_nonce := (others => '0');
				flag_found <= '0';
				flag_running <= '0';
				flag_overflow <= '0';
				flag_start <= '0';
				
				min_weight_magnitude := (others => '0');
			else
				-- new spi data received
				if spi_data_rxen = '1' then
					spi_cmd := spi_data_rx(31 downto 26);
					case spi_cmd is
						when "000000" => -- nop
						when "100001" => -- start / stop
							if spi_data_rx(0) = '1' then
								flag_start <= '1';
							end if;
						when "100010" =>	-- write to mid state
							spi_addr := spi_data_rx(25 downto 16);
							spi_data_hi := spi_data_rx(8+PARALLEL-1 downto 8);
							spi_data_lo := spi_data_rx(0+PARALLEL-1 downto 0);
							curl_mid_state_low(to_integer(unsigned(spi_addr))) <= spi_data_lo;
							curl_mid_state_high(to_integer(unsigned(spi_addr))) <= spi_data_hi;
						when "100100" =>
							min_weight_magnitude := spi_data_rx(BITS_MIN_WEIGHT_MAGINUTE_MAX-1 downto 0);

						when "000001" =>	-- read flags
							spi_data_tx <= "00000000000000000000000000000" & flag_overflow & flag_found & flag_running;

-- this costs an extreme amount of resources
--						when "000010" =>
--							spi_addr := spi_data_rx(25 downto 16);
--							spi_data_tx(0+PARALLEL-1 downto 0) <= curl_state_low(to_integer(unsigned(spi_addr)));
--							spi_data_tx(8+PARALLEL-1 downto 8) <= curl_state_high(to_integer(unsigned(spi_addr)));
						when "000011" => -- read nonce
							spi_data_tx(31 downto INTERN_NONCE_LENGTH) <= (others => '0');
							spi_data_tx(INTERN_NONCE_LENGTH-1 downto 0) <= std_logic_vector(binary_nonce);
						when "000100" => -- read mask
							spi_data_tx(PARALLEL-1 downto 0) <= mask;
							spi_data_tx(31 downto PARALLEL) <= (others => '0');
						when "010101" => -- loop back read test inverted bits
							spi_data_tx <= not spi_data_rx;
						when others =>
							spi_data_tx <= (others => '1');
					end case;
				end if;
			
				case state is
					when 0 =>
						flag_running <= '0';
						if flag_start = '1' then
							state := 1;
						end if;
						-- nop until start from spi
					when 1 =>
						flag_start <= '0';
						binary_nonce := (others => '0');
						flag_found <= '0';
						flag_running <= '1';
						flag_overflow <= '0';
						state := 8;
					when 8 =>	-- copy mid state 
						for I in 0 to STATE_LENGTH-1 loop
							curl_state_low(I) <= curl_mid_state_low(I);
							curl_state_high(I) <= curl_mid_state_high(I);
						end loop;		
						state := 9;
					when 9 =>	-- insert nonce counter
						round := NUMBER_OF_ROUNDS;
						ternary_nonce_lo := binary_nonce;
						ternary_nonce_hi := not binary_nonce;
						
						for I in 163 to 163+INTERN_NONCE_LENGTH-1 loop
							if ternary_nonce_lo(I-163) = '1' then
								curl_state_low(I) <= (others => '1');
							else
								curl_state_low(I) <= (others => '0');
							end if;
							if ternary_nonce_hi(I-163) = '1' then
								curl_state_high(I) <= (others => '1');
							else
								curl_state_high(I) <= (others => '0');
							end if;
						end loop;						
						state := 10;
					when 10 =>	-- do the curl hash
						for I in 0 to STATE_LENGTH-1 loop
							alpha(I) := curl_state_low(index_table(I));
							beta(I) := curl_state_high(index_table(I));
							gamma(I) := curl_state_high(index_table(I+1));
							
							delta(I) := (alpha(I) or (not gamma(I))) and (curl_state_low(index_table(I+1)) xor beta(I));

							curl_state_low(I) <= not delta(I);
							curl_state_high(I) <= (alpha(I) xor gamma(I)) or delta(I);
						end loop;

						round := round - 1;
						if round = 0 then
							state := 16;
						end if;						

					when 16 =>  -- find out which solution - if any
						mask := (others => '1');
						for I in 0 to BITS_MIN_WEIGHT_MAGINUTE_MAX-1 loop 
							if min_weight_magnitude(I) = '1' then
								mask := mask and not (curl_state_low(HASH_LENGTH - 1 - I) xor curl_state_high(HASH_LENGTH - 1 - I));
							end if;
						end loop;
						
						-- no solution found?
						if unsigned(mask) = 0 then
							binary_nonce := binary_nonce + 1;
							-- is overflow?
							if binary_nonce = 0 then
								flag_overflow <= '1';
								state := 0;
							else
								state := 8;	-- and try again
							end if;										
						else
							state := 30;	-- nonce found
						end if;
					when 30 =>
						flag_found <= '1';
						state := 0;
					when others =>
						state := 0;
				end case;
			end if;
		end if;
	end process;
end behv;
