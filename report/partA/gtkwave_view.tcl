# Loads the 5 signals and zooms to 0-80 ns. Times are in ps (the VCD unit).
gtkwave::addSignalsFromList [list \
  tb_example.clk tb_example.rst_n tb_example.a\[3:0\] tb_example.b\[3:0\] tb_example.p\[7:0\]]
gtkwave::setZoomRangeTimes 0 80000
gtkwave::setMarker 35000
