library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.control_reg_pkg.register_t;

entity control_reg is
    port (
        clk           : in std_logic;
        rst           : in std_logic;
        byte_in       : in std_logic_vector(7 downto 0);
        data_in_valid : in std_logic;
        register_out  : out register_t
    );
end control_reg;

architecture rtl of control_reg is



begin

MAIN_PROC : process(clk)
variable first_position : boolean := true;
begin
    if rising_edge(clk) then
        if rst = '1' then
            register_out.FOCAL_LENGTH <= 120;
            register_out.DEPTH_SCALE <= 59;
            
        else
            if data_in_valid = '1' then
                if first_position then
                    register_out.FOCAL_LENGTH <= to_integer(unsigned(byte_in));
                    first_position := not first_position;
                else
                    register_out.DEPTH_SCALE <= to_integer(unsigned(byte_in));
                    first_position := not first_position;
                end if;
            end if;
            
        end if;
    end if;
end process;

end architecture;