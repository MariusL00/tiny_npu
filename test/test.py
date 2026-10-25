import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_npu_educatif(dut):
    """Testbench automatisé pour le NPU 3x3 - Architecture Transparente"""
    
    # 1. Initialisation des signaux
    dut.ena.value = 1
    dut.clk.value = 0
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    # Sortie du reset
    await Timer(10, unit="ns")
    dut.rst_n.value = 1
    await Timer(10, unit="ns")

    dut._log.info("Démarrage des tests du NPU Éducatif...")

    # Dictionnaire pour un affichage propre dans la console
    id_to_name = {
        0: "INCONNU", 
        1: "Horizontal", 
        2: "Vertical", 
        3: "Diagonale 1", 
        4: "Diagonale 2"
    }

    # 2. Fonction utilitaire pour injecter les pixels et décoder la sortie
    async def run_test(name, pixels, expected_id, expected_score):
        # Le pixel 8 va sur uio_in[0], les pixels 0 à 7 vont sur ui_in
        ui_in_val = sum((pixels[i] << i) for i in range(8))
        uio_in_val = pixels[8]
        
        dut.ui_in.value = ui_in_val
        dut.uio_in.value = uio_in_val
        
        # Attendre le délai de propagation combinatoire
        await Timer(10, unit="ns")
        
        # --- DÉCODAGE DE LA SORTIE (Comme le fera le MCU en C++) ---
        # On lit la valeur entière des 8 broches (de 0 à 255)
        uo_val = int(dut.uo_out.value)
        
        # MASQUE 1 : On extrait les 3 bits de poids faible pour l'ID (Opération ET binaire)
        pred_id = uo_val & 0b111 
        
        # MASQUE 2 : On décale de 3 bits vers la droite pour récupérer le score sur 5 bits
        raw_score = (uo_val >> 3) & 0b11111
        
        # Gestion du signe (Complément à deux sur 5 bits) : Si le 5ème bit est 1, le nombre est négatif
        score = raw_score - 32 if raw_score >= 16 else raw_score

        # --- VÉRIFICATIONS ---
        assert pred_id == expected_id, \
            f"❌ ID Erreur sur '{name}': Attendu {expected_id} ({id_to_name[expected_id]}), Obtenu {pred_id} ({id_to_name.get(pred_id, 'Erreur')})"
            
        assert score == expected_score, \
            f"❌ Score Erreur sur '{name}': Attendu {expected_score}, Obtenu {score}"
        
        dut._log.info(f"✅ {name.ljust(25)} -> Détecté: {id_to_name[pred_id].ljust(12)} | Score NPU: {score}")

    # 3. Scénarios de tests (Forme ID, Score Attendu)
    
    # Lignes parfaites (Score maximum : +3 pixels corrects, -0 pixel faux = 3)
    await run_test("Ligne Horizontale (Haut)", [1,1,1, 0,0,0, 0,0,0], expected_id=1, expected_score=3)
    await run_test("Ligne Verticale (Gauche)", [1,0,0, 1,0,0, 1,0,0], expected_id=2, expected_score=3)
    await run_test("Diagonale 1 (\\)",         [1,0,0, 0,1,0, 0,0,1], expected_id=3, expected_score=3)
    await run_test("Diagonale 2 (/)",          [0,0,1, 0,1,0, 1,0,0], expected_id=4, expected_score=3)
    
    # Lignes imparfaites (Tolérance grâce au seuil de 2. Score : +2, -0 = 2)
    await run_test("Ligne Horizontale (2px)",  [1,1,0, 0,0,0, 0,0,0], expected_id=1, expected_score=2)
    await run_test("Ligne Verticale (2px)",    [1,0,0, 1,0,0, 0,0,0], expected_id=2, expected_score=2)
    
    # Tests de Bruit / Rejet
    await run_test("Bruit (Vide)",             [0,0,0, 0,0,0, 0,0,0], expected_id=0, expected_score=0)
    
    # Si tout est allumé, le NPU fait : +3 bons pixels, mais -6 mauvais pixels = Score de -3 !
    await run_test("Bruit (Plein)",            [1,1,1, 1,1,1, 1,1,1], expected_id=0, expected_score=-3)
    
    # Si on allume la colonne du milieu, ce n'est pas la colonne de gauche attendue. 
    # Bon pixels pour "Gauche" : 0. Mauvais pixels : 3. Score = -3.
    # Mais le Max_pooling va trouver un meilleur score ailleurs (ex: score_h = -1). Max = -1.
    await run_test("Rejet Ligne Milieu",       [0,1,0, 0,1,0, 0,1,0], expected_id=0, expected_score=-1)

    dut._log.info("🎉 Tous les tests Éducatifs sont passés avec succès ! La logique RTL et le décodage score/ID fonctionnent.")