######################## clk plan ########################
create_generated_clock -name spi_clk -source [get_pins {axi_spi_individual_i/processing_system7_0/inst/PS7_i/FCLKCLK[0]}] -divide_by 50 -add -master_clock [get_clocks clk_fpga_0] [get_ports sck]
##########################################################



######################## pin plan ########################
# 外接温度传感器
# Extended IO - 10	        AB10     miso  
# Extended IO - 11	        Y11      mosi
# Extended IO - 12	        AA11     cs
# Extended IO - 13(MRCC)	Y9       sck
# set_property PACKAGE_PIN Y9 [get_ports sck]
# set_property IOSTANDARD LVCMOS33 [get_ports sck]

# set_property PACKAGE_PIN AA11 [get_ports cs]
# set_property IOSTANDARD LVCMOS33 [get_ports cs]

# set_property PACKAGE_PIN Y11 [get_ports mosi]
# set_property IOSTANDARD LVCMOS33 [get_ports mosi]

# set_property PACKAGE_PIN AB10 [get_ports miso]
# set_property IOSTANDARD LVCMOS33 [get_ports miso]

# 板载BMI160
# BMI160_CS 	Y20     cs
# BMI160_SCK	AA19    sck
# BMI160_MOSI	Y21     mosi
# BMI160_MISO	Y13     miso
set_property PACKAGE_PIN Y20 [get_ports cs]
set_property IOSTANDARD LVCMOS33 [get_ports cs]

set_property PACKAGE_PIN AA19 [get_ports sck]
set_property IOSTANDARD LVCMOS33 [get_ports sck]

set_property PACKAGE_PIN Y21 [get_ports mosi]
set_property IOSTANDARD LVCMOS33 [get_ports mosi]

set_property PACKAGE_PIN Y13 [get_ports miso]
set_property IOSTANDARD LVCMOS33 [get_ports miso]
##########################################################