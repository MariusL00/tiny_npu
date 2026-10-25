`default_nettype none

module tt_um_npu_MariusL00 (
    input  wire [7:0] ui_in,    // Entrées dédiées (Pixels 0 à 7)
    output wire [7:0] uo_out,   // Sorties dédiées (Prédictions vers le MCU)
    input  wire [7:0] uio_in,   // IOs bidirectionnelles (Pixel 8 sur uio_in[0])
    output wire [7:0] uio_out,  // IOs bidirectionnelles sorties (Non utilisées)
    output wire [7:0] uio_oe,   // Direction des IOs (0 = Entrée, 1 = Sortie)
    input  wire       ena,      // Signal d'activation
    input  wire       clk,      // Horloge (Non utilisée, design asynchrone)
    input  wire       rst_n     // Reset actif à l'état bas
);

    // ==========================================
    // 1. MAPPING DES ENTRÉES/SORTIES (Tiny Tapeout)
    // ==========================================
    
    assign uio_oe  = 8'b00000000;
    assign uio_out = 8'b00000000;

    wire [8:0] p;
    assign p[7:0] = ui_in[7:0];
    assign p[8]   = uio_in[0];

    // ==========================================
    // 2. ÉTAGE MAC (Multiply-Accumulate)
    // Zero-Extension explicite pour satisfaire le Linting Verilator
    // ==========================================

    // Horizontal (-)
    wire [1:0] pos_h = {1'b0, p[0]} + {1'b0, p[1]} + {1'b0, p[2]};
    wire [2:0] neg_h = {2'b0, p[3]} + {2'b0, p[4]} + {2'b0, p[5]} + {2'b0, p[6]} + {2'b0, p[7]} + {2'b0, p[8]};
    wire signed [4:0] score_h = $signed({3'b0, pos_h}) - $signed({2'b0, neg_h});

    // Vertical (|)
    wire [1:0] pos_v = {1'b0, p[0]} + {1'b0, p[3]} + {1'b0, p[6]};
    wire [2:0] neg_v = {2'b0, p[1]} + {2'b0, p[2]} + {2'b0, p[4]} + {2'b0, p[5]} + {2'b0, p[7]} + {2'b0, p[8]};
    wire signed [4:0] score_v = $signed({3'b0, pos_v}) - $signed({2'b0, neg_v});

    // Diagonale 1 (\)
    wire [1:0] pos_d1 = {1'b0, p[0]} + {1'b0, p[4]} + {1'b0, p[8]};
    wire [2:0] neg_d1 = {2'b0, p[1]} + {2'b0, p[2]} + {2'b0, p[3]} + {2'b0, p[5]} + {2'b0, p[6]} + {2'b0, p[7]};
    wire signed [4:0] score_d1 = $signed({3'b0, pos_d1}) - $signed({2'b0, neg_d1});

    // Diagonale 2 (/)
    wire [1:0] pos_d2 = {1'b0, p[2]} + {1'b0, p[4]} + {1'b0, p[6]};
    wire [2:0] neg_d2 = {2'b0, p[0]} + {2'b0, p[1]} + {2'b0, p[3]} + {2'b0, p[5]} + {2'b0, p[7]} + {2'b0, p[8]};
    wire signed [4:0] score_d2 = $signed({3'b0, pos_d2}) - $signed({2'b0, neg_d2});

    // ==========================================
    // 3. MAX POOLING (Trouver le score maximum)
    // ==========================================
    wire signed [4:0] max_1 = (score_h > score_v) ? score_h : score_v;
    wire signed [4:0] max_2 = (score_d1 > score_d2) ? score_d1 : score_d2;
    wire signed [4:0] max_score = (max_1 > max_2) ? max_1 : max_2;

    // ==========================================
    // 4. CLASSIFICATION & GESTION DES ÉGALITÉS
    // ==========================================
    wire is_h  = (score_h == max_score);
    wire is_v  = (score_v == max_score);
    wire is_d1 = (score_d1 == max_score);
    wire is_d2 = (score_d2 == max_score);

    // Zero-Extension explicite sur les signaux de comparaison (1 bit vers 3 bits)
    wire [2:0] tie_count = {2'b0, is_h} + {2'b0, is_v} + {2'b0, is_d1} + {2'b0, is_d2};

    // Seuil d'activation fixé à 2
    wire valid = (max_score >= 5'sd2) && (tie_count == 3'd1);

    // ==========================================
    // 5. SORTIES VERS LE MCU (Transparence Éducative)
    // ==========================================
    
    // On crée un signal de 3 bits pour identifier la forme gagnante
    wire [2:0] pred_id;

    // Encodeur : Si ce n'est pas valide (bruit/égalité), on sort 000.
    // Sinon, on assigne un numéro unique à chaque forme.
    assign pred_id = (~valid) ? 3'b000 : // 0 = Inconnu / Bruit
                     (is_h)   ? 3'b001 : // 1 = Horizontal
                     (is_v)   ? 3'b010 : // 2 = Vertical
                     (is_d1)  ? 3'b011 : // 3 = Diagonale 1
                     (is_d2)  ? 3'b100 : // 4 = Diagonale 2
                                3'b000;

    // Concaténation pour les 8 broches de sortie (uo_out) :
    // - Les 5 bits de poids fort (uo_out[7:3]) reçoivent le max_score (de -16 à +15)
    // - Les 3 bits de poids faible (uo_out[2:0]) reçoivent le pred_id (de 0 à 4)
    assign uo_out = {max_score, pred_id};

endmodule