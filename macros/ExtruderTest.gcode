G90;Absolute
M104 0;Reset temperature
G28;Home
G1 F3000
G1 X50 Y5 F3000
M109 S195;set the temperature
G92 E0
G1 X50 Y5 F100
G1 X50 Y5 E100 F100
