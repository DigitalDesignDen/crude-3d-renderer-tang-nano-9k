//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.09 Education
//Created Time: 2025-10-13 22:24:10
create_clock -name clk_osc -period 37.037 -waveform {0 18.518} [get_ports {CLK27}]
create_generated_clock -name clk_ser -source [get_ports {CLK27}] -master_clock clk_osc -multiply_by 5 [get_pins {PLL_5x/rpll_inst/CLKOUT}]
//#create_generated_clock -name clk_pix -source [get_pins {PLL_10x/rpll_inst/CLKOUT}] -master_clock clk_ser -divide_by 10 [get_pins {PLL_10x/rpll_inst/CLKOUTD}]
