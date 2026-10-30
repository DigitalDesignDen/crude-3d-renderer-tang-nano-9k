-- A uart receiver implementation

library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
    generic (
        CLK_FREQ_HZ : positive := 27_000_000;
        BAUD_RATE   : positive := 115_200
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        rx         : in  std_logic;
        data_out   : out std_logic_vector(7 downto 0);
        data_valid : out std_logic
    );
end entity;

architecture rtl of uart_rx is
    constant BIT_TICKS      : positive := CLK_FREQ_HZ / BAUD_RATE;
    constant HALF_BIT_TICKS : positive := BIT_TICKS / 2;

    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);

    signal state      : state_t := IDLE;
    signal rx_meta    : std_logic := '1';
    signal rx_sync    : std_logic := '1';
    signal bit_count  : integer range 0 to BIT_TICKS - 1 := 0;
    signal bit_index  : integer range 0 to 7 := 0;
    signal shift_data : std_logic_vector(7 downto 0) := (others => '0');
    signal data_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_reg  : std_logic := '0';
begin
    data_out   <= data_reg;
    data_valid <= valid_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            rx_meta <= rx;
            rx_sync <= rx_meta;

            if rst = '1' then
                state      <= IDLE;
                rx_meta    <= '1';
                rx_sync    <= '1';
                bit_count  <= 0;
                bit_index  <= 0;
                shift_data <= (others => '0');
                data_reg   <= (others => '0');
                valid_reg  <= '0';
            else
                valid_reg <= '0';

                case state is
                    when IDLE =>
                        bit_count <= 0;
                        if rx_sync = '0' then
                            state <= START_BIT;
                        end if;

                    when START_BIT =>
                        if bit_count = HALF_BIT_TICKS - 1 then
                            bit_count <= 0;
                            if rx_sync = '0' then
                                bit_index <= 0;
                                state <= DATA_BITS;
                            else
                                state <= IDLE;
                            end if;
                        else
                            bit_count <= bit_count + 1;
                        end if;

                    when DATA_BITS =>
                        if bit_count = BIT_TICKS - 1 then
                            bit_count <= 0;
                            shift_data(bit_index) <= rx_sync;
                            if bit_index = 7 then
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                            end if;
                        else
                            bit_count <= bit_count + 1;
                        end if;

                    when STOP_BIT =>
                        if bit_count = BIT_TICKS - 1 then
                            bit_count <= 0;
                            state <= IDLE;
                            if rx_sync = '1' then
                                data_reg  <= shift_data;
                                valid_reg <= '1';
                            end if;
                        else
                            bit_count <= bit_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
