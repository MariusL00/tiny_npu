`default_nettype none

module tt_um_npu_MariusL00 (
    input  wire [7:0] ui_in,    // Entrées dédiées (Switches)
    output wire [7:0] uo_out,   // Sorties dédiées (MCU/LEDs)
    input  wire [7:0] uio_in,   // IOs bidirectionnelles : Entrée
    output wire [7:0] uio_out,  // IOs bidirectionnelles : Sortie
    output wire [7:0] uio_oe,   // IOs bidirectionnelles : Enable
    input  wire       ena,      // Enable signal
    input  wire       clk,      // Clock signal
    input  wire       rst_n     // Reset actif bas
);

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire signed [3:0] s_VL;
    wire signed [3:0] s_VR;
    wire signed [3:0] s_HT;
    wire signed [3:0] s_HB;

    wire signed [3:0] max_v;
    wire signed [3:0] max_h;

    wire prediction;

    // Couche 1 : Extractions des caractéristiques (Neurones)
    assign s_VL = (ui_in[3] ?  4'sd1 : 4'sd0) +
                  (ui_in[2] ? -4'sd1 : 4'sd0) +
                  (ui_in[1] ?  4'sd1 : 4'sd0) +
                  (ui_in[0] ? -4'sd1 : 4'sd0);

    assign s_VR = (ui_in[3] ? -4'sd1 : 4'sd0) +
                  (ui_in[2] ?  4'sd1 : 4'sd0) +
                  (ui_in[1] ? -4'sd1 : 4'sd0) +
                  (ui_in[0] ?  4'sd1 : 4'sd0);

    assign s_HT = (ui_in[3] ?  4'sd1 : 4'sd0) +
                  (ui_in[2] ?  4'sd1 : 4'sd0) +
                  (ui_in[1] ? -4'sd1 : 4'sd0) +
                  (ui_in[0] ? -4'sd1 : 4'sd0);

    assign s_HB = (ui_in[3] ? -4'sd1 : 4'sd0) +
                  (ui_in[2] ? -4'sd1 : 4'sd0) +
                  (ui_in[1] ?  4'sd1 : 4'sd0) +
                  (ui_in[0] ?  4'sd1 : 4'sd0);

    // Couche 2 : Max Pooling
    assign max_v = (s_VL > s_VR) ? s_VL : s_VR;
    assign max_h = (s_HT > s_HB) ? s_HT : s_HB;

    // Couche 3 : Comparateur Final
    assign prediction = (max_v >= max_h);

    // Sorties
    assign uo_out[0]   = prediction;
    assign uo_out[3:1] = max_v[2:0];
    assign uo_out[6:4] = max_h[2:0];
    assign uo_out[7]   = 1'b0;

endmodule
