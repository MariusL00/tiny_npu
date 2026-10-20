# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

def expected_output(p_array, mux_sel):
    # Les mêmes poids spatiaux que le Verilog
    w_HH = [ 1,  1,  1, -1, -1, -1, -1, -1, -1]
    w_HM = [-1, -1, -1,  1,  1,  1, -1, -1, -1]
    w_HB = [-1, -1, -1, -1, -1, -1,  1,  1,  1]

    w_VG = [ 1, -1, -1,  1, -1, -1,  1, -1, -1]
    w_VM = [-1,  1, -1, -1,  1, -1, -1,  1, -1]
    w_VD = [-1, -1,  1, -1, -1,  1, -1, -1,  1]

    w_D1 = [ 1, -1, -1, -1,  1, -1, -1, -1,  1]
    w_D2 = [-1, -1,  1, -1,  1, -1,  1, -1, -1]

    # Couche 1 : MACs
    s_HH = sum(p * w for p, w in zip(p_array, w_HH))
    s_HM = sum(p * w for p, w in zip(p_array, w_HM))
    s_HB = sum(p * w for p, w in zip(p_array, w_HB))

    s_VG = sum(p * w for p, w in zip(p_array, w_VG))
    s_VM = sum(p * w for p, w in zip(p_array, w_VM))
    s_VD = sum(p * w for p, w in zip(p_array, w_VD))

    s_D1 = sum(p * w for p, w in zip(p_array, w_D1))
    s_D2 = sum(p * w for p, w in zip(p_array, w_D2))

    # Couche 2 : Max Pooling
    max_H = max(s_HH, s_HM, s_HB)
    max_V = max(s_VG, s_VM, s_VD)
    max_global = max(max_H, max_V, s_D1, s_D2)

    # Couche 3 : Décision et Seuil
    is_H = max_H == max_global
    is_V = max_V == max_global
    is_D1 = s_D1 == max_global
    is_D2 = s_D2 == max_global

    exaequo = is_H + is_V + is_D1 + is_D2

    if max_global >= 2 and exaequo == 1:
        if is_H: pred = 1
        elif is_V: pred = 2
        elif is_D1: pred = 3
        else: pred = 4
    else:
        pred = 0

    # Multiplexeur de sortie (00: H, 01: V, 10: D1, 11: D2)
    if mux_sel == 0: selected_score = max_H
    elif mux_sel == 1: selected_score = max_V
    elif mux_sel == 2: selected_score = s_D1
    else: selected_score = s_D2

    # Conversion en complément à deux sur 5 bits
    score_5b = selected_score & 0x1F

    # Reconstitution du bus uo_out [score_5b (5 bits) | prediction (3 bits)]
    return (score_5b << 3) | pred


@cocotb.test()
async def test_project(dut):
    dut._log.info("Démarrage du Testbench TinyNPU 3x3")

    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    valid_count = 0

    # Test des 512 images possibles
    for i in range(512):
        # Extraction des 9 bits
        p_array = [(i >> bit) & 1 for bit in range(9)]
        ui_val = i & 0xFF        # ui_in[7:0] contient p[7:0]
        p8_val = (i >> 8) & 1    # uio_in[0] contient p[8]

        # Test des 4 canaux du multiplexeur pour chaque image
        for mux in range(4):
            # uio_in[2:1] = mux, uio_in[0] = p8
            uio_val = (mux << 1) | p8_val
            
            dut.ui_in.value = ui_val
            dut.uio_in.value = uio_val
            await ClockCycles(dut.clk, 1)

            actual = int(dut.uo_out.value)
            expected = expected_output(p_array, mux)

            assert actual == expected, (
                f"Erreur Image {i:09b} (mux={mux}): "
                f"Obtenu {actual:08b}, Attendu {expected:08b}"
            )

            # On n'affiche le log que si la prédiction est valide 
            # et qu'on est sur le premier canal (pour ne pas l'afficher 4 fois)
            pred = actual & 0x07
            if mux == 0 and pred != 0:
                valid_count += 1
                classes = ["INCONNU", "Hori", "Vert", "Diag1", "Diag2"]
                dut._log.info(f"Forme Reconnue ! Entrée: {i:09b} -> Classe: {classes[pred]}")

    dut._log.info(f"SUCCÈS : Les 2048 tests sont passés ! ({valid_count} formes trouvées via Max Pooling)")
