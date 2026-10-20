`default_nettype none

module tt_um_npu_MariusL00 (
    input  wire [7:0] ui_in,    // 8 premiers pixels
    output wire [7:0] uo_out,   // Sorties (Scores multiplexés + Prédiction)
    input  wire [7:0] uio_in,   // IOs : pixel 9 et sélecteur de score
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Configuration des ports bidirectionnels (tout en entrée)
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // --- 1. MAPPING DES ENTRÉES ---
    // Les 9 pixels de la matrice 3x3
    wire [8:0] p;
    assign p[7:0] = ui_in[7:0];
    assign p[8]   = uio_in[0];

    // Sélecteur pour lire les scores via le MCU
    wire [1:0] score_select = uio_in[2:1];

    // --- 2. COUCHE 1 : LES 8 SOUS-NEURONES (Filtres spatiaux) ---
    // Les scores vont de -9 à +9. Il nous faut 5 bits signés (complément à 2)
    wire signed [4:0] s_HH, s_HM, s_HB; // Horizontal (Haut, Milieu, Bas)
    wire signed [4:0] s_VG, s_VM, s_VD; // Vertical (Gauche, Milieu, Droite)
    wire signed [4:0] s_D1, s_D2;       // Diagonales

    // HORIZONTALES
    assign s_HH = (p[0]?5'sd1:5'sd0) + (p[1]?5'sd1:5'sd0) + (p[2]?5'sd1:5'sd0) +
                  (p[3]?-5'sd1:5'sd0) + (p[4]?-5'sd1:5'sd0) + (p[5]?-5'sd1:5'sd0) +
                  (p[6]?-5'sd1:5'sd0) + (p[7]?-5'sd1:5'sd0) + (p[8]?-5'sd1:5'sd0);

    assign s_HM = (p[0]?-5'sd1:5'sd0) + (p[1]?-5'sd1:5'sd0) + (p[2]?-5'sd1:5'sd0) +
                  (p[3]?5'sd1:5'sd0) + (p[4]?5'sd1:5'sd0) + (p[5]?5'sd1:5'sd0) +
                  (p[6]?-5'sd1:5'sd0) + (p[7]?-5'sd1:5'sd0) + (p[8]?-5'sd1:5'sd0);

    assign s_HB = (p[0]?-5'sd1:5'sd0) + (p[1]?-5'sd1:5'sd0) + (p[2]?-5'sd1:5'sd0) +
                  (p[3]?-5'sd1:5'sd0) + (p[4]?-5'sd1:5'sd0) + (p[5]?-5'sd1:5'sd0) +
                  (p[6]?5'sd1:5'sd0) + (p[7]?5'sd1:5'sd0) + (p[8]?5'sd1:5'sd0);

    // VERTICALES
    assign s_VG = (p[0]?5'sd1:5'sd0) + (p[1]?-5'sd1:5'sd0) + (p[2]?-5'sd1:5'sd0) +
                  (p[3]?5'sd1:5'sd0) + (p[4]?-5'sd1:5'sd0) + (p[5]?-5'sd1:5'sd0) +
                  (p[6]?5'sd1:5'sd0) + (p[7]?-5'sd1:5'sd0) + (p[8]?-5'sd1:5'sd0);

    assign s_VM = (p[0]?-5'sd1:5'sd0) + (p[1]?5'sd1:5'sd0) + (p[2]?-5'sd1:5'sd0) +
                  (p[3]?-5'sd1:5'sd0) + (p[4]?5'sd1:5'sd0) + (p[5]?-5'sd1:5'sd0) +
                  (p[6]?-5'sd1:5'sd0) + (p[7]?5'sd1:5'sd0) + (p[8]?-5'sd1:5'sd0);

    assign s_VD = (p[0]?-5'sd1:5'sd0) + (p[1]?-5'sd1:5'sd0) + (p[2]?5'sd1:5'sd0) +
                  (p[3]?-5'sd1:5'sd0) + (p[4]?-5'sd1:5'sd0) + (p[5]?5'sd1:5'sd0) +
                  (p[6]?-5'sd1:5'sd0) + (p[7]?-5'sd1:5'sd0) + (p[8]?5'sd1:5'sd0);

    // DIAGONALES (Principales uniquement)
    assign s_D1 = (p[0]?5'sd1:5'sd0) + (p[1]?-5'sd1:5'sd0) + (p[2]?-5'sd1:5'sd0) +
                  (p[3]?-5'sd1:5'sd0) + (p[4]?5'sd1:5'sd0) + (p[5]?-5'sd1:5'sd0) +
                  (p[6]?-5'sd1:5'sd0) + (p[7]?-5'sd1:5'sd0) + (p[8]?5'sd1:5'sd0);

    assign s_D2 = (p[0]?-5'sd1:5'sd0) + (p[1]?-5'sd1:5'sd0) + (p[2]?5'sd1:5'sd0) +
                  (p[3]?-5'sd1:5'sd0) + (p[4]?5'sd1:5'sd0) + (p[5]?-5'sd1:5'sd0) +
                  (p[6]?5'sd1:5'sd0) + (p[7]?-5'sd1:5'sd0) + (p[8]?-5'sd1:5'sd0);

    // --- 3. COUCHE 2 : MAX POOLING (Invariance Spatiale) ---
    wire signed [4:0] max_H_tmp = (s_HH > s_HM) ? s_HH : s_HM;
    wire signed [4:0] max_H     = (max_H_tmp > s_HB) ? max_H_tmp : s_HB;

    wire signed [4:0] max_V_tmp = (s_VG > s_VM) ? s_VG : s_VM;
    wire signed [4:0] max_V     = (max_V_tmp > s_VD) ? max_V_tmp : s_VD;

    // --- 4. COUCHE 3 : CLASSIFICATION ET SEUIL ---
    wire signed [4:0] max_global_1 = (max_H > max_V) ? max_H : max_V;
    wire signed [4:0] max_global_2 = (s_D1 > s_D2) ? s_D1 : s_D2;
    wire signed [4:0] max_global   = (max_global_1 > max_global_2) ? max_global_1 : max_global_2;

    wire is_H  = (max_H == max_global);
    wire is_V  = (max_V == max_global);
    wire is_D1 = (s_D1 == max_global);
    wire is_D2 = (s_D2 == max_global);

    // Comptage des ex-aequo
    wire [2:0] exaequo_count = is_H + is_V + is_D1 + is_D2;

    // Validation : Le max doit être >= 2, et il doit y avoir un seul gagnant
    wire valid = (max_global >= 5'sd2) && (exaequo_count == 3'd1);

    // Encodage final (0: Inconnu, 1: Hori, 2: Vert, 3: Diag1, 4: Diag2)
    wire [2:0] prediction;
    assign prediction = valid ? (is_H ? 3'd1 : (is_V ? 3'd2 : (is_D1 ? 3'd3 : 3'd4))) : 3'd0;

    // --- 5. ROUTAGE DES SORTIES (MULTIPLEXEUR) ---
    reg signed [4:0] selected_score;
    
    always @(*) begin
        case (score_select)
            2'b00: selected_score = max_H;
            2'b01: selected_score = max_V;
            2'b10: selected_score = s_D1;
            2'b11: selected_score = s_D2;
        endcase
    end

    // Les 3 bits de poids faible pour la décision
    assign uo_out[2:0] = prediction;
    
    // Les 5 bits de poids fort pour lire le score demandé par le MCU
    assign uo_out[7:3] = selected_score;

endmodule
