`timescale 1ns / 1ps
`default_nettype none

module tb;

    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    reg        ena;
    reg        clk;
    reg        rst_n;

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Instanciation du module NPU (DUT)
    tt_um_npu_MariusL00 uut(
`ifdef GL_TEST
        .VPWR(1'b1),
        .VGND(1'b0),
`endif
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        #1;
    end

endmodule
