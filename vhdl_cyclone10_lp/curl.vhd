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
		PARALLEL : integer := 7;
		INTERN_NONCE_LENGTH : integer	:= 32;
		BITS_MIN_WEIGHT_MAGINUTE_MAX : integer := 26;
		DATA_WIDTH : integer := 9
	);

	port
	(
		clk : in std_logic;
		clk_slow : in std_logic;
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
subtype mid_state_vector_type is std_logic_vector(DATA_WIDTH-1 downto 0);

type curl_state_array is array(integer range <>) of state_vector_type;
type mid_state_array is array(integer range <>) of mid_state_vector_type;

signal curl_state_low : curl_state_array(STATE_LENGTH-1 downto 0);
signal curl_state_high : curl_state_array(STATE_LENGTH-1 downto 0);

-- mid state data in 9bit packed format
signal curl_mid_state_low : mid_state_array((STATE_LENGTH/9)-1 downto 0);
signal curl_mid_state_high : mid_state_array((STATE_LENGTH/9)-1 downto 0);

signal flag_running : std_logic := '0';
signal flag_overflow : std_logic := '0';
signal flag_found : std_logic := '0';
signal flag_start : std_logic := '0';

signal binary_nonce : unsigned(INTERN_NONCE_LENGTH-1 downto 0);	
signal mask : state_vector_type;
signal min_weight_magnitude : std_logic_vector(BITS_MIN_WEIGHT_MAGINUTE_MAX-1 downto 0);


begin
	overflow <= flag_overflow;
	running <= flag_running;
	found <= flag_found;
	
	process (clk_slow)
	-- because it looks prettier
		variable spi_cmd : std_logic_vector(5 downto 0);
		variable wraddr : integer range 0 to 127 := 0;
	begin
		if rising_edge(clk_slow) then
			if reset='1' then
--				binary_nonce <= (others => '0');
				min_weight_magnitude <= (others => '0');
				flag_start <= '0';
			else
				flag_start <= '0';
-- new spi data received
				if spi_data_rxen = '1' then
					spi_cmd := spi_data_rx(31 downto 26);
					case spi_cmd is
						when "000000" => -- nop
						when "100001" => -- start / stop
							if spi_data_rx(0) = '1' then
								flag_start <= '1';
							end if;
						when "100101" =>	-- write to wr address
							wraddr := 0;
						when "100010" =>	-- write to mid state
							curl_mid_state_low(wraddr) <= std_logic_vector(spi_data_rx(DATA_WIDTH-1 downto 0));
							curl_mid_state_high(wraddr) <= std_logic_vector(spi_data_rx(DATA_WIDTH+8 downto DATA_WIDTH));
							wraddr := wraddr + 1;
						when "100100" =>
							min_weight_magnitude <= spi_data_rx(BITS_MIN_WEIGHT_MAGINUTE_MAX-1 downto 0);

						when "000001" =>	-- read flags
							spi_data_tx <= "00000000000000000000000000000" & flag_overflow & flag_found & flag_running;
  
-- this costs an extreme amount of resources
-- interesting only for debugging 
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
						when "000110" => -- read back parallel-level
							spi_data_tx <= std_logic_vector(to_unsigned(PARALLEL, spi_data_tx'length));
						when others =>
							spi_data_tx <= (others => '1');
					end case; 			
				end if;
			end if; 
		end if;
	end process;
	
	process (clk)
		variable	state : integer range 0 to 31 := 0;
		variable round : integer range 0 to 127 := 0;

		variable imask : state_vector_type;
		
		variable i_min_weight_magnitude : std_logic_vector(BITS_MIN_WEIGHT_MAGINUTE_MAX-1 downto 0);

		-- temporary registers get optimized away
		variable alpha : curl_state_array(STATE_LENGTH-1 downto 0);
		variable beta : curl_state_array(STATE_LENGTH-1 downto 0);
		variable gamma : curl_state_array(STATE_LENGTH-1 downto 0);
		variable delta : curl_state_array(STATE_LENGTH-1 downto 0);
		variable epsilon : curl_state_array(STATE_LENGTH-1 downto 0);
		
		variable tmp_index : integer range 0 to 1023;
		variable tmp_mod : integer range 0 to 31;
	begin
		if rising_edge(clk) then
			if reset='1' then
				state := 0;
				flag_found <= '0';
				flag_running <= '0';
				flag_overflow <= '0';
				binary_nonce <= (others => '0');
			else
				case state is
					when 0 =>
						flag_running <= '0';
						if flag_start = '1' then
							i_min_weight_magnitude := min_weight_magnitude;
							state := 1;
						end if;
						-- nop until start from spi
					when 1 =>
						binary_nonce <= (others => '0');
						flag_found <= '0';
						flag_running <= '1';
						flag_overflow <= '0';
						state := 8;
					when 8 =>	-- copy mid state and insert nonce
						-- pipeline adder for speed
						binary_nonce <= binary_nonce + 1;
						
						-- copy and fully expand mid-state to curl-state
						for I in 0 to (STATE_LENGTH/DATA_WIDTH)-1 loop
							for J in 0 to DATA_WIDTH-1 loop
								tmp_index := I*DATA_WIDTH+J;
								if  tmp_index < 162 or tmp_index > HASH_LENGTH-1 then
									if curl_mid_state_low(I)(J) = '1' then
										curl_state_low(tmp_index) <= (others => '1');
									else
										curl_state_low(tmp_index) <= (others => '0');
									end if;
									
									if curl_mid_state_high(I)(J) = '1' then
										curl_state_high(tmp_index) <= (others => '1');
									else
										curl_state_high(tmp_index) <= (others => '0');
									end if;
								end if;
							end loop;
						end loop;
   
--						-- generate bitmuster in first two trit-arrays of counter depending from PARALLEL setting
--						-- doesn't need additional resources for pow or division because everything is constant
						for J in 0 to 1 loop	-- TODO make adjustable ... it's okay up to PARALLEL = 9
							for I in 0 to PARALLEL-1 loop
								tmp_mod := (I/(3**J)) mod 3;
								if tmp_mod = 0 then
									curl_state_low(162+J)(I) <= '1';
									curl_state_high(162+J)(I) <= '1';
								elsif tmp_mod = 1 then
									curl_state_low(162+J)(I) <= '0';
									curl_state_high(162+J)(I) <= '1';
								elsif tmp_mod = 2 then
									curl_state_low(162+J)(I) <= '1';
									curl_state_high(162+J)(I) <= '0';
								end if;
							end loop;
						end loop;

 
						-- lowest trits for counter from 0 to 4 (for 5bit)
--						curl_state_low(162) <=  "01101"; 
--						curl_state_high(162) <= "11011";
--						curl_state_low(163) <=  "00111";
--						curl_state_high(163) <= "11111";
						
						-- insert and convert binary nonce to trinary nonce
						-- It's a fake trinary nonce but integer-values are strictly monotonously rising 
						-- with integer values of binary nonce.
						-- Doesn't bring the exact same result like reference implementation with real
						-- trinary adder - but it doesn't matter and it is way faster.
						for I in 164 to 164+INTERN_NONCE_LENGTH-1 loop
							if binary_nonce(I-164) = '1' then
								curl_state_low(I) <= (others => '1');
								curl_state_high(I) <= (others => '0');
							else
								curl_state_low(I) <= (others => '0');
								curl_state_high(I) <= (others => '1');
							end if;
						end loop;
						
						-- fill remaining trits with '11' (=0)
						for I in 164+INTERN_NONCE_LENGTH to HASH_LENGTH-1 loop
							curl_state_low(I) <= (others => '1');
							curl_state_high(I) <= (others => '1');
						end loop;	

						-- initialize round-counter
						round := NUMBER_OF_ROUNDS;
						
						state := 10;
					when 10 =>	-- do the curl hash round without any copying needed
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
						imask := (others => '1');
						
						-- doesn't work like the 2nd variant ... why? TODO^^ 
						for I in 0 to PARALLEL-1 loop
							for J in 0 to BITS_MIN_WEIGHT_MAGINUTE_MAX-1 loop
								if i_min_weight_magnitude(J) = '1' and (curl_state_low(HASH_LENGTH - 1 - J)(I) /= '1' or curl_state_high(HASH_LENGTH - 1 - J)(I) /= '1') then
									imask(I) := '0';
								end if;
							end loop;
						end loop;
						
--						imask := (others => '1');
--						for I in 0 to BITS_MIN_WEIGHT_MAGINUTE_MAX-1 loop 
--							if i_min_weight_magnitude(I) = '1' then
--								imask := imask and not (curl_state_low(HASH_LENGTH - 1 - I) xor curl_state_high(HASH_LENGTH - 1 - I));
--							end if;
--						end loop;
--						mask <= imask;						

						-- no solution found?
						if unsigned(imask) = 0 then
							-- is overflow?
							if binary_nonce = x"ffffffff" then
								flag_overflow <= '1';
								state := 0;
							else
								state := 8;	-- and try again
							end if;										
						else
							state := 30;	-- nonce found
						end if;
					when 30 =>
						mask <= imask;
						flag_found <= '1';
						state := 0;
					when others =>
						state := 0;
				end case;
			end if;
		end if;
	end process;
end behv;
