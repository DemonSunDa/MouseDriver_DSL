# clock
set_property PACKAGE_PIN W5 [get_ports CLK]
    set_property IOSTANDARD LVCMOS33 [get_ports CLK]
# clock

# reset
set_property PACKAGE_PIN U18 [get_ports RESET]
    set_property IOSTANDARD LVCMOS33 [get_ports RESET]
# reset

# PS/2
set_property PACKAGE_PIN C17 [get_ports CLK_MOUSE]
    set_property IOSTANDARD LVCMOS33 [get_ports CLK_MOUSE]
    set_property PULLUP true [get_ports CLK_MOUSE]

set_property PACKAGE_PIN B17 [get_ports DATA_MOUSE]
    set_property IOSTANDARD LVCMOS33 [get_ports DATA_MOUSE]
    set_property PULLUP true [get_ports DATA_MOUSE]
# PS/2

# display
set_property PACKAGE_PIN U2 [get_ports {DISP_SEL_OUT[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEL_OUT[0]}]

set_property PACKAGE_PIN U4 [get_ports {DISP_SEL_OUT[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEL_OUT[1]}]

set_property PACKAGE_PIN V4 [get_ports {DISP_SEL_OUT[2]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEL_OUT[2]}]

set_property PACKAGE_PIN W4 [get_ports {DISP_SEL_OUT[3]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEL_OUT[3]}]

set_property PACKAGE_PIN W7 [get_ports {DISP_OUT[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_OUT[0]}]

set_property PACKAGE_PIN W6 [get_ports {DISP_OUT[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_OUT[1]}]

set_property PACKAGE_PIN U8 [get_ports {DISP_OUT[2]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_OUT[2]}]

set_property PACKAGE_PIN V8 [get_ports {DISP_OUT[3]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_OUT[3]}]

set_property PACKAGE_PIN U5 [get_ports {DISP_OUT[4]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_OUT[4]}]

set_property PACKAGE_PIN V5 [get_ports {DISP_OUT[5]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_OUT[5]}]

set_property PACKAGE_PIN U7 [get_ports {DISP_OUT[6]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_OUT[6]}]

set_property PACKAGE_PIN V7 [get_ports {DISP_OUT[7]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {DISP_OUT[7]}]
# display