library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TOP is
    generic (
        MODEL_SCALE_Q8_8 : positive := 128;
        FOCAL_LENGTH     : positive := 120
    );
    port (
        CLK27      : in  std_logic;
        RESETN     : in  std_logic;
        tmds_clk_n : out std_logic;
        tmds_clk_p : out std_logic;
        tmds_d_n   : out std_logic_vector(2 downto 0);
        tmds_d_p   : out std_logic_vector(2 downto 0)
    );
end entity TOP;

architecture rtl of TOP is
    constant H_ACTIVE : positive := 720;
    constant V_ACTIVE : positive := 480;
    constant CENTER_X : integer := H_ACTIVE / 2;
    constant CENTER_Y : integer := V_ACTIVE / 2;
    constant VERTEX_COUNT : positive := 8;

    type vertex_array_t is array (0 to VERTEX_COUNT - 1) of integer range -4096 to 4096;
    type pixel_array_t is array (0 to VERTEX_COUNT - 1) of integer range -2048 to 2047;
    type renderer_state_t is (IDLE, CALCULATE, DIVIDE_X, SAVE_X, DIVIDE_Y, SAVE_Y);

    constant VERTEX_X : vertex_array_t := (-595, -1628, 3090, 2056, -2056, -3090, 1628, 595);
    constant VERTEX_Y : vertex_array_t := (648, 3132, 73, 2558, -2558, -73, -3132, -648);
    constant VERTEX_Z : vertex_array_t := (3437, 348, 1741, -1347, 1347, -1741, -348, -3437);

    signal reset          : std_logic;
    signal pixel_clk      : std_logic;
    signal serial_clk     : std_logic;
    signal pixel_x        : integer range 0 to 8191;
    signal pixel_y        : integer range 0 to 8191;
    signal video_de       : std_logic;
    signal hsync          : std_logic;
    signal vsync          : std_logic;
    signal red            : std_logic_vector(7 downto 0);
    signal green          : std_logic_vector(7 downto 0);
    signal blue           : std_logic_vector(7 downto 0);
    signal frame_start    : std_logic;

    signal angle          : unsigned(7 downto 0) := (others => '0');
    signal sine_value     : integer range -32767 to 32767;
    signal cosine_value   : integer range -32767 to 32767;
    signal state          : renderer_state_t := IDLE;
    signal vertex_index   : integer range 0 to VERTEX_COUNT - 1 := 0;
    signal write_bank     : std_logic := '1';
    signal display_bank   : std_logic := '0';

    signal x_pixels_0     : pixel_array_t := (others => 0);
    signal y_pixels_0     : pixel_array_t := (others => 0);
    signal valid_0        : std_logic_vector(VERTEX_COUNT - 1 downto 0) := (others => '0');
    signal x_pixels_1     : pixel_array_t := (others => 0);
    signal y_pixels_1     : pixel_array_t := (others => 0);
    signal valid_1        : std_logic_vector(VERTEX_COUNT - 1 downto 0) := (others => '0');

    signal dividend       : unsigned(22 downto 0) := (others => '0');
    signal quotient       : unsigned(22 downto 0) := (others => '0');
    signal divisor        : unsigned(15 downto 0) := (others => '0');
    signal remainder     : unsigned(16 downto 0) := (others => '0');
    signal divide_bit     : integer range 0 to 22 := 0;
    signal result_negative: std_logic := '0';
    signal point_in_front : std_logic := '0';
    signal projected_x    : integer range -2048 to 2047 := CENTER_X;

    component Gowin_rPLL is
        port (
            clkout : out std_logic;
            clkin  : in  std_logic
        );
    end component;

    component DVI_TX is
        port (
            I_rst_n       : in  std_logic;
            I_rgb_clk     : in  std_logic;
            I_ser_clk     : in  std_logic;
            I_rgb_vs      : in  std_logic;
            I_rgb_hs      : in  std_logic;
            I_rgb_de      : in  std_logic;
            I_rgb_r       : in  std_logic_vector(7 downto 0);
            I_rgb_g       : in  std_logic_vector(7 downto 0);
            I_rgb_b       : in  std_logic_vector(7 downto 0);
            O_tmds_clk_p  : out std_logic;
            O_tmds_clk_n  : out std_logic;
            O_tmds_data_p : out std_logic_vector(2 downto 0);
            O_tmds_data_n : out std_logic_vector(2 downto 0)
        );
    end component;
