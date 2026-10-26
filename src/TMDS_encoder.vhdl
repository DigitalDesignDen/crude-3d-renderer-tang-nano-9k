library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TMDS_encoder is

	port(
		clk         : in std_logic;
		data_i      : in std_logic_vector(7 downto 0);
		control_i	: in std_logic_vector(1 downto 0);
		blank_i		: in std_logic;
		encoded_o	: out std_logic_vector(9 downto 0)
		);
	
end TMDS_encoder;


architecture Behavioral of TMDS_encoder is
	signal data_i_reg	: std_logic_vector(7 downto 0);
    signal q_m			: std_logic_vector(8 downto 0);
    signal disparity	: integer range -1023 to 1023 := 0;
	signal n_ones		: integer range 0 to 8;
	signal use_xnor		: boolean;
begin

	-- handle control input and output during blanking
    process(clk)
	variable diff		 : integer range -8 to 8 := 0;
	variable ones_qm	 : integer range 0 to 8 := 0;
	variable encoded_tmp : std_logic_vector(9 downto 0);
    begin
        if rising_edge(clk) then
            if blank_i = '1' then
                -- Output control codes
                case control_i is
                    when "00" => encoded_o <= "1101010100";
                    when "01" => encoded_o <= "0010101011";
                    when "10" => encoded_o <= "0101010100";
                    when "11" => encoded_o <= "1010101011";
                    when others => encoded_o <= "1010101011";
                end case;
				disparity <= 0;
            else
				-- Count 1s in q_m[7:0]
				ones_qm := 0;
				for i in 0 to 7 loop
					if q_m(i) = '1' then
						ones_qm := ones_qm + 1;
					end if;
				end loop;
				
				-- Count difference between number of ones and number of zeros in q_m
				diff := ones_qm - 8 + ones_qm;

				-- Determine polarity
				if (disparity = 0) or (ones_qm = 4) then

					if q_m(8) = '0' then
						encoded_tmp(9) := '1';        -- MSB
						encoded_tmp(8) := '0';  	   -- second MSB
						encoded_tmp(7 downto 0) := not q_m(7 downto 0);
						disparity <= disparity - diff;
					else
						encoded_tmp := "01" & q_m(7 downto 0);
						disparity <= disparity + diff;
					end if;
				else
					if ((disparity > 0) and (ones_qm > 4)) or
					   ((disparity < 0) and (ones_qm < 4)) then
						encoded_tmp(9) := '1';
						encoded_tmp(8) := q_m(8);
						encoded_tmp(7 downto 0) := not q_m(7 downto 0);
						if q_m(8) = '0' then
							disparity <= disparity - diff;
						else
							disparity <= disparity - diff + 2;
						end if;
					else
						encoded_tmp(9) := '0';
						encoded_tmp(8) := q_m(8);
						encoded_tmp(7 downto 0) := q_m(7 downto 0);
						if q_m(8) = '0' then
							disparity <= disparity + diff - 2;
						else
							disparity <= disparity + diff;
						end if;
					end if;
				end if;

				encoded_o <= encoded_tmp;
            end if;
        end if;
    end process;
	
	-- Count number of 1s in data_i
	process(clk)
	variable n_ones_tmp : integer range 0 to 8 := 0;
	begin
		if rising_edge(clk) then
			n_ones_tmp := 0;
			for i in 0 to 7 loop
				if data_i(i) = '1' then
					n_ones_tmp := n_ones_tmp + 1;
				end if;
			end loop;
			n_ones	<= n_ones_tmp;
		end if;
	end process;
	
	-- Decide encoding method
	process(n_ones, data_i)
	begin
		if (n_ones > 4) or ((n_ones = 4) and (data_i(0) = '0')) then
			use_xnor <= true;
		else
			use_xnor <= false;
		end if;
	end process;
	
	-- register data_i
	process(clk)
	begin
		if rising_edge(clk) then
			data_i_reg <= data_i;
		end if;
	end process;
	
	-- Generate q_m[7:0]
	process(clk)
		variable q_m_tmp : std_logic_vector(8 downto 0);
	begin
		if rising_edge(clk) then
			q_m_tmp(0) := data_i_reg(0);
			for i in 1 to 7 loop
				if use_xnor then
					q_m_tmp(i) := not (q_m_tmp(i-1) xor data_i_reg(i));
				else
					q_m_tmp(i) := q_m_tmp(i-1) xor data_i_reg(i);
				end if;
			end loop;
			-- Set q_m(8) to indicate encoding type
			q_m_tmp(8) := '0' when use_xnor else '1';
			q_m <= q_m_tmp;
		end if;
	end process;

	
end Behavioral;












