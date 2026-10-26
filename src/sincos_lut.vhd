library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sincos_lut is
    port (
        phase    : in  unsigned(7 downto 0);
        sine     : out integer range -32767 to 32767;
        cosine  : out integer range -32767 to 32767
    );
end entity sincos_lut;

architecture rtl of sincos_lut is
    type quarter_lut_t is array (0 to 63) of integer range 0 to 32767;
    constant QUARTER_SINE : quarter_lut_t := (
        0, 804, 1608, 2410, 3212, 4011, 4808, 5602,
        6393, 7179, 7962, 8739, 9512, 10278, 11039, 11793,
        12539, 13279, 14010, 14732, 15446, 16151, 16846, 17530,
        18204, 18868, 19519, 20159, 20787, 21403, 22005, 22594,
        23170, 23731, 24279, 24811, 25329, 25832, 26319, 26790,
        27245, 27683, 28105, 28510, 28898, 29268, 29621, 29956,
        30273, 30571, 30852, 31113, 31356, 31580, 31785, 31971,
        32137, 32285, 32412, 32521, 32609, 32678, 32728, 32757
    );

    function sine_for_phase(value : integer) return integer is
        variable quadrant : integer range 0 to 3;
        variable offset   : integer range 0 to 63;
        variable sample   : integer range 0 to 32767;
    begin
        quadrant := value / 64;
        offset := value mod 64;
        if quadrant = 0 or quadrant = 2 then
            sample := QUARTER_SINE(offset);
        else
            sample := QUARTER_SINE(63 - offset);
        end if;

        if quadrant >= 2 then
            return -sample;
        end if;
        return sample;
    end function;
begin
    sine <= sine_for_phase(to_integer(phase));
    cosine <= sine_for_phase((to_integer(phase) + 64) mod 256);
end architecture rtl;
