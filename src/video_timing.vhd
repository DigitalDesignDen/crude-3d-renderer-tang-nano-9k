library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity video_timing is
    generic (
        H_ACTIVE  : natural := 720;      -- visible pixels per line
        H_FP      : natural := 16;       -- front porch
        H_SYNC    : natural := 62;       -- sync width
        H_BP      : natural := 60;       -- back porch
        V_ACTIVE  : natural := 480;      -- visible lines
        V_FP      : natural := 9;        -- vertical front porch
        V_SYNC    : natural := 6;        -- vertical sync lines
        V_BP      : natural := 30        -- vertical back porch
    );
    port (
        clk       : in  std_logic;               -- pixel clock (27 MHz preset)
        rst       : in  std_logic;               -- synchronous reset (active high)
        hsync     : out std_logic;
        vsync     : out std_logic;
        de        : out std_logic;
        px_x      : out integer range 0 to 8191; -- pixel x (0 .. H_ACTIVE-1 when de='1')
        px_y      : out integer range 0 to 8191  -- pixel y (0 .. V_ACTIVE-1 when de='1')
    );
end entity;

architecture rtl of video_timing is
    constant H_TOTAL : natural := H_ACTIVE + H_FP + H_SYNC + H_BP;
    constant V_TOTAL : natural := V_ACTIVE + V_FP + V_SYNC + V_BP;

    signal h_cnt : integer range 0 to H_TOTAL-1 := 0;
    signal v_cnt : integer range 0 to V_TOTAL-1 := 0;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                h_cnt <= 0;
                v_cnt <= 0;
            else
                if h_cnt = H_TOTAL-1 then
                    h_cnt <= 0;
                    if v_cnt = V_TOTAL-1 then
                        v_cnt <= 0;
                    else
                        v_cnt <= v_cnt + 1;
                    end if;
                else
                    h_cnt <= h_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Data enable: when within active window
    de <= '1' when (h_cnt < H_ACTIVE and v_cnt < V_ACTIVE) else '0';

    -- pixel coords while de = '1'
    px_x <= h_cnt when (h_cnt < H_ACTIVE) else 0;
    px_y <= v_cnt when (v_cnt < V_ACTIVE) else 0;

    -- hsync: asserted during sync pulse region (after front porch)
    -- We'll generate polarity-true pulses of 1 during sync; if you need inverted polarity,
    -- invert these assignments.
    hsync <= '1' when (h_cnt >= (H_ACTIVE + H_FP) and h_cnt < (H_ACTIVE + H_FP + H_SYNC)) else '0';

    vsync <= '1' when (v_cnt >= (V_ACTIVE + V_FP) and v_cnt < (V_ACTIVE + V_FP + V_SYNC)) else '0';
end architecture;
