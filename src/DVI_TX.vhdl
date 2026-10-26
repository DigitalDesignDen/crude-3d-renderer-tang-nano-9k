library ieee;
use ieee.std_logic_1164.all;

entity DVI_TX is
		port (
		I_rst_n		: in std_logic;
		I_rgb_clk	: in std_logic;
		I_ser_clk	: in std_logic;
		I_rgb_vs	: in std_logic;
		I_rgb_hs	: in std_logic;
		I_rgb_de	: in std_logic;
		I_rgb_r		: in std_logic_vector(7 downto 0);
		I_rgb_g		: in std_logic_vector(7 downto 0);
		I_rgb_b		: in std_logic_vector(7 downto 0);
		O_tmds_clk_p	: out std_logic;
		O_tmds_clk_n	: out std_logic;
		O_tmds_data_p	: out std_logic_vector(2 downto 0);
		O_tmds_data_n	: out std_logic_vector(2 downto 0)
	);
end entity;

architecture structural of DVI_TX is

type t_tmds_data is array (0 to 2) of std_logic_vector(9 downto 0);
signal tmds_data : t_tmds_data;

signal serial_data	 : std_logic_vector(2 downto 0);

component ELVDS_OBUF port ( O:OUT std_logic; OB:OUT std_logic; I:IN std_logic ); 
end component;

component OSER10    GENERIC (GSREN:string:="false"; LSREN:string:="true");
					PORT(
			  Q:OUT std_logic;
			  D0:IN std_logic;
			  D1:IN std_logic;
			  D2:IN std_logic;
			  D3:IN std_logic;
              D4:IN std_logic;
              D5:IN std_logic;
              D6:IN std_logic;
              D7:IN std_logic;
              D8:IN std_logic;
              D9:IN std_logic;
              FCLK:IN std_logic;
              PCLK:IN std_logic;
			  RESET:IN std_logic
			);
end component;


begin

TMDS_channel_1 : entity work.TMDS_encoder
	port map (
			clk			=> I_rgb_clk,
			data_i		=> I_rgb_b,
			control_i	=> (I_rgb_hs & I_rgb_vs),
			blank_i		=> not I_rgb_de,
			encoded_o	=> tmds_data(0)
			);

TMDS_channel_2 : entity work.TMDS_encoder
	port map (
			clk			=> I_rgb_clk,
			data_i		=> I_rgb_g,
			control_i	=> "00",
			blank_i		=> not I_rgb_de,
			encoded_o	=> tmds_data(1)
			);

TMDS_channel_3 : entity work.TMDS_encoder
	port map (
			clk			=> I_rgb_clk,
			data_i		=> I_rgb_r,
			control_i	=> "00",
			blank_i		=> not I_rgb_de,
			encoded_o	=> tmds_data(2)
			);

gen_serdes : for i in 0 to 2 generate
serdes : OSER10
	GENERIC MAP (GSREN=>"false",
				LSREN=>"true")
    PORT MAP (
           Q	 => serial_data(i),
           D0	 => tmds_data(i)(0),
           D1	 => tmds_data(i)(1),
           D2	 => tmds_data(i)(2),
           D3	 => tmds_data(i)(3),
           D4	 => tmds_data(i)(4),
           D5	 => tmds_data(i)(5),
           D6	 => tmds_data(i)(6),
           D7	 => tmds_data(i)(7),
           D8	 => tmds_data(i)(8),
           D9	 => tmds_data(i)(9),
           FCLK  => I_ser_clk,
           PCLK  => I_rgb_clk,
           RESET => not I_rst_n
     ); 
end generate;


gen_output_buffers : for i in 0 to 2 generate
output_buffer : ELVDS_OBUF
	port map (
				O  => O_tmds_data_p(i),
				OB => O_tmds_data_n(i),
				I  => serial_data(i)
			);
end generate;

output_buffer_clk : ELVDS_OBUF
	port map (
				O  => O_tmds_clk_p,
				OB => O_tmds_clk_n,
				I  => I_rgb_clk
			);



end architecture;