begin
    reset <= not RESETN;
    pixel_clk <= CLK27;
    frame_start <= '1' when video_de = '1' and pixel_x = 0 and pixel_y = 0 else '0';

    PLL_5x : Gowin_rPLL
        port map (
            clkout => serial_clk,
            clkin  => CLK27
        );

    timing_inst : entity work.video_timing
        generic map (
            H_ACTIVE => 720,
            H_FP     => 16,
            H_SYNC   => 62,
            H_BP     => 60,
            V_ACTIVE => 480,
            V_FP     => 9,
            V_SYNC   => 6,
            V_BP     => 30
        )
        port map (
            clk   => pixel_clk,
            rst   => reset,
            hsync => hsync,
            vsync => vsync,
            de    => video_de,
            px_x  => pixel_x,
            px_y  => pixel_y
        );

    trig_inst : entity work.sincos_lut
        port map (
            phase   => angle,
            sine    => sine_value,
            cosine => cosine_value
        );

    transmitter_inst : DVI_TX
        port map (
            I_rst_n       => RESETN,
            I_rgb_clk     => pixel_clk,
            I_ser_clk     => serial_clk,
            I_rgb_vs      => vsync,
            I_rgb_hs      => hsync,
            I_rgb_de      => video_de,
            I_rgb_r       => red,
            I_rgb_g       => green,
            I_rgb_b       => blue,
            O_tmds_clk_p  => tmds_clk_p,
            O_tmds_clk_n  => tmds_clk_n,
            O_tmds_data_p => tmds_d_p,
            O_tmds_data_n => tmds_d_n
        );

    transform_proc : process (pixel_clk)
        variable scaled_x       : integer;
        variable scaled_z       : integer;
        variable rotated_x      : integer;
        variable rotated_z      : integer;
        variable depth_q8_8     : integer;
        variable numerator     : integer;
        variable shifted_rem   : unsigned(16 downto 0);
        variable quotient_next : unsigned(22 downto 0);
        variable offset        : integer;
        variable screen_value  : integer;
    begin
        if rising_edge(pixel_clk) then
            if reset = '1' then
                angle <= (others => '0');
                state <= IDLE;
                vertex_index <= 0;
                write_bank <= '1';
                display_bank <= '0';
                x_pixels_0 <= (others => 0);
                y_pixels_0 <= (others => 0);
                valid_0 <= (others => '0');
                x_pixels_1 <= (others => 0);
                y_pixels_1 <= (others => 0);
                valid_1 <= (others => '0');
                dividend <= (others => '0');
                quotient <= (others => '0');
                divisor <= (others => '0');
                remainder <= (others => '0');
                divide_bit <= 0;
                result_negative <= '0';
                point_in_front <= '0';
                projected_x <= CENTER_X;
            else
                case state is
                    when IDLE =>
                        if frame_start = '1' then
                            angle <= angle + 1;
                            vertex_index <= 0;
                            write_bank <= not display_bank;
                            state <= CALCULATE;
                        end if;

                    when CALCULATE =>
                        scaled_x := (VERTEX_X(vertex_index) * MODEL_SCALE_Q8_8) / 256;
                        scaled_z := (VERTEX_Z(vertex_index) * MODEL_SCALE_Q8_8) / 256;
                        rotated_x := (scaled_x * cosine_value + scaled_z * sine_value) / 32768;
                        rotated_z := (-scaled_x * sine_value + scaled_z * cosine_value) / 32768;
                        depth_q8_8 := 1024 + (rotated_z * 59) / 256;
                        if depth_q8_8 > 256 then
                            point_in_front <= '1';
                        else
                            point_in_front <= '0';
                        end if;
                        if depth_q8_8 < 1 then
                            depth_q8_8 := 1;
                        end if;
                        if depth_q8_8 > 65535 then
                            depth_q8_8 := 65535;
                        end if;
                        divisor <= to_unsigned(depth_q8_8, divisor'length);
                        numerator := rotated_x * FOCAL_LENGTH;
                        if numerator < 0 then
                            result_negative <= '1';
                        else
                            result_negative <= '0';
                        end if;
                        dividend <= to_unsigned(abs(numerator), dividend'length);
                        quotient <= (others => '0');
                        remainder <= (others => '0');
                        divide_bit <= 22;
                        state <= DIVIDE_X;

                    when DIVIDE_X =>
                        shifted_rem := remainder(15 downto 0) & dividend(divide_bit);
                        quotient_next := quotient;
                        if shifted_rem >= resize(divisor, shifted_rem'length) then
                            remainder <= shifted_rem - resize(divisor, shifted_rem'length);
                            quotient_next(divide_bit) := '1';
                        else
                            remainder <= shifted_rem;
                            quotient_next(divide_bit) := '0';
                        end if;
                        quotient <= quotient_next;
                        if divide_bit = 0 then
                            state <= SAVE_X;
                        else
                            divide_bit <= divide_bit - 1;
                        end if;

                    when SAVE_X =>
                        offset := to_integer(quotient);
                        if result_negative = '1' then
                            screen_value := CENTER_X - offset;
                        else
                            screen_value := CENTER_X + offset;
                        end if;
                        if screen_value < -2048 then
                            projected_x <= -2048;
                        elsif screen_value > 2047 then
                            projected_x <= 2047;
                        else
                            projected_x <= screen_value;
                        end if;

                        numerator := (VERTEX_Y(vertex_index) * MODEL_SCALE_Q8_8 / 256) * FOCAL_LENGTH;
                        if numerator > 0 then
                            result_negative <= '1';
                        else
                            result_negative <= '0';
                        end if;
                        dividend <= to_unsigned(abs(numerator), dividend'length);
                        quotient <= (others => '0');
                        remainder <= (others => '0');
                        divide_bit <= 22;
                        state <= DIVIDE_Y;

                    when DIVIDE_Y =>
                        shifted_rem := remainder(15 downto 0) & dividend(divide_bit);
                        quotient_next := quotient;
                        if shifted_rem >= resize(divisor, shifted_rem'length) then
                            remainder <= shifted_rem - resize(divisor, shifted_rem'length);
                            quotient_next(divide_bit) := '1';
                        else
                            remainder <= shifted_rem;
                            quotient_next(divide_bit) := '0';
                        end if;
                        quotient <= quotient_next;
                        if divide_bit = 0 then
                            state <= SAVE_Y;
                        else
                            divide_bit <= divide_bit - 1;
                        end if;

                    when SAVE_Y =>
                        offset := to_integer(quotient);
                        if result_negative = '1' then
                            screen_value := CENTER_Y - offset;
                        else
                            screen_value := CENTER_Y + offset;
                        end if;
                        if screen_value < -2048 then
                            screen_value := -2048;
                        elsif screen_value > 2047 then
                            screen_value := 2047;
                        end if;

                        if write_bank = '0' then
                            x_pixels_0(vertex_index) <= projected_x;
                            y_pixels_0(vertex_index) <= screen_value;
                            if point_in_front = '1' and projected_x >= 0 and projected_x < H_ACTIVE and
                               screen_value >= 0 and screen_value < V_ACTIVE then
                                valid_0(vertex_index) <= '1';
                            else
                                valid_0(vertex_index) <= '0';
                            end if;
                        else
                            x_pixels_1(vertex_index) <= projected_x;
                            y_pixels_1(vertex_index) <= screen_value;
                            if point_in_front = '1' and projected_x >= 0 and projected_x < H_ACTIVE and
                               screen_value >= 0 and screen_value < V_ACTIVE then
                                valid_1(vertex_index) <= '1';
                            else
                                valid_1(vertex_index) <= '0';
                            end if;
                        end if;

                        if vertex_index = VERTEX_COUNT - 1 then
                            display_bank <= write_bank;
                            state <= IDLE;
                        else
                            vertex_index <= vertex_index + 1;
                            state <= CALCULATE;
                        end if;
                end case;
            end if;
        end if;
    end process;

    pixel_proc : process (all)
        variable point_x     : integer;
        variable point_y     : integer;
        variable point_found : boolean;
    begin
        red <= (others => '0');
        green <= (others => '0');
        blue <= (others => '0');
        point_found := false;

        if video_de = '1' then
            for i in 0 to VERTEX_COUNT - 1 loop
                if display_bank = '0' then
                    point_x := x_pixels_0(i);
                    point_y := y_pixels_0(i);
                    if valid_0(i) = '1' and not point_found and
                       pixel_x >= point_x - 2 and pixel_x <= point_x + 2 and
                       pixel_y >= point_y - 2 and pixel_y <= point_y + 2 then
                        point_found := true;
                        case i is
                            when 0 => red <= x"FF"; green <= x"FF"; blue <= x"FF";
                            when 1 => red <= x"00"; green <= x"FF"; blue <= x"00";
                            when 2 => red <= x"00"; green <= x"80"; blue <= x"FF";
                            when 3 => red <= x"FF"; green <= x"40"; blue <= x"00";
                            when 4 => red <= x"FF"; green <= x"00"; blue <= x"FF";
                            when 5 => red <= x"00"; green <= x"FF"; blue <= x"FF";
                            when 6 => red <= x"FF"; green <= x"FF"; blue <= x"00";
                            when others => red <= x"FF"; green <= x"80"; blue <= x"00";
                        end case;
                    end if;
                else
                    point_x := x_pixels_1(i);
                    point_y := y_pixels_1(i);
                    if valid_1(i) = '1' and not point_found and
                       pixel_x >= point_x - 2 and pixel_x <= point_x + 2 and
                       pixel_y >= point_y - 2 and pixel_y <= point_y + 2 then
                        point_found := true;
                        case i is
                            when 0 => red <= x"FF"; green <= x"FF"; blue <= x"FF";
                            when 1 => red <= x"00"; green <= x"FF"; blue <= x"00";
                            when 2 => red <= x"00"; green <= x"80"; blue <= x"FF";
                            when 3 => red <= x"FF"; green <= x"40"; blue <= x"00";
                            when 4 => red <= x"FF"; green <= x"00"; blue <= x"FF";
                            when 5 => red <= x"00"; green <= x"FF"; blue <= x"FF";
                            when 6 => red <= x"FF"; green <= x"FF"; blue <= x"00";
                            when others => red <= x"FF"; green <= x"80"; blue <= x"00";
                        end case;
                    end if;
                end if;
            end loop;
        end if;
    end process;
end architecture rtl;
